import {
  AbiDecodingZeroDataError,
  BaseError,
  ContractFunctionRevertedError,
  ContractFunctionZeroDataError,
  isAddressEqual,
  zeroAddress,
  type Address,
} from 'viem'
import { useReadContracts } from 'wagmi'
import { EXPECTED_PROTOCOL_VERSION, MICROCOVER_ADDRESS, TARGET_CHAIN_ID, USDC_ADDRESS, microCoverAbi } from './contract'

export type Capability =
  | { state: 'none' }
  | { state: 'checking' }
  | { state: 'unavailable'; retry: () => void }
  | { state: 'unsupported'; reason: string; retry: () => void }
  | { state: 'ready'; operator: Address; reviewWindow: bigint; uncertaintyTimeout: bigint; retry: () => void }

/** True when the contract itself answered (a revert or empty return), as opposed to a network failure. */
function contractAnswered(error: unknown): boolean {
  if (!(error instanceof BaseError)) return false
  return Boolean(
    error.walk(
      (e) =>
        e instanceof ContractFunctionRevertedError ||
        e instanceof ContractFunctionZeroDataError ||
        e instanceof AbiDecodingZeroDataError,
    ),
  )
}

/**
 * Probes the configured address BEFORE anything can be approved or sent. Requires protocol
 * version 3, the official USDC, a non-zero immutable operator/review and separate timeout120.
 * A network/RPC failure is "unavailable" (retryable), never mistaken for an unsupported
 * deployment and never treated as success.
 */
export function useCapability(): Capability {
  const contract = MICROCOVER_ADDRESS
  const base = { address: contract, abi: microCoverAbi, chainId: TARGET_CHAIN_ID } as const
  const probe = useReadContracts({
    contracts: [
      { ...base, functionName: 'protocolVersion' },
      { ...base, functionName: 'usdc' },
      { ...base, functionName: 'demoOperator' },
      { ...base, functionName: 'reviewWindow' },
      { ...base, functionName: 'uncertaintyTimeout' },
    ],
    query: { enabled: Boolean(contract), retry: 1 },
  })
  const retry = () => void probe.refetch()

  if (!contract) return { state: 'none' }
  if (probe.isLoading || (probe.data === undefined && !probe.isError)) return { state: 'checking' }
  if (probe.data === undefined) return { state: 'unavailable', retry }

  const [version, token, operator, window, uncertainty] = probe.data
  if (version.status === 'failure') {
    return contractAnswered(version.error)
      ? {
          state: 'unsupported',
          reason: 'This contract does not report a protocol version, so it is a Phase 1 deployment (or not a MicroCover contract).',
          retry,
        }
      : { state: 'unavailable', retry }
  }
  if (version.result !== EXPECTED_PROTOCOL_VERSION) {
    return {
      state: 'unsupported',
      reason: `This contract reports protocol version ${version.result.toString()}; this app needs version ${EXPECTED_PROTOCOL_VERSION.toString()}.`,
      retry,
    }
  }
  if (token.status === 'failure' || operator.status === 'failure' || window.status === 'failure' || uncertainty.status === 'failure') {
    return { state: 'unavailable', retry }
  }
  if (!isAddressEqual(token.result, USDC_ADDRESS)) {
    return { state: 'unsupported', reason: 'This contract settles in a token other than the official Arc Testnet USDC.', retry }
  }
  if (isAddressEqual(operator.result, zeroAddress)) {
    return { state: 'unsupported', reason: 'This contract reports an invalid (zero) demo operator.', retry }
  }
  if (window.result === 0n) {
    return { state: 'unsupported', reason: 'This contract reports an invalid (zero) review window.', retry }
  }
  if (uncertainty.result !== 120n) return { state: 'unsupported', reason: 'This demo requires a separately configured 120-second uncertainty timeout.', retry }
  return { state: 'ready', operator: operator.result, reviewWindow: window.result, uncertaintyTimeout: uncertainty.result, retry }
}
