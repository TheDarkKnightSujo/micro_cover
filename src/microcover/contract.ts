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

/**
 * MicroCover Phase 1 ABI: create/fund, enroll, provider failure admission, bounded
 * permissionless settlement and leftover-bond withdrawal. There is no success-release
 * function. Enum values arrive as uint8 (see STATUS / OUTCOME below).
 */
export const microCoverAbi = parseAbi([
  'function usdc() view returns (address)',
  'function MAX_COHORT() view returns (uint32)',
  'function MAX_SETTLEMENT_BATCH() view returns (uint32)',
  'function nextGuaranteeId() view returns (uint256)',
  'function getGuarantee(uint256 id) view returns ((address provider, uint128 compensation, uint128 escrowAmount, uint32 maxCohort, uint32 cohortSize, uint64 joinDeadline, uint64 settlementTime, bytes32 termsHash))',
  'function getState(uint256 id) view returns ((uint8 status, uint8 outcome, uint32 enrolled, uint32 paidCount, uint32 openSlots, uint64 failureAdmittedAt, uint256 bondHeld, uint256 reservedCompensation, uint256 escrowHeld, uint256 paidCompensation, uint256 paidEscrow, uint256 withdrawableBond, uint256 remainingOwed))',
  'function getBeneficiaries(uint256 id) view returns (address[])',
  'function isPaid(uint256 id, address account) view returns (bool)',
  'function isMember(uint256 id, address account) view returns (bool)',
  'function isJoinable(uint256 id) view returns (bool)',
  'function bondOf(uint256 id) view returns (uint256)',
  'function escrowedOf(uint256 id) view returns (uint256)',
  'function reservedOf(uint256 id) view returns (uint256)',
  'function createGuarantee(uint128 compensation, uint128 escrowAmount, uint32 maxCohort, uint64 joinDeadline, uint64 settlementTime, bytes32 termsHash) returns (uint256 id)',
  'function joinCohort(uint256 id)',
  'function admitFailure(uint256 id)',
  'function settleFailure(uint256 id, uint32 maxBeneficiaries) returns (uint32 settled)',
  'function withdrawRemainingBond(uint256 id) returns (uint256 amount)',
  'event GuaranteeCreated(uint256 indexed id, address indexed provider, uint128 compensation, uint128 escrowAmount, uint32 maxCohort, uint64 joinDeadline, uint64 settlementTime, bytes32 termsHash, uint256 bond)',
  'event CohortJoined(uint256 indexed id, address indexed beneficiary, uint32 cohortSize)',
  'event FailureAdmitted(uint256 indexed id, address indexed provider, uint32 enrolled, uint256 totalOwed)',
  'event BeneficiaryPaid(uint256 indexed id, address indexed beneficiary, uint256 escrowReturned, uint256 compensationPaid)',
  'event SettlementBatchProcessed(uint256 indexed id, address indexed caller, uint32 settled, uint32 paidCount, uint32 enrolled)',
  'event GuaranteeClosed(uint256 indexed id)',
  'event RemainingBondWithdrawn(uint256 indexed id, address indexed provider, uint256 amount)',
  'error ZeroUsdcAddress()',
  'error InvalidCompensation()',
  'error InvalidEscrowAmount()',
  'error InvalidMaxCohort()',
  'error InvalidJoinDeadline()',
  'error InvalidSettlementTime()',
  'error UnknownGuarantee(uint256 id)',
  'error JoinDeadlinePassed(uint256 id)',
  'error CohortFull(uint256 id)',
  'error AlreadyMember(uint256 id, address beneficiary)',
  'error ProviderCannotJoin(uint256 id)',
  'error IncorrectUsdcReceived(uint256 expected, uint256 balanceBefore, uint256 balanceAfter)',
  'error EnrollmentClosed(uint256 id)',
  'error InsufficientBondCapacity(uint256 id, uint256 available, uint256 required)',
  'error NotProvider(uint256 id, address caller)',
  'error AlreadyAdmitted(uint256 id)',
  'error NotFailed(uint256 id)',
  'error NothingToSettle(uint256 id)',
  'error NothingToWithdraw(uint256 id)',
  'error LiabilitiesUnpaid(uint256 id, uint32 remaining)',
  'error InvalidBatchSize(uint32 requested, uint32 max)',
  'error IncorrectUsdcSent(uint256 expected, uint256 balanceBefore, uint256 balanceAfter)',
  'error IncorrectRecipientReceipt(address recipient, uint256 expected, uint256 balanceBefore, uint256 balanceAfter)',
  'error IndexOutOfRange(uint256 id, uint256 index)',
  'error AlreadyPaid(uint256 id, address beneficiary)',
  'error ReservedCompensationRemaining(uint256 id, uint256 reserved)',
])

/** Lifecycle values returned by getState().status. */
export const STATUS = { OPEN: 0, FAILED: 1, CLOSED: 2 } as const

/** Verdict values returned by getState().outcome. Phase 1 has no success verdict. */
export const OUTCOME = { NONE: 0, FAILURE: 1 } as const

export const STATUS_LABEL: Record<number, string> = {
  [STATUS.OPEN]: 'Open',
  [STATUS.FAILED]: 'Failed, paying out',
  [STATUS.CLOSED]: 'Closed',
}

/** Mirrors the contract's MAX_COHORT constant (100); the contract enforces it too. */
export const MAX_COHORT_LIMIT = 100

/** Largest value the contract accepts for compensation and escrow (uint128). */
export const UINT128_MAX = (1n << 128n) - 1n
