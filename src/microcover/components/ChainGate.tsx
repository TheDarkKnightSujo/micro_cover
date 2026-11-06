import type { ReactNode } from 'react'
import { ConnectKitButton } from 'connectkit'
import { useAccount, useSwitchChain } from 'wagmi'
import { TARGET_CHAIN, TARGET_CHAIN_ID } from '../contract'

export const primaryButton = 'mc-btn mc-btn-primary'
export const ghostButton = 'mc-btn mc-btn-ghost'
export const dangerButton = 'mc-btn mc-btn-danger'

/** Renders its children only for a connected wallet on Arc Testnet; otherwise the right prompt. */
export function ChainGate({ children }: { children: ReactNode }) {
  const { isConnected, chainId } = useAccount()
  const { switchChain, isPending, error } = useSwitchChain()

  if (!isConnected) {
    return (
      <div className="mc-actions">
        <p className="mc-p">Connect a wallet to continue.</p>
        <ConnectKitButton label="Connect wallet" />
      </div>
    )
  }
  if (chainId !== TARGET_CHAIN_ID) {
    return (
      <div className="mc-actions">
        <p className="mc-p">This app only works on {TARGET_CHAIN.name}. Your wallet is on a different network, so nothing can be sent yet.</p>
        <button type="button" className={primaryButton} disabled={isPending} onClick={() => switchChain({ chainId: TARGET_CHAIN_ID })}>
          {isPending ? 'Confirm the switch in your wallet...' : `Switch to ${TARGET_CHAIN.name}`}
        </button>
        {error && <p className="mc-error">The network switch did not complete. Try again, or switch networks in your wallet.</p>}
      </div>
    )
  }
  return <>{children}</>
}
