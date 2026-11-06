import { hash } from '../../src/microcover/evidenceCanonical'
import { evaluateSnapshot } from '../../services/evidence/core'
import type { Activation, Receipt } from '../../services/evidence/types'

export interface Snapshot { activation: Activation; receipts: Receipt[] }
export interface Binding { consumer: string; guaranteeId: string; cohortId: string; policyHash: string; conditionHash: string; createdAt: number; outcomeDeadline: number }
/** Recompute the public append log. Authentication remains at the trusted collector. */
export function evaluateBoundSnapshot(snapshot: Snapshot, binding: Binding, now: number) {
  const a = snapshot.activation, d = a.domain, p = a.policy
  if (d.chainId !== '5042002' || d.consumer !== binding.consumer.toLowerCase() || d.guaranteeId !== binding.guaranteeId ||
      d.cohortId !== binding.cohortId || d.policyHash !== binding.policyHash || d.conditionHash !== binding.conditionHash ||
      a.activatedAt !== binding.createdAt || a.outcomeDeadline !== binding.outcomeDeadline || hash(p) !== binding.policyHash) throw Error('WRONG_EVIDENCE_DOMAIN')
  if(p.version!=='synthetic-unanimous-v1'||p.intervalSeconds!==10||p.freshnessSeconds!==60||p.cutoff!=='RECEIVED_BY_OUTCOME_DEADLINE'||
      p.conditionHash!==d.conditionHash||p.sources.length!==2||p.disclosure!=='Both demo feeds are controlled by the same team; not independent sources.') throw Error('UNSUPPORTED_POLICY')
  for(const id of ['synthetic-status-a','synthetic-status-b']) {
    const source=p.sources.filter(s=>s.id===id)
    if(source.length!==1||source[0].weight!==1||source[0].group!=='team-controlled')throw Error('UNSUPPORTED_SOURCES')
  }
  if(!Array.isArray(snapshot.receipts)||snapshot.receipts.length>1000)throw Error('INVALID_RECEIPTS')
  let previous=`0x${'0'.repeat(64)}`, time=a.activatedAt
  const nonces=new Map<string,bigint>()
  for(const [i,r] of snapshot.receipts.entries()) {
    const {hash: recorded,...body}=r
    const source=p.sources.find(s=>s.id===r.sourceId)
    if(!source||hash(body)!==recorded||r.previousHash!==previous||r.sequence!==i+1||r.domainKey!==hash(d)||
      r.group!=='team-controlled'||r.keyFingerprint!==hash(source.publicKeyDer)||!Number.isSafeInteger(r.receivedAt)||
      r.receivedAt<time||r.receivedAt>a.outcomeDeadline||!['OBSERVATION','INVALID','UNAVAILABLE'].includes(r.kind))throw Error('INVALID_RECEIPT_LOG')
    if(r.kind==='OBSERVATION') {
      if(!['FULFILLED','CANCELLED','UNKNOWN'].includes(r.status??'')||r.sourceTimestamp===null||!Number.isSafeInteger(r.sourceTimestamp)||
        r.sourceTimestamp<a.activatedAt||r.sourceTimestamp>r.receivedAt||!r.nonce||!/^(0|[1-9]\d{0,39})$/.test(r.nonce)||
        (nonces.has(r.sourceId)&&BigInt(r.nonce)<=nonces.get(r.sourceId)!))throw Error('INVALID_OBSERVATION_RECEIPT')
      nonces.set(r.sourceId,BigInt(r.nonce))
    }
    previous=recorded;time=r.receivedAt
  }
  return evaluateSnapshot(a,snapshot.receipts,now)
}
