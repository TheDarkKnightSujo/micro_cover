import { useState } from 'react'
import type { Address } from 'viem'
import { formatUsdc } from '@/onchain-money'
import { STATUS, TARGET_CHAIN_ID, microCoverAbi } from '../contract'
import type { GuaranteeRead, GuaranteeView } from '../useGuarantee'
import { useTxFlow } from '../useTxFlow'
import { Card } from './Card'
import { ChainGate, ghostButton, primaryButton } from './ChainGate'
import { EnrollSection } from './EnrollSection'
import { TxStatus } from './TxStatus'

const short = (address: string) => `${address.slice(0, 6)}...${address.slice(-4)}`
const isSame = (a: string | undefined, b: string) => a !== undefined && a.toLowerCase() === b.toLowerCase()

interface SectionProps {
  contract: Address
  id: bigint
  g: GuaranteeView
  read: GuaranteeRead
  account: Address | undefined
}

function AdmitSection({ contract, id, g, read, account }: SectionProps) {
  const [armed, setArmed] = useState(false)
  const tx = useTxFlow(() => {
    setArmed(false)
    read.refetch()
  })
  const provider = isSame(account, g.provider)
  const owed = (g.escrowAmount + g.compensation) * BigInt(g.cohortSize)

  return (
    <section>
      <h3 className="text-sm font-semibold text-[var(--ink)]">Provider: admit failure</h3>
      <p className="mt-1 text-sm text-[var(--muted)] text-pretty">
        Closes enrollment immediately and starts payouts. It can only be done once and cannot be undone.
      </p>
      <div className="mt-3">
        {g.status !== STATUS.OPEN ? (
          <p className="text-sm text-[var(--subtle)]">Failure has already been admitted for this guarantee.</p>
        ) : !provider ? (
          <p className="text-sm text-[var(--subtle)]">Only the provider ({short(g.provider)}) can admit failure.</p>
        ) : (
          <ChainGate>
            {armed && (
              <p className="mb-3 text-sm text-[var(--ink-2)] text-pretty">
                {g.cohortSize === 0
                  ? 'No one is enrolled, so nothing is paid out and you can then withdraw the whole bond.'
                  : `${g.cohortSize} beneficiar${g.cohortSize === 1 ? 'y' : 'ies'} will be paid ${formatUsdc(owed)} USDC in total (their escrow plus compensation).`}
              </p>
            )}
            <div className="flex gap-2">
              {armed && (
                <button type="button" className={`${ghostButton} !w-auto`} disabled={tx.busy} onClick={() => setArmed(false)}>
                  Cancel
                </button>
              )}
              <button
                type="button"
                className={primaryButton}
                disabled={tx.busy}
                onClick={() =>
                  armed
                    ? tx.writeContract({ address: contract, abi: microCoverAbi, functionName: 'admitFailure', args: [id], chainId: TARGET_CHAIN_ID })
                    : setArmed(true)
                }
              >
                {tx.phase === 'wallet' ? 'Confirm in wallet...' : tx.phase === 'confirming' ? 'Admitting...' : armed ? 'Confirm: admit failure' : 'Admit failure'}
              </button>
            </div>
            <TxStatus phase={tx.phase} hash={tx.hash} message={tx.message} successText="Failure admitted. Enrollment is closed." />
          </ChainGate>
        )}
      </div>
    </section>
  )
}

function SettleSection({ contract, id, g, read }: SectionProps) {
  const tx = useTxFlow(() => read.refetch())
  const remaining = g.cohortSize - g.paidCount
  const batch = Math.min(g.maxBatch, remaining)
  const next = g.beneficiaries.slice(g.paidCount, g.paidCount + batch)
  const each = g.escrowAmount + g.compensation

  return (
    <section>
      <h3 className="text-sm font-semibold text-[var(--ink)]">Settle payouts</h3>
      <p className="mt-1 text-sm text-[var(--muted)] text-pretty">
        Anyone can continue settlement. Recipients and amounts come only from enrollment and the guarantee terms;
        each call pays at most {g.maxBatch} beneficiaries.
      </p>
      <div className="mt-3">
        {g.status === STATUS.OPEN ? (
          <p className="text-sm text-[var(--subtle)]">Available after the provider admits failure.</p>
        ) : remaining === 0 ? (
          <p className="text-sm text-[var(--subtle)]">Every enrolled beneficiary has been paid.</p>
        ) : (
          <ChainGate>
            <ul className="mb-3 divide-y divide-[var(--border)] rounded-2xl bg-[var(--surface-strong)] px-4">
              {next.map((b, i) => (
                <li key={b.address} className="flex items-center justify-between gap-3 py-2 text-sm">
                  <span>
                    <span className="text-[var(--subtle)]">{g.paidCount + i + 1}.</span> <span className="mono text-[13px]">{short(b.address)}</span>
                  </span>
                  <span className="tabular-nums">{formatUsdc(each)} USDC</span>
                </li>
              ))}
            </ul>
            <button
              type="button"
              className={primaryButton}
              disabled={tx.busy}
              onClick={() =>
                tx.writeContract({
                  address: contract,
                  abi: microCoverAbi,
                  functionName: 'settleFailure',
                  args: [id, batch],
                  chainId: TARGET_CHAIN_ID,
                })
              }
            >
              {tx.phase === 'wallet'
                ? 'Confirm in wallet...'
                : tx.phase === 'confirming'
                  ? 'Paying...'
                  : `Pay next ${batch} of ${remaining} remaining`}
            </button>
            <TxStatus phase={tx.phase} hash={tx.hash} message={tx.message} successText="Payouts confirmed." />
          </ChainGate>
        )}
      </div>
    </section>
  )
}

