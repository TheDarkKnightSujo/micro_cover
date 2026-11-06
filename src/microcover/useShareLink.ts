import { useEffect, useState } from 'react'
import { buildShareLink } from '@/lib/share'

/**
 * Share link for a guarantee id (`/?guarantee=<id>`). The id is public chain data, never a secret.
 * Resolved once per id via the Studio-aware helper; undefined while resolving.
 */
export function useShareLink(id: bigint | undefined): string | undefined {
  const [resolved, setResolved] = useState<{ id: bigint; link: string }>()
  useEffect(() => {
    if (id === undefined) return
    let cancelled = false
    buildShareLink(`/?guarantee=${id.toString()}`)
      .then((link) => {
        if (!cancelled) setResolved({ id, link })
      })
      .catch(() => undefined)
    return () => {
      cancelled = true
    }
  }, [id])
  return id !== undefined && resolved?.id === id ? resolved.link : undefined
}
