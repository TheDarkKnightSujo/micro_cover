import { expect,test } from 'bun:test'
import { checkedEvidenceGas } from '../../src/microcover/evidenceSubmission'

test('expired report after slow RPC checks cannot proceed to the wallet',async()=>{
  let now=100n
  await expect(checkedEvidenceGas(async()=>{now=130n},async()=>{now=161n;return 121205n},async()=>now<=160n?{ok:true}:{ok:false,reason:'Report expired'})).rejects.toThrow('Report expired')
})
test('reverted simulation and unavailable estimates fail closed; valid estimate gets a bounded margin',async()=>{
  let estimated=false
  await expect(checkedEvidenceGas(()=>Promise.reject(Error('EvidenceBindingMismatch')),async()=>{estimated=true;return 1n},()=>Promise.resolve({ok:true}))).rejects.toThrow('EvidenceBindingMismatch')
  expect(estimated).toBe(false)
  await expect(checkedEvidenceGas(()=>Promise.resolve(),()=>Promise.reject(Error('RPC limit')),()=>Promise.resolve({ok:true}))).rejects.toThrow('RPC limit')
  await expect(checkedEvidenceGas(()=>Promise.resolve(),()=>Promise.resolve(0n),()=>Promise.resolve({ok:true}))).rejects.toThrow('invalid gas estimate')
  expect(await checkedEvidenceGas(()=>Promise.resolve(),()=>Promise.resolve(121205n),()=>Promise.resolve({ok:true}))).toBe(145446n)
})
