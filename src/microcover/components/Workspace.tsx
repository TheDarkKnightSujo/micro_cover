import { useEffect, useState } from 'react'
import { ArrowRight, ShieldCheck, Ticket, Users, Wallet, Clock3, CheckCircle2 } from 'lucide-react'
import { formatUsdc } from '@/onchain-money'
import { OUTCOME, STATUS } from '../contract'
import { nextStep } from '../lifecycle'
import { Badge, Card, Callout } from './Card'
import type { Address } from 'viem'
import { useAccount, useReadContract } from 'wagmi'
import { MICROCOVER_ADDRESS, TARGET_CHAIN_ID, microCoverAbi } from '../contract'
import { ReceiptLogProvider } from '../receipts'
import { type Capability, useCapability } from '../useCapability'
import { type ChainTime, useChainTime, useFreshChainTime } from '../useChainTime'
import { useGuarantee } from '../useGuarantee'
import { ActionsCard } from './ActionsCard'
import { CreateCard } from './CreateCard'
import { DeploymentCard } from './DeploymentCard'
import { HistoryCard } from './HistoryCard'
import { LookupCard } from './LookupCard'
import { NetworkCard } from './NetworkCard'
import { TermsCard } from './TermsCard'
import { EvidenceCard } from './EvidenceCard'
import { ArkivHistoryCard } from './ArkivHistoryCard'

function parseId(input: string): bigint | undefined {
  if (!/^\d{1,18}$/.test(input)) return undefined
  const id = BigInt(input)
  return id > 0n ? id : undefined
}

/** `?guarantee=<id>` makes a guarantee's public detail linkable from a fresh browser. */
function initialSelection(): string {
  const value = new URLSearchParams(window.location.search).get('guarantee') ?? ''
  return parseId(value) !== undefined ? value : ''
}

function writeSelection(value: string) {
  const url = parseId(value) !== undefined ? `?guarantee=${value}${window.location.hash}` : `${window.location.pathname}${window.location.hash}`
  window.history.replaceState(null, '', url)
}

type Screen = 'home' | 'create' | 'guarantee' | 'activity' | 'controls'
const screens: Screen[] = ['home', 'create', 'guarantee', 'activity', 'controls']
function currentScreen(): Screen {
  const hash = window.location.hash.slice(1) as Screen
  return screens.includes(hash) ? hash : initialSelection() ? 'guarantee' : 'home'
}

interface ReadyProps {
  contract: Address
  cap: Extract<Capability, { state: 'ready' }>
  chain: ChainTime
}