function WithdrawSection({ contract, id, g, read, account }: SectionProps) {
  const tx = useTxFlow(() => read.refetch())
  const provider = isSame(account, g.provider)
  const remaining = g.cohortSize - g.paidCount

  return (
    <section>
      <h3 className="text-sm font-semibold text-[var(--ink)]">Provider: withdraw remaining bond</h3>
      <p className="mt-1 text-sm text-[var(--muted)] text-pretty">
        After failure is admitted and every enrolled beneficiary is paid, any unused bond returns to the provider.
        It is never available while the guarantee is open.
      </p>
      <div className="mt-3">
        {g.status === STATUS.OPEN ? (
          <p className="text-sm text-[var(--subtle)]">Not available while the guarantee is open.</p>
        ) : g.status === STATUS.CLOSED ? (
          <p className="text-sm text-[var(--subtle)]">Closed: no bond remains for this guarantee.</p>
        ) : remaining > 0 ? (
          <p className="text-sm text-[var(--subtle)]">
            {remaining} beneficiar{remaining === 1 ? 'y is' : 'ies are'} still unpaid. Settle them first.
          </p>
        ) : !provider ? (
          <p className="text-sm text-[var(--subtle)]">
            {formatUsdc(g.withdrawableBond)} USDC can be withdrawn by the provider ({short(g.provider)}).
          </p>
        ) : (
          <ChainGate>
            <button
              type="button"
              className={primaryButton}
              disabled={tx.busy || g.withdrawableBond === 0n}
              onClick={() =>
                tx.writeContract({
                  address: contract,
                  abi: microCoverAbi,
                  functionName: 'withdrawRemainingBond',
                  args: [id],
                  chainId: TARGET_CHAIN_ID,
                })
              }
            >
              {tx.phase === 'wallet'
                ? 'Confirm in wallet...'
                : tx.phase === 'confirming'
                  ? 'Withdrawing...'
                  : `Withdraw ${formatUsdc(g.withdrawableBond)} USDC`}
            </button>
            <TxStatus phase={tx.phase} hash={tx.hash} message={tx.message} successText="Remaining bond withdrawn. The guarantee is closed." />
          </ChainGate>
        )}
      </div>
    </section>
  )
}

interface Props {
  contract: Address
  id: bigint | undefined
  read: GuaranteeRead
  account: Address | undefined
}

export function ActionsCard({ contract, id, read, account }: Props) {
  const g = read.data
  return (
    <Card title="Actions">
      {id === undefined ? (
        <p className="text-sm text-[var(--muted)]">Select an existing guarantee above to see what you can do with it.</p>
      ) : read.state === 'unavailable' ? (
        <p className="text-sm text-[var(--muted)]">Actions are disabled until the guarantee can be read. Use Retry above.</p>
      ) : read.state === 'unknown' ? (
        <p className="text-sm text-[var(--muted)]">No guarantee with this id yet.</p>
      ) : !g || g.forId !== id || g.forAccount !== account ? (
        <p className="text-sm text-[var(--muted)]">Loading...</p>
      ) : (
        // Remount per contract + guarantee + wallet so armed confirmations and transaction
        // results can never carry over to a different selection or account.
        <div
          key={`${contract}:${id.toString()}:${account ?? 'none'}`}
          className="flex flex-col gap-6 divide-y divide-[var(--border)] [&>section:not(:first-child)]:pt-6"
        >
          <EnrollSection contract={contract} id={id} g={g} read={read} account={account} />
          <AdmitSection contract={contract} id={id} g={g} read={read} account={account} />
          <SettleSection contract={contract} id={id} g={g} read={read} account={account} />
          <WithdrawSection contract={contract} id={id} g={g} read={read} account={account} />
        </div>
      )}
    </Card>
  )
}
