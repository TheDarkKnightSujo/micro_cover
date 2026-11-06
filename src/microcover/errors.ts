import { BaseError, ContractFunctionRevertedError, UserRejectedRequestError } from 'viem'

const REVERT_TEXT: Record<string, string> = {
  EvidenceReportRequired:'This guarantee requires an anchored evidence verdict; manual success is disabled.',
  UncertaintyTimeoutReached:'The uncertainty deadline has arrived; resolution is closed and unresolved finalization is available.',
  UncertaintyTimeoutNotReached:'The frozen uncertainty deadline has not arrived.',
  RefundsPending:'Refund every beneficiary escrow before returning the bond.',
  NothingToRefund:'No unresolved escrow refund remains.',
  EvidenceExpired:'The prepared report expired. Prepare a fresh report from the same verified snapshot.',
  EvidenceBindingMismatch:'Evidence does not match the frozen policy/cohort.',
  EvidenceRootMismatch:'The report must match the latest onchain anchor.',
  InvalidNonce:'This report or anchor nonce is outdated. Refresh the guarantee and prepare again.',
  WrongChain:'Evidence targets a different chain.',
  WrongConsumer:'Evidence targets a different contract.',
  NotEvidenceBound:'This legacy manual guarantee has no evidence policy.',
  UnresolvedAlreadyFinalized:'Escrow-only refunds were already selected; failure cannot replace that outcome.',
  NotProvider: 'Only this guarantee\u2019s provider can do that.',
  AlreadyAdmitted: 'Failure was already admitted for this guarantee.',
  EnrollmentClosed: 'Enrollment is closed for this guarantee.',
  JoinDeadlinePassed: 'The join deadline has passed.',
  CohortFull: 'The cohort is full.',
  AlreadyMember: 'This wallet is already in the cohort.',
  ProviderCannotJoin: 'A provider cannot join their own guarantee.',
  InsufficientBondCapacity: 'The bond has no capacity left for another beneficiary.',
  NotFailed: 'Failure has not been admitted yet.',
  NothingToSettle: 'Every enrolled beneficiary has already been paid.',
  NothingToWithdraw: 'There is no remaining bond to withdraw.',
  LiabilitiesUnpaid: 'Settle every enrolled beneficiary before withdrawing the remaining bond.',
  InvalidBatchSize: 'That batch size is not allowed.',
  UnknownGuarantee: 'No guarantee exists with this id.',
  IncorrectUsdcReceived: 'The token did not deliver the exact amount required.',
  IncorrectUsdcSent: 'The token did not send the exact amount required.',
  IncorrectRecipientReceipt: 'A recipient would not receive the full amount, so nothing was paid.',
  NotDemoOperator: 'Only the demo operator address can do that.',
  NotBeneficiary: 'Only an enrolled beneficiary can raise a dispute.',
  InvalidStatus: 'That action is not available in the guarantee\u2019s current status.',
  ProposalTooEarly: 'Success cannot be proposed yet: the join cutoff and outcome deadline must pass first.',
  DisputeWindowClosed: 'The dispute window has closed.',
  ReviewWindowOpen: 'The review window is still open. Success can be finalized only after it ends.',
  SuccessAlreadyFinalized: 'Success is already finalized, so failure can no longer be admitted.',
  SuccessEscrowAlreadyReleased: 'The success escrow was already released.',
  SuccessEscrowNotReleased: 'Release the success escrow before withdrawing the bond.',
  TimestampOverflow: 'A timestamp is too large for the contract.',
  InvalidJoinDeadline: 'The join deadline must be in the future.',
  InvalidSettlementTime: 'Settlement cannot be before the join deadline.',
  InvalidMaxCohort: 'The cohort size must be between 1 and the contract maximum.',
  InvalidCompensation: 'Compensation must be greater than zero.',
  InvalidEscrowAmount: 'Escrow must be greater than zero.',
}

export interface DescribedError {
  /** True when the user simply dismissed the wallet prompt. */
  cancelled: boolean
  text: string
}

/** Turns a wagmi/viem failure into short, actionable copy. Never shows raw RPC dumps. */
export function describeError(error: unknown): DescribedError {
  if (error instanceof BaseError) {
    if (error.walk((e) => e instanceof UserRejectedRequestError)) {
      return { cancelled: true, text: 'Cancelled in your wallet.' }
    }
    const reverted = error.walk((e) => e instanceof ContractFunctionRevertedError)
    if (reverted instanceof ContractFunctionRevertedError) {
      const name = reverted.data?.errorName
      if (name && REVERT_TEXT[name]) return { cancelled: false, text: REVERT_TEXT[name] }
      if (reverted.reason) return { cancelled: false, text: `The transaction would fail: ${reverted.reason}` }
    }
    const short = error.shortMessage.toLowerCase()
    if (short.includes('allowance')) {
      return { cancelled: false, text: 'USDC allowance is too low. Approve the exact amount first.' }
    }
    if (short.includes('balance') || short.includes('insufficient funds')) {
      return { cancelled: false, text: 'Insufficient balance for this transaction.' }
    }
    return { cancelled: false, text: error.shortMessage }
  }
  if (error instanceof Error) return { cancelled: false, text: 'Something went wrong. Please try again.' }
  return { cancelled: false, text: 'Something went wrong. Please try again.' }
}
