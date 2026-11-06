import type { Verdict } from './lifecycle'

/** Unsigned checks only. Slow RPC calls must not turn an expired report into a wallet request. */
export async function checkedEvidenceGas(
  simulate:()=>Promise<unknown>,
  estimate:()=>Promise<bigint>,
  recheck:()=>Promise<Verdict>,
):Promise<bigint>{
  await simulate()
  const gas=await estimate()
  if(gas<=0n)throw Error('RPC returned an invalid gas estimate; nothing sent.')
  const verdict=await recheck()
  if(!verdict.ok)throw Error(verdict.reason)
  return (gas*120n+99n)/100n
}
