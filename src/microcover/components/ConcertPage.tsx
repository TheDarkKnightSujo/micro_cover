import { useEffect, useState } from 'react'
import { useAccount } from 'wagmi'
import { useQuery } from '@tanstack/react-query'
import { ConnectKitButton } from 'connectkit'
import { ArrowRight, Ticket, ShieldCheck, CalendarDays } from 'lucide-react'
import { formatUsdc } from '@/onchain-money'
import { MICROCOVER_ADDRESS } from '../contract'
import { useCapability } from '../useCapability'
import { useChainTime, useFreshChainTime } from '../useChainTime'
import { useGuarantee } from '../useGuarantee'
import { ReceiptLogProvider } from '../receipts'
import { evidenceBase, evidenceGet } from '../evidenceClient'
import { bookingStatus, matchesPresentation, presentationCommitment, roleStorageKey, validatePresentation, type PresentationRecord } from '../presentation'
import { PRESET_CONDITION_TEXT } from '../terms'
import { Card, Callout, Dl, Row, Badge } from './Card'
import { CreateCard } from './CreateCard'
import { EnrollSection } from './EnrollSection'
import { TermsCard } from './TermsCard'
import { DeploymentCard } from './DeploymentCard'
import { ArkivHistoryCard } from './ArkivHistoryCard'
import { ActionsCard } from './ActionsCard'
import type { Address } from 'viem'
import type { Capability } from '../useCapability'
import type { ChainTime } from '../useChainTime'

type Role='organiser'|'customer'
const isRole=(v:unknown):v is Role=>v==='organiser'||v==='customer'
function eventId(){const id=new URLSearchParams(window.location.search).get('concert');return id && /^[1-9]\d{0,17}$/.test(id)?id:undefined}
function link(id:string){return `${window.location.origin}${window.location.pathname}?concert=${id}#concert`}
async function getRecord(id:string){
  const value=await evidenceGet(`presentations/${id}`) as PresentationRecord
  if(value.guaranteeId!==id)throw Error('Wrong event')
  return {...value,presentation:validatePresentation(value.presentation)}
}
function Policy(){return <Callout tone="warn"><strong>Synthetic concert demonstration.</strong> Protection is included. The two team-controlled feeds must explicitly agree on fulfilled or cancelled status at the scheduled cutoff. This does not measure real concert delays; there is no delay threshold. A trusted operator submits the result, and settlement requires transactions. It is not independent verification or a live CRE deployment.<details><summary>Exact protected condition & money rules</summary><p>{PRESET_CONDITION_TEXT}</p><p>Failure: full ticket refund plus fixed compensation. Reviewed success: ticket payment goes to the organiser, no compensation. Unresolved: full ticket refund only after the separate, non-resetting 120-second uncertainty deadline. The organiser’s backing funds return only after refunds. Success has its own 120-second review. Missing evidence alone never opens an onchain dispute.</p><p>The name and venue are presentation context. The scheduled time is the onchain outcome cutoff, not a measured start-time promise.</p></details></Callout>}

