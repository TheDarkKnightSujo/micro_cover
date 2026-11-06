import { useAccount, useSwitchChain } from 'wagmi'
import { AddressValue, Card, Dl, Row } from './Card'
import { primaryButton } from './ChainGate'
import { MICROCOVER_ADDRESS, TARGET_CHAIN, TARGET_CHAIN_ID, USDC_ADDRESS } from '../contract'

export function NetworkCard() {
  const { isConnected, chainId } = useAccount()
  const { switchChain, isPending } = useSwitchChain()
  const wrongChain = isConnected && chainId !== TARGET_CHAIN_ID

  return (
    <Card title="Network">
      <Dl>
        <Row label="Chain">
          {TARGET_CHAIN.name} (chain id {TARGET_CHAIN_ID})
        </Row>
        <Row label="USDC (official)">
          <AddressValue address={USDC_ADDRESS} label="USDC address" />
        </Row>
        <Row label="MicroCover contract">
          {MICROCOVER_ADDRESS ? <AddressValue address={MICROCOVER_ADDRESS} label="contract address" /> : <span className="mc-muted">Not configured</span>}
        </Row>
      </Dl>
      {wrongChain && (
        <div className="mc-mt-3">
          <p className="mc-p">Your wallet is on another network. Switch to {TARGET_CHAIN.name} to continue.</p>
          <button type="button" className={`${primaryButton} mc-mt-2`} onClick={() => switchChain({ chainId: TARGET_CHAIN_ID })} disabled={isPending}>
            {isPending ? 'Confirm the switch in your wallet...' : `Switch to ${TARGET_CHAIN.name}`}
          </button>
        </div>
      )}
    </Card>
  )
}
