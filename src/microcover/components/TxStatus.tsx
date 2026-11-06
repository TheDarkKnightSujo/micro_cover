import { ExternalLink, Loader2 } from 'lucide-react'
import { buildTxExplorerUrl } from '@/onchain-facts'
import { TARGET_CHAIN_ID } from '../contract'
import type { TxFlow } from '../useTxFlow'

interface Props {
  tx: TxFlow
  successText: string
}

/**
 * Inline status for one write. "Confirmed" text appears ONLY after a mined, successful receipt.
 * Wallet rejection is shown as a note (not success, not stuck); a receipt-read failure is shown
 * as unknown with a retry.
 */
export function TxStatus({ tx, successText }: Props) {
  const { phase, hash, message } = tx
  return (
    <div className="mc-status" role="status" aria-live="polite">
      {phase === 'wallet' && (
        <p className="mc-muted">
          <Loader2 size={14} className="mc-spin" aria-hidden style={{ verticalAlign: '-2px' }} /> Waiting for you to confirm in your wallet...
        </p>
      )}
      {phase === 'confirming' && (
        <p className="mc-muted">
          <Loader2 size={14} className="mc-spin" aria-hidden style={{ verticalAlign: '-2px' }} /> Submitted. Waiting for the transaction to be mined...
        </p>
      )}
      {phase === 'success' && <p className="mc-ok">{successText}</p>}
      {message && <p className={phase === 'idle' ? 'mc-muted' : 'mc-bad'}>{message}</p>}
      {tx.receiptUnknown && (
        <button type="button" className="mc-btn mc-btn-ghost mc-btn-inline" onClick={tx.retryReceipt}>
          Retry the confirmation check
        </button>
      )}
      {hash && (phase === 'success' || phase === 'error') && (
        <a className="mc-link" href={buildTxExplorerUrl(TARGET_CHAIN_ID, hash)} target="_blank" rel="noopener noreferrer">
          View transaction <ExternalLink size={12} aria-hidden style={{ verticalAlign: '-1px' }} />
          <span className="mc-sr-only"> (opens in a new tab)</span>
        </a>
      )}
    </div>
  )
}
