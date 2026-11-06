import { useState, type ReactNode } from 'react'
import { Check, Copy, ExternalLink } from 'lucide-react'
import { addressUrl } from '../contract'

export function Card({ title, aside, children }: { title: string; aside?: ReactNode; children: ReactNode }) {
  return (
    <section className="mc-card" aria-label={title}>
      <div className="mc-card-head">
        <h2 className="mc-h2">{title}</h2>
        {aside}
      </div>
      {children}
    </section>
  )
}

/** One label/value pair. Stacks on narrow containers; values wrap and are never truncated. */
export function Row({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="mc-row">
      <dt>{label}</dt>
      <dd>{children}</dd>
    </div>
  )
}

export function Dl({ children }: { children: ReactNode }) {
  return <dl className="mc-dl">{children}</dl>
}

export function Badge({ children, tone = 'neutral' }: { children: ReactNode; tone?: 'neutral' | 'ok' | 'warn' | 'danger' }) {
  const toneClass = tone === 'neutral' ? '' : ` mc-badge-${tone}`
  return <span className={`mc-badge${toneClass}`}>{children}</span>
}

export function Callout({ children, tone = 'info' }: { children: ReactNode; tone?: 'info' | 'warn' | 'danger' | 'ok' }) {
  const toneClass = tone === 'info' ? '' : ` mc-callout-${tone}`
  return <p className={`mc-callout${toneClass}`}>{children}</p>
}

/** Copy-to-clipboard chip with a visible confirmation. */
export function CopyButton({ value, label }: { value: string; label: string }) {
  const [copied, setCopied] = useState(false)
  const copy = () => {
    navigator.clipboard
      .writeText(value)
      .then(() => {
        setCopied(true)
        setTimeout(() => setCopied(false), 1500)
      })
      .catch(() => setCopied(false))
  }
  return (
    <button type="button" className="mc-chip-btn" onClick={copy} aria-label={`Copy ${label}`}>
      {copied ? <Check size={13} aria-hidden /> : <Copy size={13} aria-hidden />}
      {copied ? 'Copied' : 'Copy'}
    </button>
  )
}

/** Full, wrapping address with copy and explorer affordances. Never shortened. */
export function AddressValue({ address, label }: { address: string; label: string }) {
  return (
    <span className="mc-addr">
      <span className="mc-mono mc-addr-text">{address}</span>
      <span className="mc-addr-actions">
        <CopyButton value={address} label={label} />
        <a className="mc-link" href={addressUrl(address)} target="_blank" rel="noopener noreferrer">
          Explorer <ExternalLink size={12} aria-hidden style={{ verticalAlign: '-1px' }} />
          <span className="mc-sr-only"> (opens in a new tab)</span>
        </a>
      </span>
    </span>
  )
}
