import { createPublicClient, createWalletClient, ExpirationTime } from '@arkiv-network/sdk'
import { rabdi } from '@arkiv-network/sdk/chains'
import { custom, http, type EIP1193Provider, type Hex } from 'viem'
import { ARKIV_WRITER, encodeHistoryBody, HistorySchema, RETENTION_DAYS, validateRecord, verifyReceiptPrefix, type PublicHistoryRecord } from './arkivRecords'
import { hash } from './evidenceCanonical'
import type { Activation, Receipt } from '../../services/evidence/types'
import type { GuaranteeView } from './useGuarantee'
import { evaluateSnapshot } from '../../services/evidence/core'

const base=((import.meta.env as Record<string,string|undefined>|undefined)?.VITE_EVIDENCE_API_URL||'http://127.0.0.1:8787').replace(/\/$/,'')
export interface ArkivRow {entityKey:Hex;expiresAt:Hex;record:PublicHistoryRecord}
export interface ArkivHistory {rows:ArkivRow[];query:string;readAt:number;block:Hex}
export async function arkivGet(id:string,suffix=''):Promise<unknown>{
  const response=await fetch(`${base}/api/arkiv/v1/guarantees/${id}${suffix}`,{cache:'no-store',credentials:'omit',signal:AbortSignal.timeout(20000)})
  if(!response.ok)throw Error('Arkiv history is unavailable. Arc balances and settlement are unchanged.')
  return response.json()
}
export async function loadArkivHistory(id:string):Promise<ArkivHistory>{
  const rows:ArkivRow[]=[];let after:Hex|null=null,query='',block:Hex='0x0'
  for(let page=0;page<20;page++){
    const data=await arkivGet(id,after?`?after=${after}`:'') as {source:string;records:ArkivRow[];next:Hex|null;query:string;block:Hex}
    if(data.source!=='ARKIV_RABDI_LIVE_RPC'||!Array.isArray(data.records)||data.records.length>100)throw Error('Invalid Arkiv history response')
    rows.push(...data.records);query=data.query;block=data.block
    if(data.next===null)return{rows,query,block,readAt:Date.now()}
    if(!/^0x[0-9a-f]{64}$/.test(data.next)||data.next===after)throw Error('Invalid Arkiv cursor')
    after=data.next
  }
  throw Error('History exceeds the demo read limit; no partial integrity claim is made.')
}
export function checkHistory(records:PublicHistoryRecord[],contract:string,g:GuaranteeView){
  const snapshots=records.filter(r=>r.recordType==='SNAPSHOT')
  if(snapshots.length!==1)throw Error('One complete frozen snapshot is required for integrity checking.')
  const snapshot=JSON.parse(snapshots[0].body) as {activation:Activation;evaluation:{evidenceRoot:Hex;receiptCount:number;outcome:string;reason:string};pages:Hex[]}
  const a=snapshot.activation,d=a.domain
  if(d.chainId!=='5042002'||d.consumer!==contract.toLowerCase()||d.guaranteeId!==g.forId.toString()||d.cohortId!==g.cohortId||d.policyHash!==g.policyHash||d.conditionHash!==g.termsHash||hash(a.policy)!==g.policyHash||a.activatedAt!==Number(g.createdAt)||a.outcomeDeadline!==Number(g.settlementTime))throw Error('Arkiv snapshot does not match the selected Arc guarantee.')
  const unique=new Map<string,PublicHistoryRecord>()
  for(const r of records){
    validateRecord(r,a)
    if(unique.has(r.recordId)&&unique.get(r.recordId)!.body!==r.body)throw Error('Conflicting duplicate receipt')
    unique.set(r.recordId,r)
  }
  const receipts:Receipt[]=[]
  for(const id of snapshot.pages){
    const page=unique.get(id)
    if(!page||page.recordType!=='EVIDENCE_PAGE')throw Error('History is incomplete: a receipt page is missing or expired.')
    receipts.push(...(JSON.parse(page.body) as {receipts:Receipt[]}).receipts)
  }
  if(!verifyReceiptPrefix(a,receipts,snapshot.evaluation.evidenceRoot,snapshot.evaluation.receiptCount))throw Error('Receipt chain does not match the snapshot commitment.')
  const evaluated=evaluateSnapshot(a,receipts,a.outcomeDeadline)
  if(evaluated.outcome!==snapshot.evaluation.outcome||evaluated.reason!==snapshot.evaluation.reason)throw Error('Stored outcome disagrees with the deterministic evaluator.')
  return{...evaluated,anchored:g.latestEvidenceRoot===evaluated.evidenceRoot,records:[...unique.values()]}
}

