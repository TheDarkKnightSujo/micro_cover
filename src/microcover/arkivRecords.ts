import { bytes, defineSchema, str } from '@arkiv-network/sdk/schema'
import { canonical, hash } from './evidenceCanonical'
import type { Activation, Receipt } from '../../services/evidence/types'
import type { Hex } from 'viem'

export const ARKIV_WRITER = '0x1d39fc0e5293ab949d63217ffb375357adf3933f' as const
export const ARKIV_RPC = 'https://rpc.rabdi.db-chain.testnet.arkiv.network'
export const RETENTION_DAYS = 7
export const HistorySchema = defineSchema('microcover.public-history.v1', {
  recordId: str().indexed(), consumer: str().indexed(), guaranteeId: str().indexed(),
  cohortId: str().indexed(), recordType: str().indexed(), bodyHash: str(), bodyEncoding: str(), body: bytes(),
})
export type HistoryKind = 'EVIDENCE_PAGE' | 'SNAPSHOT' | 'ARC_EVENT'
export interface PublicHistoryRecord {
  recordId: Hex; consumer: string; guaranteeId: string; cohortId: Hex;
  recordType: HistoryKind; bodyHash: Hex; body: string
}
/** Compress only the transport bytes. IDs and commitments remain over the original canonical JSON. */
export async function encodeHistoryBody(body:string):Promise<Uint8Array>{
  if(new TextEncoder().encode(body).length>60000)throw Error('HISTORY_RECORD_TOO_LARGE')
  if(typeof CompressionStream==='undefined')throw Error('Browser gzip support is required before publishing.')
  const stream=new Blob([body]).stream().pipeThrough(new CompressionStream('gzip'))
  return new Uint8Array(await new Response(stream).arrayBuffer())
}
export function publicRecord(a: Activation, recordType: HistoryKind, value: unknown): PublicHistoryRecord {
  const body = canonical(value), bodyHash = hash(value)
  if(new TextEncoder().encode(body).length>60000)throw Error('HISTORY_RECORD_TOO_LARGE')
  return {recordId: hash({schema:HistorySchema.name,domain:a.domain,recordType,bodyHash}),
    consumer:a.domain.consumer, guaranteeId:a.domain.guaranteeId, cohortId:a.domain.cohortId,recordType,bodyHash,body}
}
export function validateRecord(r: PublicHistoryRecord, a: Activation): unknown {
  const value: unknown=JSON.parse(r.body)
  const expected=publicRecord(a,r.recordType,value)
  if(canonical(expected)!==canonical(r))throw Error('HISTORY_RECORD_INTEGRITY_OR_DOMAIN')
  return value
}
/** Verify the complete exported prefix; no claim about private payload truth or completeness. */
export function verifyReceiptPrefix(a: Activation, receipts: Receipt[], expectedRoot: Hex, count: number): boolean {
  let previous: Hex=`0x${'0'.repeat(64)}`
  if(receipts.length!==count)return false
  for(const [i,r] of receipts.entries()){
    const {hash: recorded,...body}=r
    if(hash(body)!==recorded||r.previousHash!==previous||r.sequence!==i+1||
      r.domainKey!==hash(a.domain)||r.receivedAt>a.outcomeDeadline)return false
    previous=recorded
  }
  return hash({schema:'microcover-log-root-v1',activationHash:hash(a),receiptRoot:previous,receiptCount:count})===expectedRoot
}
export function historyQuery(consumer:string,id:string,type?:HistoryKind,after?:Hex):string {
  if(!/^0x[0-9a-f]{40}$/.test(consumer)||! /^[1-9]\d{0,17}$/.test(id)||
    type!==undefined&&!['SNAPSHOT','EVIDENCE_PAGE','ARC_EVENT'].includes(type)||
    after!==undefined&&!/^0x[0-9a-f]{64}$/.test(after))throw Error('INVALID_HISTORY_QUERY')
  return `arkiv.schema = str('${HistorySchema.name}') AND $creator = addr(${ARKIV_WRITER}) AND $owner = addr(${ARKIV_WRITER}) AND consumer = str('${consumer}') AND guaranteeId = str('${id}')`+
    (type?` AND recordType = str('${type}')`:'')+(after?` AND $key > key(${after})`:'')+' ORDER BY $key ASC'
}
