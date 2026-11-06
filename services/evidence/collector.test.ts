import { afterEach, expect, test } from 'bun:test'
import { mkdtempSync, symlinkSync } from 'node:fs'
import { testTempRoot } from './test-support'
import { join } from 'node:path'
import { Database } from 'bun:sqlite'
import { ChainObserver } from './chain'
import { Collector } from './collector'
import { EvidenceStore, privateDirectory } from './store'
import { canonical, hash } from './model'
import { testActivation, removeTestDirectory } from './test-support'

const dirs:string[]=[]
const stores:EvidenceStore[]=[]
afterEach(()=>{ for(const s of stores.splice(0)) s.close(); for(const d of dirs.splice(0)) removeTestDirectory(d) })
function setup() {
  const dir=mkdtempSync(join(testTempRoot(),'microcover-evidence-test-')); dirs.push(dir)
  const store=new EvidenceStore(dir);stores.push(store)
  const fixture=testActivation();const key=store.activate(fixture.a)
  return {dir,store,key,...fixture}
}
test('canonical encoding rejects ambiguous values and sorts nested keys',()=>{
  expect(canonical({z:[{b:2,a:1}],a:true})).toBe('{"a":true,"z":[{"a":1,"b":2}]}')
  for(const v of [NaN,Infinity,1.5,-0,undefined,new Date(),Array(1),JSON.parse('{"__proto__":1}')]) expect(()=>canonical(v)).toThrow()
})
test('private storage rejects checkout, child and symlink destinations',()=>{
  expect(()=>privateDirectory(process.cwd())).toThrow('OUTSIDE_CHECKOUT')
  expect(()=>privateDirectory(join(process.cwd(),'..private-evidence'))).toThrow('OUTSIDE_CHECKOUT')
  const dir=mkdtempSync(join(testTempRoot(),'microcover-path-test-'));dirs.push(dir)
  const linked=join(dir,'link');symlinkSync(process.cwd(),linked,'junction')
  expect(()=>privateDirectory(join(linked,'payloads'))).toThrow('OUTSIDE_CHECKOUT')
})
test('activation is frozen; source keys and domains cannot silently change',()=>{
  const {store,key,a}=setup()
  expect(store.activate(a)).toBe(key)
  expect(()=>store.activate({...a,outcomeDeadline:1200})).toThrow('FROZEN')
  expect(()=>store.activate({...a,policy:{...a.policy,freshnessSeconds:5 as 60}})).toThrow()
})
test('collector runs before claims; persistent attempt and nonce cursors survive restart',async()=>{
  const {store,dir,key,a,envelope}=setup();let now=1000;let calls=0
  const transport=async(source:Parameters<typeof envelope>[0],_a:unknown,slot:number)=>{calls++;return envelope(source,String(slot),now)}
  const c=new Collector(store,transport,()=>now)
  await c.tick();await c.tick();expect(calls).toBe(2);expect(store.verified(key)).toHaveLength(2)
  store.close();stores.splice(stores.indexOf(store),1)
  const restarted=new EvidenceStore(dir);stores.push(restarted)
  const next=new Collector(restarted,transport,()=>now);await next.tick();expect(calls).toBe(2)
  now=1010;await next.tick();expect(calls).toBe(4)
  const log=restarted.verified(key);expect(log).toHaveLength(4);expect(log[2].previousHash).toBe(log[1].hash)
  expect(restarted.activation(key)).toEqual(a)
})
test('duplicate poll is idempotent; reused source nonce becomes INVALID, never fresh evidence',()=>{
  const {store,key,envelope}=setup();const e=envelope('synthetic-status-a','1',1000)
  const first=store.append(key,'synthetic-status-a',0,1000,e)
  expect(store.append(key,'synthetic-status-a',0,1001,e)).toEqual(first)
  expect(store.append(key,'synthetic-status-a',1,1010,e).error).toBe('REPLAYED_NONCE')
})
test('signature tamper, source spoof, cross-contract/guarantee replay and future clocks reject',()=>{
  const {store,key,envelope}=setup()
  const good=envelope('synthetic-status-a','1',1000)
  const wrongDomains=[{guaranteeId:'2'},{consumer:`0x${'34'.repeat(20)}`},{chainId:'1'},{cohortId:`0x${'34'.repeat(32)}`},{policyHash:`0x${'34'.repeat(32)}`},{conditionHash:`0x${'34'.repeat(32)}`}]
  const bads=[{...good,signature:'0'.repeat(128)},...wrongDomains.map(d=>({...good,payload:{...good.payload,domain:{...good.payload.domain,...d}}})),envelope('synthetic-status-b','2',1000),envelope('synthetic-status-a','3',1020)]
  for(const [slot,bad] of bads.entries()) expect(store.append(key,'synthetic-status-a',slot,1010,bad).kind).toBe('INVALID')
})
test('feed failure is a receipt; collector never invokes a chain transaction',async()=>{
  const {store,key}=setup();const c=new Collector(store,async()=>{throw Error('secret upstream details')},()=>1000)
  await c.tick();const receipts=store.verified(key)
  expect(receipts.map(r=>r.kind)).toEqual(['UNAVAILABLE','UNAVAILABLE'])
  expect(JSON.stringify(receipts)).not.toContain('secret upstream details')
  expect(receipts.every(r=>r.payloadHash===null && r.signature===null)).toBe(true)
})
test('stored private payload/hash tampering and deleted middle receipt are detected',()=>{
  const {dir,store,key,envelope}=setup()
  store.append(key,'synthetic-status-a',0,1000,envelope('synthetic-status-a','0',1000))
  store.append(key,'synthetic-status-b',0,1000,envelope('synthetic-status-b','0',1000))
  const db=new Database(join(dir,'evidence.sqlite'))
  db.query('UPDATE entries SET envelope=? WHERE domain=? AND seq=1').run('{"payload":{}}',key)
  expect(()=>store.verified(key)).toThrow()
  db.query('DELETE FROM entries WHERE domain=? AND seq=1').run(key)
  expect(()=>store.verified(key)).toThrow('TAMPERED');db.close()
})

