import { Loader2 } from 'lucide-react'
import { fmtDuration } from '../format'
import { MICROCOVER_ADDRESS } from '../contract'
import type { Capability } from '../useCapability'
import { AddressValue, Badge, Callout, Card, Dl, Row } from './Card'
import { ghostButton } from './ChainGate'

/**
 * Deployment capability gate. Until this reads "ready" nothing can be approved, created,
 * enrolled or sent. The app never changes the configured address and never deploys anything.
 */
export function DeploymentCard({ cap }: { cap: Capability }) {
  const contract = MICROCOVER_ADDRESS
  return (
    <Card
      title="Deployment and authority"
      aside={
        cap.state === 'ready' ? (
          <Badge tone="ok">Phase 3 contract detected</Badge>
        ) : cap.state === 'none' ? (
          <Badge>Preview only</Badge>
        ) : cap.state === 'unsupported' ? (
          <Badge tone="danger">Unsupported</Badge>
        ) : cap.state === 'unavailable' ? (
          <Badge tone="warn">Unavailable</Badge>
        ) : (
          <Badge>Checking</Badge>
        )
      }
    >
      {cap.state === 'none' && (
        <Callout>
          <strong>Preview only.</strong> No MicroCover contract is configured for this app, so nothing can be created, approved or sent. You can still edit the amounts below to preview a guarantee.
        </Callout>
      )}

      {cap.state === 'checking' && (
        <p className="mc-p mc-muted" role="status">
          <Loader2 size={14} className="mc-spin" aria-hidden style={{ verticalAlign: '-2px' }} /> Checking the configured contract on Arc Testnet...
        </p>
      )}

      {cap.state === 'unavailable' && (
        <div className="mc-actions" role="alert">
          <Callout tone="warn">
            <strong>Could not reach Arc Testnet to check the deployment.</strong> This is a network problem, not a verdict on the contract. All actions stay disabled until the check succeeds.
          </Callout>
          <button type="button" className={ghostButton} onClick={cap.retry}>
            Retry the check
          </button>
        </div>
      )}

      {cap.state === 'unsupported' && contract && (
        <div className="mc-actions" role="alert">
          <Callout tone="danger">
            <strong>Phase 3 deployment required.</strong> {cap.reason} The contract this app is pointed at cannot be upgraded, so approvals, creating guarantees, enrolling and every other action are disabled. The app does not change the address by itself. The verified Phase 2 deployment remains unchanged.
          </Callout>
          <Dl>
            <Row label="Configured contract">
              <AddressValue address={contract} label="configured contract address" />
            </Row>
          </Dl>
          <button type="button" className={ghostButton} onClick={cap.retry}>
            Check again
          </button>
        </div>
      )}

      {cap.state === 'ready' && contract && (
        <>
          <Callout tone="warn">
            <strong>Restricted demo authority.</strong> The fixed demo operator anchors evidence and submits a trusted verdict, including evidence failure without provider cooperation. Success gets a full review. It can explicitly mark uncertainty but cannot change payout recipients, amounts or frozen durations. Both authenticated demo feeds are controlled by us; this is not decentralized evidence or a deployed CRE workflow. Provider admission remains a separate path.
          </Callout>
          <Dl>
            <Row label="MicroCover contract">
              <AddressValue address={contract} label="contract address" />
            </Row>
            <Row label="Demo operator (immutable)">
              <AddressValue address={cap.operator} label="demo operator address" />
            </Row>
            <Row label="Review duration (immutable)">
              {fmtDuration(cap.reviewWindow)} ({cap.reviewWindow.toString()} s). A short synthetic test value, not a production safety claim.
            </Row>
            <Row label="Uncertainty timeout (separate immutable)">{fmtDuration(cap.uncertaintyTimeout)} from first onchain uncertainty, never reset. Escrow-only refunds if still unresolved.</Row>
            <Row label="Protocol version">3</Row>
          </Dl>
        </>
      )}
    </Card>
  )
}