const chain=rabdi({accessKey:''})
const publicClient=createPublicClient({chain,transport:http(`${base}/api/arkiv/v1/rpc`,{timeout:25000,retryCount:1})})
/** Only an explicit human click calls this. Persist an ambiguous attempt before wallet interaction. */
export async function publishHistory(provider:EIP1193Provider,id:string,records:PublicHistoryRecord[],onHash:(hash:Hex)=>void){
  if(!navigator.locks)throw Error('Browser transaction locking is unavailable; use current Edge or Chrome.')
  return navigator.locks.request('microcover-arkiv-publisher',{ifAvailable:true},async lock=>{
    if(!lock)throw Error('Another tab is publishing. Wait for that attempt.')
    const storageKey=`microcover:arkiv-attempt:${ARKIV_WRITER}:${id}`
    const old=localStorage.getItem(storageKey)
    if(old){
      const attempt=JSON.parse(old) as {hash?:Hex}
      if(!attempt.hash)throw Error('Previous wallet request has unknown status. Check MetaMask activity before clearing this browser attempt.')
      let receipt
      try{receipt=await publicClient.getTransactionReceipt({hash:attempt.hash})}catch{throw Error('Previous transaction is pending or unavailable. Do not submit again.')}
      if(receipt.status==='success'){
        const live=await loadArkivHistory(id)
        const existing=new Set(live.rows.map(row=>row.record.recordId))
        const attemptIds=(JSON.parse(old) as {ids:string[]}).ids
        if(attemptIds.some(id=>!existing.has(id as Hex)))throw Error('Previous write succeeded but is not queryable yet. Retry reads only.')
      }
      localStorage.removeItem(storageKey)
    }
    const accounts=await provider.request({method:'eth_accounts'})
    if(accounts[0]?.toLowerCase()!==ARKIV_WRITER)throw Error('Select Account 1, the proposed Arkiv writer, before publishing.')
    await provider.request({method:'wallet_switchEthereumChain',params:[{chainId:'0x76edaf'}]})
    if(await provider.request({method:'eth_chainId'})!=='0x76edaf')throw Error('Rabdi network is required.')
    const live=await loadArkivHistory(id),existing=new Map(live.rows.map(row=>[row.record.recordId,row.record.bodyHash]))
    for(const r of records)if(existing.has(r.recordId)&&existing.get(r.recordId)!==r.bodyHash)throw Error('Existing ID has different content; publication blocked.')
    const pending=records.filter(r=>!existing.has(r.recordId)).slice(0,20)
    if(!pending.length)return{written:0,remaining:0}
    const attempt:{ids:string[];hash?:Hex}={ids:pending.map(r=>r.recordId)}
    let walletRequested=false
    localStorage.setItem(storageKey,JSON.stringify(attempt))
    // Observe send hash immediately, before SDK receipt waiting. Never log transport errors/URLs.
    const transport=custom({async request(args:{method:string;params?:unknown}){
      if(args.method==='eth_sendTransaction'){
        const current=await provider.request({method:'eth_accounts'})
        if(current[0]?.toLowerCase()!==ARKIV_WRITER||await provider.request({method:'eth_chainId'})!=='0x76edaf')throw Error('Wallet account or network changed')
        walletRequested=true
        const result=await provider.request(args as Parameters<EIP1193Provider['request']>[0])
        attempt.hash=result as Hex;localStorage.setItem(storageKey,JSON.stringify(attempt));onHash(attempt.hash)
        return result
      }
      if(['eth_accounts','eth_chainId'].includes(args.method))return provider.request(args as Parameters<EIP1193Provider['request']>[0])
      return publicClient.request(args as Parameters<typeof publicClient.request>[0])
    }},{retryCount:0})
    const wallet=createWalletClient({chain,account:ARKIV_WRITER,transport})
    try{
      const creates=await Promise.all(pending.map(async r=>({schema:HistorySchema,
        values:{recordId:r.recordId,consumer:r.consumer,guaranteeId:r.guaranteeId,cohortId:r.cohortId,recordType:r.recordType,bodyHash:r.bodyHash,bodyEncoding:'gzip-json-v1',body:await encodeHistoryBody(r.body)},
        expiration:ExpirationTime.fromDays(RETENTION_DAYS),flags:{readonly:true,permissionlessExtension:true},salt:BigInt(r.recordId.slice(0,34))})))
      const result=await wallet.executeBatch({creates})
      onHash(result.txHash)
      const verified=await loadArkivHistory(id),found=new Set(verified.rows.map(row=>row.record.recordId))
      if(pending.some(r=>!found.has(r.recordId)))throw Error('Write confirmed; indexing is still pending. Retry reads, not writes.')
      localStorage.removeItem(storageKey)
      return{written:pending.length,remaining:records.filter(r=>!found.has(r.recordId)).length}
    }catch(error){
      if(!walletRequested){localStorage.removeItem(storageKey);throw Error('Arkiv preparation or gas estimate failed before any wallet transaction request. Restore read access first.')}
      let cause:unknown=error
      for(let i=0;i<8&&cause&&typeof cause==='object';i++){
        if('code' in cause&&cause.code===4001&&!attempt.hash){localStorage.removeItem(storageKey);throw Error('Cancelled in your wallet. No history write was submitted.')}
        cause='cause' in cause?cause.cause:null
      }
      throw Error(attempt.hash?'Transaction hash saved. Refresh history and inspect the transaction before any retry.':'Write was not confirmed. Check MetaMask activity before retrying; this attempt remains locked.')
    }
  })
}
