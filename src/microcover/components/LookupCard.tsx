import type { Address } from 'viem'
import { formatUsdc } from '@/onchain-money'
import { OUTCOME, STATUS, STATUS_LABEL } from '../contract'
import type { GuaranteeRead, GuaranteeView } from '../useGuarantee'
import { Card, Row } from './Card'
import { ghostButton } from './ChainGate'

const when = (seconds: bigint) => new Date(Number(seconds) * 1000).toLocaleString()
const short = (address: string) => `${address.slice(0, 6)}...${address.slice(-4)}`

interface Props {
  /** Undefined until the contract address is published; no read is attempted then. */
  live: boolean
  idInput: string
  onIdChange: (value: string) => void
  /** Highest existing guarantee id, when known. */
  latestId: bigint | undefined
  read: GuaranteeRead | undefined
  account: Address | undefined
}

function badgeClass(status: number): string {
  if (status === STATUS.CLOSED) return 'bg-[var(--surface-muted)] text-[var(--muted)]'
  if (status === STATUS.FAILED) return 'bg-[#fbe9ee] text-[var(--danger)]'
  return 'bg-[#e6f4ec] text-[var(--success)]'
}

function Terms({ g, account }: { g: GuaranteeView; account: Address | undefined }) {
  const role =
    account && g.provider.toLowerCase() === account.toLowerCase()
      ? 'You are the provider'
      : g.isMember
        ? 'You are a beneficiary'
        : undefined
  return (
    <>
      <div className="flex flex-wrap items-center gap-2">
        <span className={`rounded-full px-2.5 py-1 text-xs font-semibold ${badgeClass(g.status)}`}>
          {STATUS_LABEL[g.status] ?? 'Unknown'}
        </span>
        <span className="rounded-full bg-[var(--surface-muted)] px-2.5 py-1 text-xs font-medium text-[var(--muted)]">
          Verdict: {g.outcome === OUTCOME.FAILURE ? 'failure admitted' : 'none yet'}
        </span>
        {role && <span className="text-xs text-[var(--subtle)]">{role}</span>}
      </div>

      <dl className="mt-4 rounded-2xl bg-[var(--surface-strong)] p-4">
        <Row label="Provider">
          <span className="mono text-[13px]">{short(g.provider)}</span>
        </Row>
        <Row label="Cohort">
          {g.cohortSize} / {g.maxCohort}
        </Row>
        <Row label="Compensation each">{formatUsdc(g.compensation)} USDC</Row>
        <Row label="Escrow each">{formatUsdc(g.escrowAmount)} USDC</Row>
        <Row label="Join deadline">{when(g.joinDeadline)}</Row>
        <Row label="Open to join">{g.joinable ? `Yes, ${g.openSlots} slot${g.openSlots === 1 ? '' : 's'}` : 'No'}</Row>
      </dl>

      <h3 className="mt-5 text-xs font-semibold uppercase tracking-[0.08em] text-[var(--muted)]">Funds held</h3>
      <dl className="mt-2 rounded-2xl bg-[var(--surface-strong)] p-4">
        <Row label="Bond held">{formatUsdc(g.bondHeld)} USDC</Row>
        <Row label="Of which reserved for beneficiaries">{formatUsdc(g.reservedCompensation)} USDC</Row>
        <Row label="Escrow held">{formatUsdc(g.escrowHeld)} USDC</Row>
        <Row label="Still owed to beneficiaries">{formatUsdc(g.remainingOwed)} USDC</Row>
        <Row label="Remaining bond provider can withdraw">{formatUsdc(g.withdrawableBond)} USDC</Row>
      </dl>

      <h3 className="mt-5 text-xs font-semibold uppercase tracking-[0.08em] text-[var(--muted)]">
        Payout progress: {g.paidCount} of {g.cohortSize} paid
      </h3>
      {g.beneficiaries.length === 0 ? (
        <p className="mt-2 text-sm text-[var(--muted)]">No beneficiaries enrolled.</p>
      ) : (
        <ul className="mt-2 divide-y divide-[var(--border)] rounded-2xl bg-[var(--surface-strong)] px-4">
          {g.beneficiaries.map((b, i) => (
            <li key={b.address} className="flex items-center justify-between gap-3 py-2.5 text-sm">
              <span className="min-w-0 truncate">
                <span className="text-[var(--subtle)]">{i + 1}.</span> <span className="mono text-[13px]">{short(b.address)}</span>
              </span>
              <span className="shrink-0 tabular-nums text-[var(--ink-2)]">
                {formatUsdc(g.escrowAmount + g.compensation)} USDC{' '}
                <span className={b.paid ? 'text-[var(--success)]' : 'text-[var(--subtle)]'}>{b.paid ? 'paid' : 'pending'}</span>
              </span>
            </li>
          ))}
        </ul>
      )}
      <p className="mt-2 text-xs text-[var(--subtle)] text-pretty">
        Each payout returns the beneficiary&apos;s escrow plus the fixed compensation, in enrollment order.
      </p>
    </>
  )
}

