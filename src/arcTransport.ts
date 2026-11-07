import { fallback, http } from 'viem'

// Official Arc testnet endpoints: https://docs.arc.io/arc/references/rpc-endpoints
// No cached financial responses or background ranking pings. A failed provider
// falls through immediately; contract reverts retain viem's terminal semantics.
export const ARC_RPC_URLS = [
  'https://rpc.blockdaemon.testnet.arc.io',
  'https://rpc.drpc.testnet.arc.io',
  'https://rpc.testnet.arc.io',
] as const

export function arcTransport(urls: readonly string[] = ARC_RPC_URLS) {
  return fallback(urls.map(url => http(url, { timeout: 5_000, retryCount: 0 })), {
    rank: false,
    retryCount: 0,
  })
}
