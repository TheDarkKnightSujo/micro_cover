import { expect, test } from 'bun:test'
import { readFileSync } from 'node:fs'
import { type Address } from 'viem'
import { microCoverAbi } from '../../src/microcover/contract'
import { canAdmitFailure, canPropose, canWithdraw, nextStep } from '../../src/microcover/lifecycle'
import { validatePrepared, validatePublicPolicy, validateSnapshot } from '../../src/microcover/evidenceClient'
import type { GuaranteeView } from '../../src/microcover/useGuarantee'
import { testActivation } from './test-support'
import { hash } from './model'

const contract=`0x${'12'.repeat(20)}` as Address
function fixture(){
  const {a}=testActivation()
  const g={forId:1n,provider:contract,status:5,outcome:0,uncertainReadyAt:1200n,settlementTime:1100n,joinDeadline:1099n,evidenceBound:true,policyHash:a.domain.policyHash,cohortId:a.domain.cohortId,termsHash:a.domain.conditionHash,nextVerdictNonce:1n,cohortSize:3,refundedCount:1,bondHeld:15_000000n,reviewWindow:120n,claimEndsAt:1220n} as GuaranteeView
  const evaluation={domain:a.domain,outcome:'SUCCESS',evidenceRoot:hash('verified-test-root'),receiptRoot:hash('test-receipt'),sources:['synthetic-status-a','synthetic-status-b'].map(id=>({id,status:'FULFILLED',usable:true})),requiredSources:2,coveredSources:2,totalWeight:2,sourceGroupCount:1,independentSourcesClaimed:false}
  const report={chainId:'5042002',consumer:contract,guaranteeId:'1',cohortId:g.cohortId,policyHash:g.policyHash,evidenceRoot:evaluation.evidenceRoot,outcome:2,evaluatedAt:'1100',validUntil:'1160',nonce:'1'}
  return {a,g,evaluation,report}
}
test('browser validates frozen keys/policy and refuses old or different deployments',()=>{
  const {a}=fixture()
  const wire={policy:a.policy,policyHash:hash(a.policy),consumer:contract,chainError:''}
  expect(validatePublicPolicy(wire,contract).policyHash).toBe(a.domain.policyHash)
  expect(()=>validatePublicPolicy({...wire,chainError:'PHASE3_DEPLOYMENT_REQUIRED'},contract)).toThrow()
  expect(()=>validatePublicPolicy({...wire,policyHash:hash('wrong')},contract)).toThrow()
  expect(()=>validatePublicPolicy(wire,`0x${'34'.repeat(20)}`)).toThrow()
})
test('browser rejects report replay, wrong domain, unsupported outcome and oversized validity',()=>{
  const {g,evaluation,report}=fixture()
  expect(validatePrepared({evaluation,report},g,contract).outcome).toBe(2)
  for(const patch of [{chainId:'1'},{consumer:`0x${'34'.repeat(20)}`},{guaranteeId:'2'},{cohortId:hash('other')},{policyHash:hash('other')},{nonce:'2'},{evidenceRoot:hash('other')},{outcome:3},{validUntil:'1161'}])expect(()=>validatePrepared({evaluation,report:{...report,...patch}},g,contract)).toThrow()
  expect(()=>validatePrepared({evaluation:{...evaluation,outcome:'UNCERTAIN'},report},g,contract)).toThrow()
  expect(()=>validatePrepared({evaluation:{...evaluation,coveredSources:1},report},g,contract)).toThrow()
  const snapshot={evaluation,receipts:[],nextCursor:0}
  expect(validateSnapshot(snapshot,g,contract).nextCursor).toBe(0)
  expect(()=>validateSnapshot({...snapshot,evaluation:{...evaluation,domain:{...evaluation.domain,guaranteeId:'2'}}},g,contract)).toThrow()
})
test('UI offers resolution strictly before timeout and bond only after all refunds',()=>{
  const {g}=fixture();const ctx={account:contract,operator:contract,now:1199n}
  expect(canAdmitFailure(g,ctx).ok).toBe(true)
  expect(canAdmitFailure(g,{...ctx,now:1200n}).ok).toBe(false)
  expect(canPropose({...g,status:0},ctx).ok).toBe(false)
  expect(canWithdraw({...g,status:6},ctx).ok).toBe(false)
  expect(canWithdraw({...g,status:6,refundedCount:3},ctx).ok).toBe(true)
  expect(nextStep({...g,status:2,outcome:3},ctx)).toContain('UNRESOLVED_REFUNDED')
})
test('UI ABI function/event/error shapes match the compiled Phase 3 source',()=>{
  const compiled=JSON.parse(readFileSync('contracts/out/MicroCover.sol/MicroCover.json','utf8')).abi as Record<string,unknown>[]
  const normalize=(v:unknown):unknown=>{
    if(Array.isArray(v))return v.map(normalize)
    if(v&&typeof v==='object')return Object.fromEntries(Object.entries(v).filter(([k])=>k!=='internalType').map(([k,value])=>[k,normalize(value)]))
    return v
  }
  for(const item of microCoverAbi){
    const match=compiled.find(c=>c.type===item.type&&'name' in item&&c.name===item.name)
    // Input parameter names do not affect encoding; output tuple names do affect read consumers.
    expect(match).toBeDefined()
    const actual=normalize(match) as Record<string,unknown>
    const ui=normalize(item) as Record<string,unknown>
    const types=(params:unknown):unknown=>Array.isArray(params)?params.map(p=>({type:p.type,indexed:!!p.indexed,components:types(p.components)})):undefined
    expect(types(ui.inputs)).toEqual(types(actual.inputs))
    const outputs=(p:unknown)=>Array.isArray(p)?p.map(({name:_name,...wire})=>wire):undefined
    expect(outputs(ui.outputs)).toEqual(outputs(actual.outputs))
  }
})
