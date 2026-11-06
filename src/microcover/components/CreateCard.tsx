import { useState } from 'react'
import { keccak256, parseEventLogs, stringToHex } from 'viem'
import { usePublicClient } from 'wagmi'
import { formatUsdc, parseUsdc } from '@/onchain-money'
import { EXAMPLE } from '../example'
import { MAX_COHORT_LIMIT, MICROCOVER_ADDRESS, TARGET_CHAIN_ID, UINT128_MAX, microCoverAbi } from '../contract'
import { useTxFlow } from '../useTxFlow'
import { useUsdcApproval } from '../useUsdcApproval'
import { ApprovalStep, approvalReady } from './ApprovalStep'
import { Card, Row } from './Card'
import { ChainGate, primaryButton } from './ChainGate'
import { Field } from './Field'
import { TxStatus } from './TxStatus'

/** Opaque, fixed terms label for the synthetic demo (the contract only stores the hash). */
const TERMS_HASH = keccak256(stringToHex('microcover-phase1-synthetic-demo'))
const SETTLEMENT_DELAY_SECONDS = 24n * 60n * 60n

/** Parses a positive USDC amount that fits the contract's uint128 term; undefined otherwise. */
function tryParseUsdc(value: string): bigint | undefined {
  try {
    const parsed = parseUsdc(value)
    return parsed > 0n && parsed <= UINT128_MAX ? parsed : undefined
  } catch {
    return undefined
  }
}

function amountError(value: string, parsed: bigint | undefined): string | undefined {
  if (parsed !== undefined) return undefined
  try {
    return parseUsdc(value) > UINT128_MAX ? 'Amount is too large' : 'Enter an amount above 0'
  } catch {
    return 'Enter an amount above 0, up to 6 decimals'
  }
}

export function CreateCard({ onCreated }: { onCreated: (id: bigint) => void }) {
  const contract = MICROCOVER_ADDRESS
  const publicClient = usePublicClient({ chainId: TARGET_CHAIN_ID })
  const [compensation, setCompensation] = useState(formatUsdc(EXAMPLE.compensation))
  const [escrow, setEscrow] = useState(formatUsdc(EXAMPLE.escrowAmount))
  const [cohort, setCohort] = useState(String(EXAMPLE.beneficiaries.length))
  const [minutes, setMinutes] = useState('60')
  const [preparing, setPreparing] = useState(false)
  const [prepareError, setPrepareError] = useState<string>()

  const comp = tryParseUsdc(compensation)
  const esc = tryParseUsdc(escrow)
  const sizeNumber = /^\d{1,4}$/.test(cohort) ? Number(cohort) : 0
  const size = sizeNumber >= 1 && sizeNumber <= MAX_COHORT_LIMIT ? BigInt(sizeNumber) : undefined
  const windowMinutes = /^\d{1,5}$/.test(minutes) && Number(minutes) >= 1 ? BigInt(minutes) : undefined

  const bond = comp !== undefined && size !== undefined ? comp * size : undefined
  const maxEscrow = esc !== undefined && size !== undefined ? esc * size : undefined
  const valid = comp !== undefined && esc !== undefined && size !== undefined && windowMinutes !== undefined

  const approval = useUsdcApproval(valid ? bond : undefined)
  const tx = useTxFlow((receipt) => {
    const logs = parseEventLogs({ abi: microCoverAbi, eventName: 'GuaranteeCreated', logs: receipt.logs })
    const mine = logs.find((log) => log.address.toLowerCase() === contract?.toLowerCase())
    if (mine) onCreated(mine.args.id)
    approval.refetch()
  })

  const create = async () => {
    if (!contract || !publicClient || comp === undefined || esc === undefined || size === undefined || windowMinutes === undefined) return
    setPrepareError(undefined)
    setPreparing(true)
    try {
      // Deadlines are measured against the chain's own clock, not this browser's.
      const block = await publicClient.getBlock()
      const joinDeadline = block.timestamp + windowMinutes * 60n
      tx.writeContract({
        address: contract,
        abi: microCoverAbi,
        functionName: 'createGuarantee',
        args: [comp, esc, Number(size), joinDeadline, joinDeadline + SETTLEMENT_DELAY_SECONDS, TERMS_HASH],
        chainId: TARGET_CHAIN_ID,
      })
    } catch {
      setPrepareError('Could not read the latest block. Check your connection and try again.')
    } finally {
      setPreparing(false)
    }
  }

  return (
    <Card
      title="Create and fund"
      aside={
        <span className="rounded-full bg-[var(--surface-muted)] px-2.5 py-1 text-[11px] font-medium text-[var(--muted)]">
          Synthetic demo
        </span>
      }
    >
      <p className="mb-4 text-sm text-[var(--muted)] text-pretty">
        You become the provider and lock the full bond up front: compensation x cohort size, in testnet USDC.
        There is no success release in this phase: funds move only if you admit failure.
      </p>

      <div className="grid grid-cols-2 gap-3">
        <Field id="create-comp" label="Compensation each" value={compensation} onChange={setCompensation} suffix="USDC"
          error={amountError(compensation, comp)} />
        <Field id="create-escrow" label="Escrow each" value={escrow} onChange={setEscrow} suffix="USDC"
          error={amountError(escrow, esc)} />
        <Field id="create-cohort" label="Cohort size" value={cohort} onChange={setCohort}
          error={size === undefined ? `Whole number from 1 to ${MAX_COHORT_LIMIT}` : undefined} />
        <Field id="create-window" label="Join window" value={minutes} onChange={setMinutes} suffix="min"
          error={windowMinutes === undefined ? 'Whole minutes, 1 or more' : undefined} />
      </div>

      <dl className="mt-4 rounded-2xl bg-[var(--surface-strong)] p-4">
        <Row label="Bond you lock now">{bond !== undefined ? `${formatUsdc(bond)} USDC` : '-'}</Row>
        <Row label="Escrow from a full cohort">{maxEscrow !== undefined ? `${formatUsdc(maxEscrow)} USDC` : '-'}</Row>
        <Row label="Held when the cohort is full">
          {bond !== undefined && maxEscrow !== undefined ? `${formatUsdc(bond + maxEscrow)} USDC` : '-'}
        </Row>
      </dl>

      <div className="mt-4">
        {!contract ? (
          <p className="text-sm text-[var(--muted)] text-pretty">
            Preview only: MicroCover is not live on Arc Testnet yet, so nothing can be created or sent. You can edit
            the amounts above to see how the bond and escrow add up.
          </p>
        ) : (
          <ChainGate>
            <div className="flex flex-col gap-2">
              <ApprovalStep approval={approval} contract={contract} required={valid ? bond : undefined} valid={valid} />
              <button
                type="button"
                className={primaryButton}
                disabled={!valid || !approvalReady(approval) || tx.busy || preparing}
                onClick={() => void create()}
              >
                {preparing || tx.phase === 'wallet' ? 'Confirm in wallet...' : tx.phase === 'confirming' ? 'Creating...' : '2. Create guarantee'}
              </button>
              <TxStatus phase={tx.phase} hash={tx.hash} message={prepareError ?? tx.message} successText="Guarantee created and funded. It is selected below." />
            </div>
          </ChainGate>
        )}
      </div>
    </Card>
  )
}
