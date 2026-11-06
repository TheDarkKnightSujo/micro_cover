import { keccak256, stringToHex, type Hex } from 'viem'

/** Project canonical JSON subset v1; shared by the collector, evaluator and browser. */
export function canonical(value: unknown): string {
  if (value === null || typeof value === 'boolean' || typeof value === 'string') return JSON.stringify(value)
  if (typeof value === 'number' && Number.isSafeInteger(value) && !Object.is(value, -0)) return String(value)
  if (Array.isArray(value)) {
    if (Array.from({ length:value.length }, (_,i)=>i).some(i=>!Object.prototype.hasOwnProperty.call(value,i))) throw Error('INVALID_CANONICAL_VALUE')
    return `[${value.map(canonical).join(',')}]`
  }
  if (typeof value === 'object' && value !== null && Object.getPrototypeOf(value) === Object.prototype) {
    const record = value as Record<string, unknown>
    const keys = Object.keys(record).sort()
    if (keys.some(k => ['__proto__', 'constructor', 'prototype'].includes(k))) throw Error('INVALID_CANONICAL_KEY')
    return `{${keys.map(k => `${JSON.stringify(k)}:${canonical(record[k])}`).join(',')}}`
  }
  throw Error('INVALID_CANONICAL_VALUE')
}
export const hash = (value: unknown): Hex => keccak256(stringToHex(canonical(value)))
