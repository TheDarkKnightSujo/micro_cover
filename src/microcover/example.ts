/**
 * Synthetic example used to illustrate the generic model.
 * Nothing here is onchain and nothing here is a contract field: the contract only knows
 * provider, beneficiary, cohort, bond, escrow and compensation.
 */

import { formatUsdc, parseUsdc } from '@/onchain-money'

export interface ExampleBeneficiary {
  label: string
}

export interface ExampleTerms {
  scenario: string
  providerLabel: string
  beneficiaryNoun: string
  beneficiaries: readonly ExampleBeneficiary[]
  /** USDC base units (6 decimals). */
  compensation: bigint
  escrowAmount: bigint
}

export const EXAMPLE: ExampleTerms = {
  scenario: 'Synthetic example: a live event guaranteed to its three attendees',
  providerLabel: 'Event organiser',
  beneficiaryNoun: 'Attendee',
  beneficiaries: [{ label: 'Attendee 1' }, { label: 'Attendee 2' }, { label: 'Attendee 3' }],
  compensation: parseUsdc('5'),
  escrowAmount: parseUsdc('2'),
}

export interface ExampleAmounts {
  cohort: number
  bond: string
  perCompensation: string
  perEscrow: string
  totalEscrow: string
  totalLocked: string
}

/** Same arithmetic as the contract: bond = compensation x maxCohort. */
export function exampleAmounts(terms: ExampleTerms): ExampleAmounts {
  const cohort = terms.beneficiaries.length
  const size = BigInt(cohort)
  const bond = terms.compensation * size
  const escrow = terms.escrowAmount * size
  return {
    cohort,
    bond: formatUsdc(bond),
    perCompensation: formatUsdc(terms.compensation),
    perEscrow: formatUsdc(terms.escrowAmount),
    totalEscrow: formatUsdc(escrow),
    totalLocked: formatUsdc(bond + escrow),
  }
}
