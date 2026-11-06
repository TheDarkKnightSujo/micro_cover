import { useState } from 'react'
import { parseEventLogs } from 'viem'
import { formatUsdc, parseUsdc } from '@/onchain-money'
import { EXAMPLE } from '../example'
import { MAX_COHORT_LIMIT, MICROCOVER_ADDRESS, TARGET_CHAIN_ID, UINT128_MAX, microCoverAbi } from '../contract'
import { fmtDuration, fmtTime } from '../format'
import { PRESET_CONDITION_TEXT, PRESET_TERMS_HASH } from '../terms'
import type { Capability } from '../useCapability'
import { type ChainTime, useFreshChainTime } from '../useChainTime'
import { useTxFlow } from '../useTxFlow'
import { useUsdcApproval } from '../useUsdcApproval'
import { ApprovalStep, approvalReady } from './ApprovalStep'
import { Badge, Callout, Card, Dl, Row } from './Card'
import { ChainGate, primaryButton } from './ChainGate'
import { Field } from './Field'
import { TxStatus } from './TxStatus'

const MAX_MINUTES = 10_080n // one week

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

function minutes(value: string, min: bigint): bigint | undefined {
  if (!/^\d{1,5}$/.test(value)) return undefined
  const n = BigInt(value)
  return n >= min && n <= MAX_MINUTES ? n : undefined
}

interface Props {
  cap: Capability
  chain: ChainTime
  onCreated: (id: bigint) => void
}

