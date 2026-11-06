import type { Hex } from 'viem'
declare const SOURCE_IDS: readonly ['synthetic-status-a', 'synthetic-status-b']
export type SourceId = typeof SOURCE_IDS[number]
export type ExplicitStatus = 'FULFILLED' | 'CANCELLED' | 'UNKNOWN'
export interface Domain {
  schema: 'microcover-evidence-v1'
  chainId: string
  consumer: string
  guaranteeId: string
  cohortId: Hex
  conditionHash: Hex
  policyHash: Hex
}
export interface Policy {
  version: 'synthetic-unanimous-v1'
  conditionHash: Hex
  disclosure: 'Both demo feeds are controlled by the same team; not independent sources.'
  intervalSeconds: 10
  freshnessSeconds: 60
  cutoff: 'RECEIVED_BY_OUTCOME_DEADLINE'
  sources: { id: SourceId; group: 'team-controlled'; weight: 1; publicKeyDer: string }[]
}
export interface Activation {
  domain: Domain
  policy: Policy
  activatedAt: number
  outcomeDeadline: number
}
export interface Observation {
  domain: Domain
  sourceId: SourceId
  sourceTimestamp: number
  nonce: string
  status: ExplicitStatus
}
export interface Envelope { payload: Observation; signature: string }
export interface Receipt {
  domainKey: Hex
  sequence: number
  previousHash: Hex
  attemptKey: string
  sourceId: SourceId
  group: 'team-controlled'
  receivedAt: number
  sourceTimestamp: number | null
  nonce: string | null
  kind: 'OBSERVATION' | 'UNAVAILABLE' | 'INVALID'
  status: ExplicitStatus | null
  payloadHash: Hex | null
  signature: string | null
  keyFingerprint: Hex
  error: string | null
  hash: Hex
}
