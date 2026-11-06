import { afterEach, expect, test } from 'bun:test'
import { mkdtempSync } from 'node:fs'
import { testTempRoot } from './test-support'
import { join } from 'node:path'
import { Database } from 'bun:sqlite'
import { EvidenceStore } from './store'
import { evaluate, prepareReport } from './evaluator'
import { testActivation, removeTestDirectory } from './test-support'
import type { ExplicitStatus } from './model'
const dirs:string[]=[];const stores:EvidenceStore[]=[]
afterEach(()=>{for(const s of stores.splice(0))s.close();for(const d of dirs.splice(0))removeTestDirectory(d)})
function setup(aStatus:ExplicitStatus='FULFILLED',bStatus:ExplicitStatus='FULFILLED'){
  const dir=mkdtempSync(join(testTempRoot(),'microcover-evaluator-test-'));dirs.push(dir)
  const store=new EvidenceStore(dir);stores.push(store);const fixture=testActivation();const key=store.activate(fixture.a)
  store.append(key,'synthetic-status-a',0,1090,fixture.envelope('synthetic-status-a','1',1090,aStatus))
  store.append(key,'synthetic-status-b',0,1090,fixture.envelope('synthetic-status-b','1',1090,bStatus))
  return{dir,store,key,...fixture}
}
test('two explicit fulfilled statuses establish success; provider cooperation is absent',()=>{
  const {store,key}=setup();const e=evaluate(store,key,1100)
  expect(e.outcome).toBe('SUCCESS');expect(e.successSupportBps).toBe(10000);expect(e.independentSourcesClaimed).toBe(false)
  const report=prepareReport(e,1100,1n);expect(report.outcome).toBe(2);expect(report.validUntil-report.evaluatedAt).toBe(60n)
})
test('two explicit cancellations establish failure, not a call to provider admission',()=>{
  const {store,key}=setup('CANCELLED','CANCELLED');const e=evaluate(store,key,1100)
  expect(e.outcome).toBe('FAILURE');expect(e.failureSupportBps).toBe(10000);expect(prepareReport(e,1100,3n).outcome).toBe(1)
})
test('conflict and explicit unknown never establish a verdict',()=>{
  for(const status of ['CANCELLED','UNKNOWN'] as const){const {store,key}=setup('FULFILLED',status);const e=evaluate(store,key,1100)
    expect(e.outcome).toBe('UNCERTAIN');expect(e.successSupportBps).toBe(5000);expect(()=>prepareReport(e,1100,1n)).toThrow()}
})
test('latest unavailable or invalid poll blocks earlier matching observations; denominator never shrinks',()=>{
  for(const invalid of [false,true]){const {store,key,envelope}=setup()
    store.append(key,'synthetic-status-b',1,1095,invalid?{...envelope('synthetic-status-b','2',1095),signature:'0'.repeat(128)}:null,!invalid)
    const e=evaluate(store,key,1100);expect(e.outcome).toBe('UNCERTAIN');expect(e.coveredSources).toBe(1);expect(e.totalWeight).toBe(2);expect(e.successSupportBps).toBe(5000)}
})
test('stale and absent source coverage cannot prove either outcome',()=>{
  const {store,key,envelope}=setup()
  // Fresh receipt of a stale, correctly signed observation remains stale at the frozen cutoff.
  store.append(key,'synthetic-status-a',1,1095,envelope('synthetic-status-a','2',1039))
  expect(evaluate(store,key,1100).outcome).toBe('UNCERTAIN')
  const f=testActivation('2');const other=store.activate(f.a);expect(evaluate(store,other,1100).coveredSources).toBe(0)
})
test('inclusive freshness/cutoff boundary and late evidence are deterministic across restart',()=>{
  const {store,key,dir,envelope}=setup()
  store.append(key,'synthetic-status-a',1,1100,envelope('synthetic-status-a','2',1040))
  const before=evaluate(store,key,1100);expect(before.outcome).toBe('SUCCESS')
  store.append(key,'synthetic-status-b',2,1101,envelope('synthetic-status-b','2',1101,'CANCELLED'))
  expect(evaluate(store,key,5000)).toEqual(before)
  store.close();stores.splice(stores.indexOf(store),1);const restarted=new EvidenceStore(dir);stores.push(restarted)
  expect(evaluate(restarted,key,6000)).toEqual(before)
})
test('no verdict before deadline; invalid report clocks/nonces reject',()=>{
  const {store,key}=setup();expect(evaluate(store,key,1099).reason).toBe('NOT_DUE')
  const e=evaluate(store,key,1100);expect(()=>prepareReport(e,1099,1n)).toThrow();expect(()=>prepareReport(e,1100,0n)).toThrow()
})
test('payload and log tampering fail closed with no anchorable commitment',()=>{
  const {store,key,dir}=setup();const db=new Database(join(dir,'evidence.sqlite'))
  db.query('UPDATE entries SET receipt=? WHERE domain=? AND seq=1').run('{}',key)
  const e=evaluate(store,key,1100);expect(e.reason).toBe('INTEGRITY_FAILURE');expect(e.outcome).toBe('UNCERTAIN');expect(()=>prepareReport(e,1100,1n)).toThrow();db.close()
})
