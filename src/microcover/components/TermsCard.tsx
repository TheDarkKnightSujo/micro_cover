import { formatUsdc } from '@/onchain-money'
import { STATUS } from '../contract'
import { fmtDuration, fmtTime } from '../format'
import { earliestProposal, readyIfProposedAt } from '../lifecycle'
import { readableTerms } from '../terms'
import type { GuaranteeView } from '../useGuarantee'
import { Badge, Callout, Card, CopyButton, Dl, Row } from './Card'

/** Everything a beneficiary should see BEFORE enrolling, read from the chain. */
export function TermsCard({ g }: { g: GuaranteeView }) {
  const text = readableTerms(g.termsHash)
  const originalBond = g.compensation * BigInt(g.maxCohort)
  const each = g.escrowAmount + g.compensation
  const readyHint = (): string => {
    if (g.status === STATUS.SUCCESS_PENDING || g.status === STATUS.SUCCEEDED || (g.successReadyAt !== 0n)) return fmtTime(g.successReadyAt)
    return `Not queued. If success were proposed at the earliest time (${fmtTime(earliestProposal(g))}), review would end at ${fmtTime(readyIfProposedAt(g, earliestProposal(g)))}.`
  }
  return (
    <Card title="Terms before you enroll" aside={<Badge>Read from the chain</Badge>}>
      <h3 className="mc-sub-h" style={{ marginTop: 0 }}>
        Condition
      </h3>
      {text ? (
        <Callout>
          <strong>Synthetic preset.</strong> {text}
        </Callout>
      ) : (
        <Callout tone="warn">
          <strong>Readable terms unavailable; verify terms.</strong> This guarantee uses a terms hash this app does not recognise, so it cannot show what the condition says. Check the hash with the provider before enrolling.
        </Callout>
      )}
      <Dl>
        <Row label="Terms hash">
          <span className="mc-addr">
            <span className="mc-mono mc-addr-text">{g.termsHash}</span>
            <span className="mc-addr-actions">
              <CopyButton value={g.termsHash} label="terms hash" />
            </span>
          </span>
        </Row>
      </Dl>

      <h3 className="mc-sub-h">Money</h3>
      <Dl>
        <Row label="Price (full escrow)">{formatUsdc(g.escrowAmount)} USDC each</Row>
        <Row label="Guaranteed escrow share">100% ({formatUsdc(g.escrowAmount)} USDC), refunded on failure</Row>
        <Row label="Non-guaranteed share kept by provider">0% (0 USDC)</Row>
        <Row label="Fixed compensation on failure">{formatUsdc(g.compensation)} USDC each</Row>
        <Row label="Maximum cohort / open slots">
          {g.maxCohort} / {g.status === STATUS.OPEN ? g.openSlots : 0} open
        </Row>
        <Row label="Locked bond (provider)">{formatUsdc(originalBond)} USDC at creation</Row>
        <Row label="Reserved for enrolled (subset of bond)">{formatUsdc(g.reservedCompensation)} USDC now</Row>
      </Dl>

      <h3 className="mc-sub-h">Timing (chain time)</h3>
      <Dl>
        <Row label="Join cutoff (inclusive)">{fmtTime(g.joinDeadline)}</Row>
        <Row label="Outcome deadline">{fmtTime(g.settlementTime)}</Row>
        <Row label="Review duration (immutable)">{fmtDuration(g.reviewWindow)}</Row>
        <Row label="Claim end (dispute allowed through)">{fmtTime(g.claimEndsAt)}</Row>
        <Row label="Queued success readiness">{readyHint()}</Row>
        <Row label="Success can finalize">Strictly after the readiness time. At the exact moment a dispute is still allowed.</Row>
      </Dl>
      <p className="mc-hint">Times are shown in your timezone. The blockchain&apos;s own latest block time controls every deadline, not this device&apos;s clock.</p>

      <h3 className="mc-sub-h">Where the money goes</h3>
      <Dl>
        <Row label="If evidence establishes failure or the provider admits it">
          Each enrolled beneficiary receives their escrow plus the compensation: {formatUsdc(each)} USDC. The provider can then withdraw any unused bond.
        </Row>
        <Row label="If success is finalized">
          No beneficiary payout. All beneficiary escrow is released to the provider, then the provider withdraws the whole bond.
        </Row>
        <Row label="If an explicit dispute freezes it">Nothing moves during uncertainty. Timely authorized evidence or provider admission may resolve it strictly before the first uncertainty deadline. Retries do not reset it.</Row>
        <Row label="Separate frozen uncertainty timeout">{fmtDuration(g.uncertaintyTimeout)} from first onchain uncertainty. If still unresolved: full escrow refunds in bounded batches, zero compensation, then bond return after all refunds. A later dispute reuses the first deadline.</Row>
      </Dl>
      <Callout tone="warn">
        A request for evaluation alone does not open an onchain dispute. Offchain uncertainty never automatically locks settlement. The unresolved refund fallback can refund a delivered service when evidence is inconclusive. Success is irreversible once finalized.
      </Callout>
    </Card>
  )
}