export function LookupCard({ live, idInput, onIdChange, latestId, read, account }: Props) {
  const parsed = /^\d{1,18}$/.test(idInput) ? BigInt(idInput) : undefined

  return (
    <Card title="Guarantee">
      {!live ? (
        <p className="text-sm text-[var(--muted)] text-pretty">
          MicroCover is not live on Arc Testnet yet. Once it is, guarantees you create or look up appear here with
          their status, funds held and payout progress, read straight from the chain.
        </p>
      ) : (
        <>
          <label className="block text-xs font-semibold uppercase tracking-[0.08em] text-[var(--muted)]" htmlFor="guarantee-id">
            Guarantee id
          </label>
          <div className="mt-1.5 flex gap-2">
            <input
              id="guarantee-id"
              inputMode="numeric"
              placeholder={latestId && latestId > 0n ? latestId.toString() : '1'}
              value={idInput}
              onChange={(e) => onIdChange(e.target.value.trim())}
              className="min-h-11 min-w-0 flex-1 rounded-2xl border border-[var(--border)] bg-[var(--surface-strong)] px-4 text-base tabular-nums text-[var(--ink)] outline-none focus:border-[var(--focus)] focus:ring-2 focus:ring-[var(--focus)]/40"
            />
            <button
              type="button"
              className={`${ghostButton} !w-auto shrink-0`}
              disabled={!latestId || latestId < 1n}
              onClick={() => latestId && onIdChange(latestId.toString())}
            >
              Latest
            </button>
          </div>
          <p className="mt-1 text-xs text-[var(--subtle)]">
            {latestId === undefined
              ? 'Reading the contract...'
              : `${latestId.toString()} guarantee${latestId === 1n ? '' : 's'} created so far`}
          </p>

          <div className="mt-4">
            {idInput === '' ? (
              <p className="text-sm text-[var(--muted)]">Enter a guarantee id, or create one above.</p>
            ) : parsed === undefined || parsed === 0n ? (
              <p className="text-sm text-[var(--danger)]">Enter a whole number of 1 or more.</p>
            ) : read?.state === 'ready' && read.data ? (
              <Terms g={read.data} account={account} />
            ) : read?.state === 'unknown' ? (
              <p className="text-sm text-[var(--muted)]">No guarantee with this id yet.</p>
            ) : read?.state === 'unavailable' ? (
              <div>
                <p className="text-sm text-[var(--danger)]">
                  Could not read the {read.failed.join(', ')}. Nothing is shown until every read succeeds, so no action is offered.
                </p>
                <button type="button" className={`${ghostButton} mt-3`} onClick={read.refetch}>
                  Retry
                </button>
              </div>
            ) : (
              <p className="text-sm text-[var(--muted)]">Loading...</p>
            )}
          </div>
        </>
      )}
    </Card>
  )
}
