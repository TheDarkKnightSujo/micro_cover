import { ExternalLink } from 'lucide-react'
import { buildTxExplorerUrl } from '@/onchain-facts'
import { formatUsdc } from '@/onchain-money'
import { OUTCOME, STATUS, TARGET_CHAIN_ID } from '../contract'
import { fmtTime, relativeTo } from '../format'
import { useReceiptLog } from '../receipts'
import type { ChainTime } from '../useChainTime'
import type { GuaranteeView } from '../useGuarantee'
import { AddressValue, Callout, Card, Dl, Row } from './Card'

interface Props {
  id: bigint | undefined
  g: GuaranteeView | undefined
  chain: ChainTime
}

export function HistoryCard({ id, g, chain }: Props) {
  const { entries } = useReceiptLog()
  const mine = entries.filter((e) => e.guaranteeId === undefined || e.guaranteeId === id)
  const at = (label: string, ts: bigint) => (
    <Row label={label}>
      {fmtTime(ts)}
      {chain.now !== undefined && <span className="mc-muted"> ({relativeTo(chain.now, ts)})</span>}
    </Row>
  )

  return (
    <Card title="Lifecycle summary and receipts">
      <Callout>
        <strong>Not a full history.</strong> The summary below is built only from timestamps stored in the contract and the current state. This app does not run an indexer, so it cannot list every past event.
      </Callout>
      {g ? (
        <Dl>
          {at('Join cutoff', g.joinDeadline)}
          {at('Outcome deadline', g.settlementTime)}
          {at('Claim end', g.claimEndsAt)}
          {g.successProposedAt !== 0n && at('Success proposed', g.successProposedAt)}
          {g.successProposedAt !== 0n && g.successReadyAt !== 0n && at('Review window ends', g.successReadyAt)}
          {g.uncertainAt !== 0n && at('Frozen as uncertain', g.uncertainAt)}
          {g.uncertainAt !== 0n && (
            <Row label="Frozen by">
              <AddressValue address={g.uncertainBy} label="address that froze the guarantee" />
              <span className="mc-muted">{g.uncertainBy.toLowerCase() === g.demoOperator.toLowerCase() ? ' (the demo operator)' : ' (an enrolled beneficiary)'}</span>
            </Row>
          )}
          {g.outcome === OUTCOME.FAILURE && (g.failureOrigin===2?<Row label="Failure established">Evidence verdict; no provider admission</Row>:g.failureAdmittedAt !== 0n ? at('Provider admitted failure', g.failureAdmittedAt) : <Row label="Provider admitted failure">Time recorded as 0</Row>)}
          {g.uncertaintyStarted&&at('First uncertainty deadline (never reset)',g.uncertainReadyAt)}
          {g.outcome===OUTCOME.UNRESOLVED_REFUNDED&&<Row label="Distinct unresolved outcome">UNRESOLVED_REFUNDED; {g.refundedCount}/{g.cohortSize} escrow refunds; {formatUsdc(g.refundedEscrow)} USDC, zero compensation</Row>}
          {g.successFinalizedAt !== 0n && at('Success finalized', g.successFinalizedAt)}
          {g.outcome === OUTCOME.SUCCESS && <Row label="Success escrow released">{g.successEscrowReleased ? `${formatUsdc(g.releasedSuccessEscrow)} USDC` : 'Not yet'}</Row>}
          {g.withdrawnBond > 0n && <Row label="Remaining bond withdrawn">{formatUsdc(g.withdrawnBond)} USDC</Row>}
          {g.status === STATUS.CLOSED && <Row label="Closed">Yes, outcome {g.outcome === OUTCOME.SUCCESS ? 'success' : g.outcome===OUTCOME.UNRESOLVED_REFUNDED?'UNRESOLVED_REFUNDED':'failure'}</Row>}
        </Dl>
      ) : (
        <p className="mc-p mc-muted mc-mt-3">Select a guarantee to see its stored timeline.</p>
      )}

      <h3 className="mc-sub-h">Confirmed in this browser tab</h3>
      {mine.length === 0 ? (
        <p className="mc-p mc-muted mc-mt-2">No confirmed transactions yet in this tab. This list clears when you reload.</p>
      ) : (
        <ul className="mc-list">
          {mine.map((e) => (
            <li key={e.hash}>
              <span>
                <strong>{e.label}</strong>
                {e.guaranteeId !== undefined && <span className="mc-muted"> (guarantee {e.guaranteeId.toString()})</span>}
              </span>
              <a className="mc-link mc-mono" href={buildTxExplorerUrl(TARGET_CHAIN_ID, e.hash)} target="_blank" rel="noopener noreferrer">
                {e.hash} <ExternalLink size={12} aria-hidden />
              </a>
            </li>
          ))}
        </ul>
      )}
    </Card>
  )
}
