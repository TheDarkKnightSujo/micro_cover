import { useId, useState } from 'react'
import type { Address } from 'viem'
import { formatUsdc } from '@/onchain-money'
import { TARGET_CHAIN_ID, microCoverAbi } from '../contract'
import { canEnroll, type Ctx } from '../lifecycle'
import type { ChainTime } from '../useChainTime'
import type { GuaranteeRead, GuaranteeView } from '../useGuarantee'
import { useTxFlow } from '../useTxFlow'
import { useUsdcApproval } from '../useUsdcApproval'
import { ApprovalStep, approvalReady } from './ApprovalStep'
import { Callout } from './Card'
import { ChainGate, primaryButton } from './ChainGate'
import { TxStatus } from './TxStatus'
import { useEvidencePolicy, EVIDENCE_DISCLOSURE, evidenceGet, validatePublicPolicy } from '../evidenceClient'

interface Props {
  contract: Address
  id: bigint
  g: GuaranteeView
  read: GuaranteeRead
  account: Address | undefined
  operator: Address
  chain: ChainTime
  freshNow: () => Promise<bigint>
}

export function EnrollSection({ contract, id, g, read, account, operator, chain, freshNow }: Props) {
  const policy=useEvidencePolicy(contract)
  const policyReady=!g.evidenceBound||(policy.isSuccess&&!policy.isError&&policy.data?.policyHash===g.policyHash)
  const headingId = useId()
  const approval = useUsdcApproval(g.escrowAmount)
  const [guard, setGuard] = useState<string>()
  const tx = useTxFlow({
    label: 'Enroll as beneficiary',
    guaranteeId: id,
    onConfirmed: () => {
      read.refetch()
      chain.refetch()
      approval.refetch()
    },
  })
  const ctxFor = (now: bigint): Ctx => ({ now, account, operator })
  const verdict = !policyReady ? {ok:false as const,reason:'Evidence policy is unavailable or does not match the frozen guarantee. Enrollment is disabled.'} : chain.now === undefined ? { ok: false as const, reason: chain.failed ? 'Chain time is unavailable, so enrollment is disabled.' : 'Reading chain time...' } : canEnroll(g, ctxFor(chain.now))

  const enroll = () => {
    if(!policyReady)return
    void (async () => {
      setGuard(undefined)
      try {
        if(g.evidenceBound && validatePublicPolicy(await evidenceGet('policy'),contract).policyHash!==g.policyHash) throw Error('POLICY_CHANGED')
        const recheck = canEnroll(g, ctxFor(await freshNow()))
        if (!recheck.ok) {
          setGuard(recheck.reason)
          return
        }
      } catch {
        setGuard('Latest chain time or the frozen evidence policy could not be verified. Nothing was sent. Refresh and review before trying again.')
        return
      }
      tx.writeContract({ address: contract, abi: microCoverAbi, functionName: 'joinCohort', args: [id], chainId: TARGET_CHAIN_ID })
    })()
  }

  return (
    <section aria-labelledby={headingId}>
      {g.evidenceBound&&<Callout tone="warn">{EVIDENCE_DISCLOSURE} Both feeds must agree with fresh explicit statuses; polling 10 s, freshness 60 s at the outcome deadline. Policy {g.policyHash}. A separately frozen {g.uncertaintyTimeout.toString()} s timeout starts only on first onchain uncertainty. Unresolved refunds return your full escrow, pay no compensation, and return the bond after all refunds. Later disputes reuse the first deadline. Early disputes can make refunds eligible before the outcome deadline. A delivered service may be refunded when evidence is inconclusive.</Callout>}
      <span className="mc-role-tag">Beneficiary</span>
      <h3 className="mc-h3" id={headingId}>
        Enroll in this guarantee
      </h3>
      <p className="mc-p">
        Lock {formatUsdc(g.escrowAmount)} USDC of escrow. If the provider admits failure you get it back plus {formatUsdc(g.compensation)} USDC compensation. If success is finalized, your escrow goes to the provider and you are not paid. Review the terms above first.
      </p>
      <div className="mc-mt-3">
        {!verdict.ok ? (
          <p className="mc-p mc-muted">{verdict.reason}</p>
        ) : (
          <ChainGate>
            <Callout tone="warn">Enrolling locks your escrow until the guarantee settles. You can leave only through failure payout or a finalized success.</Callout>
            <div className="mc-actions mc-mt-3">
              <ApprovalStep approval={approval} contract={contract} required={g.escrowAmount} />
              <button type="button" className={primaryButton} disabled={!approvalReady(approval) || tx.busy} onClick={enroll}>
                {tx.phase === 'wallet' ? 'Confirm in your wallet...' : tx.phase === 'confirming' ? 'Enrolling...' : '2. Enroll'}
              </button>
            </div>
          </ChainGate>
        )}
        {guard && (
          <p className="mc-bad mc-mt-2" role="alert">
            {guard}
          </p>
        )}
        <TxStatus tx={tx} successText="Enrolled onchain. Your escrow is locked." />
      </div>
    </section>
  )
}
