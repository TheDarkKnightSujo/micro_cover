import { hash } from '../../src/microcover/evidenceCanonical'
import type { Activation, Receipt } from './types'
import type { Hex } from 'viem'
const ZERO = ('0x' + '0'.repeat(64)) as Hex

export interface Evaluation {
  domain: Activation['domain']
  policyVersion: Activation['policy']['version']
  asOf: number
  outcome: 'SUCCESS' | 'FAILURE' | 'UNCERTAIN'
  reason: string
  coveredSources: number
  requiredSources: 2
  totalWeight: 2
  successSupportBps: number
  failureSupportBps: number
  sourceGroupCount: 1
  independentSourcesClaimed: false
  evidenceRoot: Hex
  receiptRoot: Hex
  receiptCount: number
  sources: { id:string; usable:boolean; status:string|null; reason:string }[]
}

/** Pure snapshot decision function; a future orchestrator can supply independently verified receipts. */
export function evaluateSnapshot(a:Activation, input:readonly Receipt[], now:number, integrity=true):Evaluation {
  if(!Number.isSafeInteger(now)||now<0)throw Error('INVALID_EVALUATION_TIME')
  const receipts=input.filter(r=>r.receivedAt<=a.outcomeDeadline)
  const receiptRoot=receipts[receipts.length-1]?.hash??ZERO
  const evidenceRoot=integrity ? hash({schema:'microcover-log-root-v1',activationHash:hash(a),receiptRoot,receiptCount:receipts.length}) : ZERO
  const sources=a.policy.sources.map(source=>{
    const latest=[...receipts].reverse().find(r=>r.sourceId===source.id)
    if(!latest) return {id:source.id,usable:false,status:null,reason:'MISSING'}
    if(latest.kind!=='OBSERVATION') return {id:source.id,usable:false,status:null,reason:latest.kind}
    if(latest.sourceTimestamp===null || latest.sourceTimestamp<a.outcomeDeadline-a.policy.freshnessSeconds ||
       latest.sourceTimestamp>a.outcomeDeadline || latest.receivedAt<a.activatedAt) return {id:source.id,usable:false,status:null,reason:'STALE'}
    return {id:source.id,usable:true,status:latest.status,reason:latest.status==='UNKNOWN'?'EXPLICIT_UNKNOWN':'AUTHENTICATED'}
  })
  const covered=sources.filter(s=>s.usable).length
  const success=sources.filter(s=>s.usable&&s.status==='FULFILLED').length
  const failure=sources.filter(s=>s.usable&&s.status==='CANCELLED').length
  let outcome:Evaluation['outcome']='UNCERTAIN'
  let reason='INSUFFICIENT_COVERAGE'
  if(!integrity) reason='INTEGRITY_FAILURE'
  else if(now<a.outcomeDeadline) reason='NOT_DUE'
  else if(covered<2) reason='INSUFFICIENT_COVERAGE'
  else if(success===2){outcome='SUCCESS';reason='MATCHING_EXPLICIT_FULFILLED'}
  else if(failure===2){outcome='FAILURE';reason='MATCHING_EXPLICIT_CANCELLED'}
  else reason=sources.some(s=>s.status==='UNKNOWN')?'EXPLICIT_UNKNOWN':'CONFLICTING_STATUSES'
  return {domain:a.domain,policyVersion:a.policy.version,asOf:a.outcomeDeadline,outcome,reason,coveredSources:covered,requiredSources:2,totalWeight:2,
    successSupportBps:success*5000,failureSupportBps:failure*5000,sourceGroupCount:1,independentSourcesClaimed:false,
    evidenceRoot,receiptRoot,receiptCount:receipts.length,sources}
}

export interface EvidenceReport {
  chainId: bigint
  consumer: `0x${string}`
  guaranteeId: bigint
  cohortId: Hex
  policyHash: Hex
  evidenceRoot: Hex
  outcome: number
  evaluatedAt: bigint
  validUntil: bigint
  nonce: bigint
}
/** Preparation only. No wallet import, signing, broadcast or provider admission fallback. */
export function prepareReport(e:Evaluation, chainNow:number, nextVerdictNonce:bigint): EvidenceReport {
  if(e.outcome==='UNCERTAIN'||e.evidenceRoot===ZERO) throw Error('NO_ESTABLISHED_VERDICT')
  if(!Number.isSafeInteger(chainNow)||chainNow<e.asOf||nextVerdictNonce<1n) throw Error('INVALID_REPORT_TIME_OR_NONCE')
  return {chainId:BigInt(e.domain.chainId),consumer:e.domain.consumer as `0x${string}`,guaranteeId:BigInt(e.domain.guaranteeId),cohortId:e.domain.cohortId,
    policyHash:e.domain.policyHash,evidenceRoot:e.evidenceRoot,outcome:e.outcome==='SUCCESS'?2:1,evaluatedAt:BigInt(chainNow),validUntil:BigInt(chainNow+60),nonce:nextVerdictNonce}
}
