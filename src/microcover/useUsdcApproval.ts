import type { Address } from 'viem'
import { erc20Abi } from 'viem'
import { useAccount, usePublicClient, useReadContracts } from 'wagmi'
import { useEffect, useRef, useState } from 'react'
import { MICROCOVER_ADDRESS, TARGET_CHAIN_ID, USDC_ADDRESS } from './contract'
import { useTxFlow } from './useTxFlow'
import { checkedEvidenceGas } from './evidenceSubmission'
import { describeError } from './errors'

/**
 * Exact-amount ERC-20 approval for the MicroCover contract. Approves precisely `required`
 * (never unlimited) and reports whether the wallet already has enough balance and allowance.
 */
export function useUsdcApproval(required: bigint | undefined) {
  const { address } = useAccount()
  const client = usePublicClient({chainId: TARGET_CHAIN_ID})
  const lock = useRef(false)
  const current = useRef({address, required})
  useEffect(() => { current.current = {address, required} }, [address, required])
  const active = useRef(true)
  useEffect(() => { active.current=true; return () => { active.current=false } }, [])
  const [preparing, setPreparing] = useState(false)
  const [prepareError, setPrepareError] = useState<string>()
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
    if (required === undefined || !address || !client || target.toLowerCase() !== spender?.toLowerCase() || lock.current || tx.busy) return
    lock.current=true
    setPreparing(true)
    setPrepareError(undefined)
    tx.reset()
    const request = {
      address: USDC_ADDRESS,
      abi: erc20Abi,
      functionName: 'approve' as const,
      args: [target, required] as const,
      account: address,
    }
    void (async () => {
      try {
        const gas = await checkedEvidenceGas(
          () => client.simulateContract(request),
          () => client.estimateContractGas(request),
          () => Promise.resolve(active.current && current.current.address === address && current.current.required === required
            ? {ok:true} : {ok:false, reason:'Wallet or amount changed. Review the approval again.'}),
        )
        tx.writeContract({...request, gas, chainId: TARGET_CHAIN_ID})
      } catch(error) {
        if(active.current) setPrepareError(`Approval preparation stopped before a wallet request. ${describeError(error).text}`)
      } finally {
        lock.current=false
        if(active.current) setPreparing(false)
      }
    })()
  }

  return {
    /** idle: no wallet. loading: balance/allowance not read yet. error: a read failed. ready: both read. */
    readState,
    tx: {...tx, busy: tx.busy || preparing, message: prepareError ?? tx.message, phase: prepareError ? 'error' as const : tx.phase},
    balance,
    allowance,
    approve,
    refetch: () => void reads.refetch(),
    hasBalance: known ? balance >= required : undefined,
    hasAllowance: known ? allowance >= required : undefined,
  }
}