function Event({id,contract,cap,chain}: {id:string;contract:Address;cap:Extract<Capability,{state:'ready'}>;chain:ChainTime}){
  const {address:account,chainId}=useAccount()
  const metadata=useQuery({queryKey:['concert',contract,id],queryFn:()=>getRecord(id),retry:1})
  const read=useGuarantee(contract,BigInt(id),account)
  const freshNow=useFreshChainTime()
  const g=read.state==='ready' && read.data?.forId===BigInt(id) && read.data.forAccount===account ? read.data : undefined
  const p=metadata.data?.presentation
  const verified=g && p && p.consumer===contract.toLowerCase() && matchesPresentation(p,g)
  const [copied,setCopied]=useState(false)
  if(metadata.isPending || read.state==='loading')return <Card title="Opening your concert"><p>Checking the shared event details against Arc Testnet...</p></Card>
  if(!verified)return <Card title="Concert details unavailable"><Callout>The shared details could not be verified against this ticket protection. No purchase is enabled. This may be a generic previous test run or a service outage; it does not establish a concert outcome.</Callout><button className="mc-btn mc-btn-ghost" onClick={()=>{void metadata.refetch();read.refetch()}}>Retry event check</button><a className="mc-text-link" href={`?guarantee=${id}#guarantee`}>Open generic guarantee details</a></Card>
  const provider=account?.toLowerCase()===g.provider.toLowerCase()
  const received=bookingStatus(g,account)
  return <>
    <Card title={p.name} aside={<Badge>{g.status===2?'Completed':g.outcome===3?'Unresolved — refunds':g.outcome===1?'Failure confirmed':g.outcome===2?'Success confirmed':g.status===5?'Under review':'Ticket protection active'}</Badge>}>
      <p className="mc-concert-location"><CalendarDays size={20}/>{p.venue} · {new Date(Number(p.scheduledAt)*1000).toLocaleString()}</p>
      <div className="mc-money-grid"><div><Ticket size={24}/><span>Ticket, protection included</span><strong>{formatUsdc(g.escrowAmount)} <small>test USDC</small></strong></div><div><ShieldCheck size={24}/><span>Potential failure payment to a ticket holder</span><strong>{formatUsdc(g.escrowAmount+g.compensation)} <small>USDC</small></strong><span>{formatUsdc(g.escrowAmount)} refund + {formatUsdc(g.compensation)} compensation. Not a payment received.</span></div><div><span>Tickets booked</span><strong>{g.cohortSize} / {g.maxCohort}</strong><span>{g.joinable?`${g.openSlots} available`:'Sales closed'}</span></div></div>
      <Policy/>
      <Dl><Row label="Ticket sales & evidence cutoff">{new Date(Number(g.settlementTime)*1000).toLocaleString()}</Row><Row label="Success review">120 seconds after a success proposal</Row><Row label="Final review deadline">{g.uncertaintyStarted ? new Date(Number(g.uncertainReadyAt)*1000).toLocaleString() : 'Not started — 120 seconds from first onchain uncertainty'}</Row></Dl>
      <button className="mc-btn mc-btn-ghost" onClick={()=>void navigator.clipboard.writeText(link(id)).then(()=>setCopied(true)).catch(()=>setCopied(false))}>{copied?'Customer link copied':'Copy customer event link'}</button><p className="mc-hint mc-break">{link(id)}</p>
    </Card>
    <Card title={provider?'Your organiser dashboard':'Your ticket'}>
      {provider?<><p>You are this concert’s onchain organiser. {g.cohortSize} tickets sold; {g.openSlots} remaining places. You cannot buy your own ticket protection. Use another account to test the customer journey.</p><Dl><Row label="Money backing your promise">{formatUsdc(g.bondHeld)} USDC still held</Row><Row label="Ticket payments held until outcome">{formatUsdc(g.escrowHeld)} USDC</Row><Row label="Backing funds returned">{formatUsdc(g.withdrawnBond)} USDC</Row></Dl><ActionsCard contract={contract} id={BigInt(id)} read={read} account={account} operator={cap.operator} chain={chain} freshNow={freshNow} audience="provider"/></>:<>
        <p className="mc-h3" role="status">{received}</p>
        {g.isMember?<><p>One protected ticket for this account. Original ticket payment: {formatUsdc(g.escrowAmount)} USDC. Duplicate purchases are disabled.</p><p>{g.outcome===3?'Your unresolved refund is escrow only; compensation is zero.':g.outcome===1?'The payment status above comes from your onchain settlement flag.':g.outcome===2?'Your ticket payment is owed to the organiser after success; no customer compensation is due.':'Your payment stays locked while the outcome is unresolved. A presenter must submit evidence and trigger settlement.'}</p></>:<><p>Order summary: 1 ticket · {formatUsdc(g.escrowAmount)} test USDC total · protection included, no extra premium. First approve this exact amount; the separate purchase transaction then locks it in the contract.</p>{!account&&<ConnectKitButton label="Connect to buy a protected ticket"/>}<EnrollSection key={`${contract}:${id}:${account}:${chainId}`} contract={contract} id={BigInt(id)} g={g} read={read} account={account} operator={cap.operator} chain={chain} freshNow={freshNow} concert/></>}
      </>}
    </Card>
    <details className="mc-disclosure"><summary>How this was verified — full terms, receipts & history</summary><p>Event details match the cohort commitment in the organiser’s creation transaction. This proves integrity, not that a concert exists or that observations are true.</p><TermsCard g={g}/><ArkivHistoryCard contract={contract} id={BigInt(id)} g={g}/></details>
    <a className="mc-text-link" href={`?guarantee=${id}#controls`}>Presenter / settlement workspace <ArrowRight size={16}/></a>
  </>
}
function Organiser({contract,cap,chain,onOpen}:{contract:Address;cap:Extract<Capability,{state:'ready'}>;chain:ChainTime;onOpen:(id:string)=>void}){
  const {address:account}=useAccount()
  const [name,setName]=useState(''),[venue,setVenue]=useState(''),[schedule,setSchedule]=useState('')
  const [recoveryId,setRecoveryId]=useState('')
  const [recoverDraft,setRecoverDraft]=useState(()=>{try{const raw=localStorage.getItem(`microcover:concert-draft:${contract.toLowerCase()}:${account?.toLowerCase()}`);return raw?validatePresentation(JSON.parse(raw)):undefined}catch{return undefined}})
  const [review,setReview]=useState(false),[error,setError]=useState(''),[busy,setBusy]=useState(false)
  const storage=`microcover:concert-publication:${contract.toLowerCase()}:${account?.toLowerCase()}`
  const [pending,setPending]=useState<PresentationRecord|undefined>(()=>{try{return JSON.parse(localStorage.getItem(storage)??'null') as PresentationRecord | undefined}catch{return undefined}})
  const list=useQuery({queryKey:['organiser-concerts',contract,account],enabled:!!account,queryFn:async()=>{const data=await evidenceGet(`presentations?provider=${account!.toLowerCase()}`) as {records:PresentationRecord[]};if(!Array.isArray(data.records))throw Error('Invalid events');return data.records.map(r=>{const p=validatePresentation(r.presentation);if(!/^[1-9]\d{0,17}$/.test(r.guaranteeId)||p.consumer!==contract.toLowerCase()||p.provider!==account!.toLowerCase())throw Error('Event listing mismatch');return {guaranteeId:r.guaranteeId,presentation:p}})},retry:1})
  const publish=async(record:PresentationRecord)=>{
    setBusy(true);setError('')
    try{
      const res=await fetch(evidenceBase+'/api/evidence/v1/presentations',{method:'POST',headers:{'content-type':'application/json'},credentials:'omit',body:JSON.stringify(record)})
      if(!res.ok)throw Error('Not stored')
      const saved=await getRecord(record.guaranteeId)
      if(presentationCommitment(saved.presentation)!==presentationCommitment(record.presentation))throw Error('Different details')
      localStorage.removeItem(storage);localStorage.removeItem(`microcover:concert-draft:${contract.toLowerCase()}:${account?.toLowerCase()}`);setPending(undefined);void list.refetch();onOpen(record.guaranteeId)
    }catch{setError('The funding transaction is confirmed, but shared event details are not published yet. Do not fund again. Retry saving these details when the service is available.')}finally{setBusy(false)}
  }
  if(pending)return <Card title="Funding confirmed — finish sharing"><p>Your funds were already locked. Saving the public event details is a separate service step and needs no wallet transaction.</p><button className="mc-btn mc-btn-primary" disabled={busy} onClick={()=>void publish(pending)}>{busy?'Verifying & saving...':'Retry publishing event details'}</button>{error&&<p role="alert">{error}</p>}</Card>
  return <>
    <Card title="Your concerts">
      {list.isPending?<p>Loading events published by this account...</p>:list.isError?<p>Event listing is unavailable. This does not mean you have no events. Retry before funding another event.</p>:list.data?.length?list.data.map(r=><button key={r.guaranteeId} className="mc-recent" onClick={()=>onOpen(r.guaranteeId)}><strong>{r.presentation.name}</strong><span>Open organiser dashboard and check live ticket sales</span></button>):<p>No concert records published by this account in this demo store. You can create one below. This does not scan every generic guarantee you may own.</p>}
      {list.isError&&<button className="mc-btn mc-btn-ghost" onClick={()=>void list.refetch()}>Retry listing</button>}
    </Card>
    {recoverDraft?<Card title="Check your previous funding attempt before creating another concert"><p>A draft from this wallet is saved on this device. It is not proof that a transaction was sent or confirmed. Check MetaMask activity first. If funding succeeded, recover its shared details below; this never sends another transaction.</p><label>Confirmed guarantee number from your creation receipt<input className="mc-input" inputMode="numeric" value={recoveryId} onChange={e=>setRecoveryId(e.target.value)}/></label><button className="mc-btn mc-btn-primary" disabled={busy||!/^[1-9]\d{0,17}$/.test(recoveryId)} onClick={()=>void publish({guaranteeId:recoveryId,presentation:recoverDraft})}>Verify & recover shared event details</button><button className="mc-btn mc-btn-ghost" onClick={()=>{if(window.confirm('Only discard after checking that funding was cancelled or never broadcast. A confirmed event must be recovered instead.')){localStorage.removeItem(`microcover:concert-draft:${contract.toLowerCase()}:${account?.toLowerCase()}`);setRecoverDraft(undefined)}}}>I checked wallet activity: no funding was sent</button>{error&&<p role="alert">{error}</p>}</Card>:<>
    <Card title="1. Tell customers about your concert">
      <p>Use public, synthetic event details only. MicroCover backs a specific promise; this demo does not sell real insurance.</p>
      <fieldset disabled={review} className="mc-concert-form"><label>Concert name<input className="mc-input" maxLength={120} value={name} onChange={e=>setName(e.target.value)}/></label><label>Venue<input className="mc-input" maxLength={120} value={venue} onChange={e=>setVenue(e.target.value)}/></label><label>Scheduled time / synthetic outcome cutoff (your local time)<input className="mc-input" type="datetime-local" value={schedule} onChange={e=>setSchedule(e.target.value)}/></label></fieldset>
      <Policy/>
      {!review && <button className="mc-btn mc-btn-primary" disabled={name.trim().length<2||venue.trim().length<2||!Number.isFinite(Date.parse(schedule))} onClick={()=>setReview(true)}>Continue to price & backing funds <ArrowRight size={16}/></button>}
      {review&&<p className="mc-hint">Details are frozen for this funding flow. Start a new concert after completion to use different details.</p>}
    </Card>
    {review&&<CreateCard cap={cap} chain={chain} concert={{name:name.trim(),venue:venue.trim(),scheduledAt:String(Math.floor(Date.parse(schedule)/1000))}} onCreated={(id,p)=>{if(!p){setError('Creation confirmed but metadata recovery is required. Do not repeat funding.');return}const record={guaranteeId:id.toString(),presentation:p};localStorage.setItem(storage,JSON.stringify(record));setPending(record);void publish(record)}}/>}
    {error&&<Callout>{error}</Callout>}</>}
  </>
}
function ConcertSession({cap,chain,contract}:{cap:Capability;chain:ChainTime;contract:Address|undefined}){
  const {address,chainId}=useAccount()
  const [id,setId]=useState(eventId)
  useEffect(()=>{const sync=()=>setId(eventId());window.addEventListener('popstate',sync);return()=>window.removeEventListener('popstate',sync)},[])
  const [role,setRole]=useState<Role|undefined>(()=>{try {const value=address?localStorage.getItem(roleStorageKey(chainId,address)):null;return isRole(value)?value:undefined}catch{return undefined}})
  const choose=(value:Role)=>{setRole(value);if(address)try{localStorage.setItem(roleStorageKey(chainId,address),value)}catch{/* Preference is optional, never authority. */}}
  const open=(value:string)=>{window.history.pushState(null,'',link(value));setId(value);window.scrollTo(0,0)}
  return <>
    <nav className="mc-nav" aria-label="Concert navigation"><a className="mc-text-link" href="#home">MicroCover platform</a><strong>Concert demo</strong>{role&&<button onClick={()=>setRole(undefined)}>Switch role</button>}<a className="mc-text-link" href="#concert" onClick={e=>{e.preventDefault();setId(undefined);window.history.replaceState(null,'',window.location.pathname+'#concert')}}>Concert home</a></nav>
    <section className="mc-concert-hero"><span className="mc-eyebrow"><Ticket size={18}/> One promise. A protected ticket.</span><h1>A great night.<br/><em>A backed promise.</em></h1><p>MicroCover helps organisations back promises with locked funds. Explore one example: concert ticket payments held until the outcome is confirmed.</p><p className="mc-hint">Synthetic concert demo · Arc Testnet · Test USDC · Protection included</p></section>
    {!address&&!id&&<Card title="Explore the concert demo"><p>Got an organiser’s event link? Open it to see that exact concert, its ticket price and protection. Connect a test wallet to buy a ticket. Organisers can connect to create a fresh event.</p><ConnectKitButton label="Connect test wallet"/><div className="mc-btn-row"><button className="mc-btn mc-btn-primary" onClick={()=>choose('customer')}>I’m a customer</button><button className="mc-btn mc-btn-ghost" onClick={()=>choose('organiser')}>I’m an organiser</button></div></Card>}
    {address&&!role&&<Card title="How are you using MicroCover?"><p>Choose your view for this wallet and network. Your role is still checked onchain.</p><div className="mc-btn-row"><button className="mc-btn mc-btn-primary" onClick={()=>choose('customer')}>I’m a customer</button><button className="mc-btn mc-btn-ghost" onClick={()=>choose('organiser')}>I’m an organiser</button></div></Card>}
    {cap.state!=='ready'||!contract?<DeploymentCard cap={cap}/>:<>
      {id?<Event key={`${contract}:${id}:${address}:${chainId}:${role}`} id={id} contract={contract} cap={cap} chain={chain}/>:role==='organiser'&&address?<Organiser key={`${contract}:${address}:${chainId}:${role}`} contract={contract} cap={cap} chain={chain} onOpen={open}/>:<Card title="Your next concert starts with an event link"><p>There is no concert selected. Ask the organiser for their customer link. We never pick an old guarantee or the latest event for you.</p><p>Illustrative ticket: 2 test USDC, including protection. On verified synthetic failure: 2 USDC refund + 5 USDC compensation. Your actual order will show its own price.</p><Policy/></Card>}
    </>}
  </>
}
export function ConcertPage(){const {address,chainId}=useAccount();const cap=useCapability();const chain=useChainTime();return <ReceiptLogProvider><ConcertSession key={`${address??'disconnected'}:${chainId??'none'}`} cap={cap} chain={chain} contract={MICROCOVER_ADDRESS}/></ReceiptLogProvider>}
