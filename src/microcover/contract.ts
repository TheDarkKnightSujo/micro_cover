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
 * MicroCover Phase 2 ABI, derived from the reviewed contracts/MicroCover.sol (protocol version 2).
 * Enums arrive as uint8 (see STATUS / OUTCOME). There is no function that lets anyone choose a
 * payout recipient or amount.
 */
export const microCoverAbi = parseAbi([
  'function protocolVersion() pure returns (uint256)',
  'function usdc() view returns (address)',
  'function demoOperator() view returns (address)',
  'function reviewWindow() view returns (uint64)',
  'function MAX_COHORT() view returns (uint32)',
  'function MAX_SETTLEMENT_BATCH() view returns (uint32)',
  'function nextGuaranteeId() view returns (uint256)',
  'function getGuarantee(uint256 id) view returns ((address provider, uint128 compensation, uint128 escrowAmount, uint32 maxCohort, uint32 cohortSize, uint64 joinDeadline, uint64 settlementTime, bytes32 termsHash))',
  'function getState(uint256 id) view returns ((uint8 status, uint8 outcome, uint32 enrolled, uint32 paidCount, uint32 openSlots, uint64 failureAdmittedAt, uint256 bondHeld, uint256 reservedCompensation, uint256 escrowHeld, uint256 paidCompensation, uint256 paidEscrow, uint256 withdrawableBond, uint256 remainingOwed))',
  'function getLifecycle(uint256 id) view returns ((uint8 status, uint8 outcome, uint64 joinDeadline, uint64 settlementTime, uint64 claimEndsAt, uint64 successProposedAt, uint64 successReadyAt, uint64 successFinalizedAt, uint64 uncertainAt, address uncertainBy, bool successEscrowReleased, uint256 releasedSuccessReservation, uint256 releasedSuccessEscrow, uint256 withdrawnBond, address demoOperator, uint64 reviewWindow))',
  'function getBeneficiaries(uint256 id) view returns (address[])',
  'function isPaid(uint256 id, address account) view returns (bool)',
  'function isMember(uint256 id, address account) view returns (bool)',
  'function isJoinable(uint256 id) view returns (bool)',
  'function bondOf(uint256 id) view returns (uint256)',
  'function escrowedOf(uint256 id) view returns (uint256)',
  'function reservedOf(uint256 id) view returns (uint256)',
  'function createGuarantee(uint128 compensation, uint128 escrowAmount, uint32 maxCohort, uint64 joinDeadline, uint64 settlementTime, bytes32 termsHash) returns (uint256 id)',
  'function joinCohort(uint256 id)',
  'function proposeSuccess(uint256 id)',
  'function raiseDispute(uint256 id)',
  'function markUncertain(uint256 id)',
  'function finalizeSuccess(uint256 id)',
  'function releaseSuccessEscrow(uint256 id) returns (uint256 amount)',
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
  'event SuccessProposed(uint256 indexed id, address indexed operator, uint64 readyAt)',
  'event DisputeRaised(uint256 indexed id, address indexed beneficiary)',
  'event UncertaintyMarked(uint256 indexed id, address indexed operator)',
  'event SuccessFinalized(uint256 indexed id, uint256 releasedReservation)',
  'event SuccessEscrowReleased(uint256 indexed id, address indexed provider, uint256 amount)',
  'error ZeroUsdcAddress()',
  'error ZeroOperatorAddress()',
  'error ZeroReviewWindow()',
  'error InvalidCompensation()',
  'error InvalidEscrowAmount()',
  'error InvalidMaxCohort()',
  'error InvalidJoinDeadline()',
  'error InvalidSettlementTime()',
  'error TimestampOverflow(uint256 value)',
  'error UnknownGuarantee(uint256 id)',
  'error JoinDeadlinePassed(uint256 id)',
  'error CohortFull(uint256 id)',
  'error AlreadyMember(uint256 id, address beneficiary)',
  'error ProviderCannotJoin(uint256 id)',
  'error IncorrectUsdcReceived(uint256 expected, uint256 balanceBefore, uint256 balanceAfter)',
  'error EnrollmentClosed(uint256 id)',
  'error InsufficientBondCapacity(uint256 id, uint256 available, uint256 required)',
  'error NotProvider(uint256 id, address caller)',
  'error NotDemoOperator(address caller)',
  'error NotBeneficiary(uint256 id, address caller)',
  'error InvalidStatus(uint256 id, uint8 status)',
  'error ProposalTooEarly(uint256 id, uint256 earliestTimestamp)',
  'error DisputeWindowClosed(uint256 id, uint64 deadline)',
  'error ReviewWindowOpen(uint256 id, uint64 successReadyAt)',
  'error AlreadyAdmitted(uint256 id)',
  'error SuccessAlreadyFinalized(uint256 id)',
  'error SuccessEscrowAlreadyReleased(uint256 id)',
  'error SuccessEscrowNotReleased(uint256 id)',
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

/** Protocol version this app understands. Phase 1 contracts have no protocolVersion(). */
export const EXPECTED_PROTOCOL_VERSION = 2n

/** Mirrors the contract's MAX_COHORT constant (100); the contract enforces it too. */
export const MAX_COHORT_LIMIT = 100

/** Largest value the contract accepts for compensation and escrow (uint128). */
export const UINT128_MAX = (1n << 128n) - 1n

/** Lifecycle values returned by getState().status / getLifecycle().status. Append-only in the contract. */
export const STATUS = {
  OPEN: 0,
  FAILED: 1,
  CLOSED: 2,
  SUCCESS_PENDING: 3,
  SUCCEEDED: 4,
  UNCERTAIN: 5,
} as const

/** Terminal verdicts returned by outcome. NONE means no final verdict yet. */
export const OUTCOME = { NONE: 0, FAILURE: 1, SUCCESS: 2 } as const

export const STATUS_LABEL: Record<number, string> = {
  [STATUS.OPEN]: 'Open',
  [STATUS.FAILED]: 'Failed, paying out',
  [STATUS.CLOSED]: 'Closed',
  [STATUS.SUCCESS_PENDING]: 'Success proposed, in review',
  [STATUS.SUCCEEDED]: 'Succeeded, releasing funds',
  [STATUS.UNCERTAIN]: 'Uncertain, frozen',
}

export const OUTCOME_LABEL: Record<number, string> = {
  [OUTCOME.NONE]: 'No final verdict',
  [OUTCOME.FAILURE]: 'Failure admitted by provider',
  [OUTCOME.SUCCESS]: 'Success finalized',
}
