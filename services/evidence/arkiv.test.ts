import { expect, test } from 'bun:test'
import { mkdtempSync } from 'node:fs'
import { join } from 'node:path'
import { EvidenceStore } from './store'
import { testActivation, testTempRoot, removeTestDirectory } from './test-support'
import { enqueueHistory, queuedHistory, snapshotRecords } from './arkiv-outbox'
import { ARKIV_WRITER, encodeHistoryBody, historyQuery, publicRecord, validateRecord, verifyReceiptPrefix } from '../../src/microcover/arkivRecords'
import { gunzipSync } from 'node:zlib'
import { checkHistory, publishHistory } from '../../src/microcover/arkivClient'
import { hash } from './model'
import { forwardArkivRead, readArkiv } from './arkiv-reader'
import type { GuaranteeView } from '../../src/microcover/useGuarantee'
import { bytesToHex, type EIP1193Provider } from 'viem'

function fixture(){
  const dir=mkdtempSync(join(testTempRoot(),'microcover-arkiv-test-'))
  const store=new EvidenceStore(dir),f=testActivation(),key=store.activate(f.a)
  store.append(key,'synthetic-status-a',0,1090,f.envelope('synthetic-status-a','1',1090))
  store.append(key,'synthetic-status-b',0,1090,f.envelope('synthetic-status-b','1',1090))
  const receipts=store.verified(key),records=snapshotRecords(f.a,receipts)
  const snapshot=JSON.parse(records.at(-1)!.body) as {evaluation:{evidenceRoot:`0x${string}`}}
  const g={forId:1n,cohortId:f.a.domain.cohortId,policyHash:f.a.domain.policyHash,termsHash:f.a.domain.conditionHash,createdAt:1000n,settlementTime:1100n,latestEvidenceRoot:snapshot.evaluation.evidenceRoot} as GuaranteeView
  return{dir,store,f,key,receipts,records,g,close:()=>{store.close();removeTestDirectory(dir)}}
}
test('durable outbox retry deduplicates stable IDs and preserves private-envelope exclusion',()=>{
  const x=fixture()
  try{
    enqueueHistory(x.store,x.records);enqueueHistory(x.store,snapshotRecords(x.f.a,x.receipts))
    expect(queuedHistory(x.store,x.f.a.domain.consumer,'1')).toHaveLength(2)
    const reopened=new EvidenceStore(x.dir)
    expect(queuedHistory(reopened,x.f.a.domain.consumer,'1')).toEqual(queuedHistory(x.store,x.f.a.domain.consumer,'1'));reopened.close()
    const publicJson=JSON.stringify(x.records)
    expect(publicJson).not.toContain('PRIVATE KEY');expect(publicJson).not.toContain('"payload":')
    expect(publicJson).toContain('team-controlled')
  }finally{x.close()}
})
test('complete public receipt chain matches Arc anchor; missing, reordered, tampered or wrong-domain history fails',()=>{
  const x=fixture()
  try{
    expect(checkHistory(x.records,x.f.a.domain.consumer,x.g).anchored).toBe(true)
    expect(()=>checkHistory(x.records.slice(1),x.f.a.domain.consumer,x.g)).toThrow()
    expect(()=>checkHistory(x.records,'0x'+'34'.repeat(20),x.g)).toThrow()
    expect(()=>checkHistory(x.records,x.f.a.domain.consumer,{...x.g,forId:2n})).toThrow()
    const changed=structuredClone(x.records);changed[0]!.body+=' '
    expect(()=>checkHistory(changed,x.f.a.domain.consumer,x.g)).toThrow()
    expect(verifyReceiptPrefix(x.f.a,[...x.receipts].reverse(),x.g.latestEvidenceRoot,2)).toBe(false)
    const altered=structuredClone(x.receipts);altered[0]!.status='CANCELLED'
    expect(verifyReceiptPrefix(x.f.a,altered,x.g.latestEvidenceRoot,2)).toBe(false)
    expect(checkHistory(x.records,x.f.a.domain.consumer,{...x.g,latestEvidenceRoot:hash('other')}).anchored).toBe(false)
  }finally{x.close()}
})
test('snapshot outcome cannot be relabelled even with a recomputed public body hash',()=>{
  const x=fixture()
  try{
    const content=JSON.parse(x.records.at(-1)!.body) as {evaluation:{outcome:string}}
    content.evaluation.outcome='FAILURE'
    const forged=publicRecord(x.f.a,'SNAPSHOT',content)
    expect(()=>checkHistory([x.records[0]!,forged],x.f.a.domain.consumer,x.g)).toThrow('Stored outcome')
    const mutated={...x.records[0]!,cohortId:hash('wrong')}
    expect(()=>validateRecord(mutated,x.f.a)).toThrow()
  }finally{x.close()}
})
test('query scopes schema, creator, owner, guarantee and type; rejects injected literals',()=>{
  const consumer=`0x${'12'.repeat(20)}`
  const q=historyQuery(consumer,'1','ARC_EVENT')
  expect(q).toContain(`$creator = addr(${ARKIV_WRITER})`);expect(q).toContain('$owner');expect(q).toContain('ORDER BY $key ASC')
  for(const id of ["1') OR true",'0','-1'])expect(()=>historyQuery(consumer,id)).toThrow()
})
test('browser gzip transport round trips exact canonical bytes and preserves record hashes',async()=>{
  const x=fixture()
  try{
    for(const r of x.records){
      const bytes=await encodeHistoryBody(r.body)
      expect(gunzipSync(bytes,{maxOutputLength:60000}).toString('utf8')).toBe(r.body)
      expect(hash(JSON.parse(gunzipSync(bytes).toString('utf8')))).toBe(r.bodyHash)
    }
    await expect(encodeHistoryBody('a'.repeat(60001))).rejects.toThrow('HISTORY_RECORD_TOO_LARGE')
  }finally{x.close()}
})
test('Arkiv outage never becomes an empty-success history response',async()=>{
  const saved=globalThis.fetch
  globalThis.fetch=(async()=>new Response('rate limited',{status:429})) as unknown as typeof fetch
  try{await expect(readArkiv(`0x${'12'.repeat(20)}`,'1')).rejects.toThrow('ARKIV_UNAVAILABLE')}
  finally{globalThis.fetch=saved}
})
test('live reader decodes gzip wire bytes, checks canonical hash and rejects a spoofed creator',async()=>{
  const x=fixture(),saved=globalThis.fetch
  try{
    const r=x.records.at(-1)!,compressed=await encodeHistoryBody(r.body)
    const entity={key:hash('entity'),owner:ARKIV_WRITER,creator:ARKIV_WRITER,expiresAt:'0x100000',creationFlags:{readonly:true},attributes:[
      ...Object.entries(r).filter(([k])=>k!=='body').map(([name,value])=>({name,type:'str',value})),
      {name:'bodyEncoding',type:'str',value:'gzip-json-v1'},{name:'body',type:'bytes',value:bytesToHex(compressed)}]}
    globalThis.fetch=(async()=>Response.json({result:{data:[entity],blockNumber:'0x123'}})) as unknown as typeof fetch
    const result=await readArkiv(x.f.a.domain.consumer,'1')
    expect(result.records[0]!.record).toEqual(r)
    entity.creator=`0x${'34'.repeat(20)}` as typeof ARKIV_WRITER
    await expect(readArkiv(x.f.a.domain.consumer,'1')).rejects.toThrow('UNTRUSTED_ARKIV_ENTITY')
  }finally{globalThis.fetch=saved;x.close()}
})
test('keyed RPC proxy refuses broadcast, signing and estimates to arbitrary contracts',async()=>{
  for(const method of ['eth_sendTransaction','eth_sendRawTransaction','personal_sign','eth_signTypedData_v4'])await expect(forwardArkivRead({method,params:[]})).rejects.toThrow('READ_METHOD_NOT_ALLOWED')
  await expect(forwardArkivRead({method:'eth_estimateGas',params:[{to:`0x${'12'.repeat(20)}`}]})).rejects.toThrow('UNSUPPORTED_ESTIMATE_TARGET')
})
test('ambiguous browser attempt blocks another wallet request',async()=>{
  const oldNavigator=Object.getOwnPropertyDescriptor(globalThis,'navigator'),oldStorage=Object.getOwnPropertyDescriptor(globalThis,'localStorage')
  Object.defineProperty(globalThis,'navigator',{configurable:true,value:{locks:{request:async(_name:unknown,_options:unknown,fn:(lock:object)=>unknown)=>fn({})}}})
  Object.defineProperty(globalThis,'localStorage',{configurable:true,value:{getItem:()=>JSON.stringify({ids:['pending']})}})
  let calls=0
  try{
    await expect(publishHistory({request:async()=>{calls++;return []}} as unknown as EIP1193Provider,'1',[],()=>undefined)).rejects.toThrow('unknown status')
    expect(calls).toBe(0)
  }finally{
    if(oldNavigator)Object.defineProperty(globalThis,'navigator',oldNavigator);else Reflect.deleteProperty(globalThis,'navigator')
    if(oldStorage)Object.defineProperty(globalThis,'localStorage',oldStorage);else Reflect.deleteProperty(globalThis,'localStorage')
  }
})
