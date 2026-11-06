import { usePublicClient, useBlock } from 'wagmi'
import { TARGET_CHAIN_ID } from './contract'

export interface ChainTime {
  /** Timestamp (seconds) of the latest block the app has seen; undefined until read. */
  now: bigint | undefined
  /** True when the latest block could not be read. */
  failed: boolean
  refetch: () => void
}

/**
 * Chain time = the timestamp of the latest block. All time-gated buttons use this, never the
 * browser clock. The block is polled; the contract remains the final authority because your
 * transaction is mined in a LATER block than the one shown here.
 */
export function useChainTime(): ChainTime {
  const block = useBlock({ chainId: TARGET_CHAIN_ID, query: { refetchInterval: 3_000 } })
  return {
    now: block.data?.timestamp,
    failed: block.isError && block.data === undefined,
    refetch: () => void block.refetch(),
  }
}

/** Reads the newest block's timestamp right now (used immediately before a time-gated send). */
export function useFreshChainTime(): () => Promise<bigint> {
  const client = usePublicClient({ chainId: TARGET_CHAIN_ID })
  return async () => {
    if (!client) throw new Error('No public client')
    const block = await client.getBlock({ blockTag: 'latest' })
    return block.timestamp
  }
}
