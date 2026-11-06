import { hash, SOURCE_IDS, type Activation, type SourceId } from './model'
import { EvidenceStore } from './store'

export type FeedTransport = (source: SourceId, activation: Activation, slot: number) => Promise<unknown>
export class Collector {
  private busy = false
  constructor(private store: EvidenceStore, private transport: FeedTransport, private clock = () => Math.floor(Date.now()/1000)) {}
  async tick(): Promise<void> {
    if (this.busy) return
    this.busy = true
    try {
      for (const a of this.store.activations()) {
        const now = this.clock()
        if (now < a.activatedAt || now > a.outcomeDeadline) continue
        const slot = Math.floor((now-a.activatedAt)/a.policy.intervalSeconds)
        const key = hash(a.domain)
        for (const source of SOURCE_IDS) {
          if (this.store.hasAttempt(key,`${source}:${slot}`)) continue
          let payload: unknown
          let unavailable = false
          try { payload = await this.transport(source,a,slot) } catch { unavailable = true }
          this.store.append(key,source,slot,this.clock(),payload,unavailable)
        }
      }
    } finally { this.busy = false }
  }
}
