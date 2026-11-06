import { useEffect, useRef } from 'react'
import type { TransactionReceipt } from 'viem'
import { useWaitForTransactionReceipt, useWriteContract } from 'wagmi'
import { TARGET_CHAIN_ID } from './contract'
import { describeError } from './errors'

export type TxPhase = 'idle' | 'wallet' | 'confirming' | 'success' | 'error'

/**
 * One wallet write plus its receipt, with honest phases: wallet prompt, waiting for the
 * block, confirmed, or failed. `onConfirmed` fires once per successful receipt.
 */
export function useTxFlow(onConfirmed?: (receipt: TransactionReceipt) => void) {
  const { writeContract, data: hash, isPending, error: writeError, reset } = useWriteContract()
  const receipt = useWaitForTransactionReceipt({ hash, chainId: TARGET_CHAIN_ID })
  const callback = useRef(onConfirmed)
  useEffect(() => {
    callback.current = onConfirmed
  })

  // Fire the success callback once per confirmed transaction hash, however often it re-renders.
  const firedFor = useRef<string | undefined>(undefined)
  const confirmed = receipt.data
  useEffect(() => {
    if (confirmed && confirmed.status === 'success' && firedFor.current !== confirmed.transactionHash) {
      firedFor.current = confirmed.transactionHash
      callback.current?.(confirmed)
    }
  }, [confirmed])

  const failure = writeError ?? receipt.error
  let phase: TxPhase = 'idle'
  let message: string | undefined
  if (isPending) {
    phase = 'wallet'
  } else if (failure) {
    const described = describeError(failure)
    phase = described.cancelled ? 'idle' : 'error'
    message = described.text
  } else if (confirmed?.status === 'reverted') {
    phase = 'error'
    message = 'The transaction was mined but reverted onchain.'
  } else if (confirmed) {
    phase = 'success'
  } else if (hash) {
    phase = 'confirming'
  }

  return {
    writeContract,
    reset,
    hash,
    phase,
    message,
    busy: phase === 'wallet' || phase === 'confirming',
  }
}
