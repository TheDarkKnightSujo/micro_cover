import { readFileSync, writeFileSync } from 'node:fs'
import { createPublicClient, http, parseAbi, type Abi, type Address } from 'viem'

// Read-only checkpoint audit. Never imports a wallet or sends a transaction.
const address = '0xdcd11bb347f063b5a876c8816f5a02b8ea0f11e0' as Address
const client = createPublicClient({ transport: http('https://rpc.testnet.arc.io') })
const abi = (JSON.parse(readFileSync('contracts/out/MicroCover.sol/MicroCover.json', 'utf8')) as { abi: Abi }).abi
if (await client.getChainId() !== 5042002) throw Error('WRONG_CHAIN')
const block = await client.getBlock()
const read = (functionName: string, args: readonly unknown[] = []) => client.readContract({ address, abi, functionName, args, blockNumber: block.number })
const configuration: Record<string, unknown> = Object.fromEntries(await Promise.all(['protocolVersion', 'usdc', 'demoOperator', 'reviewWindow', 'uncertaintyTimeout'].map(async n => [n, await read(n)]))) as Record<string, unknown>
if (configuration.protocolVersion !== 3n || configuration.reviewWindow !== 120n || configuration.uncertaintyTimeout !== 120n) throw Error('CONFIG_CHANGED')
const next = await read('nextGuaranteeId') as bigint
const guarantees = []
let obligations = 0n
for (let id = 1n; id < next; id++) {
  const [terms, state, evidence, members] = await Promise.all([read('getGuarantee', [id]), read('getState', [id]), read('getEvidenceState', [id]), read('getBeneficiaries', [id])])
  const s = state as { bondHeld: bigint; escrowHeld: bigint }
  obligations += s.bondHeld + s.escrowHeld // Reserve is part of bond, not an extra asset.
  let collection: unknown
  try {
    const response = await fetch(`http://127.0.0.1:8787/api/evidence/v1/guarantees/${id}`)
    const body = await response.json() as { evaluation?: unknown }
    collection = { httpStatus: response.status, evaluation: body.evaluation ?? null }
  } catch { collection = { unavailable: true } }
  guarantees.push({ id, terms, state, evidence, members, collection })
}
const balance = await client.readContract({ address: configuration.usdc as Address, abi: parseAbi(['function balanceOf(address) view returns (uint256)']), functionName: 'balanceOf', args: [address], blockNumber: block.number })
if (balance < obligations) throw Error('INSOLVENT')
const proof = { chainId: 5042002, address, block: block.number, chainTimestamp: block.timestamp, configuration, balance, obligations, guarantees, checkpoint: 'IMPLEMENTATION_FROZEN_HUMAN_CHECKS_DEFERRED', studioReconciled: false }
writeFileSync('docs/evidence/phase3-freeze-state.json', JSON.stringify(proof, (_: string, v: unknown) => typeof v === 'bigint' ? v.toString() : v, 2) + '\n')
console.log(JSON.stringify({ block: String(block.number), balance: String(balance), obligations: String(obligations), guarantees: guarantees.map(g => ({ id: String(g.id), state: g.state, collection: g.collection })) }, (_: string, v: unknown) => typeof v === 'bigint' ? v.toString() : v))