export function CreateCard({ cap, chain, onCreated }: Props) {
  const contract = MICROCOVER_ADDRESS
  const live = cap.state === 'ready' && contract !== undefined
  const freshNow = useFreshChainTime()
  const [compensation, setCompensation] = useState(formatUsdc(EXAMPLE.compensation))
  const [escrow, setEscrow] = useState(formatUsdc(EXAMPLE.escrowAmount))
  const [cohort, setCohort] = useState(String(EXAMPLE.beneficiaries.length))
  const [joinMinutes, setJoinMinutes] = useState('10')
  const [delayMinutes, setDelayMinutes] = useState('0')
  const [preparing, setPreparing] = useState(false)
  const [prepareError, setPrepareError] = useState<string>()

  const comp = tryParseUsdc(compensation)
  const esc = tryParseUsdc(escrow)
  const sizeNumber = /^\d{1,4}$/.test(cohort) ? Number(cohort) : 0
  const size = sizeNumber >= 1 && sizeNumber <= MAX_COHORT_LIMIT ? BigInt(sizeNumber) : undefined
  const join = minutes(joinMinutes, 1n)
  const delay = minutes(delayMinutes, 0n)

  const bond = comp !== undefined && size !== undefined ? comp * size : undefined
  const maxEscrow = esc !== undefined && size !== undefined ? esc * size : undefined
  const valid = comp !== undefined && esc !== undefined && size !== undefined && join !== undefined && delay !== undefined

  const approval = useUsdcApproval(valid ? bond : undefined)
  const tx = useTxFlow({
    label: 'Create and fund guarantee',
    onConfirmed: (receipt) => {
      const logs = parseEventLogs({ abi: microCoverAbi, eventName: 'GuaranteeCreated', logs: receipt.logs })
      const mine = logs.find((log) => log.address.toLowerCase() === contract?.toLowerCase())
      if (mine) onCreated(mine.args.id)
      approval.refetch()
    },
  })

  // Illustrative timings from the latest block; the real ones are fixed from the newest block at submit.
  const reviewWindow = cap.state === 'ready' ? cap.reviewWindow : undefined
  const previewJoin = chain.now !== undefined && join !== undefined ? chain.now + join * 60n : undefined
  const previewOutcome = previewJoin !== undefined && delay !== undefined ? previewJoin + delay * 60n : undefined
  const previewClaimEnd = previewOutcome !== undefined && reviewWindow !== undefined ? previewOutcome + reviewWindow : undefined

  const create = () => {
    if (!live || comp === undefined || esc === undefined || size === undefined || join === undefined || delay === undefined) return
    setPrepareError(undefined)
    setPreparing(true)
    void (async () => {
      try {
        // Deadlines come from the chain's own latest block, never from this device's clock.
        const ts = await freshNow()
        const joinDeadline = ts + join * 60n
        const settlementTime = joinDeadline + delay * 60n
        tx.writeContract({
          address: contract,
          abi: microCoverAbi,
          functionName: 'createGuarantee',
          args: [comp, esc, Number(size), joinDeadline, settlementTime, PRESET_TERMS_HASH],
          chainId: TARGET_CHAIN_ID,
        })
      } catch {
        setPrepareError('Could not read the latest block time, so nothing was sent. Check your connection and try again.')
      } finally {
        setPreparing(false)
      }
    })()
  }

  return (
    <Card title="Provider setup: create and fund" aside={<Badge>Synthetic demo</Badge>}>
      <p className="mc-p">
        You become the provider and lock the full bond up front: compensation x cohort size, in testnet USDC. If the guarantee ends in failure, beneficiaries are paid from it. If success is finalized, the whole bond comes back to you.
      </p>

      <div className="mc-fields mc-fields-2 mc-mt-4">
        <Field id="create-comp" label="Compensation each" value={compensation} onChange={setCompensation} suffix="USDC" error={amountError(compensation, comp)} />
        <Field id="create-escrow" label="Price = full escrow each" value={escrow} onChange={setEscrow} suffix="USDC" error={amountError(escrow, esc)} />
        <Field id="create-cohort" label="Maximum cohort" value={cohort} onChange={setCohort} error={size === undefined ? `Whole number from 1 to ${MAX_COHORT_LIMIT}` : undefined} />
        <Field id="create-join" label="Join duration" value={joinMinutes} onChange={setJoinMinutes} suffix="min" error={join === undefined ? 'Whole minutes, 1 to 10080' : undefined} hint="Enrollment stays open this long after creation." />
        <Field id="create-delay" label="Outcome delay after join cutoff" value={delayMinutes} onChange={setDelayMinutes} suffix="min" error={delay === undefined ? 'Whole minutes, 0 to 10080' : undefined} hint="0 means the outcome deadline equals the join cutoff." />
      </div>

      <h3 className="mc-sub-h">Funds you lock</h3>
      <Dl>
        <Row label="Bond you lock now">{bond !== undefined ? `${formatUsdc(bond)} USDC` : '-'}</Row>
        <Row label="Escrow from a full cohort">{maxEscrow !== undefined ? `${formatUsdc(maxEscrow)} USDC` : '-'}</Row>
        <Row label="Held when the cohort is full">{bond !== undefined && maxEscrow !== undefined ? `${formatUsdc(bond + maxEscrow)} USDC` : '-'}</Row>
      </Dl>

      <h3 className="mc-sub-h">Resulting timings (chain time)</h3>
      <Dl>
        <Row label="Join cutoff">{previewJoin !== undefined ? `${fmtTime(previewJoin)} (about)` : '-'}</Row>
        <Row label="Outcome deadline">{previewOutcome !== undefined ? `${fmtTime(previewOutcome)} (about)` : '-'}</Row>
        <Row label="Review duration">{reviewWindow !== undefined ? fmtDuration(reviewWindow) : 'Fixed by the deployment'}</Row>
        <Row label="Claim end">{previewClaimEnd !== undefined ? `${fmtTime(previewClaimEnd)} (about)` : '-'}</Row>
      </Dl>
      <p className="mc-hint">
        Exact deadlines are fixed from the newest block when you submit, using chain time rather than this device&apos;s clock. Nothing is proposed or finalized automatically.
      </p>

      <h3 className="mc-sub-h">Condition</h3>
      <Callout>
        <strong>Synthetic preset.</strong> {PRESET_CONDITION_TEXT}
        <br />
        <span className="mc-mono">Terms hash {PRESET_TERMS_HASH}</span>
      </Callout>

      <div className="mc-mt-4">
        {!live ? (
          <Callout>
            <strong>Preview only.</strong> {cap.state === 'none' ? 'No contract is configured, so nothing can be created or sent.' : 'The deployment check has not passed, so creating is disabled.'} Edit the amounts above to see how the bond and escrow add up.
          </Callout>
        ) : (
          <ChainGate>
            <div className="mc-actions">
              <ApprovalStep approval={approval} contract={contract} required={valid ? bond : undefined} valid={valid} />
              <button type="button" className={primaryButton} disabled={!valid || !approvalReady(approval) || tx.busy || preparing} onClick={create}>
                {preparing || tx.phase === 'wallet' ? 'Confirm in your wallet...' : tx.phase === 'confirming' ? 'Creating...' : '2. Create guarantee'}
              </button>
              {prepareError && (
                <p className="mc-bad" role="alert">
                  {prepareError}
                </p>
              )}
              <TxStatus tx={tx} successText="Guarantee created and funded onchain. It is selected below." />
            </div>
          </ChainGate>
        )}
      </div>
    </Card>
  )
}
