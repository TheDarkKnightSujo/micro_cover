import { expect, test } from 'bun:test'
import { createPublicClient } from 'viem'
import { arcTransport } from '../../src/arcTransport'

test('rate limiting fails over without retrying the throttled provider', async () => {
  let failures = 0, successes = 0
  const limited = Bun.serve({ port: 0, fetch: () => {
    failures++
    return Response.json({ jsonrpc: '2.0', id: 1, error: { code: -32005, message: 'rate limit exceeded' } }, { status: 429 })
  } })
  const healthy = Bun.serve({ port: 0, fetch: () => {
    successes++
    return Response.json({ jsonrpc: '2.0', id: 1, result: '0x4cef52' })
  } })
  try {
    const client = createPublicClient({ transport: arcTransport([limited.url.toString(), healthy.url.toString()]) })
    expect(await client.getChainId()).toBe(5042002)
    expect(failures).toBe(1)
    expect(successes).toBe(1)
  } finally { limited.stop(true); healthy.stop(true) }
})

test('all providers unavailable rejects rather than returning stale success', async () => {
  const down = Bun.serve({ port: 0, fetch: () => new Response('unavailable', { status: 503 }) })
  try {
    const client = createPublicClient({ transport: arcTransport([down.url.toString()]) })
    await expect(client.getChainId()).rejects.toThrow()
  } finally { down.stop(true) }
})

test('a contract revert is terminal and cannot be replaced by another provider', async () => {
  let fallbackCalls = 0
  const reverted = Bun.serve({ port: 0, fetch: () => Response.json({ jsonrpc: '2.0', id: 1, error: { code: 3, message: 'execution reverted', data: '0x' } }) })
  const other = Bun.serve({ port: 0, fetch: () => { fallbackCalls++; return Response.json({ jsonrpc: '2.0', id: 1, result: '0x' }) } })
  try {
    const client = createPublicClient({ transport: arcTransport([reverted.url.toString(), other.url.toString()]) })
    await expect(client.call({ to: '0x0000000000000000000000000000000000000001' })).rejects.toThrow()
    expect(fallbackCalls).toBe(0)
  } finally { reverted.stop(true); other.stop(true) }
})
