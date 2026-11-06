/**
 * Readable terms. The contract stores only a 32-byte terms hash; it cannot say what the
 * hash means. This app knows exactly one synthetic demo condition, and shows its text ONLY
 * when a guarantee's stored hash equals keccak256(utf8(text)). Any other hash is shown as
 * "readable terms unavailable; verify terms": the app never guesses.
 *
 * To verify independently: keccak256 of the exact UTF-8 bytes of PRESET_CONDITION_TEXT
 * (no trailing newline) equals PRESET_TERMS_HASH.
 */
import { keccak256, stringToHex, type Hex } from 'viem'

export const PRESET_CONDITION_TEXT =
  'Synthetic demo condition: the provider delivers the described service to every enrolled beneficiary by the outcome deadline. This text is illustrative only and is not a real-world commitment.'

export const PRESET_TERMS_HASH: Hex = keccak256(stringToHex(PRESET_CONDITION_TEXT))

/** The preset text if (and only if) the hash matches it; otherwise undefined. */
export function readableTerms(termsHash: Hex): string | undefined {
  return termsHash.toLowerCase() === PRESET_TERMS_HASH.toLowerCase() ? PRESET_CONDITION_TEXT : undefined
}
