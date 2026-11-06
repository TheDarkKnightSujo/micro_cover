import { useEffect, useRef } from 'react'
import type { TransactionReceipt } from 'viem'
import { useWaitForTransactionReceipt, useWriteContract } from 'wagmi'
import { TARGET_CHAIN_ID } from './contract'
import { describeError } from './errors'
import { useReceiptLog } from './receipts'

export type TxPhase = 'idle' | 'wallet' | 'confirming' | 'success' | 'error'

export interface TxOptions {
  /** Shown in the session receipt list once the receipt is successful. */
  label?: string
  guaranteeId?: bigint
  onConfirmed?: (receipt: TransactionReceipt) => void
}

/**
 * One wallet write plus its receipt, with honest phases:
 * wallet prompt -> waiting for the block -> confirmed (successful receipt only) or failed.
 * A wallet rejection returns to idle with a note, a reverted receipt is an error, and a
 * receipt read failure is reported as unknown (with a retry), never as success.
 * `onConfirmed` fires once per confirmed transaction hash.
 */
export function useTxFlow(options: TxOptions = {}) {
  const { writeContract, data: hash, isPending, error: writeError, reset } = useWriteContract()
  const receipt = useWaitForTransactionReceipt({ hash, chainId: TARGET_CHAIN_ID })
  const log = useReceiptLog()
  const latest = useRef(options)
  useEffect(() => {
    latest.current = options
  })

  const firedFor = useRef<string | undefined>(undefined)
  const confirmed = receipt.data
  useEffect(() => {
    if (confirmed && confirmed.status === 'success' && firedFor.current !== confirmed.transactionHash) {
      firedFor.current = confirmed.transactionHash
      const { label, guaranteeId, onConfirmed } = latest.current
      if (label) log.add({ label, hash: confirmed.transactionHash, guaranteeId })
      onConfirmed?.(confirmed)
    }
  }, [confirmed, log])

  let phase: TxPhase = 'idle'
  let message: string | undefined
  let receiptUnknown = false
  if (isPending) {
    phase = 'wallet'
  } else if (writeError) {
    const described = describeError(writeError)
    phase = described.cancelled ? 'idle' : 'error'
    message = described.text
  } else if (confirmed?.status === 'reverted') {
    phase = 'error'
    message = 'The transaction was mined but reverted onchain. Nothing changed.'
  } else if (confirmed) {
    phase = 'success'
  } else if (hash && receipt.isError) {
    phase = 'error'
    receiptUnknown = true
    message = 'Could not confirm the transaction. It may still be pending or may have failed. Check the explorer, then retry the check.'
  } else if (hash) {
    phase = 'confirming'
  }

  return {
    writeContract,
    reset,
    hash,
    phase,
    message,
    /** True when the receipt could not be read, so the outcome is unknown. */
    receiptUnknown,
    retryReceipt: () => void receipt.refetch(),
    busy: phase === 'wallet' || phase === 'confirming',
  }
}

export type TxFlow = ReturnType<typeof useTxFlow>
export type TxWriter = TxFlow['writeContract']
