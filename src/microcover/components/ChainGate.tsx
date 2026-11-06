import type { ReactNode } from 'react'
import { ConnectKitButton } from 'connectkit'
import { useAccount, useSwitchChain } from 'wagmi'
import { TARGET_CHAIN, TARGET_CHAIN_ID } from '../contract'

export const primaryButton =
  'min-h-11 w-full rounded-2xl bg-[var(--accent)] px-4 text-sm font-semibold text-white transition hover:bg-[var(--accent-hover)] disabled:cursor-not-allowed disabled:opacity-50'

export const ghostButton =
  'min-h-11 w-full rounded-2xl border border-[var(--border)] bg-[var(--surface-strong)] px-4 text-sm font-semibold text-[var(--ink)] transition hover:bg-[var(--surface-muted)] disabled:cursor-not-allowed disabled:opacity-50'

/** Renders its children only for a connected wallet on Arc Testnet; otherwise the right prompt. */
export function ChainGate({ children }: { children: ReactNode }) {
  const { isConnected, chainId } = useAccount()
  const { switchChain, isPending } = useSwitchChain()

  if (!isConnected) {
    return (
      <div className="flex flex-col gap-2">
        <p className="text-sm text-[var(--muted)]">Connect a wallet to continue.</p>
        <ConnectKitButton label="Connect wallet" />
      </div>
    )
  }
  if (chainId !== TARGET_CHAIN_ID) {
    return (
      <div className="flex flex-col gap-2">
        <p className="text-sm text-[var(--muted)]">This app only works on {TARGET_CHAIN.name}.</p>
        <button type="button" className={primaryButton} disabled={isPending} onClick={() => switchChain({ chainId: TARGET_CHAIN_ID })}>
          {isPending ? 'Confirm in wallet...' : `Switch to ${TARGET_CHAIN.name}`}
        </button>
      </div>
    )
  }
  return <>{children}</>
}
