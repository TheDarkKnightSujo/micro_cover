/**
 * Pure eligibility rules mirroring contracts/MicroCover.sol (protocol version 2). They only decide
 * whether a button is OFFERED; the contract re-checks everything, so hiding a button is not
 * authorization. Every time comparison uses CHAIN time (latest block timestamp), never the
 * browser clock.
 */
import { isAddressEqual, type Address } from 'viem'
import { STATUS } from './contract'
import { fmtTime } from './format'
import type { GuaranteeView } from './useGuarantee'

export interface Ctx {
  /** Latest chain block timestamp (seconds). */
  now: bigint
  account: Address | undefined
  /** The immutable demo operator of the deployment. */
  operator: Address
}

export type Verdict = { ok: true } | { ok: false; reason: string }
const OK: Verdict = { ok: true }
const no = (reason: string): Verdict => ({ ok: false, reason })

const same = (a: Address | undefined, b: Address): boolean => a !== undefined && isAddressEqual(a, b)

export const isProvider = (g: GuaranteeView, c: Pick<Ctx, 'account'>): boolean => same(c.account, g.provider)
export const isOperator = (c: Pick<Ctx, 'account' | 'operator'>): boolean => same(c.account, c.operator)

const needWallet = (c: Ctx): Verdict | undefined =>
  c.account === undefined ? no('Connect a wallet to see whether you can do this.') : undefined

/** Earliest time the operator may propose success: max(joinDeadline + 1, settlementTime). */
export const earliestProposal = (g: GuaranteeView): bigint =>
  g.joinDeadline + 1n > g.settlementTime ? g.joinDeadline + 1n : g.settlementTime

/** readyAt a proposal made at `at` would get: max(claimEndsAt, at + reviewWindow). */
export const readyIfProposedAt = (g: GuaranteeView, at: bigint): bigint =>
  g.claimEndsAt > at + g.reviewWindow ? g.claimEndsAt : at + g.reviewWindow

export function canEnroll(g: GuaranteeView, c: Ctx): Verdict {
  if (g.status !== STATUS.OPEN) return no('Enrollment is closed for this guarantee.')
  if (isProvider(g, c)) return no('A provider cannot join their own guarantee.')
  if (g.isMember) return no('You are already enrolled in this cohort.')
  if (c.now > g.joinDeadline) return no(`The join cutoff passed at ${fmtTime(g.joinDeadline)}.`)
  if (!g.joinable || g.openSlots === 0) return no('The cohort is full.')
  return needWallet(c) ?? OK
}

export function canPropose(g: GuaranteeView, c: Ctx): Verdict {
  if (!isOperator(c)) return no('Only the demo operator address can propose success.')
  if (g.status !== STATUS.OPEN) return no('Success can be proposed only while the guarantee is open.')
  const earliest = earliestProposal(g)
  if (c.now < earliest) return no(`Too early: opens at ${fmtTime(earliest)} (chain time).`)
  return OK
}

export function canDispute(g: GuaranteeView, c: Ctx): Verdict {
  const wallet = needWallet(c)
  if (wallet) return wallet
  if (!g.isMember) return no('Only an enrolled beneficiary can raise a dispute.')
  if (g.status === STATUS.OPEN) {
    return c.now <= g.claimEndsAt ? OK : no(`The dispute window ended at ${fmtTime(g.claimEndsAt)}.`)
  }
  if (g.status === STATUS.SUCCESS_PENDING) {
    return c.now <= g.successReadyAt ? OK : no(`The review window ended at ${fmtTime(g.successReadyAt)}.`)
  }
  return no('A dispute can be raised only while the guarantee is open or success is in review.')
}

export function canMarkUncertain(g: GuaranteeView, c: Ctx): Verdict {
  if (!isOperator(c)) return no('Only the demo operator address can mark a guarantee uncertain.')
  if (g.status !== STATUS.OPEN && g.status !== STATUS.SUCCESS_PENDING) {
    return no('Only an open guarantee or one with success in review can be marked uncertain.')
  }
  return OK
}

