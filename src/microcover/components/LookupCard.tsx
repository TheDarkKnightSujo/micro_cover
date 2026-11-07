import type { Address } from 'viem'
import { formatUsdc } from '@/onchain-money'
import { OUTCOME, OUTCOME_LABEL, STATUS, STATUS_LABEL } from '../contract'
import { fmtTime } from '../format'
import { isOperator, isProvider, nextStep } from '../lifecycle'
import type { ChainTime } from '../useChainTime'
import type { GuaranteeRead, GuaranteeView } from '../useGuarantee'
import { useShareLink } from '../useShareLink'
import { AddressValue, Badge, Callout, Card, CopyButton, Dl, Row } from './Card'
import { ghostButton } from './ChainGate'

interface Props {
  compact?: boolean
  idInput: string
  onIdChange: (value: string) => void
  /** Highest existing guarantee id, when known. */
  latestId: bigint | undefined
  read: GuaranteeRead
  account: Address | undefined
  operator: Address
  chain: ChainTime
}

const statusTone = (status: number): 'ok' | 'warn' | 'danger' | 'neutral' =>
  status === STATUS.OPEN || status === STATUS.SUCCEEDED ? 'ok' : status === STATUS.FAILED || status === STATUS.UNCERTAIN ? 'danger' : status === STATUS.SUCCESS_PENDING ? 'warn' : 'neutral'

function Roles({ g, account, operator }: { g: GuaranteeView; account: Address | undefined; operator: Address }) {
  const ctx = { account, operator }
  const roles: string[] = []
  if (isProvider(g, ctx)) roles.push('You are the provider')
  if (isOperator(ctx)) roles.push('You are the demo operator')
  if (g.isMember) roles.push('You are an enrolled beneficiary')
  if (account === undefined) return <p className="mc-hint">Connect a wallet to see your role on this guarantee.</p>
  if (roles.length === 0) return <p className="mc-hint">You are viewing this guarantee as an outside observer.</p>
  return (
    <div className="mc-badges" aria-label="Your roles">
      {roles.map((r) => (
        <Badge key={r} tone="ok">
          {r}
        </Badge>
      ))}
    </div>
  )
}

function Details({ g, account, operator, chain }: { g: GuaranteeView; account: Address | undefined; operator: Address; chain: ChainTime }) {
  const success = g.outcome === OUTCOME.SUCCESS
  const failure = g.outcome === OUTCOME.FAILURE
  const each = g.escrowAmount + g.compensation
  const myIndex = account ? g.beneficiaries.findIndex((b) => b.address.toLowerCase() === account.toLowerCase()) : -1
  return (
    <>
      <div className="mc-badges">
        <Badge tone={statusTone(g.status)}>Status: {STATUS_LABEL[g.status] ?? 'Unknown'}</Badge>
        <Badge tone={success ? 'ok' : failure ? 'danger' : 'neutral'}>Outcome: {OUTCOME_LABEL[g.outcome] ?? 'Unknown'}</Badge>
      </div>
      <div className="mc-mt-2">
        <Roles g={g} account={account} operator={operator} />
      </div>
      {chain.now !== undefined && (
        <div className="mc-mt-3">
          <Callout>
            <strong>What happens next.</strong> {nextStep(g, { now: chain.now, account, operator })}
          </Callout>
        </div>
      )}

      <h3 className="mc-sub-h">People</h3>
      <Dl>
        <Row label="Provider">
          <AddressValue address={g.provider} label="provider address" />
        </Row>
        <Row label="Demo operator">
          <AddressValue address={g.demoOperator} label="demo operator address" />
        </Row>
        <Row label="Enrolled / maximum">
          {g.cohortSize} / {g.maxCohort}
        </Row>
      </Dl>

      <h3 className="mc-sub-h">Funds held for this guarantee</h3>
      <Dl>
        <Row label="Bond held">{formatUsdc(g.bondHeld)} USDC</Row>
        <Row label="Reserved for beneficiaries (part of the bond)">{formatUsdc(g.reservedCompensation)} USDC</Row>
        <Row label="Beneficiary escrow held">{formatUsdc(g.escrowHeld)} USDC</Row>
      </Dl>

      {failure && (
        <>
          <h3 className="mc-sub-h">Failure payout progress</h3>
          <Dl>
            <Row label="Beneficiaries paid">
              {g.paidCount} of {g.cohortSize}
            </Row>
            <Row label="Still owed to beneficiaries">{formatUsdc(g.remainingOwed)} USDC</Row>
            <Row label="Unused bond the provider can withdraw">{formatUsdc(g.withdrawableBond)} USDC</Row>
          </Dl>
        </>
      )}
      {success && (
        <>
          <h3 className="mc-sub-h">Success release progress</h3>
          <Dl>
            <Row label="Compensation reservation released">{formatUsdc(g.releasedSuccessReservation)} USDC</Row>
            <Row label="Escrow released to provider">{g.successEscrowReleased ? `Yes, ${formatUsdc(g.releasedSuccessEscrow)} USDC` : 'Not yet'}</Row>
            <Row label="Bond withdrawn by provider">{g.status === STATUS.CLOSED ? `Yes, ${formatUsdc(g.withdrawnBond)} USDC` : 'Not yet'}</Row>
          </Dl>
          <p className="mc-hint">No beneficiary is paid when a guarantee succeeds.</p>
        </>
      )}

      <h3 className="mc-sub-h">{success ? 'Enrolled beneficiaries (no payout on success)' : 'Enrolled beneficiaries'}</h3>
      {g.beneficiaries.length === 0 ? (
        <p className="mc-p mc-muted mc-mt-2">No beneficiaries enrolled.</p>
      ) : (
        <ul className="mc-list">
          {g.beneficiaries.map((b, i) => (
            <li key={b.address}>
              <span className="mc-mono">
                {i + 1}. {b.address}
                {i === myIndex ? ' (you)' : ''}
              </span>
              <span>
                {g.outcome===OUTCOME.UNRESOLVED_REFUNDED?`${formatUsdc(g.escrowAmount)} USDC escrow refund: ${i<g.refundedCount?'settled':'pending'}; no compensation`:success ? 'No payout' : failure ? `${formatUsdc(each)} USDC: ${b.paid ? 'paid' : 'pending'}` : `${formatUsdc(each)} USDC if failure is established`}
              </span>
            </li>
          ))}
        </ul>
      )}
      {myIndex >= 0 && failure && !g.beneficiaries[myIndex]?.paid && (
        <p className="mc-hint">Your payout is pending. Anyone can run settlement; you do not need to claim.</p>
      )}
      {chain.now !== undefined && <p className="mc-hint">Chain time {fmtTime(chain.now)}</p>}
    </>
  )
}

