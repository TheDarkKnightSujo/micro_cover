import { hexToBytes, type Hex } from 'viem'
import { gunzipSync } from 'node:zlib'
import { ARKIV_RPC, ARKIV_WRITER, historyQuery, type HistoryKind, type PublicHistoryRecord } from '../../src/microcover/arkivRecords'
import { hash } from '../../src/microcover/evidenceCanonical'

const READ_METHODS=new Set(['eth_chainId','eth_blockNumber','eth_getBlockByNumber','eth_getTransactionReceipt','eth_getTransactionByHash','eth_getTransactionCount','eth_getBalance','eth_gasPrice','eth_maxPriorityFeePerGas','eth_feeHistory','eth_estimateGas','eth_call'])
/** Keyed transport for SDK estimation/receipt reads. Never forwards a signing or broadcast method. */
export async function forwardArkivRead(input:unknown){
  const r=input as {id?:unknown;method?:unknown;params?:unknown[]}
  const params=r?.params??[]
  if(!r||typeof r.method!=='string'||!READ_METHODS.has(r.method)||!Array.isArray(params)||params.length>5)throw Error('READ_METHOD_NOT_ALLOWED')
  if(['eth_call','eth_estimateGas'].includes(r.method)){
    const tx=params[0] as {to?:string;from?:string;value?:string}
    if(tx?.to?.toLowerCase()!=='0x4400000000000000000000000000000000000044'||tx.from&&tx.from.toLowerCase()!==ARKIV_WRITER||tx.value&&BigInt(tx.value)!==0n)throw Error('UNSUPPORTED_ESTIMATE_TARGET')
  }
  const key=process.env.ARKIV_ACCESS_KEY??''
  const response=await fetch(ARKIV_RPC+(key?'/'+encodeURIComponent(key):''),{method:'POST',headers:{'content-type':'application/json'},signal:AbortSignal.timeout(20000),body:JSON.stringify({jsonrpc:'2.0',id:1,method:r.method,params})})
  const result=await response.json() as {result?:unknown;error?:unknown}
  if(!response.ok||result.error||!Object.hasOwn(result,'result'))throw Error('ARKIV_READ_UNAVAILABLE')
  return{jsonrpc:'2.0',id:typeof r.id==='number'||typeof r.id==='string'?r.id:null,result:result.result}
}

/** Public read proxy: an optional RPC access key stays server-side; errors never expose its URL. */
export async function readArkiv(consumer:string,id:string,type?:HistoryKind,after?:Hex){
  const query=historyQuery(consumer,id,type,after)
  const key=process.env.ARKIV_ACCESS_KEY??''
  const response=await fetch(ARKIV_RPC+(key?'/'+encodeURIComponent(key):''),{
    method:'POST',headers:{'content-type':'application/json'},signal:AbortSignal.timeout(15000),
    body:JSON.stringify({jsonrpc:'2.0',id:1,method:'arkiv_query',params:[query,{select:{key:true,owner:true,creator:true,attributes:true,creationFlags:true,expiresAt:true},limit:'0x64'}]})})
  if(!response.ok)throw Error('ARKIV_UNAVAILABLE')
  const data=await response.json() as {error?:unknown;result?:{data?:unknown[];blockNumber?:Hex}}
  if(data.error||!data.result||!Array.isArray(data.result.data))throw Error('ARKIV_UNAVAILABLE_OR_INCOMPATIBLE')
  const records=data.result.data.map(input=>{
    const row=input as {key:Hex;owner:string;creator:string;expiresAt:Hex;creationFlags:{readonly:boolean};attributes:{name:string;type:string;value:unknown}[]}
    if(!/^0x[0-9a-f]{64}$/.test(row.key)||row.owner?.toLowerCase()!==ARKIV_WRITER||row.creator?.toLowerCase()!==ARKIV_WRITER||!row.creationFlags?.readonly||!Array.isArray(row.attributes))throw Error('UNTRUSTED_ARKIV_ENTITY')
    const attributes=Object.fromEntries(row.attributes.map(a=>[a.name,a.value]))
    if(attributes.bodyEncoding!=='gzip-json-v1')throw Error('UNSUPPORTED_HISTORY_ENCODING')
    const body=gunzipSync(hexToBytes(attributes.body as Hex),{maxOutputLength:60000}).toString('utf8')
    const record={recordId:attributes.recordId,consumer:attributes.consumer,guaranteeId:attributes.guaranteeId,cohortId:attributes.cohortId,recordType:attributes.recordType,bodyHash:attributes.bodyHash,body} as PublicHistoryRecord
    if(record.consumer!==consumer||record.guaranteeId!==id||!['SNAPSHOT','EVIDENCE_PAGE','ARC_EVENT'].includes(record.recordType)||typeof record.body!=='string'||record.body.length>60000||hash(JSON.parse(record.body))!==record.bodyHash||!/^0x[0-9a-f]+$/.test(row.expiresAt))throw Error('INVALID_ARKIV_RECORD')
    return {entityKey:row.key,expiresAt:row.expiresAt,record}
  })
  return{source:'ARKIV_RABDI_LIVE_RPC' as const,query,block:data.result.blockNumber,writer:ARKIV_WRITER,records,next:records.length===100?records.at(-1)!.entityKey:null,readAt:Date.now()}
}
