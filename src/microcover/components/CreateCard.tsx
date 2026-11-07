import { useAccount, usePublicClient } from 'wagmi'
import { presentationCommitment, validatePresentation, type Presentation } from '../presentation'
import { useEffect, useRef, useState } from 'react'
import { bytesToHex, parseEventLogs } from 'viem'
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
import { EVIDENCE_DISCLOSURE, evidenceGet, useEvidencePolicy, validatePublicPolicy } from '../evidenceClient'
import { checkedEvidenceGas } from '../evidenceSubmission'
import { describeError } from '../errors'

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
  onCreated: (id: bigint, presentation?: Presentation) => void
  concert?: {name:string;venue:string;scheduledAt:string}
}

export function CreateCard({ cap, chain, onCreated, concert }: Props) {
  const {address:account}=useAccount()
  const client=usePublicClient({chainId:TARGET_CHAIN_ID})
  const creationLock=useRef(false)
  const active=useRef(true)
  useEffect(()=>{active.current=true;return()=>{active.current=false}},[])
  const pendingPresentation=useRef<Presentation | undefined>(undefined)
  const contract = MICROCOVER_ADDRESS
  const policy = useEvidencePolicy(contract)
  const policyReady = policy.isSuccess && !policy.isError && policy.data !== undefined
  const live = cap.state === 'ready' && contract !== undefined && policyReady
  const [cohortId,setCohortId] = useState(()=>bytesToHex(crypto.getRandomValues(new Uint8Array(32))))
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
  const amountsValid = comp !== undefined && esc !== undefined && size !== undefined && join !== undefined && delay !== undefined

  let context:Presentation|undefined
  try { if(concert && account && contract && policy.data && comp && esc && size) context=validatePresentation({schema:'microcover-concert-context-v1',chainId:'5042002',consumer:contract.toLowerCase(),provider:account.toLowerCase(),name:concert.name,venue:concert.venue,scheduledAt:concert.scheduledAt,price:esc.toString(),compensation:comp.toString(),capacity:Number(size),termsHash:PRESET_TERMS_HASH,policyHash:policy.data.policyHash}) } catch { /* Invalid event details never enable funding. */ }
  const valid=amountsValid && (!concert || !!context && chain.now!==undefined && BigInt(context.scheduledAt)>chain.now+60n && BigInt(context.scheduledAt)<=chain.now+604800n)
  const approval = useUsdcApproval(valid && live ? bond : undefined)
  const tx = useTxFlow({
    label: 'Create and fund guarantee',
    onConfirmed: (receipt) => {
      const logs = parseEventLogs({ abi: microCoverAbi, eventName: 'GuaranteeCreated', logs: receipt.logs })
      const mine = logs.find((log) => log.address.toLowerCase() === contract?.toLowerCase())
      if (mine) onCreated(mine.args.id, pendingPresentation.current)
      setCohortId(bytesToHex(crypto.getRandomValues(new Uint8Array(32))))
      approval.refetch()
    },
  })

  // Illustrative timings from the latest block; the real ones are fixed from the newest block at submit.
  const reviewWindow = cap.state === 'ready' ? cap.reviewWindow : undefined
  const relativePreviewJoin = chain.now !== undefined && join !== undefined ? chain.now + join * 60n : undefined
  const previewJoin=concert && context ? BigInt(context.scheduledAt) : relativePreviewJoin
  const previewOutcome = concert ? previewJoin : previewJoin !== undefined && delay !== undefined ? previewJoin + delay * 60n : undefined
  const previewClaimEnd = previewOutcome !== undefined && reviewWindow !== undefined ? previewOutcome + reviewWindow : undefined

  const create = () => {
    if (creationLock.current || !client || !account || !valid || !live || comp === undefined || esc === undefined || size === undefined || join === undefined || delay === undefined) return
    creationLock.current=true
    setPrepareError(undefined)
    setPreparing(true)
    void (async () => {
      try {
        // Deadlines come from the chain's own latest block, never from this device's clock.
        const ts = await freshNow()
        const currentPolicy = validatePublicPolicy(await evidenceGet('policy'), contract)
        if(!active.current) return
        if (currentPolicy.policyHash !== policy.data?.policyHash) throw Error('The displayed evidence policy changed. Review it again before purchase.')
        if(concert && (!context || BigInt(context.scheduledAt)<=ts+60n))throw Error('SCHEDULE_PASSED')
        const joinDeadline = context ? BigInt(context.scheduledAt) : ts + join * 60n
        const settlementTime = context ? joinDeadline : joinDeadline + delay * 60n
        pendingPresentation.current=context
        if(context)localStorage.setItem(`microcover:concert-draft:${context.consumer}:${context.provider}`,JSON.stringify(context))
        const request={
          address: contract,
          abi: microCoverAbi,
          functionName: 'createGuaranteeWithPolicy' as const,
          args: [comp, esc, Number(size), joinDeadline, settlementTime, PRESET_TERMS_HASH, currentPolicy.policyHash, context ? presentationCommitment(context) : cohortId] as const,
          account,
        }
        const gas=await checkedEvidenceGas(
          ()=>client.simulateContract(request),
          ()=>client.estimateContractGas(request),
          async()=>active.current && joinDeadline>(await freshNow())+(context?60n:0n)
            ? {ok:true} : {ok:false,reason:'The schedule is too close or this form was closed. Review before retrying.'},
        )
        tx.writeContract({...request,gas,chainId:TARGET_CHAIN_ID})
      } catch(error) {
        setPrepareError(`Funding preparation stopped before a wallet request. ${describeError(error).text}`)
      } finally {
        creationLock.current=false
        setPreparing(false)
      }
    })()
  }

  return (
    <Card title={concert ? "2. Price, protection & backing funds" : "Create your guarantee"} aside={<Badge>Synthetic demo</Badge>}>
      <p className="mc-p">
        You become the provider and lock the full bond up front: compensation x cohort size, in testnet USDC. If the guarantee ends in failure, beneficiaries are paid from it. If success is finalized, the whole bond comes back to you.
      </p>

      <fieldset disabled={tx.busy || approval.tx.busy || preparing} className="mc-fields mc-fields-2 mc-mt-4" style={{border:0,padding:0,minWidth:0}}>
        <Field id="create-comp" label={concert ? "Compensation per ticket holder" : "Extra compensation if it fails"} value={compensation} onChange={setCompensation} suffix="USDC" error={amountError(compensation, comp)} />
        <Field id="create-escrow" label={concert ? "Ticket price (protection included)" : "Customer payment (held in escrow)"} value={escrow} onChange={setEscrow} suffix="USDC" error={amountError(escrow, esc)} />
        <Field id="create-cohort" label={concert ? "Protected ticket capacity" : "Maximum customers"} value={cohort} onChange={setCohort} error={size === undefined ? `Whole number from 1 to ${MAX_COHORT_LIMIT}` : undefined} />
        {!concert && <><Field id="create-join" label="How long can customers join?" value={joinMinutes} onChange={setJoinMinutes} suffix="min" error={join === undefined ? 'Whole minutes, 1 to 10080' : undefined} hint="Enrollment stays open this long after creation." />
        <Field id="create-delay" label="Service deadline after joining closes" value={delayMinutes} onChange={setDelayMinutes} suffix="min" error={delay === undefined ? 'Whole minutes, 0 to 10080' : undefined} hint="0 means the outcome deadline equals the join cutoff." /></>}
      </fieldset>
      {concert && <Callout>Protection is included at no extra charge. To promise {comp ? formatUsdc(comp) : "X"} USDC compensation for {size?.toString() ?? "N"} tickets, set aside {bond ? formatUsdc(bond) : "X × N"} USDC. Ticket sales and the synthetic evidence cutoff both end at the scheduled time. Choose a time at least two minutes ahead, within seven days.</Callout>}

      <h3 className="mc-sub-h">Funds you lock</h3>
      <Dl>
        <Row label="Bond you lock now">{bond !== undefined ? `${formatUsdc(bond)} USDC` : '-'}</Row>
        <Row label="Escrow from a full cohort">{maxEscrow !== undefined ? `${formatUsdc(maxEscrow)} USDC` : '-'}</Row>
        <Row label="Held when the cohort is full">{bond !== undefined && maxEscrow !== undefined ? `${formatUsdc(bond + maxEscrow)} USDC` : '-'}</Row>
      </Dl>

      <details className="mc-disclosure mc-mt-4"><summary>Review exact deadlines</summary>
      <h3 className="mc-sub-h">Resulting timings (chain time)</h3>
      <Dl>
        <Row label="Join cutoff">{previewJoin !== undefined ? `${fmtTime(previewJoin)} (about)` : '-'}</Row>
        <Row label="Outcome deadline">{previewOutcome !== undefined ? `${fmtTime(previewOutcome)} (about)` : '-'}</Row>
        <Row label="Review duration">{reviewWindow !== undefined ? fmtDuration(reviewWindow) : 'Fixed by the deployment'}</Row>
        <Row label="Separate uncertainty timeout">{cap.state==='ready'?fmtDuration(cap.uncertaintyTimeout):'120 s required by this demo, separate from review'}</Row>
        <Row label="Claim end">{previewClaimEnd !== undefined ? `${fmtTime(previewClaimEnd)} (about)` : '-'}</Row>
      </Dl>
      <p className="mc-hint">
        Exact deadlines are fixed from the newest block when you submit, using chain time rather than this device&apos;s clock. Nothing is proposed or finalized automatically.
      </p>

      </details>
      <h3 className="mc-sub-h">What are you promising?</h3>
      <Callout>
        <strong>Synthetic preset.</strong> {PRESET_CONDITION_TEXT}
        <br />
        <span className="mc-hint">Fixed synthetic condition for this testnet demo.</span>
      </Callout>

      <h3 className="mc-sub-h">Evidence policy frozen before purchase</h3>
      <Callout tone="warn">{EVIDENCE_DISCLOSURE} Both synthetic-status-a and synthetic-status-b must provide fresh matching explicit statuses. Collection every 10 s; freshness 60 s at the outcome deadline. Missing, invalid, stale or conflicting evidence means offchain UNCERTAIN and opens no dispute automatically. Once explicitly onchain UNCERTAIN, the first 120 s deadline never resets. Unresolved fallback refunds full escrow, pays no compensation, and returns the bond only after all refunds. This can refund a delivered service if evidence is inconclusive.</Callout>
      <p className="mc-hint">Preserved dispute timing permits early onchain uncertainty. Its first timeout can therefore become eligible before the service outcome deadline.</p>
      <details className="mc-disclosure mc-mt-3"><summary>Technical policy identifiers</summary><Dl><Row label="Policy hash"><span className="mc-mono">{policyReady?policy.data.policyHash:'Unavailable: start the configured evidence service before creating'}</span></Row><Row label="Cohort ID"><span className="mc-mono">{cohortId}</span></Row></Dl></details>

      <div className="mc-mt-4">
        {!live ? (
          <Callout>
            <strong>Preview only.</strong> {cap.state === 'none' ? 'No contract is configured, so nothing can be created or sent.' : 'The deployment check has not passed, so creating is disabled.'} Edit the amounts above to see how the bond and escrow add up.
          </Callout>
        ) : (
          <ChainGate>
            <div className="mc-actions">
              <ApprovalStep approval={approval} contract={contract} required={valid ? bond : undefined} valid={valid} />
              <button type="button" className={primaryButton} disabled={!valid || !approvalReady(approval) || tx.busy || preparing || tx.receiptUnknown || !!concert && tx.phase==='success'} onClick={create}>
                {preparing ? 'Checking funding and estimating gas...' : tx.phase === 'wallet' ? 'Confirm in your wallet...' : tx.phase === 'confirming' ? 'Creating...' : concert ? '2. Fund ticket protection' : '2. Create guarantee'}
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
