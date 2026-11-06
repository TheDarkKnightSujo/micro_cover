import { createContext, useCallback, useContext, useMemo, useState, type ReactNode } from 'react'

export interface SessionReceipt {
  label: string
  hash: string
  guaranteeId: bigint | undefined
}

interface ReceiptLog {
  entries: readonly SessionReceipt[]
  add: (entry: SessionReceipt) => void
}

const ReceiptContext = createContext<ReceiptLog>({ entries: [], add: () => undefined })

/**
 * Keeps ONLY transactions this browser tab saw confirmed with a successful receipt. It is not
 * an indexer: it is empty after a reload and never contains events this tab did not observe.
 */
export function ReceiptLogProvider({ children }: { children: ReactNode }) {
  const [entries, setEntries] = useState<readonly SessionReceipt[]>([])
  const add = useCallback((entry: SessionReceipt) => {
    setEntries((current) => (current.some((e) => e.hash === entry.hash) ? current : [entry, ...current].slice(0, 20)))
  }, [])
  const value = useMemo(() => ({ entries, add }), [entries, add])
  return <ReceiptContext.Provider value={value}>{children}</ReceiptContext.Provider>
}

export function useReceiptLog(): ReceiptLog {
  return useContext(ReceiptContext)
}
