import { TokenUSDC } from '@web3icons/react'
import { Card, Row } from './Card'
import { EXAMPLE, exampleAmounts } from '../example'

const amounts = exampleAmounts(EXAMPLE)

export function ExampleCard() {
  return (
    <Card
      title="Guarantee model"
      aside={
        <span className="rounded-full bg-[var(--surface-muted)] px-2.5 py-1 text-[11px] font-medium text-[var(--muted)]">
          Illustrative
        </span>
      }
    >
      <p className="text-sm text-[var(--muted)] text-pretty">{EXAMPLE.scenario}</p>

      <div className="mt-4 flex items-end gap-2">
        <span className="display text-5xl font-semibold tabular-nums text-[var(--ink)]">{amounts.totalLocked}</span>
        <span className="mb-1.5 flex items-center gap-1.5 text-sm font-medium text-[var(--ink-2)]">
          <TokenUSDC variant="branded" size={18} /> USDC
        </span>
      </div>
      <p className="mt-1 text-sm text-[var(--muted)]">Held by the contract once the cohort is full</p>

      <dl className="mt-5 rounded-2xl bg-[var(--surface-strong)] p-4">
        <Row label="Provider bond">{amounts.bond} USDC</Row>
        <Row label={`Escrow per beneficiary (${amounts.perEscrow} x ${amounts.cohort})`}>{amounts.totalEscrow} USDC</Row>
        <Row label="Fixed compensation per beneficiary">{amounts.perCompensation} USDC</Row>
        <Row label="Cohort bound">{amounts.cohort} beneficiaries</Row>
      </dl>

      <ul className="mt-4 grid grid-cols-3 gap-2">
        {EXAMPLE.beneficiaries.map((b, i) => (
          <li
            key={b.label}
            className="rounded-2xl border border-[var(--border)] bg-[var(--surface-strong)] px-3 py-3 text-center"
          >
            <div className="display text-lg font-semibold text-[var(--ink)]">{i + 1}</div>
            <div className="text-[11px] text-[var(--muted)]">Beneficiary</div>
          </li>
        ))}
      </ul>

      <p className="mt-4 text-xs text-[var(--subtle)] text-pretty">
        {EXAMPLE.providerLabel} is the provider. Each {EXAMPLE.beneficiaryNoun.toLowerCase()} is a beneficiary.
        The bond always covers the full cohort, so every beneficiary can be compensated.
      </p>
    </Card>
  )
}