export function LookupCard({ idInput, onIdChange, latestId, read, account, operator, chain, compact = false }: Props) {
  const parsed = /^\d{1,18}$/.test(idInput) ? BigInt(idInput) : undefined
  const id = parsed !== undefined && parsed > 0n ? parsed : undefined
  const shareLink = useShareLink(read.state === 'ready' ? id : undefined)

  return (
    <Card title="Find a guarantee">
      <label className="mc-label" htmlFor="guarantee-id">
        Guarantee id
      </label>
      <div className="mc-actions mc-mt-1">
        <input
          id="guarantee-id"
          className="mc-input"
          inputMode="numeric"
          autoComplete="off"
          placeholder={latestId && latestId > 0n ? `Latest is ${latestId.toString()}` : 'For example 1'}
          value={idInput}
          onChange={(e) => onIdChange(e.target.value.trim())}
        />
        <button type="button" className={ghostButton} disabled={!latestId || latestId < 1n} onClick={() => latestId && onIdChange(latestId.toString())}>
          Load the latest guarantee
        </button>
      </div>
      <p className="mc-hint">
        {latestId === undefined ? 'Reading the contract...' : `${latestId.toString()} guarantee${latestId === 1n ? '' : 's'} created so far.`}
      </p>

      {shareLink && (
        <div className="mc-mt-3">
          <Dl>
            <Row label="Shareable link">
              <span className="mc-addr">
                <span className="mc-mono mc-addr-text">{shareLink}</span>
                <span className="mc-addr-actions">
                  <CopyButton value={shareLink} label="share link" />
                </span>
              </span>
            </Row>
          </Dl>
          <p className="mc-hint">Anyone who opens this link sees the same public detail, read from the chain. It contains only the guarantee id.</p>
        </div>
      )}

      <div className="mc-mt-4" aria-live="polite">
        {idInput === '' ? (
          <p className="mc-p mc-muted">Enter the guarantee number shared by the provider.</p>
        ) : id === undefined ? (
          <p className="mc-bad">Enter a whole number of 1 or more.</p>
        ) : read.state === 'ready' && read.data ? (
          compact ? null : <Details g={read.data} account={account} operator={operator} chain={chain} />
        ) : read.state === 'unknown' ? (
          <Callout>No guarantee exists with this id on this contract.</Callout>
        ) : read.state === 'unavailable' ? (
          <div className="mc-actions" role="alert">
            <Callout tone="warn">
              Could not read the {read.failed.join(', ')} from the network. This does not mean the guarantee is missing or that you are unpaid. Every action stays disabled until all reads succeed.
            </Callout>
            <button type="button" className={ghostButton} onClick={read.refetch}>
              Retry
            </button>
          </div>
        ) : (
          <p className="mc-p mc-muted">Loading from the chain...</p>
        )}
      </div>
    </Card>
  )
}