test('another guarantee with an unsupported policy cannot block discovery of our cohort',async()=>{
  const {store,a}=setup()
  class SyntheticObserver extends ChainObserver {
    override async check() {} // Unit fixture, no claim of actual chain connectivity.
    override async read(name:string,args:readonly unknown[]=[]):Promise<unknown> {
      if(name==='nextGuaranteeId')return 3n
      if(name==='getGuarantee')return {termsHash:a.domain.conditionHash,settlementTime:1100n}
      if(name==='getEvidenceState')return {policyHash:args[0]===1n?hash('unsupported-policy'):a.domain.policyHash,cohortId:hash(['cohort',String(args[0])]),createdAt:1000n}
      throw Error('UNEXPECTED_SYNTHETIC_READ')
    }
  }
  const observer=new SyntheticObserver(a.domain.consumer as `0x${string}`,a.policy,store)
  await observer.discover()
  expect(store.setting(`cursor:${a.domain.consumer}`)).toBe('3')
  expect(store.activations().some(v=>v.domain.guaranteeId==='2')).toBe(true)
  expect(store.setting(`unsupported:${a.domain.consumer}:1`)).toBe('POLICY_KEYS_OR_RULES_MISMATCH')
  const count=store.activations().length
  await observer.discover();expect(store.activations()).toHaveLength(count)
})

test('discovery transport errors preserve the retry cursor instead of inventing activation',async()=>{
  const {store,a}=setup()
  class UnavailableObserver extends ChainObserver {
    override async check() {}
    override async read(name:string):Promise<unknown> {
      if(name==='nextGuaranteeId')return 3n
      throw Error('SIMULATED_RPC_OUTAGE')
    }
  }
  store.setSetting(`cursor:${a.domain.consumer}`,'2')
  const observer=new UnavailableObserver(a.domain.consumer as `0x${string}`,a.policy,store)
  await expect(observer.discover()).rejects.toThrow('SIMULATED_RPC_OUTAGE')
  expect(store.setting(`cursor:${a.domain.consumer}`)).toBe('2')
  expect(store.activations().some(v=>v.domain.guaranteeId==='2')).toBe(false)
})
