import type { Address } from 'viem'
import { formatUsdc } from '@/onchain-money'
import { STATUS, TARGET_CHAIN_ID, microCoverAbi } from '../contract'
import type { GuaranteeRead, GuaranteeView } from '../useGuarantee'
import { useTxFlow } from '../useTxFlow'
import { useUsdcApproval } from '../useUsdcApproval'
import { ApprovalStep, approvalReady } from './ApprovalStep'
import { ChainGate, primaryButton } from './ChainGate'
import { TxStatus } from './TxStatus'

function blocker(g: GuaranteeView, account: Address | undefined): string | undefined {
  if (g.status !== STATUS.OPEN) return 'Enrollment is closed for this guarantee.'
  if (account && g.provider.toLowerCase() === account.toLowerCase()) return 'A provider cannot join their own guarantee.'
  if (g.isMember) return 'You are already enrolled in this cohort.'
  if (!g.joinable) return 'Not open to join: the deadline has passed or the cohort is full.'
  return undefined
}

interface Props {
  contract: Address
  id: bigint
  g: GuaranteeView
  read: GuaranteeRead
  account: Address | undefined
}

export function EnrollSection({ contract, id, g, read, account }: Props) {
  const approval = useUsdcApproval(g.escrowAmount)
  const tx = useTxFlow(() => {
    read.refetch()
    approval.refetch()
  })
  const why = blocker(g, account)
  const ready = approvalReady(approval)

  return (
    <section>
      <h3 className="text-sm font-semibold text-[var(--ink)]">Enroll as a beneficiary</h3>
      <p className="mt-1 text-sm text-[var(--muted)] text-pretty">
        Lock {formatUsdc(g.escrowAmount)} USDC of escrow. If the provider admits failure you get it back plus{' '}
        {formatUsdc(g.compensation)} USDC compensation.
      </p>
      <div className="mt-3">
        {why ? (
          <p className="text-sm text-[var(--subtle)]">{why}</p>
        ) : (
          <ChainGate>
            <div className="flex flex-col gap-2">
              <ApprovalStep approval={approval} contract={contract} required={g.escrowAmount} />
              <button
                type="button"
                className={primaryButton}
                disabled={!ready || tx.busy}
                onClick={() =>
                  tx.writeContract({ address: contract, abi: microCoverAbi, functionName: 'joinCohort', args: [id], chainId: TARGET_CHAIN_ID })
                }
              >
                {tx.phase === 'wallet' ? 'Confirm in wallet...' : tx.phase === 'confirming' ? 'Enrolling...' : '2. Enroll'}
              </button>
              <TxStatus phase={tx.phase} hash={tx.hash} message={tx.message} successText="Enrolled. Your escrow is locked." />
            </div>
          </ChainGate>
        )}
      </div>
    </section>
  )
}
