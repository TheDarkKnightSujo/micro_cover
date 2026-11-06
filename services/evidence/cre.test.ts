import { afterEach, expect, test } from 'bun:test'
import { mkdtempSync } from 'node:fs'
import { join } from 'node:path'
import { EvidenceStore } from './store'
import { testActivation, testTempRoot, removeTestDirectory } from './test-support'
import { evaluate } from './evaluator'
import { evaluateBoundSnapshot, type Snapshot } from '../../workflows/cre/snapshot'
import type { ExplicitStatus } from './model'
import { publicCreRun } from './cre-run'
const stores:EvidenceStore[]=[],dirs:string[]=[]
afterEach(()=>{for(const s of stores.splice(0))s.close();for(const d of dirs.splice(0))removeTestDirectory(d)})
function fixture(status:ExplicitStatus='FULFILLED') {
  const dir=mkdtempSync(join(testTempRoot(),'microcover-cre-test-'));dirs.push(dir)
  const store=new EvidenceStore(dir);stores.push(store);const f=testActivation(),key=store.activate(f.a)
  store.append(key,'synthetic-status-a',0,1090,f.envelope('synthetic-status-a','1',1090))
  store.append(key,'synthetic-status-b',0,1090,f.envelope('synthetic-status-b','1',1090,status))
  const snapshot:Snapshot={activation:f.a,receipts:store.verified(key)}
  const binding={consumer:f.a.domain.consumer,guaranteeId:'1',cohortId:f.a.domain.cohortId,policyHash:f.a.domain.policyHash,conditionHash:f.a.domain.conditionHash,createdAt:1000,outcomeDeadline:1100}
  return{store,key,snapshot,binding}
}
test('CRE adapter reuses exact evaluator/root for success and conflicting uncertainty',()=>{
  for(const status of ['FULFILLED','CANCELLED','UNKNOWN'] as const){const f=fixture(status);expect(evaluateBoundSnapshot(f.snapshot,f.binding,1100)).toEqual(evaluate(f.store,f.key,1100))}
})
test('wrong chain, guarantee, consumer, policy or cutoff cannot reuse a snapshot',()=>{
  const f=fixture()
  for(const change of [{guaranteeId:'2'},{consumer:`0x${'ab'.repeat(20)}`},{policyHash:`0x${'22'.repeat(32)}`},{outcomeDeadline:1101}])expect(()=>evaluateBoundSnapshot(f.snapshot,{...f.binding,...change},1100)).toThrow()
  f.snapshot.activation.domain.chainId='1';expect(()=>evaluateBoundSnapshot(f.snapshot,f.binding,1100)).toThrow()
})
test('receipt mutation, ordering and replayed entries fail closed',()=>{
  const f=fixture()
  const bad=structuredClone(f.snapshot);bad.receipts[0].status='CANCELLED'
  expect(()=>evaluateBoundSnapshot(bad,f.binding,1100)).toThrow()
  expect(()=>evaluateBoundSnapshot({...f.snapshot,receipts:[...f.snapshot.receipts].reverse()},f.binding,1100)).toThrow()
  expect(()=>evaluateBoundSnapshot({...f.snapshot,receipts:[...f.snapshot.receipts,f.snapshot.receipts[1]]},f.binding,1100)).toThrow()
})
test('missing evidence stays uncertain and never gains a smaller coverage denominator',()=>{
  const f=fixture();const e=evaluateBoundSnapshot({...f.snapshot,receipts:[]},f.binding,1100)
  expect(e.outcome).toBe('UNCERTAIN');expect(e.totalWeight).toBe(2)
})
test('captured CLI records are domain checked and never represented as network authentication',()=>{
  const f=fixture(),evaluation=evaluate(f.store,f.key,1100)
  const record={exitCode:0,broadcast:false,chainWrites:false,matchingPhase3Root:true,output:{mode:'READ_ONLY_SIMULATION',evaluatedAt:1100,evaluation}}
  const run=publicCreRun(record,f.binding.consumer,'1')
  expect(run.verifiedNetworkReport).toBe(false);expect(run.chainWrites).toBe(false)
  expect(()=>publicCreRun(record,f.binding.consumer,'2')).toThrow()
  expect(()=>publicCreRun({...record,broadcast:true},f.binding.consumer,'1')).toThrow()
  expect(()=>publicCreRun({...record,matchingPhase3Root:false},f.binding.consumer,'1')).toThrow()
})
