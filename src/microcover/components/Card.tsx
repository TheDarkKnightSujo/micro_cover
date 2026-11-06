import type { ReactNode } from 'react'

export function Card({ title, aside, children }: { title: string; aside?: ReactNode; children: ReactNode }) {
  return (
    <section className="rounded-3xl border border-[var(--border)] bg-[var(--surface)] p-5 shadow-[0_8px_30px_rgba(18,45,69,0.06)] backdrop-blur-xl sm:p-6">
      <div className="mb-4 flex items-center justify-between gap-3">
        <h2 className="text-xs font-semibold uppercase tracking-[0.08em] text-[var(--muted)]">{title}</h2>
        {aside}
      </div>
      {children}
    </section>
  )
}

export function Row({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="flex items-baseline justify-between gap-4 border-t border-[var(--border)] py-3 first:border-t-0 first:pt-0 last:pb-0">
      <dt className="text-sm text-[var(--muted)]">{label}</dt>
      <dd className="min-w-0 truncate text-right text-sm font-medium tabular-nums text-[var(--ink)]">{children}</dd>
    </div>
  )
}
