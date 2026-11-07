import { useEffect, useId, useRef, useState, type ReactNode } from 'react'
import { useAccount, usePublicClient } from 'wagmi'
import { TARGET_CHAIN_ID } from '../contract'
import { checkedEvidenceGas } from '../evidenceSubmission'
import { describeError } from '../errors'
import { type TxWriter, useTxFlow } from '../useTxFlow'
import type { ChainTime } from '../useChainTime'
import type { Verdict } from '../lifecycle'
import { Callout } from './Card'
import { ChainGate, dangerButton, ghostButton, primaryButton } from './ChainGate'
import { TxStatus } from './TxStatus'

interface Props {
  title: string
  /** Who may do this, e.g. "Provider only". */
  role: string
  description: ReactNode
  /** When set, a first click only arms the action and shows this irreversible-action warning. */
  warning?: string
  /** Pure eligibility check against a chain timestamp. Re-run with a fresh block just before sending. */
  eligible: (now: bigint) => Verdict
  chain: ChainTime
  freshNow: () => Promise<bigint>
  label: string
  workingLabel: string
  successText: string
  receiptLabel: string
  guaranteeId: bigint
  send: (write: TxWriter) => void
  onConfirmed: () => void
  /** Rendered above the button when the action is available (e.g. the recipients it will pay). */
  preview?: ReactNode
}

/**
 * One guarded contract action. The button is offered only when `eligible(chainNow)` says so, and
 * eligibility is re-checked against the newest block immediately before the wallet prompt. The
 * contract still enforces everything; this only avoids offering actions that cannot work.
 */
export function GuardedAction(props: Props) {
  const { title, role, description, warning, eligible, chain, freshNow, label, workingLabel, successText, receiptLabel, guaranteeId, send, onConfirmed, preview } = props
  const headingId = useId()
  const [armed, setArmed] = useState(false)
  const [guard, setGuard] = useState<string>()
  const {address:account}=useAccount()
  const client=usePublicClient({chainId:TARGET_CHAIN_ID})
  const lock=useRef(false)
  const active=useRef(true)
  useEffect(()=>{active.current=true;return()=>{active.current=false}},[])
  const [preparing,setPreparing]=useState(false)
  const tx = useTxFlow({
    label: receiptLabel,
    guaranteeId,
    onConfirmed: () => {
      setArmed(false)
      onConfirmed()
    },
  })

  const verdict: Verdict =
    chain.now === undefined
      ? { ok: false, reason: chain.failed ? 'Chain time is unavailable, so time-limited actions are disabled.' : 'Reading chain time...' }
      : eligible(chain.now)
  const isArmed = armed && verdict.ok

  const click = () => {
    if(lock.current || tx.busy)return
    if (warning && !isArmed) {
      setGuard(undefined)
      setArmed(true)
      return
    }
    if(!client || !account)return
    lock.current=true
    setPreparing(true)
    void (async () => {
      setGuard(undefined)
      try {
        const fresh = await freshNow()
        const recheck = eligible(fresh)
        if (!recheck.ok) {
          setGuard(recheck.reason)
          setArmed(false)
          return
        }
      } catch {
        setGuard('Could not read the latest block time, so nothing was sent. Try again.')
        return
      }
      const preparations:Promise<void>[]=[]
      const checkedWrite:TxWriter=(parameters)=>{
        preparations.push((async()=>{
          try{
            const request={...parameters,account}
            // Concrete ABI/function/args originate in this action's existing send callback.
            const gas=await checkedEvidenceGas(
              ()=>client.simulateContract(request as never),
              ()=>client.estimateContractGas(request as never),
              async()=>active.current?eligible(await freshNow()):{ok:false,reason:'Action closed. Nothing sent.'},
            )
            if(active.current)tx.writeContract({...parameters,account,gas} as never)
          }catch(error){if(active.current)setGuard(`Preparation stopped before a wallet request. ${describeError(error).text}`)}
        })())
      }
      send(checkedWrite)
      await Promise.all(preparations)
    })().finally(()=>{lock.current=false;if(active.current)setPreparing(false)})
  }

  const busyLabel = tx.phase === 'wallet' ? 'Confirm in your wallet...' : workingLabel

  return (
    <section aria-labelledby={headingId}>
      <span className="mc-role-tag">{role}</span>
      <h3 className="mc-h3" id={headingId}>
        {title}
      </h3>
      <p className="mc-p">{description}</p>
      <div className="mc-mt-3">
        {!verdict.ok ? (
          <>
            <p className="mc-p mc-muted">{verdict.reason}</p>
            {chain.failed && chain.now === undefined && (
              <button type="button" className={`${ghostButton} mc-mt-2`} onClick={chain.refetch}>
                Retry reading chain time
              </button>
            )}
          </>
        ) : (
          <ChainGate>
            {preview}
            {isArmed && warning && <Callout tone="warn">{warning}</Callout>}
            <div className={isArmed ? 'mc-btn-row mc-mt-3' : 'mc-mt-3'}>
              {isArmed && (
                <button type="button" className={ghostButton} disabled={tx.busy || preparing} onClick={() => setArmed(false)}>
                  Cancel
                </button>
              )}
              <button type="button" className={isArmed ? dangerButton : primaryButton} disabled={tx.busy || preparing} onClick={click}>
                {preparing ? 'Checking transaction...' : tx.busy ? busyLabel : isArmed ? `Confirm: ${label}` : label}
              </button>
            </div>
          </ChainGate>
        )}
        {guard && (
          <p className="mc-bad mc-mt-2" role="alert">
            {guard}
          </p>
        )}
        <TxStatus tx={tx} successText={successText} />
      </div>
    </section>
  )
}
