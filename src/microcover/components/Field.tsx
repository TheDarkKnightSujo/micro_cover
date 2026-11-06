import type { ReactNode } from 'react'

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
  const describedBy = error ? `${id}-error` : hint ? `${id}-hint` : undefined
  return (
    <div>
      <label className="mc-label" htmlFor={id}>
        {label}
      </label>
      <div className="mc-input-wrap">
        <input
          id={id}
          className="mc-input"
          inputMode="decimal"
          autoComplete="off"
          value={value}
          disabled={disabled}
          onChange={(e) => onChange(e.target.value.trim())}
          aria-invalid={Boolean(error)}
          aria-describedby={describedBy}
        />
        {suffix && <span className="mc-input-suffix">{suffix}</span>}
      </div>
      {error ? (
        <p className="mc-error" id={`${id}-error`}>
          {error}
        </p>
      ) : (
        hint && (
          <p className="mc-hint" id={`${id}-hint`}>
            {hint}
          </p>
        )
      )}
    </div>
  )
}