function ReadyWorkspace({ contract, cap, chain }: ReadyProps) {
  const { address: account } = useAccount()
  const [screen, setScreen] = useState<Screen>(currentScreen)
  const navigate = (target: Screen) => {
    window.history.pushState(null, '', `${window.location.pathname}${window.location.search}#${target}`)
    setScreen(target)
    window.scrollTo({ top: 0, behavior: 'instant' })
  }
  useEffect(() => {
    const sync = () => setScreen(currentScreen())
    window.addEventListener('popstate', sync)
    window.addEventListener('hashchange', sync)
    return () => { window.removeEventListener('popstate', sync); window.removeEventListener('hashchange', sync) }
  }, [])
  const freshNow = useFreshChainTime()
  const [idInput, setIdInput] = useState(initialSelection)
  const id = parseId(idInput)

  const select = (value: string) => {
    setIdInput(value)
    writeSelection(value)
  }

  const next = useReadContract({
    address: contract,
    abi: microCoverAbi,
    functionName: 'nextGuaranteeId',
    chainId: TARGET_CHAIN_ID,
    query: { refetchInterval: 8_000 },
  })
  const latestId = next.data === undefined ? undefined : next.data - 1n
  const read = useGuarantee(contract, id, account)
  const g = read.state === 'ready' && read.data && read.data.forId === id && read.data.forAccount === account ? read.data : undefined

  const provider = g && account?.toLowerCase() === g.provider.toLowerCase()
  const recent = latestId && latestId > 0n ? Array.from({length: Number(latestId < 3n ? latestId : 3n)}, (_, i) => latestId - BigInt(i)) : []
  const openGuarantee = (value: string) => { select(value); navigate('guarantee') }
  const lookup = <LookupCard compact idInput={idInput} onIdChange={select} latestId={latestId} read={read} account={account} operator={cap.operator} chain={chain} />
  const common = {contract, id, read, account, operator: cap.operator, chain, freshNow}

  return <>
    <nav className="mc-nav" aria-label="Main navigation">
      {([['home','Overview'],['create','For organisers'],['guarantee','My protection'],['activity','Activity']] as const).map(([key,label]) => <button key={key} type="button" aria-current={screen === key ? 'page' : undefined} onClick={() => navigate(key)}>{label}</button>)}
    </nav>

    {screen === 'home' && <>
      <section className="mc-hero">
        <div><span className="mc-eyebrow"><ShieldCheck size={16}/> A promise with money behind it</span>
          <h1>Book with confidence.<br/><em>Deliver with trust.</em></h1>
          <p>Providers put up a bond. Customers pay into secure escrow. If the promise fails, the guarantee pays a refund plus the agreed compensation.</p>
          <div className="mc-hero-actions"><button className="mc-btn mc-btn-primary" onClick={() => navigate('create')}>Create a guarantee <ArrowRight size={18}/></button><button className="mc-btn mc-btn-ghost" onClick={() => navigate('guarantee')}>I have a guarantee link</button></div>
          <p className="mc-hint">Arc Testnet · Test USDC only · No real-world insurance policy</p>
        </div>
        <div className="mc-example-ticket"><span className="mc-eyebrow"><Ticket size={18}/> Concert ticket example</span><h2>Your payment.<br/>A backed promise.</h2><div className="mc-price">2 <span>USDC / customer</span></div><hr/><p>If failure is established</p><strong className="mc-example-return">7 USDC returned</strong><p>2 USDC refund + 5 USDC compensation</p><span className="mc-ticket-note">Illustration only. Review each guarantee’s actual terms.</span></div>
      </section>
      <section className="mc-step-grid" aria-label="How MicroCover works">
        {[['01', 'Provider backs the promise', 'The provider funds a compensation bond before customers join.', Wallet], ['02', 'Customer joins securely', 'Review the terms and pay into escrow. The provider cannot take it while the guarantee is open.', Users], ['03', 'Outcome decides the payment', 'Failure pays a refund plus compensation. Reviewed success pays the provider. Unresolved cases refund escrow only.', ShieldCheck]].map(([n,title,body,Icon]) => { const Symbol = Icon as typeof Wallet; return <article className="mc-step" key={String(n)}><span className="mc-step-number">{String(n)}</span><Symbol size={24}/><h3>{String(title)}</h3><p>{String(body)}</p></article> })}
      </section>
      <details className="mc-disclosure"><summary>Previous test runs — generic guarantees, not concerts</summary>
      <div className="mc-recent-grid">{recent.map(value => <button className="mc-recent" key={value.toString()} onClick={() => openGuarantee(value.toString())}><ShieldCheck size={24}/><strong>Guarantee #{value.toString()}</strong><span>View live terms, outcome and payment progress</span><ArrowRight size={20}/></button>)}</div></details>
      <Callout>Demo evidence comes from two feeds controlled by our team. A trusted demo operator submits the outcome. This is not an independent oracle or a deployed CRE network.</Callout>
    </>}

    <div hidden={screen !== 'create'} className="mc-screen-stack">
      <div className="mc-page-intro"><span className="mc-eyebrow">For organisers & service providers</span><h1>Back your next promise.</h1><p>Set the customer payment and compensation, fund your bond, then share the guarantee link. The contract keeps both sides’ funds separate until an outcome is resolved.</p></div>
      <div className="mc-flow-strip"><span><b>1</b> Set terms</span><span><b>2</b> Approve & fund</span><span><b>3</b> Share your link</span></div>
      <CreateCard key={`${contract}:${account ?? 'none'}`} cap={cap} chain={chain} onCreated={created => {select(created.toString()); void next.refetch(); navigate('guarantee')}}/>
    </div>

    {(screen === 'guarantee' || screen === 'activity' || screen === 'controls') && <>
      <div className="mc-page-intro"><span className="mc-eyebrow">{screen === 'activity' ? 'A clear record of what happened' : screen === 'controls' ? 'Testnet operator workspace' : 'Your guarantee'}</span><h1>{screen === 'activity' ? 'Activity & receipts' : screen === 'controls' ? 'Demo controls' : 'Know what happens to your money.'}</h1><p>{screen === 'activity' ? 'Activity records are receipts: they explain changes and link to the blockchain. They are not extra payments.' : screen === 'controls' ? 'Evidence submission and permissionless settlement tools. Each action still requires the appropriate wallet and contract checks.' : 'Open the guarantee number shared by your provider. Review the price, protection and status before joining.'}</p></div>
      {lookup}
      {g && <>
        <Card title={`Guarantee #${id?.toString()}`} aside={<Badge tone={g.outcome === OUTCOME.FAILURE ? 'danger' : g.status === STATUS.CLOSED ? 'neutral' : 'ok'}>{g.status === STATUS.CLOSED ? 'Completed' : g.outcome === OUTCOME.FAILURE ? 'Refund & compensation' : g.status === STATUS.UNCERTAIN ? 'Under review' : g.status === STATUS.SUCCESS_PENDING ? 'Success under review' : g.outcome === OUTCOME.SUCCESS ? 'Success confirmed' : 'In progress'}</Badge>}>
          <div className="mc-money-grid"><div><Ticket size={20}/><span>Customer payment</span><strong>{formatUsdc(g.escrowAmount)} <small>USDC</small></strong><span>Held in escrow until resolution</span></div><div><ShieldCheck size={20}/><span>If failure is established</span><strong>{formatUsdc(g.escrowAmount + g.compensation)} <small>USDC</small></strong><span>Refund + {formatUsdc(g.compensation)} USDC compensation</span></div><div><Users size={20}/><span>Customers joined</span><strong>{g.cohortSize} <small>/ {g.maxCohort}</small></strong><span>{g.joinable ? `${g.openSlots} places available` : 'Joining closed'}</span></div></div>
          <p className="mc-role-summary">{!account ? 'Connect a wallet to join or see your role.' : provider ? 'You are the provider for this guarantee.' : g.isMember ? 'You have joined this guarantee. Your payment status is shown below.' : 'You have not joined this guarantee.'}</p>
          {chain.now !== undefined && <Callout><strong>Next step:</strong> {nextStep(g, {now: chain.now, account, operator: cap.operator})}</Callout>}
          <div className="mc-outcomes"><p><CheckCircle2 size={16}/><span><strong>Delivered:</strong> after a successful review, your payment goes to the provider. No compensation is paid.</span></p><p><ShieldCheck size={16}/><span><strong>Failed:</strong> your payment is refunded, plus the agreed compensation from the provider’s bond.</span></p><p><Clock3 size={16}/><span><strong>Unresolved:</strong> after the fixed uncertainty timeout, your full payment is refundable with no extra compensation.</span></p></div>
          <div className="mc-btn-row mc-mt-4"><button className="mc-btn mc-btn-ghost" onClick={() => navigate('guarantee')}>Protection & actions</button><button className="mc-btn mc-btn-ghost" onClick={() => navigate('activity')}>View activity</button></div>
        </Card>
        {screen === 'guarantee' && <>
          <details className="mc-disclosure"><summary>Full terms, timing & evidence policy — review before joining</summary><TermsCard g={g}/></details>
          <ActionsCard {...common} audience={provider ? 'provider' : 'customer'}/>
          <button className="mc-text-link" onClick={() => navigate('controls')}>Demo operator & settlement tools <ArrowRight size={16}/></button>
        </>}
        {screen === 'activity' && id !== undefined && <><ArkivHistoryCard key={`${contract}:${id}`} contract={contract} id={id} g={g}/><details className="mc-disclosure"><summary>Blockchain lifecycle & transactions from this tab</summary><HistoryCard id={id} g={g} chain={chain}/></details></>}
        {screen === 'controls' && <>
          {id !== undefined && <EvidenceCard key={`${contract}:${id}:${account??'none'}`} contract={contract} id={id} g={g} read={read} account={account} operator={cap.operator} chain={chain} freshNow={freshNow}/>}
          <ActionsCard {...common} audience="operator"/>
          <ActionsCard {...common} audience="settlement"/>
          {provider && <ActionsCard {...common} audience="provider"/>}
        </>}
      </>}
    </>}
    <footer className="mc-footer"><span><ShieldCheck size={16}/> MicroCover · Synthetic testnet demo</span><button className="mc-text-link" onClick={() => navigate('controls')}>Demo controls</button></footer>
  </>

}

/**
 * Phase 3 capability gate. Writes require the new protocol and official USDC.
 */
export function Workspace() {
  const cap = useCapability()
  const chain = useChainTime()
  const contract = MICROCOVER_ADDRESS

  return (
    <ReceiptLogProvider>
      {cap.state === 'ready' ? <details className="mc-system-details"><summary><span className="mc-connection-dot"/> Connected to Arc Testnet · Network & demo authority</summary><DeploymentCard cap={cap}/><NetworkCard/></details> : <DeploymentCard cap={cap}/>}
      {cap.state === 'ready' && contract ? (
        <ReadyWorkspace contract={contract} cap={cap} chain={chain} />
      ) : (
        <CreateCard cap={cap} chain={chain} onCreated={() => undefined} />
      )}

    </ReceiptLogProvider>
  )
}
