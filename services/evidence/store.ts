import { Database } from 'bun:sqlite'
import { existsSync, mkdirSync, realpathSync } from 'node:fs'
import { resolve, dirname, relative, isAbsolute, sep, join } from 'node:path'
import { authenticate, canonical, hash, validateActivation, ZERO, type Activation, type Envelope, type Receipt, type SourceId, type Hex } from './model'

export function privateDirectory(input: string, workspace = process.cwd()): string {
  // Resolve existing ancestors before mkdir to reject symlinks into the checkout as well.
  const absolute = resolve(input)
  let ancestor = absolute
  const tail: string[] = []
  for (;;) {
    try { ancestor = realpathSync(ancestor); break } catch {
      const parent = dirname(ancestor)
      if (parent === ancestor) throw Error('INVALID_PRIVATE_PATH')
      tail.unshift(relative(parent, ancestor)); ancestor = parent
    }
  }
  const actual = resolve(ancestor, ...tail)
  const rel = relative(realpathSync(workspace), actual)
  if (!rel || (!isAbsolute(rel) && rel !== '..' && !rel.startsWith(`..${sep}`))) throw Error('PRIVATE_STORE_MUST_BE_OUTSIDE_CHECKOUT')
  for (let parent=actual;;parent=dirname(parent)) {
    if(existsSync(join(parent,'.git')))throw Error('PRIVATE_STORE_MUST_BE_OUTSIDE_CHECKOUT')
    if(dirname(parent)===parent)break
  }
  mkdirSync(actual, { recursive: true, mode: 0o700 })
  return realpathSync(actual)
}

