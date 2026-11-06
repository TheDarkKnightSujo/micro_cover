/** Formatting helpers for chain timestamps and durations. All times shown are CHAIN time. */

const timeFormat = new Intl.DateTimeFormat(undefined, {
  year: 'numeric',
  month: 'short',
  day: 'numeric',
  hour: 'numeric',
  minute: '2-digit',
  second: '2-digit',
  timeZoneName: 'short',
})

/** Local-timezone rendering of a unix-seconds chain timestamp, with the timezone name. */
export function fmtTime(seconds: bigint): string {
  if (seconds === 0n) return 'Not set'
  return timeFormat.format(new Date(Number(seconds) * 1000))
}

/** "2 h 5 min", "45 s", "0 s". */
export function fmtDuration(totalSeconds: bigint): string {
  if (totalSeconds <= 0n) return '0 s'
  const s = Number(totalSeconds)
  const d = Math.floor(s / 86400)
  const h = Math.floor((s % 86400) / 3600)
  const m = Math.floor((s % 3600) / 60)
  const sec = s % 60
  const parts: string[] = []
  if (d) parts.push(`${d} d`)
  if (h) parts.push(`${h} h`)
  if (m) parts.push(`${m} min`)
  if (sec && !d && !h) parts.push(`${sec} s`)
  return parts.join(' ')
}

/** Relative position of a target time versus chain now. */
export function relativeTo(now: bigint | undefined, target: bigint): string {
  if (now === undefined || target === 0n) return ''
  if (target > now) return `in ${fmtDuration(target - now)}`
  if (target === now) return 'now'
  return `${fmtDuration(now - target)} ago`
}
