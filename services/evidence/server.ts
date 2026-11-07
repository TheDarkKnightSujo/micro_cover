import { savePresentation } from './presentation'
import type { PresentationRecord } from '../../src/microcover/presentation'
import type { Address } from 'viem'
import { readFileSync } from 'node:fs'
import { publicCreRun } from './cre-run'
import { hash, SOURCE_IDS } from './model'
import { EvidenceStore } from './store'
import { Collector } from './collector'
import { evaluate } from './evaluator'
import { fixtureResponse, loadPolicy } from './demo'
import { ChainObserver } from './chain'
import { queuedHistory } from './arkiv-outbox'
import { forwardArkivRead, readArkiv } from './arkiv-reader'
import type { HistoryKind } from '../../src/microcover/arkivRecords'
import type { Hex } from 'viem'

const json=(data:unknown,status=200,headers:Record<string,string>={})=>new Response(JSON.stringify(data,(_,v)=>typeof v==='bigint'?v.toString():v),{status,headers:{'content-type':'application/json','cache-control':'no-store',...headers}})
export function serveEvidence(directory:string,consumer:Address|undefined,port=8787){
  const store=new EvidenceStore(directory)
  const policy=loadPolicy(directory)
  const observer=consumer?new ChainObserver(consumer,policy,store):undefined
  let chainError=consumer?'CHECKING':'PHASE3_ADDRESS_NOT_CONFIGURED'
  let lastDiscovery=0
  const collector=new Collector(store,async(source,a,slot)=>{
    // Real HTTP polling of two authenticated, named, same-team synthetic feed routes.
    const response=await fetch(`http://127.0.0.1:${server.port}/demo-feed/${source}/${hash(a.domain)}/${slot}`,{signal:AbortSignal.timeout(2000)})
    if(!response.ok)throw Error('FEED_UNAVAILABLE')
    return response.json()
  })
  const server=Bun.serve({hostname:'127.0.0.1',port,async fetch(request){
    const url=new URL(request.url)
    if(!['127.0.0.1','localhost'].includes(url.hostname))return json({error:'INVALID_HOST'},403)
    const origin=request.headers.get('origin')
    if(origin && !['http://127.0.0.1:5173','http://localhost:5173'].includes(origin))return json({error:'ORIGIN_NOT_ALLOWED'},403)
    const headers:Record<string,string>=origin?{'access-control-allow-origin':origin,'vary':'Origin'}:{}
    if((url.pathname==='/api/arkiv/v1/rpc'||url.pathname==='/api/evidence/v1/presentations')&&request.method==='OPTIONS'){
      if(!origin||request.headers.get('access-control-request-method')!=='POST'||
        (request.headers.get('access-control-request-headers')??'').split(',').some(h=>h.trim()&&h.trim().toLowerCase()!=='content-type'))return json({error:'PREFLIGHT_NOT_ALLOWED'},403,headers)
      return new Response(null,{status:204,headers:{...headers,'access-control-allow-methods':'POST','access-control-allow-headers':'content-type'}})
    }
    if(url.pathname==='/api/arkiv/v1/rpc'&&request.method==='POST'){
      try{
        if(!request.headers.get('content-type')?.startsWith('application/json'))throw Error('JSON_REQUIRED')
        const raw=await request.text()
        if(raw.length>2000000)throw Error('REQUEST_TOO_LARGE')
        return json(await forwardArkivRead(JSON.parse(raw) as unknown),200,headers)
      }catch{return json({jsonrpc:'2.0',id:null,error:{code:-32000,message:'Arkiv read unavailable or method not permitted'}},200,headers)}
    }
    if(url.pathname==='/api/evidence/v1/presentations' && request.method==='POST'){
      if(!observer||!consumer||chainError)return json({error:'CHAIN_UNAVAILABLE'},503,headers)
      try{
        if(!request.headers.get('content-type')?.startsWith('application/json'))throw Error('JSON_REQUIRED')
        const reader=request.body?.getReader();const parts:Uint8Array[]=[];let size=0
        if(reader)for(;;){const c=await reader.read();if(c.done)break;size+=c.value.length;if(size>8192){await reader.cancel();return json({error:'TOO_LARGE'},413,headers)}parts.push(c.value)}
        const record=JSON.parse(await new Blob(parts as BlobPart[]).text()) as PresentationRecord
        return json(await savePresentation(store,record,consumer,observer),200,headers)
      }catch{return json({error:'EVENT_DETAILS_NOT_VERIFIED_OR_NOT_COMMITTED'},409,headers)}
    }
    if(request.method!=='GET')return json({error:'READ_ONLY_API'},405,headers)
    try{
      const presentation=url.pathname.match(/^\/api\/evidence\/v1\/presentations(?:\/([1-9]\d{0,17}))?$/)
      if(presentation){
        if(!consumer)return json({error:'CONTRACT_NOT_CONFIGURED'},503,headers)
        const prefix=`presentation:${consumer.toLowerCase()}:`
        if(presentation[1]){
          const body=store.setting(prefix+presentation[1])
          return body?json(JSON.parse(body),200,headers):json({error:'NO_CONCERT_CONTEXT'},404,headers)
        }
        const provider=url.searchParams.get('provider')?.toLowerCase()
        if(!provider || !/^0x[0-9a-f]{40}$/.test(provider))return json({error:'PROVIDER_REQUIRED'},400,headers)
        return json({records:store.settingsWithPrefix(prefix).map(v=>JSON.parse(v) as PresentationRecord).filter(r=>r.presentation.provider===provider).slice(0,100)},200,headers)
      }
      const history=url.pathname.match(/^\/api\/arkiv\/v1\/guarantees\/([1-9]\d{0,17})(\/queue)?$/)
      if(history){
        if(!consumer)return json({error:'CONTRACT_NOT_CONFIGURED'},503,headers)
        if(history[2])return json({records:queuedHistory(store,consumer.toLowerCase(),history[1])},200,headers)
        try{return json(await readArkiv(consumer.toLowerCase(),history[1],url.searchParams.get('type') as HistoryKind|null??undefined,url.searchParams.get('after') as Hex|null??undefined),200,headers)}
        catch{return json({error:'ARKIV_HISTORY_UNAVAILABLE',source:'ARKIV_RABDI_LIVE_RPC',moneyAuthority:'ARC_UNCHANGED'},503,headers)}
      }
      if(url.pathname==='/api/evidence/v1/policy')return json({policy,policyHash:hash(policy),disclosure:policy.disclosure,chainError,consumer:consumer??null},200,headers)
      if(url.pathname==='/api/evidence/v1/health')return json({service:'microcover-evidence-demo',chainError,activeGuarantees:store.activations().length},200,headers)
      const fixture=url.pathname.match(/^\/demo-feed\/(synthetic-status-[ab])\/(0x[0-9a-f]{64})\/(\d{1,12})$/)
      if(fixture){
        // Fixture response is deliberately synthetic/nonpersonal; raw stored envelopes have no read endpoint.
        if(origin)return json({error:'FIXTURE_TRANSPORT_INTERNAL'},403,headers)
        const a=store.activation(fixture[2])
        if(!SOURCE_IDS.includes(fixture[1] as typeof SOURCE_IDS[number]))return json({error:'UNKNOWN_SOURCE'},404,headers)
        return json(fixtureResponse(directory,store,fixture[1] as typeof SOURCE_IDS[number],a,Number(fixture[3]),Math.floor(Date.now()/1000)))
      }
      const match=url.pathname.match(/^\/api\/evidence\/v1\/guarantees\/([1-9]\d{0,17})(\/(?:prepare|snapshot|cre))?$/)
      if(match){
        if(!observer||chainError)return json({error:chainError||'CHAIN_UNAVAILABLE'},503,headers)
        const id=BigInt(match[1])
        if(match[2]==='/cre'){
          for(const name of ['success','failure','uncertain']){
            try{return json(publicCreRun(JSON.parse(readFileSync(`docs/evidence/phase4/${name}.json`,'utf8')) as unknown,consumer!,id.toString()),200,headers)}catch{ /* Try only fixed local public record names. */ }
          }
          return json({error:'NO_MATCHING_CRE_SIMULATION'},404,headers)
        }
        if(match[2]==='/prepare')return json(await observer.prepare(id),200,headers)
        const key=await observer.activate(id)
        if(!key)return json({error:'NO_BOUND_EVIDENCE_POLICY'},409,headers)
        if(match[2]==='/snapshot'){
          const activation=store.activation(key)
          const receipts=store.verified(key).filter(r=>r.receivedAt<=activation.outcomeDeadline)
          // Bound simulator response size; no raw/private envelopes are exported.
          if(receipts.length>1000)return json({error:'SNAPSHOT_TOO_LARGE'},413,headers)
          return json({activation,receipts,trust:'Collector authenticated private envelopes; CRE rechecks public receipt integrity, not source signatures or truth.'},200,headers)
        }
        const evaluation=evaluate(store,key,Math.floor(Date.now()/1000))
        const after=Number(url.searchParams.get('after')??'0')
        if(!Number.isSafeInteger(after)||after<0)return json({error:'INVALID_CURSOR'},400,headers)
        const all=store.verified(key)
        return json({evaluation,receipts:all.filter(r=>r.sequence>after).slice(0,100),nextCursor:Math.min(after+100,all.length),disclosure:policy.disclosure},200,headers)
      }
      return json({error:'NOT_FOUND'},404,headers)
    }catch{
      // No raw upstream errors, signing material, paths, bodies or arbitrary JSON leaks.
      return json({error:'EVIDENCE_UNAVAILABLE_OR_INVALID'},503,headers)
    }
  }})
  let running=false
  const tick=async()=>{
    if(running)return
    running=true
    try{
      if(observer&&Date.now()-lastDiscovery>=10000){
        lastDiscovery=Date.now()
        try{await observer.discover();chainError=''}catch{chainError='CHAIN_OR_POLICY_UNAVAILABLE'}
      }
      // Previously frozen activations keep collecting during RPC outages. Discovery and
      // report preparation may fail closed without creating gaps in known feed history.
      await collector.tick()
    }catch{chainError='COLLECTOR_INTEGRITY_OR_STORAGE_ERROR'}finally{running=false}
  }
  void tick()
  const timer=setInterval(()=>void tick(),1000)
  return{server,store,stop:()=>{clearInterval(timer);server.stop(true);store.close()}}
}
