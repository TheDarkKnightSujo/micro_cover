import type { Address } from 'viem'
import { formatUsdc } from '@/onchain-money'
import type { useUsdcApproval } from '../useUsdcApproval'
import { ghostButton, primaryButton } from './ChainGate'
import { TxStatus } from './TxStatus'

type Approval = ReturnType<typeof useUsdcApproval>

/** True only when the balance and allowance were actually read and both cover `required`. */
export const approvalReady = (approval: Approval): boolean =>
  approval.readState === 'ready' && approval.hasAllowance === true && approval.hasBalance === true

interface Props {
  approval: Approval
  contract: Address
  required: bigint | undefined
  /** Disables the approve button when the form above it is not valid. */
  valid?: boolean
}

/** Step 1 of every funding flow: approve exactly `required` USDC, with honest loading/error states. */
export function ApprovalStep({ approval, contract, required, valid = true }: Props) {
  if (required === undefined) {
    return (
      <button type="button" className={ghostButton} disabled>
        1. Approve USDC
      </button>
    )
  }
  const amount = formatUsdc(required)

  if (approval.readState === 'loading' || approval.readState === 'idle') {
    return (
      <button type="button" className={ghostButton} disabled>
        1. Checking your USDC balance and allowance...
      </button>
    )
  }
  if (approval.readState === 'error') {
    return (
      <div>
        <p className="mb-2 text-sm text-[var(--danger)]">Could not read your USDC balance or allowance.</p>
        <button type="button" className={ghostButton} onClick={approval.refetch}>
          Retry
        </button>
      </div>
    )
  }

  const lacksBalance = approval.hasBalance === false
  const needsApproval = approval.hasAllowance === false
  return (
    <>
      {lacksBalance && (
        <p className="mb-2 text-sm text-[var(--danger)]">
          You need {amount} USDC but hold {approval.balance !== undefined ? formatUsdc(approval.balance) : '0'}. Add testnet USDC
          to this wallet first.
        </p>
      )}
      <button
        type="button"
        className={needsApproval ? primaryButton : ghostButton}
        disabled={!valid || !needsApproval || approval.tx.busy || lacksBalance}
        onClick={() => approval.approve(contract)}
      >
        {needsApproval ? `1. Approve exactly ${amount} USDC` : `1. ${amount} USDC approved`}
      </button>
      <TxStatus phase={approval.tx.phase} hash={approval.tx.hash} message={approval.tx.message} successText="Approval confirmed." />
    </>
  )
}
