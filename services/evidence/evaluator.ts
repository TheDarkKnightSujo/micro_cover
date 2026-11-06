import type { Receipt } from './model'
import type { EvidenceStore } from './store'
import { evaluateSnapshot, type Evaluation } from './core'
export { evaluateSnapshot, prepareReport, type Evaluation, type EvidenceReport } from './core'

/** Pure deterministic cutoff snapshot. `now` only gates NOT_DUE, never changes a final snapshot. */
export function evaluate(store: EvidenceStore, key: string, now: number): Evaluation {
  const a=store.activation(key)
  let receipts:Receipt[]=[]
  let integrity=true
  try { receipts=store.verified(key).filter(r=>r.receivedAt<=a.outcomeDeadline) } catch { integrity=false }
  return evaluateSnapshot(a,receipts,now,integrity)
}
