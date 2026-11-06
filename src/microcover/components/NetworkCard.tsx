import { ExternalLink } from 'lucide-react'
import { useAccount, useSwitchChain } from 'wagmi'
import { Card, Row } from './Card'
import { MICROCOVER_ADDRESS, TARGET_CHAIN, TARGET_CHAIN_ID, USDC_ADDRESS, addressUrl } from '../contract'

const short = (address: string) => `${address.slice(0, 6)}...${address.slice(-4)}`

function AddressLink({ address }: { address: string }) {
  return (
    <a
      href={addressUrl(address)}
      target="_blank"
      rel="noopener noreferrer"
      className="mono inline-flex items-center gap-1 text-[13px] text-[var(--accent-hover)] hover:underline"
    >
      {short(address)} <ExternalLink size={12} aria-hidden />
    </a>
  )
}

export function NetworkCard() {
  const { isConnected, chainId } = useAccount()
  const { switchChain, isPending } = useSwitchChain()
  const wrongChain = isConnected && chainId !== TARGET_CHAIN_ID

  return (
    <Card title="Network">
      <dl>
        <Row label="Chain">
          {TARGET_CHAIN.name} ({TARGET_CHAIN_ID})
        </Row>
        <Row label="USDC (official)">
          <AddressLink address={USDC_ADDRESS} />
        </Row>
        <Row label="MicroCover">
          {MICROCOVER_ADDRESS ? (
            <AddressLink address={MICROCOVER_ADDRESS} />
          ) : (
            <span className="text-[var(--subtle)]">Not deployed yet</span>
          )}
        </Row>
      </dl>

      {wrongChain && (
        <button
          type="button"
          onClick={() => switchChain({ chainId: TARGET_CHAIN_ID })}
          disabled={isPending}
          className="mt-4 min-h-11 w-full rounded-2xl bg-[var(--accent)] px-4 text-sm font-semibold text-white transition hover:bg-[var(--accent-hover)] disabled:opacity-60"
        >
          {isPending ? 'Confirm in wallet...' : `Switch to ${TARGET_CHAIN.name}`}
        </button>
      )}
    </Card>
  )
}
