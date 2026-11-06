import { BaseError, ContractFunctionRevertedError, type Address } from 'viem'
import { useReadContract, useReadContracts } from 'wagmi'
import { TARGET_CHAIN_ID, microCoverAbi } from './contract'

const REFRESH_MS = 5_000
const NO_ACCOUNT = '0x0000000000000000000000000000000000000000'

export interface GuaranteeView {
  /** The selection this snapshot belongs to; actions must never reuse it for another one. */
  forId: bigint
  forAccount: Address | undefined
  provider: Address
  compensation: bigint
  escrowAmount: bigint
  maxCohort: number
  cohortSize: number
  joinDeadline: bigint
  settlementTime: bigint
  status: number
  outcome: number
  paidCount: number
  openSlots: number
  bondHeld: bigint
  reservedCompensation: bigint
  escrowHeld: bigint
  paidCompensation: bigint
  paidEscrow: bigint
  withdrawableBond: bigint
  remainingOwed: bigint
  joinable: boolean
  /** Enrollment order, straight from the contract. Every paid flag was read successfully. */
  beneficiaries: readonly { address: Address; paid: boolean }[]
  isMember: boolean
  maxBatch: number
}

/**
 * idle: no id selected. loading: first read in flight. unknown: the contract itself answered
 * UnknownGuarantee. unavailable: a read failed (RPC/network/unsupported), so nothing is known.
 * ready: every read the actions depend on succeeded.
 */
export type GuaranteeReadState = 'idle' | 'loading' | 'unknown' | 'unavailable' | 'ready'

export interface GuaranteeRead {
  state: GuaranteeReadState
  /** Which reads failed, in plain words, when state is unavailable. */
  failed: readonly string[]
  data: GuaranteeView | undefined
  refetch: () => void
}

function isUnknownGuaranteeError(error: unknown): boolean {
  if (!(error instanceof BaseError)) return false
  const reverted = error.walk((e) => e instanceof ContractFunctionRevertedError)
  return reverted instanceof ContractFunctionRevertedError && reverted.data?.errorName === 'UnknownGuarantee'
}

/**
 * Reads one guarantee and everything needed to act on it. Data is only returned when ALL
 * required reads succeeded for the current contract, id and wallet: a failed or still-loading
 * membership or paid-flag read is never treated as "false", and a failed beneficiary list is
 * never treated as an empty cohort.
 */
export function useGuarantee(contract: Address, id: bigint | undefined, account: Address | undefined): GuaranteeRead {
  const base = { address: contract, abi: microCoverAbi, chainId: TARGET_CHAIN_ID } as const
  const enabled = id !== undefined
  const args = [id ?? 0n] as const

  const main = useReadContracts({
    contracts: [
      { ...base, functionName: 'getGuarantee', args },
      { ...base, functionName: 'getState', args },
      { ...base, functionName: 'getBeneficiaries', args },
      { ...base, functionName: 'isJoinable', args },
      { ...base, functionName: 'MAX_SETTLEMENT_BATCH' },
    ],
    query: { enabled, refetchInterval: REFRESH_MS },
  })
  const member = useReadContract({
    ...base,
    functionName: 'isMember',
    args: [id ?? 0n, account ?? NO_ACCOUNT],
    query: { enabled: enabled && account !== undefined, refetchInterval: REFRESH_MS },
  })

  const [terms, state, beneficiaries, joinable, maxBatch] = main.data ?? []
  const addresses = beneficiaries?.status === 'success' ? beneficiaries.result : []

  const paid = useReadContracts({
    contracts: addresses.map((beneficiary) => ({
      ...base,
      functionName: 'isPaid' as const,
      args: [id ?? 0n, beneficiary] as const,
    })),
    query: { enabled: enabled && addresses.length > 0, refetchInterval: REFRESH_MS },
  })

  const refetch = () => {
    void main.refetch()
    void paid.refetch()
    void member.refetch()
  }

  if (!enabled) return { state: 'idle', failed: [], data: undefined, refetch }

  if (terms?.status === 'failure' && isUnknownGuaranteeError(terms.error)) {
    return { state: 'unknown', failed: [], data: undefined, refetch }
  }

  // Anything still in flight for the current selection: not ready, and not an error.
  const memberPending = account !== undefined && !member.isSuccess && !member.isError
  const paidPending = addresses.length > 0 && !paid.isSuccess && !paid.isError && paid.data === undefined
  if (main.isLoading || main.data === undefined || memberPending || paidPending) {
    if (!main.isError && !member.isError && !paid.isError) {
      return { state: 'loading', failed: [], data: undefined, refetch }
    }
  }

  const failed: string[] = []
  if (main.isError || terms?.status === 'failure') failed.push('guarantee terms')
  if (state?.status === 'failure') failed.push('guarantee state')
  if (beneficiaries?.status === 'failure') failed.push('beneficiary list')
  if (joinable?.status === 'failure') failed.push('enrollment status')
  if (maxBatch?.status === 'failure') failed.push('settlement batch limit')
  if (account !== undefined && member.isError) failed.push('your membership')
  const paidFlags = paid.data ?? []
  if (addresses.length > 0 && (paid.isError || paidFlags.some((flag) => flag.status === 'failure'))) {
    failed.push('payout flags')
  }
  if (addresses.length > 0 && !paid.isError && paidFlags.length !== addresses.length) failed.push('payout flags')
  if (failed.length > 0) return { state: 'unavailable', failed, data: undefined, refetch }

  if (
    terms?.status !== 'success' ||
    state?.status !== 'success' ||
    beneficiaries?.status !== 'success' ||
    joinable?.status !== 'success' ||
    maxBatch?.status !== 'success' ||
    (account !== undefined && member.data === undefined)
  ) {
    return { state: 'loading', failed: [], data: undefined, refetch }
  }

  const t = terms.result
  const s = state.result
  const flags = paidFlags.map((flag) => flag.status === 'success' && flag.result)
  return {
    state: 'ready',
    failed: [],
    refetch,
    data: {
      forId: id,
      forAccount: account,
      provider: t.provider,
      compensation: t.compensation,
      escrowAmount: t.escrowAmount,
      maxCohort: t.maxCohort,
      cohortSize: t.cohortSize,
      joinDeadline: t.joinDeadline,
      settlementTime: t.settlementTime,
      status: s.status,
      outcome: s.outcome,
      paidCount: s.paidCount,
      openSlots: s.openSlots,
      bondHeld: s.bondHeld,
      reservedCompensation: s.reservedCompensation,
      escrowHeld: s.escrowHeld,
      paidCompensation: s.paidCompensation,
      paidEscrow: s.paidEscrow,
      withdrawableBond: s.withdrawableBond,
      remainingOwed: s.remainingOwed,
      joinable: joinable.result,
      beneficiaries: beneficiaries.result.map((address, i) => ({ address, paid: flags[i] ?? false })),
      isMember: account !== undefined && member.data === true,
      maxBatch: maxBatch.result,
    },
  }
}
