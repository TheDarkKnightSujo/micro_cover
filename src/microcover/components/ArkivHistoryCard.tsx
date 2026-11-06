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
  return <Card title="Public history on Arkiv" aside={<Badge>Rabdi testnet</Badge>}>
    <p className="mc-muted">Public receipts and Arc event references, retrieved from Arkiv through the read-only evidence service. Money and final outcomes remain authoritative on Arc.</p>
    <button className="mc-btn mc-btn-ghost" onClick={()=>void query.refetch()} disabled={query.isFetching}>Refresh Arkiv history</button>
    {query.isPending&&<p role="status">Loading Arkiv history…</p>}
    {query.isError&&<Callout tone="warn">Arkiv history unavailable. Any previously loaded records below may be stale. Arc balances and settlement are unchanged.</Callout>}
    {query.data&&<>
      <p className="mc-muted">Source: live Arkiv RPC · read {new Date(query.data.readAt).toLocaleTimeString()} · {query.data.rows.length} entities.</p>
      {!query.data.rows.length&&<p>No published records for this guarantee from the configured writer. This is not a guarantee verdict.</p>}
      {integrityError&&<Callout tone="danger">{integrityError}</Callout>}
      {integrity&&<Callout tone={integrity.anchored?'ok':'warn'}>{integrity.anchored?'Receipt hash chain recomputed and snapshot matches the current Arc anchor.':'Receipt hash chain recomputed; this snapshot does not match a current Arc anchor.'} Hashes do not prove source truth or complete collection. Both feeds are controlled by us.</Callout>}
      {(integrity?query.data.rows:[]).filter(row=>row.record.recordType!=='EVIDENCE_PAGE').map(row=>{
        const body=JSON.parse(row.record.body) as {event?:string;receiptTimestamp?:number;transactionHash?:string;evaluation?:{outcome:string;reason:string;receiptCount:number}}
        return <div key={row.entityKey} className="mc-callout">
          <strong>{row.record.recordType==='SNAPSHOT'?`Evidence snapshot: ${body.evaluation?.outcome??'unknown'}`:body.event??'Arc event'}</strong>
          {body.evaluation&&<p>{body.evaluation.reason} · {body.evaluation.receiptCount} receipts · same-team sources</p>}
          {body.receiptTimestamp&&<p>{new Date(body.receiptTimestamp*1000).toLocaleString()} · Arc block timestamp</p>}
          <p><a className="mc-link" href={`https://rabdi.explorer.arkiv.network/entity/${row.entityKey}`} target="_blank" rel="noreferrer">View Arkiv entity</a> · expires at Rabdi block {BigInt(row.expiresAt).toString()}</p>
          {body.transactionHash&&/^0x[0-9a-f]{64}$/.test(body.transactionHash)&&<a className="mc-link" href={`https://explorer.testnet.arc.io/tx/${body.transactionHash}`} target="_blank" rel="noreferrer">View Arc transaction reference</a>}
          <details><summary>Receipt ID and integrity details</summary><p className="mc-mono">{row.record.recordId}</p><p className="mc-mono">Payload hash {row.record.bodyHash}</p><p className="mc-mono">Entity {row.entityKey}</p></details>
        </div>
      })}
      <details><summary>Rerunnable Arkiv query</summary><pre style={{whiteSpace:'pre-wrap',overflowWrap:'anywhere'}}>{query.data.query}</pre></details>
    </>}
    <details><summary>Publish queued public history (writer only)</summary>
      <p>Proposed writer: Account 1 ({ARKIV_WRITER}). Retention: {RETENTION_DAYS} days from publication; read-only attributes, permissionless expiry extension. The owner can still delete or transfer entities. Expiry or deletion makes records unavailable.</p>
      <p>{queue.data?.records.length??0} records queued locally. One explicit click publishes at most 20 new entities on Rabdi, using test tGLM for fees. No Arc funds move. Existing records are queried and skipped.</p>
      <button className="mc-btn" disabled={busy||address?.toLowerCase()!==ARKIV_WRITER||!queue.data?.records.length||query.isError||query.isPending} onClick={()=>void publish()}>{busy?'Waiting for wallet / Arkiv confirmation…':'Switch to Rabdi and publish next batch'}</button>
      {message&&<p role="status">{message}</p>}
      {tx&&<a className="mc-link" href={`https://rabdi.explorer.arkiv.network/tx/${tx}`} target="_blank" rel="noreferrer">Inspect saved publication transaction</a>}
      <p className="mc-muted">Return your wallet to Arc Testnet for guarantee actions. This panel never changes the main deployment/version guards.</p>
    </details>
  </Card>
}
