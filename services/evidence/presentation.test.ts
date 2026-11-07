import { test, expect } from 'bun:test'
import { mkdtempSync } from 'node:fs'
import { join } from 'node:path'
import { testTempRoot, removeTestDirectory } from './test-support'
import { EvidenceStore } from './store'
import { savePresentation, verifyPresentation } from './presentation'
import { presentationCommitment, validatePresentation, bookingStatus, roleStorageKey, type Presentation } from '../../src/microcover/presentation'
import { PRESET_TERMS_HASH } from '../../src/microcover/terms'
const consumer='0x1111111111111111111111111111111111111111'
const provider='0x2222222222222222222222222222222222222222'
const p:Presentation={schema:'microcover-concert-context-v1',chainId:'5042002',consumer,provider,name:'Synthetic night',venue:'Demo hall',scheduledAt:'1800000000',price:'2000000',compensation:'5000000',capacity:3,termsHash:PRESET_TERMS_HASH,policyHash:'0x'+'a'.repeat(64)}
const terms={provider,termsHash:p.termsHash,escrowAmount:2000000n,compensation:5000000n,maxCohort:3,settlementTime:1800000000n,joinDeadline:1800000000n}
const state:{policyHash:string;cohortId:string}={policyHash:p.policyHash,cohortId:presentationCommitment(p)}
const reader=(t=terms,s=state)=>({read:async(name:string)=>name==='getGuarantee'?t:s})
test('presentation is bound to provider-signed creation commitment; old generic runs and changed terms fail',async()=>{
  expect(await verifyPresentation({guaranteeId:'4',presentation:p},consumer,reader())).toEqual({guaranteeId:'4',presentation:p})
  for(const patch of [{name:'Other concert'},{venue:'Another hall'},{scheduledAt:'1800000001'},{price:'3000000'},{compensation:'9000000'},{capacity:4},{provider:consumer},{consumer:provider},{policyHash:'0x'+'b'.repeat(64)}]){
    await expect(verifyPresentation({guaranteeId:'4',presentation:{...p,...patch}},consumer,reader())).rejects.toThrow()
  }
  await expect(verifyPresentation({guaranteeId:'4',presentation:p},consumer,reader(terms,{...state,cohortId:'0x'+'c'.repeat(64)}))).rejects.toThrow()
  await expect(verifyPresentation({guaranteeId:'4',presentation:p},consumer,reader({...terms,settlementTime:1800000001n}))).rejects.toThrow()
  await expect(verifyPresentation({guaranteeId:'4',presentation:p},consumer,reader({...terms,provider:consumer}))).rejects.toThrow()
  expect(()=>validatePresentation({...p,termsHash:'0x'+'0'.repeat(64)})).toThrow()
  expect(()=>validatePresentation({...p,name:'<script>alert(1)</script>'})).toThrow()
  expect(()=>validatePresentation({...p,extra:'not canonical'})).toThrow()
})
test('public context persists across service/browser sessions; immutable and idempotent',async()=>{
  const dir=mkdtempSync(join(testTempRoot(),'microcover-context-test-'))
  let store=new EvidenceStore(dir)
  try{
    await savePresentation(store,{guaranteeId:'4',presentation:p},consumer,reader())
    await savePresentation(store,{guaranteeId:'4',presentation:p},consumer,reader())
    store.close();store=new EvidenceStore(dir)
    expect(store.settingsWithPrefix(`presentation:${consumer}:`)).toHaveLength(1)
    expect(JSON.parse(store.setting(`presentation:${consumer}:4`)!)).toEqual({guaranteeId:'4',presentation:p})
    expect(()=>store.freezeSetting(`presentation:${consumer}:4`,'{}')).toThrow('PRESENTATION_FROZEN')
  }finally{store.close();removeTestDirectory(dir)}
})
test('customer status never confuses potential with received; account/role scopes stay separate',()=>{
  const customer='0x3333333333333333333333333333333333333333'
  const g={isMember:true,outcome:1,status:1,refundedCount:0,beneficiaries:[{address:customer,paid:false}]}
  expect(bookingStatus(g,customer)).toContain('ready')
  expect(bookingStatus({...g,beneficiaries:[{address:customer,paid:true}]},customer)).toContain('received')
  expect(bookingStatus({...g,isMember:false},provider)).toContain('haven’t booked')
  expect(bookingStatus({...g,isMember:false},undefined)).toContain('haven’t booked')
  expect(bookingStatus({...g,outcome:3},customer)).toContain('ready')
  expect(bookingStatus({...g,outcome:3,refundedCount:1},customer)).toContain('no compensation')
  expect(bookingStatus({...g,outcome:2},customer)).toContain('no customer payout')
  expect(bookingStatus({...g,outcome:0,status:5},customer)).toContain('Checking')
  expect(roleStorageKey(5042002,customer)).not.toBe(roleStorageKey(1,customer))
  expect(roleStorageKey(5042002,customer)).not.toBe(roleStorageKey(5042002,provider))
})