/** Append-only application API; SQLite atomically commits private envelope and receipt/cursor. */
export class EvidenceStore {
  private db: Database
  constructor(directory: string) {
    this.db = new Database(resolve(privateDirectory(directory), 'evidence.sqlite'), { create: true, strict: true })
    this.db.exec(`PRAGMA journal_mode=WAL; PRAGMA synchronous=FULL; PRAGMA busy_timeout=5000;
      CREATE TABLE IF NOT EXISTS activation (domain TEXT PRIMARY KEY, body TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS entries (domain TEXT NOT NULL, seq INTEGER NOT NULL, attempt TEXT NOT NULL,
        receipt TEXT NOT NULL, envelope TEXT, PRIMARY KEY(domain,seq), UNIQUE(domain,attempt));
      CREATE TABLE IF NOT EXISTS nonces (domain TEXT NOT NULL, source TEXT NOT NULL, nonce TEXT NOT NULL, PRIMARY KEY(domain,source));`)
    this.db.exec('CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)')
  }
  setting(key:string):string|undefined { return this.db.query<{value:string},[string]>('SELECT value FROM settings WHERE key=?').get(key)?.value }
  settingsWithPrefix(prefix:string):string[] {
    return this.db.query<{value:string},[string]>('SELECT value FROM settings WHERE substr(key,1,length(?1))=?1 ORDER BY key').all(prefix).map(r=>r.value)
  }
  setSetting(key:string,value:string):void { this.db.query('INSERT INTO settings VALUES (?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value').run(key,value) }
  close() { this.db.close() }
  activate(a: Activation): Hex {
    validateActivation(a)
    const key = hash(a.domain)
    this.db.transaction(() => {
      const existing = this.db.query<{ body: string }, [string]>('SELECT body FROM activation WHERE domain=?').get(key)
      if (existing && existing.body !== canonical(a)) throw Error('ACTIVATION_FROZEN')
      this.db.query('INSERT OR IGNORE INTO activation VALUES (?,?)').run(key, canonical(a))
    }).immediate()
    return key
  }
  activation(key: string): Activation {
    const row = this.db.query<{ body: string }, [string]>('SELECT body FROM activation WHERE domain=?').get(key)
    if (!row) throw Error('UNKNOWN_ACTIVATION')
    const a = JSON.parse(row.body) as Activation
    validateActivation(a)
    if (hash(a.domain) !== key) throw Error('ACTIVATION_TAMPERED')
    return a
  }
  activations(): Activation[] {
    return this.db.query<{ domain: string }, []>('SELECT domain FROM activation ORDER BY domain').all().map(r => this.activation(r.domain))
  }
  hasAttempt(key: string, attempt: string): boolean {
    return Boolean(this.db.query('SELECT 1 FROM entries WHERE domain=? AND attempt=?').get(key, attempt))
  }
  append(key: Hex, sourceId: SourceId, slot: number, receivedAt: number, input: unknown, unavailable = false): Receipt {
    const a = this.activation(key)
    const source = a.policy.sources.find(s => s.id === sourceId)
    if (!source || !Number.isSafeInteger(slot) || slot < 0 || !Number.isSafeInteger(receivedAt) || receivedAt < a.activatedAt) throw Error('INVALID_ATTEMPT')
    const attemptKey = `${sourceId}:${slot}`
    return this.db.transaction(() => {
      const priorAttempt = this.db.query<{ receipt: string }, [string,string]>('SELECT receipt FROM entries WHERE domain=? AND attempt=?').get(key, attemptKey)
      if (priorAttempt) return JSON.parse(priorAttempt.receipt) as Receipt
      const all = this.verified(key)
      const previous = all.at(-1)
      if (previous && receivedAt < previous.receivedAt) throw Error('RECEIPT_CLOCK_REGRESSION')
      let envelope: Envelope | undefined
      let error: string | null = unavailable ? 'FEED_UNAVAILABLE' : null
      if (!unavailable) {
        try {
          envelope = authenticate(input, a, sourceId, receivedAt)
          // The verified append log is authoritative even if a cached cursor is lost.
          const previousNonce = [...all].reverse().find(r => r.sourceId === sourceId && r.kind === 'OBSERVATION')?.nonce
          if (previousNonce !== undefined && previousNonce !== null && BigInt(envelope.payload.nonce) <= BigInt(previousNonce)) throw Error('REPLAYED_NONCE')
        } catch (e) {
          // Stable error codes only; never expose exception contents, payloads or credentials.
          error = e instanceof Error && /^[A-Z_]+$/.test(e.message) ? e.message : 'INVALID_ENVELOPE'
          envelope = undefined
        }
      }
      const base = {
        domainKey: key, sequence: all.length + 1, previousHash: previous?.hash ?? ZERO, attemptKey,
        sourceId, group: source.group, receivedAt, sourceTimestamp: envelope?.payload.sourceTimestamp ?? null,
        nonce: envelope?.payload.nonce ?? null, kind: unavailable ? 'UNAVAILABLE' as const : envelope ? 'OBSERVATION' as const : 'INVALID' as const,
        status: envelope?.payload.status ?? null, payloadHash: envelope ? hash(envelope.payload) : null,
        signature: envelope?.signature ?? null, keyFingerprint: hash(source.publicKeyDer), error,
      }
      const receipt: Receipt = { ...base, hash: hash(base) }
      this.db.query('INSERT INTO entries VALUES (?,?,?,?,?)').run(key, receipt.sequence, attemptKey, canonical(receipt), envelope ? canonical(envelope) : null)
      if (envelope) this.db.query('INSERT INTO nonces VALUES (?,?,?) ON CONFLICT(domain,source) DO UPDATE SET nonce=excluded.nonce').run(key,sourceId,envelope.payload.nonce)
      return receipt
    }).immediate()
  }
  /** Recompute every link and reauthenticate private payloads before exposing a root/verdict. */
  verified(key: string): Receipt[] {
    const a = this.activation(key)
    const rows = this.db.query<{ seq:number; attempt:string; receipt:string; envelope:string|null }, [string]>('SELECT seq,attempt,receipt,envelope FROM entries WHERE domain=? ORDER BY seq').all(key)
    const result: Receipt[] = []
    const nonces = new Map<string,bigint>()
    for (const row of rows) {
      const r = JSON.parse(row.receipt) as Receipt
      const { hash: recorded, ...body } = r
      const source = a.policy.sources.find(s => s.id === r.sourceId)
      if (!source || hash(body) !== recorded || r.sequence !== result.length+1 || row.seq !== r.sequence ||
          row.attempt !== r.attemptKey || r.domainKey !== key || r.previousHash !== (result.at(-1)?.hash ?? ZERO) ||
          r.group !== source.group || r.keyFingerprint !== hash(source.publicKeyDer) ||
          (result.length > 0 && r.receivedAt < result.at(-1)!.receivedAt)) throw Error('LOG_TAMPERED')
      if (r.kind === 'OBSERVATION') {
        if (!row.envelope) throw Error('PAYLOAD_MISSING')
        const e = authenticate(JSON.parse(row.envelope),a,r.sourceId,r.receivedAt)
        if (hash(e.payload) !== r.payloadHash || e.signature !== r.signature || e.payload.nonce !== r.nonce ||
            e.payload.status !== r.status || e.payload.sourceTimestamp !== r.sourceTimestamp) throw Error('PAYLOAD_TAMPERED')
        if (nonces.has(r.sourceId) && BigInt(e.payload.nonce) <= nonces.get(r.sourceId)!) throw Error('LOG_REPLAY')
        nonces.set(r.sourceId,BigInt(e.payload.nonce))
      } else if (r.kind !== 'INVALID' && r.kind !== 'UNAVAILABLE') throw Error('INVALID_RECEIPT_KIND')
      result.push(r)
    }
    return result
  }
}
