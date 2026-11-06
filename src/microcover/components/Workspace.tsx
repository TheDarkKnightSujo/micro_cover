import { useState } from 'react'
import type { Address } from 'viem'
import { useAccount, useReadContract } from 'wagmi'
import { MICROCOVER_ADDRESS, TARGET_CHAIN_ID, microCoverAbi } from '../contract'
import { useGuarantee } from '../useGuarantee'
import { ActionsCard } from './ActionsCard'
import { CreateCard } from './CreateCard'
import { LookupCard } from './LookupCard'

function parseId(input: string): bigint | undefined {
  if (!/^\d{1,18}$/.test(input)) return undefined
  const id = BigInt(input)
  return id > 0n ? id : undefined
}

function LiveWorkspace({ contract }: { contract: Address }) {
  const { address: account } = useAccount()
  const [idInput, setIdInput] = useState('')
  const id = parseId(idInput)

  const next = useReadContract({
    address: contract,
    abi: microCoverAbi,
    functionName: 'nextGuaranteeId',
    chainId: TARGET_CHAIN_ID,
    query: { refetchInterval: 8_000 },
  })
  const latestId = next.data === undefined ? undefined : next.data - 1n
  const read = useGuarantee(contract, id, account)

  return (
    <>
      <CreateCard
        key={`${contract}:${account ?? 'none'}`}
        onCreated={(created) => {
          setIdInput(created.toString())
          void next.refetch()
        }}
      />
      <LookupCard live idInput={idInput} onIdChange={setIdInput} latestId={latestId} read={read} account={account} />
      <ActionsCard contract={contract} id={id} read={read} account={account} />
    </>
  )
}

/** The Phase 1 flow. Without a published contract address nothing is read or sent. */
export function Workspace() {
  if (!MICROCOVER_ADDRESS) {
    return (
      <>
        <CreateCard onCreated={() => undefined} />
        <LookupCard live={false} idInput="" onIdChange={() => undefined} latestId={undefined} read={undefined} account={undefined} />
      </>
    )
  }
  return <LiveWorkspace contract={MICROCOVER_ADDRESS} />
}
