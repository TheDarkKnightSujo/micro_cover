import { useState } from 'react'
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
import { ExampleCard } from './ExampleCard'
import { HistoryCard } from './HistoryCard'
import { LookupCard } from './LookupCard'
import { NetworkCard } from './NetworkCard'
import { TermsCard } from './TermsCard'

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
  const url = parseId(value) !== undefined ? `?guarantee=${value}` : window.location.pathname
  window.history.replaceState(null, '', url)
}

interface ReadyProps {
  contract: Address
  cap: Extract<Capability, { state: 'ready' }>
  chain: ChainTime
}

function ReadyWorkspace({ contract, cap, chain }: ReadyProps) {
  const { address: account } = useAccount()
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

  return (
    <>
      <LookupCard idInput={idInput} onIdChange={select} latestId={latestId} read={read} account={account} operator={cap.operator} chain={chain} />
      {g && <TermsCard g={g} />}
      <ActionsCard contract={contract} id={id} read={read} account={account} operator={cap.operator} chain={chain} freshNow={freshNow} />
      <HistoryCard id={id} g={g} chain={chain} />
      <CreateCard
        key={`${contract}:${account ?? 'none'}`}
        cap={cap}
        chain={chain}
        onCreated={(created) => {
          select(created.toString())
          void next.refetch()
        }}
      />
    </>
  )
}

/**
 * The Phase 2 flow. Nothing is approved, created, enrolled or sent until the configured
 * contract is verified as a Phase 2 deployment with the official USDC.
 */
export function Workspace() {
  const cap = useCapability()
  const chain = useChainTime()
  const contract = MICROCOVER_ADDRESS

  return (
    <ReceiptLogProvider>
      <DeploymentCard cap={cap} />
      {cap.state === 'ready' && contract ? (
        <ReadyWorkspace contract={contract} cap={cap} chain={chain} />
      ) : (
        <CreateCard cap={cap} chain={chain} onCreated={() => undefined} />
      )}
      <ExampleCard />
      <NetworkCard />
    </ReceiptLogProvider>
  )
}
