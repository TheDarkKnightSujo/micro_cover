import type { ReactNode } from 'react'

const inputClass =
  'mt-1.5 min-h-11 w-full rounded-2xl border border-[var(--border)] bg-[var(--surface-strong)] px-4 text-base tabular-nums text-[var(--ink)] outline-none focus:border-[var(--focus)] focus:ring-2 focus:ring-[var(--focus)]/40 disabled:opacity-60'

interface Props {
  id: string
  label: string
  value: string
  onChange: (value: string) => void
  hint?: ReactNode
  error?: string
  disabled?: boolean
  suffix?: string
}

export function Field({ id, label, value, onChange, hint, error, disabled, suffix }: Props) {
  return (
    <div>
      <label className="block text-xs font-semibold uppercase tracking-[0.08em] text-[var(--muted)]" htmlFor={id}>
        {label}
      </label>
      <div className="relative">
        <input
          id={id}
          inputMode="decimal"
          autoComplete="off"
          value={value}
          disabled={disabled}
          onChange={(e) => onChange(e.target.value.trim())}
          aria-invalid={Boolean(error)}
          className={inputClass}
        />
        {suffix && (
          <span className="pointer-events-none absolute right-4 top-1/2 mt-[3px] -translate-y-1/2 text-sm text-[var(--muted)]">
            {suffix}
          </span>
        )}
      </div>
      {error ? (
        <p className="mt-1 text-xs text-[var(--danger)]">{error}</p>
      ) : (
        hint && <p className="mt-1 text-xs text-[var(--subtle)]">{hint}</p>
      )}
    </div>
  )
}
