import { useState } from 'react'
import type { Address } from 'viem'
import { useReadContract, useReadContracts } from 'wagmi'
import { formatUsdc } from '@/onchain-money'
import { Card, Row } from './Card'
import { MICROCOVER_ADDRESS, TARGET_CHAIN_ID, microCoverAbi } from '../contract'

const when = (seconds: bigint | number) => new Date(Number(seconds) * 1000).toLocaleString()

function Reader({ address }: { address: Address }) {
  const [input, setInput] = useState('1')
  const id = /^\d{1,18}$/.test(input) ? BigInt(input) : undefined

  const next = useReadContract({
    address,
    abi: microCoverAbi,
    functionName: 'nextGuaranteeId',
    chainId: TARGET_CHAIN_ID,
  })

  const base = { address, abi: microCoverAbi, chainId: TARGET_CHAIN_ID } as const
  const guarantee = useReadContracts({
    contracts: [
      { ...base, functionName: 'getGuarantee', args: [id ?? 0n] },
      { ...base, functionName: 'bondOf', args: [id ?? 0n] },
      { ...base, functionName: 'escrowedOf', args: [id ?? 0n] },
      { ...base, functionName: 'isJoinable', args: [id ?? 0n] },
    ],
    query: { enabled: id !== undefined },
  })

  const [terms, bond, escrowed, joinable] = guarantee.data ?? []
  const created = next.data === undefined ? undefined : next.data - 1n

  return (
    <>
      <p className="text-sm text-[var(--muted)]">
        {created === undefined ? 'Reading the contract...' : `${created.toString()} guarantee${created === 1n ? '' : 's'} created`}
      </p>

      <label className="mt-4 block text-xs font-semibold uppercase tracking-[0.08em] text-[var(--muted)]" htmlFor="guarantee-id">
        Guarantee id
      </label>
      <input
        id="guarantee-id"
        inputMode="numeric"
        value={input}
        onChange={(e) => setInput(e.target.value.trim())}
        className="mt-1.5 min-h-11 w-full rounded-2xl border border-[var(--border)] bg-[var(--surface-strong)] px-4 text-base tabular-nums text-[var(--ink)] outline-none focus:border-[var(--focus)] focus:ring-2 focus:ring-[var(--focus)]/40"
      />

      <div className="mt-4">
        {id === undefined ? (
          <p className="text-sm text-[var(--danger)]">Enter a whole number.</p>
        ) : guarantee.isLoading ? (
          <p className="text-sm text-[var(--muted)]">Loading...</p>
        ) : terms?.status === 'success' ? (
          <dl className="rounded-2xl bg-[var(--surface-strong)] p-4">
            <Row label="Provider">
              <span className="mono text-[13px]">{`${terms.result.provider.slice(0, 6)}...${terms.result.provider.slice(-4)}`}</span>
            </Row>
            <Row label="Cohort">
              {terms.result.cohortSize} / {terms.result.maxCohort}
            </Row>
            <Row label="Compensation each">{formatUsdc(terms.result.compensation)} USDC</Row>
            <Row label="Escrow each">{formatUsdc(terms.result.escrowAmount)} USDC</Row>
            <Row label="Bond held">{bond?.status === 'success' ? `${formatUsdc(bond.result)} USDC` : '-'}</Row>
            <Row label="Escrow held">{escrowed?.status === 'success' ? `${formatUsdc(escrowed.result)} USDC` : '-'}</Row>
            <Row label="Join deadline">{when(terms.result.joinDeadline)}</Row>
            <Row label="Settlement time">{when(terms.result.settlementTime)}</Row>
            <Row label="Open to join">{joinable?.status === 'success' ? (joinable.result ? 'Yes' : 'No') : '-'}</Row>
          </dl>
        ) : (
          <p className="text-sm text-[var(--muted)]">No guarantee with this id yet.</p>
        )}
      </div>
    </>
  )
}

export function LookupCard() {
  return (
    <Card title="Onchain guarantee">
      {MICROCOVER_ADDRESS ? (
        <Reader address={MICROCOVER_ADDRESS} />
      ) : (
        <p className="text-sm text-[var(--muted)] text-pretty">
          Deploy MicroCover to Arc Testnet, then add its address to <span className="mono text-[13px]">.env</span> as{' '}
          <span className="mono text-[13px]">VITE_MICROCOVER_ADDRESS</span> and restart the dev server. Live guarantees
          appear here, read directly from the chain.
        </p>
      )}
    </Card>
  )
}
