import { publicRecord, type PublicHistoryRecord } from '../../src/microcover/arkivRecords'
import { canonical, hash, type Activation, type Receipt } from './model'
import { evaluateSnapshot } from './core'
import { EvidenceStore } from './store'

export function snapshotRecords(a:Activation, receipts:Receipt[]):PublicHistoryRecord[]{
  const prefix=receipts.filter(r=>r.receivedAt<=a.outcomeDeadline)
  const evaluation=evaluateSnapshot(a,prefix,a.outcomeDeadline)
  const pages:PublicHistoryRecord[]=[]
  for(let i=0;i<prefix.length;i+=30){
    pages.push(publicRecord(a,'EVIDENCE_PAGE',{schema:'microcover-public-page-v1',domain:a.domain,
      sourceGroup:'team-controlled',receiptTimestamp:prefix[i]!.receivedAt,
      previousHash:prefix[i]!.previousHash,receipts:prefix.slice(i,i+30)}))
  }
  pages.push(publicRecord(a,'SNAPSHOT',{schema:'microcover-public-snapshot-v1',activation:a,
    evaluation,pages:pages.map(p=>p.recordId),disclosure:a.policy.disclosure}))
  return pages
}
/** Durable append-only public outbox. Stable IDs survive retries/restarts; no signer here. */
export function enqueueHistory(store:EvidenceStore,records:PublicHistoryRecord[]):void{
  for(const r of records){
    const key=`arkiv-outbox:${r.consumer}:${r.guaranteeId}:${r.recordId}`
    const old=store.setting(key)
    if(old&&old!==canonical(r))throw Error('OUTBOX_COLLISION')
    store.setSetting(key,canonical(r))
  }
}
export function queuedHistory(store:EvidenceStore,consumer:string,id:string):PublicHistoryRecord[]{
  return store.settingsWithPrefix(`arkiv-outbox:${consumer}:${id}:`).map(v=>JSON.parse(v) as PublicHistoryRecord)
    // Earlier local-only preparation omitted event timestamps. Never publish that incomplete draft.
    .filter(r=>r.recordType!=='ARC_EVENT'||Number.isSafeInteger((JSON.parse(r.body) as {receiptTimestamp?:number}).receiptTimestamp))
}
export const activationKey=(a:Activation)=>hash(a.domain)