export function canFinalize(g: GuaranteeView, c: Ctx): Verdict {
  if (g.status !== STATUS.SUCCESS_PENDING) return no('Nothing to finalize: success has not been proposed, or it was frozen or resolved.')
  if (c.now <= g.successReadyAt) return no(`The review window is open until ${fmtTime(g.successReadyAt)}. Finalizing is possible only after that moment.`)
  return OK
}

export function canAdmitFailure(g: GuaranteeView, c: Ctx): Verdict {
  if (!isProvider(g, c)) return no('Only the provider can admit failure.')
  if (g.status === STATUS.OPEN || g.status === STATUS.SUCCESS_PENDING || g.status === STATUS.UNCERTAIN) return OK
  if (g.status === STATUS.SUCCEEDED || (g.status === STATUS.CLOSED && g.outcome === 2)) {
    return no('Success is finalized, so failure can no longer be admitted.')
  }
  return no('Failure was already admitted.')
}

export function canSettle(g: GuaranteeView): Verdict {
  if (g.status !== STATUS.FAILED) return no(g.status === STATUS.OPEN ? 'Available after the provider admits failure.' : 'There is no failure payout to settle.')
  if (g.cohortSize - g.paidCount === 0) return no('Every enrolled beneficiary has been paid.')
  return OK
}

export function canReleaseEscrow(g: GuaranteeView): Verdict {
  if (g.status !== STATUS.SUCCEEDED) return no('Available only after success is finalized.')
  if (g.successEscrowReleased) return no('The success escrow was already released.')
  return OK
}

export function canWithdraw(g: GuaranteeView, c: Ctx): Verdict {
  if (!isProvider(g, c)) return no('Only the provider can withdraw the remaining bond.')
  if (g.status === STATUS.FAILED) {
    if (g.paidCount < g.cohortSize) return no(`${g.cohortSize - g.paidCount} beneficiaries are still unpaid. Settle them first.`)
    return g.bondHeld > 0n ? OK : no('No bond remains.')
  }
  if (g.status === STATUS.SUCCEEDED) {
    return g.successEscrowReleased ? OK : no('Release the success escrow first.')
  }
  if (g.status === STATUS.CLOSED) return no('Closed: no bond remains for this guarantee.')
  return no('The bond stays locked until failure is admitted and paid, or success is finalized and the escrow released.')
}

/** One plain sentence describing what happens next for the selected guarantee. */
export function nextStep(g: GuaranteeView, c: Ctx): string {
  switch (g.status) {
    case STATUS.OPEN:
      if (c.now <= g.joinDeadline) return `Open for enrollment until ${fmtTime(g.joinDeadline)}. The demo operator may propose success from ${fmtTime(earliestProposal(g))}; the provider may admit failure at any time.`
      if (c.now < earliestProposal(g)) return `Enrollment is over. The demo operator may propose success from ${fmtTime(earliestProposal(g))}. Enrolled beneficiaries can dispute until ${fmtTime(g.claimEndsAt)}.`
      return 'Enrollment is over and the outcome deadline has passed. Waiting for the demo operator to propose success, or for the provider to admit failure. No success happens automatically.'
    case STATUS.SUCCESS_PENDING:
      return c.now <= g.successReadyAt
        ? `Success is proposed and in review until ${fmtTime(g.successReadyAt)}. A beneficiary can still dispute, and the provider can still admit failure.`
        : 'The review window has ended. Anyone can finalize success now, but the provider can still admit failure until someone does.'
    case STATUS.UNCERTAIN:
      return 'Frozen. In this phase only the provider can resolve it, by admitting failure; there is no route to success. Funds stay locked until then.'
    case STATUS.FAILED:
      return g.paidCount < g.cohortSize
        ? `Failure admitted. ${g.cohortSize - g.paidCount} of ${g.cohortSize} beneficiaries still need to be paid; anyone can continue settlement.`
        : 'All beneficiaries are paid. The provider can withdraw any unused bond.'
    case STATUS.SUCCEEDED:
      return g.successEscrowReleased
        ? 'Escrow released to the provider. The provider can now withdraw the whole bond.'
        : 'Success finalized and irreversible. Anyone can release the escrow to the provider; then the provider withdraws the bond.'
    default:
      return g.outcome === 2 ? 'Closed after success. Escrow and bond were returned to the provider.' : 'Closed after failure. Every obligation is settled.'
  }
}
