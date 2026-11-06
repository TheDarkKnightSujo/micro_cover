/**
 * MicroCover contract wiring: one chain (Arc Testnet), one token (official USDC).
 * Every chain/token fact comes from `@/onchain-facts`; the deployed contract address
 * comes from `VITE_MICROCOVER_ADDRESS` in `.env` (a public value, never a secret).
 */

import { isAddress, parseAbi, type Address } from 'viem'
import { arcTestnet } from 'viem/chains'
import { buildAddressExplorerUrl, getUsdc, requireChain } from '@/onchain-facts'

export const TARGET_CHAIN_ID = arcTestnet.id

export const TARGET_CHAIN = requireChain(TARGET_CHAIN_ID)

const usdcFact = getUsdc(TARGET_CHAIN_ID)
if (!usdcFact) {
  throw new Error(`USDC is not registered for chain ${TARGET_CHAIN_ID}`)
}

/** Official Arc Testnet USDC (ERC-20 view, 6 decimals). */
export const USDC_ADDRESS: Address = usdcFact.address as Address

const rawAddress = (import.meta.env as Record<string, string | undefined>).VITE_MICROCOVER_ADDRESS?.trim()

/** Undefined until the contract is deployed and the address is added to `.env`. */
export const MICROCOVER_ADDRESS: Address | undefined =
  rawAddress && isAddress(rawAddress) ? rawAddress : undefined

export const addressUrl = (address: string): string => buildAddressExplorerUrl(TARGET_CHAIN_ID, address)

/** Read surface of the foundation contract. Write ABI is added with the lifecycle features. */
export const microCoverAbi = parseAbi([
  'function usdc() view returns (address)',
  'function MAX_COHORT() view returns (uint32)',
  'function nextGuaranteeId() view returns (uint256)',
  'function getGuarantee(uint256 id) view returns ((address provider, uint128 compensation, uint128 escrowAmount, uint32 maxCohort, uint32 cohortSize, uint64 joinDeadline, uint64 settlementTime, bytes32 termsHash))',
  'function isMember(uint256 id, address account) view returns (bool)',
  'function isJoinable(uint256 id) view returns (bool)',
  'function bondOf(uint256 id) view returns (uint256)',
  'function escrowedOf(uint256 id) view returns (uint256)',
  'event GuaranteeCreated(uint256 indexed id, address indexed provider, uint128 compensation, uint128 escrowAmount, uint32 maxCohort, uint64 joinDeadline, uint64 settlementTime, bytes32 termsHash, uint256 bond)',
  'event CohortJoined(uint256 indexed id, address indexed beneficiary, uint32 cohortSize)',
])
