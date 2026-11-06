import { useRef, useState } from 'react'
import { usePublicClient } from 'wagmi'
import { useQuery } from '@tanstack/react-query'
import type { Address } from 'viem'
import { formatUsdc } from '@/onchain-money'
import { TARGET_CHAIN_ID, STATUS, microCoverAbi } from '../contract'
import { EVIDENCE_DISCLOSURE, evidenceGet, validatePrepared, validateSnapshot, type PreparedReport } from '../evidenceClient'
import { fmtDuration, fmtTime } from '../format'
import { earliestProposal, isOperator, type Verdict } from '../lifecycle'
import type { ChainTime } from '../useChainTime'
import type { GuaranteeRead, GuaranteeView } from '../useGuarantee'
import { Badge, Callout, Card, CopyButton, Dl, Row } from './Card'
import { ghostButton } from './ChainGate'
import { GuardedAction } from './GuardedAction'
import { checkedEvidenceGas } from '../evidenceSubmission'
import { describeError } from '../errors'
import type { TxWriter } from '../useTxFlow'

interface Props {contract:Address;id:bigint;g:GuaranteeView;read:GuaranteeRead;account:Address|undefined;operator:Address;chain:ChainTime;freshNow:()=>Promise<bigint>}
export function EvidenceCard({contract,id,g,read,account,operator,chain,freshNow}:Props){
  const [cursor,setCursor]=useState(0)
  const [report,setReport]=useState<PreparedReport>()
  const [error,setError]=useState<string>()
  const [preparing,setPreparing]=useState(false)
  const client=usePublicClient({chainId:TARGET_CHAIN_ID})
  const submissionLock=useRef(false)
  const [estimating,setEstimating]=useState(false)
  const [gasNote,setGasNote]=useState<string>()
  const snapshot=useQuery({queryKey:['evidence',contract,id.toString(),cursor],enabled:g.evidenceBound,queryFn:async({signal})=>validateSnapshot(await evidenceGet(`guarantees/${id}?after=${cursor}`,signal),g,contract),refetchInterval:5000,retry:1})
  const done=()=>{read.refetch();chain.refetch();setReport(undefined);void snapshot.refetch()}
  const common={chain,freshNow,guaranteeId:id,onConfirmed:done}
  const allowed=(now:bigint):Verdict=>{
    if(!isOperator({account,operator}))return {ok:false,reason:'Only the immutable demo operator can submit evidence.'}
    if(g.outcome!==0||!([STATUS.OPEN,STATUS.SUCCESS_PENDING,STATUS.UNCERTAIN] as number[]).includes(g.status))return {ok:false,reason:'This financial outcome is already established.'}
    if(g.status===STATUS.UNCERTAIN&&now>=g.uncertainReadyAt)return {ok:false,reason:'Timeout eligibility closes evidence resolution.'}
    if(!report)return {ok:false,reason:'Prepare a fresh established verdict first. UNCERTAIN is never submitted automatically.'}
    if(report.nonce!==g.nextVerdictNonce||now<report.evaluatedAt||now>report.validUntil)return {ok:false,reason:'Report is outdated. Prepare again.'}
    if(report.outcome===2&&(g.status===STATUS.SUCCESS_PENDING||now<earliestProposal(g)))return {ok:false,reason:'Success timing/review protections do not permit this proposal.'}
    return {ok:true}
  }
  const prepare=async()=>{
    setPreparing(true);setError(undefined);setReport(undefined)
    try{setReport(validatePrepared(await evidenceGet(`guarantees/${id}/prepare`),g,contract))}
    catch(e){setError(e instanceof Error?e.message:'Evidence unavailable; nothing sent.')}
    finally{setPreparing(false)}
  }
  const submit=(write:TxWriter)=>{
    if(submissionLock.current||!report||!account||!client)return
    submissionLock.current=true;setEstimating(true);setError(undefined);setGasNote(undefined)
    const request={address:contract,abi:microCoverAbi,functionName:'submitEvidenceVerdict' as const,args:[report] as const,account}
    void (async()=>{
      try{
        const gas=await checkedEvidenceGas(
          ()=>client.simulateContract(request),
          ()=>client.estimateContractGas(request),
          async()=>allowed(await freshNow()),
        )
        setGasNote(`Unsigned simulation passed. Gas limit ${gas} includes a 20% margin; review the actual fee in your wallet.`)
        write({...request,gas,chainId:TARGET_CHAIN_ID})
      }catch(e){setError(`Submission preflight stopped; no wallet request made. ${e instanceof Error&&!(e instanceof Object&&'shortMessage' in e)?e.message:describeError(e).text}`)}
      finally{submissionLock.current=false;setEstimating(false)}
    })()
  }
  const e=snapshot.data?.evaluation
  const refundRemaining=g.cohortSize-g.refundedCount
  return <Card title="Evidence, commitments and unresolved refunds" aside={<Badge>Synthetic feeds</Badge>}>
    <Callout tone="warn"><strong>{EVIDENCE_DISCLOSURE}</strong> Two authenticated identities are one source group. The trusted operator submits the result; the contract does not verify feed signatures or real-world truth. No CRE or Arkiv integration is active.</Callout>
    <Dl>
      <Row label="Frozen policy"><span className="mc-mono">{g.evidenceBound?g.policyHash:'Legacy manual demo: no evidence policy'}</span></Row>
      <Row label="Frozen cohort"><span className="mc-mono">{g.cohortId}</span></Row>
      <Row label="Uncertainty duration (separate)">{fmtDuration(g.uncertaintyTimeout)}</Row>
      <Row label="Success review (separate)">{fmtDuration(g.reviewWindow)}</Row>
      <Row label="First onchain uncertainty">{g.uncertaintyStarted?fmtTime(g.uncertainSince):'Not entered; offchain uncertainty does not start it'}</Row>
      <Row label="Non-resetting uncertainty deadline">{g.uncertaintyStarted?fmtTime(g.uncertainReadyAt):'Not started'}</Row>
      {g.status===STATUS.UNCERTAIN&&<Row label="Time remaining">{chain.now===undefined?'Chain time unavailable':chain.now>=g.uncertainReadyAt?'Eligible now':fmtDuration(g.uncertainReadyAt-chain.now)}</Row>}
      <Row label="Failure origin">{g.failureOrigin===2?'Evidence verdict (no provider admission)':g.failureOrigin===1?'Provider admission':'None'}</Row>
      <Row label="Latest Arc anchor"><span className="mc-mono">{g.latestEvidenceRoot}</span></Row>
    </Dl>
    {g.evidenceBound&&<>
      <h3 className="mc-sub-h">Deterministic deadline snapshot</h3>
      <p className="mc-p">Poll every 10 seconds. Both feeds must have matching explicit statuses fresh within 60 seconds at the outcome deadline. Later arrivals cannot rewrite that snapshot. Missing, stale, invalid, unknown or conflicting evidence stays UNCERTAIN.</p>
      {snapshot.isError&&<Callout tone="warn">Evidence unavailable. Start the local collector or restore its connection. No onchain dispute was opened, no money moved, and unavailable evidence is not proof of failure.</Callout>}
      {snapshot.isPending&&<p role="status">Reading evidence service...</p>}
      <button className={ghostButton} onClick={()=>void snapshot.refetch()}>Refresh evidence</button>
      {e&&<>
        <Dl>
          <Row label="Offchain outcome">{e.outcome}: {e.reason}</Row>
          <Row label="Coverage">{e.coveredSources}/2 identities, one team-controlled group</Row>
          <Row label="Weighted support (not probability)">Success {e.successSupportBps/100}% / failure {e.failureSupportBps/100}%</Row>
          <Row label="Snapshot deadline">{fmtTime(BigInt(e.asOf))}</Row>
          <Row label="Evidence commitment"><span className="mc-mono">{e.evidenceRoot}</span><CopyButton value={e.evidenceRoot} label="evidence commitment"/></Row>
          <Row label="Anchor comparison">{e.evidenceRoot===g.latestEvidenceRoot?'Matches latest onchain anchor':'Not matched to latest onchain anchor'}</Row>
          <Row label="Receipt count">{e.receiptCount}</Row>
        </Dl>
        <p className="mc-hint">A matching commitment checks integrity against the submitted fingerprint; it proves neither truth nor complete collection. The operator controls both feeds and private storage. Unanchored history can be rewritten by its owner.</p>
        <ul className="mc-list">{e.sources.map(s=><li key={s.id}>{s.id}: {s.status??'unavailable'} / {s.reason}</li>)}</ul>
        <h3 className="mc-sub-h">Public receipt metadata</h3>
        <ul className="mc-list">{snapshot.data?.receipts.map(r=><li key={r.sequence}><span>#{r.sequence} {r.sourceId} / {r.kind}<br/>Received {fmtTime(BigInt(r.receivedAt))}; source {r.sourceTimestamp===null?'none':fmtTime(BigInt(r.sourceTimestamp))}</span><span className="mc-mono">Hash {r.hash}<br/>Previous {r.previousHash}<br/>Payload {r.payloadHash??'none'}</span></li>)}</ul>
        <div className="mc-btn-row"><button className={ghostButton} disabled={cursor===0} onClick={()=>setCursor(Math.max(0,cursor-100))}>Previous receipts</button><button className={ghostButton} disabled={(snapshot.data?.receipts.length??0)<100} onClick={()=>setCursor(snapshot.data?.nextCursor??cursor)}>Next receipts</button></div>
      </>}
      <GuardedAction {...common} title="Request evaluation" role="Enrolled beneficiary" description="Request collection review without choosing a verdict, opening a dispute or moving funds." eligible={()=>g.isMember&&g.outcome===0?{ok:true}:{ok:false,reason:'Only an enrolled beneficiary with an unresolved guarantee can request evaluation.'}} label="Request evaluation only" workingLabel="Requesting..." successText="Evaluation requested. No dispute or funds movement." receiptLabel="Request evaluation" send={write=>write({address:contract,abi:microCoverAbi,functionName:'requestEvaluation',args:[id],chainId:TARGET_CHAIN_ID})}/>
      {isOperator({account,operator})&&<div className="mc-mt-4"><button className={ghostButton} disabled={preparing||g.outcome!==0} onClick={()=>void prepare()}>{preparing?'Preparing...':'Prepare fresh evidence verdict'}</button>{error&&<p className="mc-bad" role="alert">{error}</p>}{report&&<p className="mc-p">Prepared {report.outcome===1?'FAILURE':'SUCCESS review'}; expires {fmtTime(report.validUntil)}. Anchor first, then prepare again for a fresh submission.</p>}</div>}
      <GuardedAction {...common} title="Anchor evidence commitment" role="Demo operator" description="Anchor the verified deadline snapshot root. This records a fingerprint, selects no outcome and does not reset uncertainty." eligible={now=>{const v=allowed(now);return v.ok&&report?.evidenceRoot===g.latestEvidenceRoot?{ok:false,reason:'This root is already anchored. Submit the fresh verdict below.'}:v}} label="Anchor root" workingLabel="Anchoring..." successText="Commitment anchored. Prepare again before submitting." receiptLabel="Anchor evidence" send={write=>{if(report)write({address:contract,abi:microCoverAbi,functionName:'anchorEvidence',args:[id,report.evidenceRoot,g.policyHash,g.cohortId,g.nextAnchorNonce],chainId:TARGET_CHAIN_ID})}}/>
      <GuardedAction {...common} title="Submit evidence verdict" role="Demo operator" description="FAILURE establishes beneficiary compensation without provider cooperation. SUCCESS starts a full review window; it releases no money immediately." warning="This submits the trusted operator's evidence verdict. An established failure cannot be undone." eligible={now=>{if(estimating)return {ok:false,reason:'Simulating the verdict and estimating gas; nothing has been signed.'};const v=allowed(now);return v.ok&&report?.evidenceRoot!==g.latestEvidenceRoot?{ok:false,reason:'Anchor this root first.'}:v}} label="Submit prepared verdict" workingLabel="Submitting..." successText="Evidence verdict recorded onchain." receiptLabel="Submit evidence verdict" send={submit}/>
      {gasNote&&<p className="mc-p" role="status">{gasNote}</p>}
    </>}
    <h3 className="mc-sub-h">Unresolved fallback</h3>
    <Callout tone="warn">If still unresolved at the first uncertainty deadline: full escrow refund, zero compensation. The provider gets the bond only after all refunds. A delivered service may be refunded when evidence is inconclusive. A later dispute reuses the first deadline, even if it is already past. Blocklisted recipients can block a batch.</Callout>
    <GuardedAction {...common} title="Finalize unresolved timeout" role="Anyone" description="Select UNRESOLVED_REFUNDED only while still uncertain and eligible. This step moves no tokens." warning="This irrevocably selects escrow-only refunds with no compensation." eligible={now=>g.status!==STATUS.UNCERTAIN?{ok:false,reason:'Only a still-uncertain guarantee can take this fallback.'}:now<g.uncertainReadyAt?{ok:false,reason:'The frozen uncertainty duration has not elapsed.'}:{ok:true}} label="Finalize unresolved" workingLabel="Finalizing..." successText="Unresolved finalization recorded; escrow refunds can start." receiptLabel="Finalize unresolved" send={write=>write({address:contract,abi:microCoverAbi,functionName:'finalizeUnresolved',args:[id],chainId:TARGET_CHAIN_ID})}/>
    {g.outcome===3&&<Dl><Row label="Unresolved outcome">UNRESOLVED_REFUNDED</Row><Row label="Refund progress">{g.refundedCount}/{g.cohortSize}; {formatUsdc(g.refundedEscrow)} USDC refunded</Row><Row label="Compensation">0 USDC</Row><Row label="Pending escrow refunds">{formatUsdc(g.remainingOwed)} USDC</Row></Dl>}
    <GuardedAction {...common} title="Refund beneficiary escrows" role="Anyone, bounded batches" description={`Refund full escrow only to the next enrolled recipients. At most ${g.maxBatch} per transaction. Failure payout counters are separate.`} eligible={()=>g.status===STATUS.REFUNDING&&refundRemaining>0?{ok:true}:{ok:false,reason:'No unresolved escrow refund is pending.'}} label={`Refund next ${Math.min(g.maxBatch,refundRemaining)} of ${refundRemaining}`} workingLabel="Refunding..." successText="Escrow refunds confirmed onchain." receiptLabel="Refund unresolved escrow" send={write=>write({address:contract,abi:microCoverAbi,functionName:'refundUnresolved',args:[id,Math.min(g.maxBatch,refundRemaining)],chainId:TARGET_CHAIN_ID})}/>
  </Card>
}
