import type { Address } from 'viem'
import { erc20Abi } from 'viem'
import { useAccount, useReadContracts } from 'wagmi'
import { MICROCOVER_ADDRESS, TARGET_CHAIN_ID, USDC_ADDRESS } from './contract'
import { useTxFlow } from './useTxFlow'

/**
 * Exact-amount ERC-20 approval for the MicroCover contract. Approves precisely `required`
 * (never unlimited) and reports whether the wallet already has enough balance and allowance.
 */
export function useUsdcApproval(required: bigint | undefined) {
  const { address } = useAccount()
  const owner = address
  const spender = MICROCOVER_ADDRESS

  const reads = useReadContracts({
    contracts:
      owner && spender
        ? [
            { address: USDC_ADDRESS, abi: erc20Abi, functionName: 'balanceOf', args: [owner], chainId: TARGET_CHAIN_ID },
            {
              address: USDC_ADDRESS,
              abi: erc20Abi,
              functionName: 'allowance',
              args: [owner, spender],
              chainId: TARGET_CHAIN_ID,
            },
          ]
        : [],
    query: { enabled: Boolean(owner && spender), refetchInterval: 5_000 },
  })

  const tx = useTxFlow({
    label: 'Approve USDC',
    onConfirmed: () => {
      void reads.refetch()
    },
  })

  const balance = reads.data?.[0]?.status === 'success' ? reads.data[0].result : undefined
  const allowance = reads.data?.[1]?.status === 'success' ? reads.data[1].result : undefined
  const known = required !== undefined && balance !== undefined && allowance !== undefined
  const walletReady = Boolean(owner && spender)
  const readState: 'idle' | 'loading' | 'error' | 'ready' = !walletReady
    ? 'idle'
    : reads.isError || reads.data?.some((read) => read.status === 'failure')
      ? 'error'
      : balance === undefined || allowance === undefined
        ? 'loading'
        : 'ready'

  const approve = (target: Address) => {
    if (required === undefined) return
    tx.writeContract({
      address: USDC_ADDRESS,
      abi: erc20Abi,
      functionName: 'approve',
      args: [target, required],
      chainId: TARGET_CHAIN_ID,
    })
  }

  return {
    /** idle: no wallet. loading: balance/allowance not read yet. error: a read failed. ready: both read. */
    readState,
    tx,
    balance,
    allowance,
    approve,
    refetch: () => void reads.refetch(),
    hasBalance: known ? balance >= required : undefined,
    hasAllowance: known ? allowance >= required : undefined,
  }
}
