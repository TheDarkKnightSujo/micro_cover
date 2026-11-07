import { useRef, useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { useAccount } from 'wagmi'
import type { Address, EIP1193Provider, Hex } from 'viem'
import type { GuaranteeView } from '../useGuarantee'
import { ARKIV_WRITER, RETENTION_DAYS, type PublicHistoryRecord } from '../arkivRecords'
import { arkivGet, checkHistory, loadArkivHistory, publishHistory } from '../arkivClient'
import { Badge, Callout, Card } from './Card'

export function ArkivHistoryCard({contract,id,g}:{contract:Address;id:bigint;g:GuaranteeView}){
  const {address,connector}=useAccount(),busyRef=useRef(false)
  const [busy,setBusy]=useState(false),[message,setMessage]=useState(''),[tx,setTx]=useState<Hex>()
  const query=useQuery({queryKey:['arkiv-history',contract,id.toString()],queryFn:()=>loadArkivHistory(id.toString()),retry:1,staleTime:30000})
  const queue=useQuery({queryKey:['arkiv-outbox',contract,id.toString()],queryFn:async()=>await arkivGet(id.toString(),'/queue') as {records:PublicHistoryRecord[]},retry:0,staleTime:30000})
  let integrity:ReturnType<typeof checkHistory>|undefined,integrityError=''
  if(query.data?.rows.length){try{integrity=checkHistory(query.data.rows.map(r=>r.record),contract,g)}catch{integrityError='History is incomplete or fails its integrity/domain check. No settlement decision is taken from it.'}}
  const publish=async()=>{
    if(busyRef.current||!connector||!queue.data?.records.length)return
    busyRef.current=true;setBusy(true);setMessage('Review the Rabdi write in MetaMask. This publishes public data only.')
    try{
      checkHistory(queue.data.records,contract,g)
      const provider=await connector.getProvider() as EIP1193Provider
      const result=await publishHistory(provider,id.toString(),queue.data.records,setTx)
      setMessage(result?`${result.written} records written; ${result.remaining} remain. Existing record IDs are skipped on retry.`:'Publisher is busy.')
      await query.refetch()
    }catch(error){setMessage(error instanceof Error?error.message:'Arkiv write was not confirmed.')}
    finally{busyRef.current=false;setBusy(false)}
  }
  const labels: Record<string, [string, string]> = {
    GuaranteeCreated: ['Guarantee created', 'The provider funded the compensation bond.'],
    EvidencePolicyBound: ['Protection rules fixed', 'The evidence rules and customer group were locked in before purchase.'],
    CohortJoined: ['Customer joined', 'A customer enrolled and paid into escrow.'],
    EvidenceAnchored: ['Evidence recorded', 'A fingerprint of the collected evidence was recorded on Arc.'],
    EvidenceSuccessReported: ['Evidence indicated success', 'The demo operator submitted a success result. This did not release money immediately.'],
    SuccessProposed: ['Success review started', 'Customers had a review period before success could be finalized.'],
    SuccessFinalized: ['Success confirmed', 'The review period ended and success became final.'],
    SuccessEscrowReleased: ['Customer payment released', 'The escrow payment was sent to the provider.'],
    RemainingBondWithdrawn: ['Provider bond returned', 'The remaining compensation bond was returned to the provider.'],
    GuaranteeClosed: ['Guarantee completed', 'All obligations for this guarantee were settled.'],
    FailureAdmitted: ['Provider reported failure', 'Refunds and compensation became available for settlement.'],
    EvidenceFailureReported: ['Failure established from evidence', 'The operator submitted failure independently of provider admission.'],
    BeneficiaryPaid: ['Customer paid', 'A refund and the agreed compensation were sent to an enrolled customer.'],
    UnresolvedFinalized: ['Refund-only outcome confirmed', 'The uncertainty timeout ended with no established outcome. No compensation is paid.'],
    UnresolvedRefunded: ['Customer payment refunded', 'The full escrow payment was returned without extra compensation.'],
  }
  const timeline = (integrity ? query.data?.rows ?? [] : []).filter(row => row.record.recordType !== 'EVIDENCE_PAGE').map(row => ({row, body: JSON.parse(row.record.body) as {event?:string;receiptTimestamp?:number;transactionHash?:string;evaluation?:{outcome:string;reason:string;receiptCount:number}}})).sort((a,b) => (a.body.receiptTimestamp ?? 0) - (b.body.receiptTimestamp ?? 0))
  return <Card title="What happened" aside={<Badge>Receipts on Arkiv</Badge>}>
    <p className="mc-muted">A receipt is a record of an action, not a new charge. This timeline shows published activity for this guarantee. Payments and final outcomes are controlled by the contract on Arc.</p>
    <button className="mc-btn mc-btn-ghost" onClick={()=>void query.refetch()} disabled={query.isFetching}>Refresh activity</button>
    {query.isPending&&<p role="status">Loading Arkiv history…</p>}
    {query.isError&&<Callout tone="warn">Arkiv history unavailable. Any previously loaded records below may be stale. Arc balances and settlement are unchanged.</Callout>}
    {query.data&&<>
      <p className="mc-muted">Source: live Arkiv RPC · read {new Date(query.data.readAt).toLocaleTimeString()} · {query.data.rows.length} entities.</p>
      {!query.data.rows.length&&<p>No activity has been published for this guarantee yet. This does not change its payment status.</p>}
      {integrityError&&<Callout tone="danger">{integrityError}</Callout>}
      {integrity&&<Callout tone={integrity.anchored?'ok':'warn'}>{integrity.anchored?'Receipt hash chain recomputed and snapshot matches the current Arc anchor.':'Receipt hash chain recomputed; this snapshot does not match a current Arc anchor.'} Hashes do not prove source truth or complete collection. Both feeds are controlled by us.</Callout>}
      <ol className="mc-timeline">{timeline.map(({row,body}) => {
        const copy = body.event ? labels[body.event] : undefined
        return <li key={row.entityKey}>
          <span className="mc-timeline-dot"/>
          <strong>{row.record.recordType === 'SNAPSHOT' ? 'Evidence summary saved' : copy?.[0] ?? 'Blockchain activity recorded'}</strong>
          <p>{row.record.recordType === 'SNAPSHOT' ? `Collected evidence indicated ${body.evaluation?.outcome?.toLowerCase() ?? 'an unknown outcome'}. Both demo feeds are controlled by our team.` : copy?.[1] ?? 'A contract event was recorded. Open its receipt for the exact technical details.'}</p>
          {body.receiptTimestamp && <time>{new Date(body.receiptTimestamp*1000).toLocaleString()}</time>}
          <details className="mc-receipt-details"><summary>View receipt & blockchain proof</summary>
            <p>Published event: {body.event ?? body.evaluation?.reason ?? row.record.recordType}</p>
            {body.transactionHash && /^0x[0-9a-f]{64}$/.test(body.transactionHash) && <p><a className="mc-link" href={`https://explorer.testnet.arc.io/tx/${body.transactionHash}`} target="_blank" rel="noreferrer">View transaction on Arc</a></p>}
            <p><a className="mc-link" href={`https://rabdi.explorer.arkiv.network/entity/${row.entityKey}`} target="_blank" rel="noreferrer">View stored receipt on Arkiv</a></p>
            <p className="mc-hint">Storage expires at Rabdi block {BigInt(row.expiresAt).toString()}. The receipt owner can delete or transfer it.</p>
            <p className="mc-mono">Receipt: {row.record.recordId}</p><p className="mc-mono">Payload fingerprint: {row.record.bodyHash}</p>
          </details>
        </li>
      })}</ol>
      <details><summary>Rerunnable Arkiv query</summary><pre style={{whiteSpace:'pre-wrap',overflowWrap:'anywhere'}}>{query.data.query}</pre></details>
    </>}
    {address?.toLowerCase() === ARKIV_WRITER && <details className="mc-disclosure mc-mt-4"><summary>Demo publisher tools</summary>
      <p>Proposed writer: Account 1 ({ARKIV_WRITER}). Retention: {RETENTION_DAYS} days from publication; read-only attributes, permissionless expiry extension. The owner can still delete or transfer entities. Expiry or deletion makes records unavailable.</p>
      <p>{queue.data?.records.length??0} records queued locally. One explicit click publishes at most 20 new entities on Rabdi, using test tGLM for fees. No Arc funds move. Existing records are queried and skipped.</p>
      <button className="mc-btn" disabled={busy||address?.toLowerCase()!==ARKIV_WRITER||!queue.data?.records.length||query.isError||query.isPending} onClick={()=>void publish()}>{busy?'Waiting for wallet / Arkiv confirmation…':'Switch to Rabdi and publish next batch'}</button>
      {message&&<p role="status">{message}</p>}
      {tx&&<a className="mc-link" href={`https://rabdi.explorer.arkiv.network/tx/${tx}`} target="_blank" rel="noreferrer">Inspect saved publication transaction</a>}
      <p className="mc-muted">Return your wallet to Arc Testnet for guarantee actions. This panel never changes the main deployment/version guards.</p>
    </details>}
  </Card>
}
