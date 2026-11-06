import { createPublicKey, verify } from 'node:crypto'
import type { Hex } from 'viem'
import { canonical, hash } from '../../src/microcover/evidenceCanonical'
export { canonical, hash } from '../../src/microcover/evidenceCanonical'
import { PRESET_TERMS_HASH } from '../../src/microcover/terms'
export type { Hex } from 'viem'

export const ZERO = `0x${'0'.repeat(64)}` as Hex
export const SOURCE_IDS = ['synthetic-status-a', 'synthetic-status-b'] as const
export type * from './types'
import type { SourceId, Envelope, Policy, Activation } from './types'

export function seconds(value: unknown): asserts value is number {
  if (typeof value !== 'number' || !Number.isSafeInteger(value) || value < 0) throw Error('INVALID_TIMESTAMP')
}
export function validatePolicy(policy: Policy): void {
  if (policy.version !== 'synthetic-unanimous-v1' || policy.conditionHash !== PRESET_TERMS_HASH || policy.intervalSeconds !== 10 || policy.freshnessSeconds !== 60 ||
      policy.cutoff !== 'RECEIVED_BY_OUTCOME_DEADLINE' ||
      policy.disclosure !== 'Both demo feeds are controlled by the same team; not independent sources.' || policy.sources.length !== 2) throw Error('INVALID_POLICY')
  for (const id of SOURCE_IDS) {
    const matches = policy.sources.filter(s => s.id === id)
    if (matches.length !== 1 || matches[0].weight !== 1 || matches[0].group !== 'team-controlled') throw Error('INVALID_SOURCES')
    const key = createPublicKey({ key: Buffer.from(matches[0].publicKeyDer, 'hex'), format: 'der', type: 'spki' })
    if (key.asymmetricKeyType !== 'ed25519') throw Error('INVALID_KEY_TYPE')
  }
  if (policy.sources[0].publicKeyDer === policy.sources[1].publicKeyDer) throw Error('DUPLICATE_KEY_IDENTITY')
  canonical(policy)
}
export function validateActivation(a: Activation): void {
  validatePolicy(a.policy)
  const d = a.domain
  if (d.schema !== 'microcover-evidence-v1' || d.chainId !== '5042002' || !/^[1-9]\d*$/.test(d.guaranteeId) ||
      !/^0x[0-9a-f]{40}$/.test(d.consumer) || /^0x0{40}$/.test(d.consumer) ||
      ![d.cohortId, d.conditionHash, d.policyHash].every(v => /^0x[0-9a-f]{64}$/.test(v) && v !== ZERO)) throw Error('INVALID_DOMAIN')
  if (hash(a.policy) !== d.policyHash) throw Error('POLICY_HASH_MISMATCH')
  if (d.conditionHash !== a.policy.conditionHash) throw Error('CONDITION_POLICY_MISMATCH')
  seconds(a.activatedAt); seconds(a.outcomeDeadline)
  if (a.outcomeDeadline <= a.activatedAt) throw Error('INVALID_WINDOW')
}
export function authenticate(envelope: unknown, a: Activation, sourceId: SourceId, receivedAt: number): Envelope {
  seconds(receivedAt)
  if (!envelope || typeof envelope !== 'object') throw Error('INVALID_ENVELOPE')
  const e = envelope as Envelope
  const p = e.payload
  if (canonical(Object.keys(e).sort()) !== canonical(['payload', 'signature']) || !p ||
      canonical(Object.keys(p).sort()) !== canonical(['domain', 'nonce', 'sourceId', 'sourceTimestamp', 'status'])) throw Error('INVALID_SCHEMA')
  if (canonical(p.domain) !== canonical(a.domain) || p.sourceId !== sourceId) throw Error('WRONG_DOMAIN_OR_SOURCE')
  seconds(p.sourceTimestamp)
  if (p.sourceTimestamp > receivedAt || p.sourceTimestamp < a.activatedAt) throw Error('INVALID_SOURCE_TIME')
  if (!['FULFILLED', 'CANCELLED', 'UNKNOWN'].includes(p.status) || typeof p.nonce !== 'string' || !/^(0|[1-9]\d{0,39})$/.test(p.nonce)) throw Error('INVALID_OBSERVATION')
  if (typeof e.signature !== 'string' || !/^[0-9a-f]{128}$/.test(e.signature)) throw Error('INVALID_SIGNATURE')
  const source = a.policy.sources.find(s => s.id === sourceId)
  if (!source || !verify(null, Buffer.from(canonical(p)), {
    key: Buffer.from(source.publicKeyDer, 'hex'), format: 'der', type: 'spki',
  }, Buffer.from(e.signature, 'hex'))) throw Error('INVALID_SIGNATURE')
  return e
}
