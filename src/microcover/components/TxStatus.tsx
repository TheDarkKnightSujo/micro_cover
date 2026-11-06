import { ExternalLink, Loader2 } from 'lucide-react'
import { buildTxExplorerUrl } from '@/onchain-facts'
import { TARGET_CHAIN_ID } from '../contract'
import type { TxPhase } from '../useTxFlow'

interface Props {
  phase: TxPhase
  hash: string | undefined
  message: string | undefined
  successText: string
}

/** Inline status for one write: wallet prompt, confirming, confirmed (with explorer link) or error. */
export function TxStatus({ phase, hash, message, successText }: Props) {
  if (phase === 'idle' && !message) return null
  return (
    <div className="mt-3 text-sm" role="status" aria-live="polite">
      {phase === 'wallet' && (
        <p className="flex items-center gap-2 text-[var(--muted)]">
          <Loader2 size={14} className="animate-spin" aria-hidden /> Confirm in your wallet...
        </p>
      )}
      {phase === 'confirming' && (
        <p className="flex items-center gap-2 text-[var(--muted)]">
          <Loader2 size={14} className="animate-spin" aria-hidden /> Waiting for confirmation...
        </p>
      )}
      {phase === 'success' && <p className="text-[var(--success)]">{successText}</p>}
      {message && <p className="text-[var(--danger)]">{message}</p>}
      {hash && (phase === 'success' || phase === 'error') && (
        <a
          href={buildTxExplorerUrl(TARGET_CHAIN_ID, hash)}
          target="_blank"
          rel="noopener noreferrer"
          className="mt-1 inline-flex items-center gap-1 text-[13px] text-[var(--accent-hover)] hover:underline"
        >
          View transaction <ExternalLink size={12} aria-hidden />
        </a>
      )}
    </div>
  )
}
