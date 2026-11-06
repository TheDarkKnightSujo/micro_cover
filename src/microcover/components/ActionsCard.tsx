import type { Address } from 'viem'
import { formatUsdc } from '@/onchain-money'
import { TARGET_CHAIN_ID, microCoverAbi } from '../contract'
import { canAdmitFailure, canDispute, canFinalize, canMarkUncertain, canPropose, canReleaseEscrow, canSettle, canWithdraw, type Ctx } from '../lifecycle'
import type { ChainTime } from '../useChainTime'
import type { GuaranteeRead, GuaranteeView } from '../useGuarantee'
import { Card } from './Card'
import { EnrollSection } from './EnrollSection'
import { GuardedAction } from './GuardedAction'

interface Props {
  contract: Address
  id: bigint | undefined
  read: GuaranteeRead
  account: Address | undefined
  operator: Address
  chain: ChainTime
  freshNow: () => Promise<bigint>
}

function Actions({ contract, id, g, read, account, operator, chain, freshNow }: Props & { id: bigint; g: GuaranteeView }) {
  const ctxFor = (now: bigint): Ctx => ({ now, account, operator })
  const done = () => {
    read.refetch()
    chain.refetch()
  }
  const common = { chain, freshNow, guaranteeId: id, onConfirmed: done }
  const remaining = g.cohortSize - g.paidCount
  const batch = Math.min(g.maxBatch, remaining)
  const next = g.beneficiaries.slice(g.paidCount, g.paidCount + batch)
  const each = g.escrowAmount + g.compensation

  return (
    <div className="mc-sections">
      <EnrollSection contract={contract} id={id} g={g} read={read} account={account} operator={operator} chain={chain} freshNow={freshNow} />

      <GuardedAction
        {...common}
        title="Request review (dispute)"
        role="Enrolled beneficiary"
        description="An explicit onchain dispute freezes settlement and starts the first uncertainty timeout. It is not proof of failure. Request evaluation above to ask for evidence review without opening a dispute. Timely authorized evidence or provider admission may resolve uncertainty."
        warning="This starts or reuses the first non-resetting deadline. Early disputes may make refunds eligible before the service deadline. If still unresolved when eligible, anyone may select full escrow refunds with no compensation. A later dispute may be immediately eligible."
        eligible={(now) => canDispute(g, ctxFor(now))}
        label="Raise dispute"
        workingLabel="Submitting dispute..."
        successText="Dispute recorded onchain. The guarantee is now uncertain and frozen."
        receiptLabel="Raise dispute"
        send={(write) => write({ address: contract, abi: microCoverAbi, functionName: 'raiseDispute', args: [id], chainId: TARGET_CHAIN_ID })}
      />

      <GuardedAction
        {...common}
        title="Admit failure"
        role="Provider only"
        description="You, the provider, admit the guarantee failed. Enrollment closes and every enrolled beneficiary is paid their escrow plus compensation. You may do this until success is actually finalized."
        warning="Admitting failure is final: it can never be undone and success becomes impossible."
        eligible={(now) => canAdmitFailure(g, ctxFor(now))}
        label="Admit failure"
        workingLabel="Admitting failure..."
        successText="Failure admitted onchain. Enrollment is closed and payouts can start."
        receiptLabel="Admit failure"
        send={(write) => write({ address: contract, abi: microCoverAbi, functionName: 'admitFailure', args: [id], chainId: TARGET_CHAIN_ID })}
      />

      <GuardedAction
        {...common}
        title="Propose success"
        role="Demo operator only"
        description="The immutable demo operator proposes that the guarantee succeeded. This starts a review window; it is not final, moves no money and can be disputed or overridden by the provider's failure admission."
        eligible={(now) => canPropose(g, ctxFor(now))}
        label="Propose success"
        workingLabel="Proposing success..."
        successText="Success proposed onchain. The review window has started."
        receiptLabel="Propose success"
        send={(write) => write({ address: contract, abi: microCoverAbi, functionName: 'proposeSuccess', args: [id], chainId: TARGET_CHAIN_ID })}
      />

      <GuardedAction
        {...common}
        title="Mark uncertain"
        role="Demo operator only"
        description="Explicitly enter onchain uncertainty. An unavailable offchain snapshot never calls this automatically. Timely evidence or provider admission can resolve it; otherwise the fixed timeout enables escrow-only refunds."
        warning="This starts or reuses the first uncertainty deadline, which cannot be extended. No compensation is paid by the unresolved fallback."
        eligible={() => canMarkUncertain(g, ctxFor(0n))}
        label="Mark uncertain"
        workingLabel="Marking uncertain..."
        successText="Marked uncertain onchain. The guarantee is frozen."
        receiptLabel="Mark uncertain"
        send={(write) => write({ address: contract, abi: microCoverAbi, functionName: 'markUncertain', args: [id], chainId: TARGET_CHAIN_ID })}
      />

      <GuardedAction
        {...common}
        title="Finalize success"
        role="Anyone, after the review window"
        description="After the review window ends, anyone can finalize success. It becomes the permanent outcome, so failure can no longer be admitted. No tokens move yet."
        warning="Finalizing success is irreversible. Beneficiaries will not be paid and the provider can no longer admit failure."
        eligible={(now) => canFinalize(g, ctxFor(now))}
        label="Finalize success"
        workingLabel="Finalizing success..."
        successText="Success finalized onchain."
        receiptLabel="Finalize success"
        send={(write) => write({ address: contract, abi: microCoverAbi, functionName: 'finalizeSuccess', args: [id], chainId: TARGET_CHAIN_ID })}
      />

      <GuardedAction
        {...common}
        title="Release success escrow"
        role="Anyone, after success is finalized"
        description={`Sends all beneficiary escrow held for this guarantee (${formatUsdc(g.escrowHeld)} USDC) to the provider. The amount and recipient are fixed by the contract.`}
        eligible={() => canReleaseEscrow(g)}
        label="Release escrow to provider"
        workingLabel="Releasing escrow..."
        successText="Escrow released to the provider onchain."
        receiptLabel="Release success escrow"
        send={(write) => write({ address: contract, abi: microCoverAbi, functionName: 'releaseSuccessEscrow', args: [id], chainId: TARGET_CHAIN_ID })}
      />

      <GuardedAction
        {...common}
        title="Settle failure payouts"
        role="Anyone, after failure is established"
        description={`Pays the next enrolled beneficiaries their escrow plus compensation, in enrollment order, at most ${g.maxBatch} per transaction. Recipients and amounts come only from enrollment and the guarantee terms.`}
        eligible={() => canSettle(g)}
        preview={
          <ul className="mc-list" aria-label="Next payouts">
            {next.map((b, i) => (
              <li key={b.address}>
                <span className="mc-mono">
                  {g.paidCount + i + 1}. {b.address}
                </span>
                <span>{formatUsdc(each)} USDC</span>
              </li>
            ))}
          </ul>
        }
        label={`Pay next ${batch} of ${remaining}`}
        workingLabel="Paying beneficiaries..."
        successText="Payouts confirmed onchain."
        receiptLabel="Settle failure payouts"
        send={(write) => write({ address: contract, abi: microCoverAbi, functionName: 'settleFailure', args: [id, batch], chainId: TARGET_CHAIN_ID })}
      />

      <GuardedAction
        {...common}
        title="Withdraw remaining bond"
        role="Provider only"
        description={`Returns this guarantee's remaining bond (${formatUsdc(g.bondHeld)} USDC held now) to you. After failure it is only the unused part, once every beneficiary is paid. After success it is the whole bond, once the escrow has been released. Never available while the guarantee is open, in review or frozen.`}
        eligible={() => canWithdraw(g, ctxFor(0n))}
        label="Withdraw remaining bond"
        workingLabel="Withdrawing bond..."
        successText="Bond withdrawn onchain. The guarantee is closed."
        receiptLabel="Withdraw remaining bond"
        send={(write) => write({ address: contract, abi: microCoverAbi, functionName: 'withdrawRemainingBond', args: [id], chainId: TARGET_CHAIN_ID })}
      />
    </div>
  )
}

export function ActionsCard(props: Props) {
  const { id, read, account, contract } = props
  const g = read.data
  return (
    <Card title="Actions for your role">
      {id === undefined ? (
        <p className="mc-p mc-muted">Select an existing guarantee above to see what you can do with it.</p>
      ) : read.state === 'unavailable' ? (
        <p className="mc-p mc-muted">Actions are disabled because the guarantee could not be read. Use Retry above.</p>
      ) : read.state === 'unknown' ? (
        <p className="mc-p mc-muted">No guarantee exists with this id.</p>
      ) : !g || g.forId !== id || g.forAccount !== account ? (
        <p className="mc-p mc-muted">Loading from the chain...</p>
      ) : (
        // Remount per contract + guarantee + wallet so armed confirmations and transaction
        // results can never carry over to a different selection or account.
        <div key={`${contract}:${id.toString()}:${account ?? 'none'}`}>
          <p className="mc-hint" style={{ marginTop: 0, marginBottom: 12 }}>
            Every action is checked by the contract. A disabled or hidden button is a convenience, not permission.
          </p>
          <Actions {...props} id={id} g={g} />
        </div>
      )}
    </Card>
  )
}
