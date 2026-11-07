import type { PresentationRecord } from '../../src/microcover/presentation'
import { matchesPresentation, validatePresentation } from '../../src/microcover/presentation'
import { canonical } from '../../src/microcover/evidenceCanonical'
import type { EvidenceStore } from './store'
interface Reader {read(name:string,args?:readonly unknown[]):Promise<unknown>}
export async function verifyPresentation(record:PresentationRecord,consumer:string,reader:Reader) {
  if(!/^[1-9]\d{0,17}$/.test(record.guaranteeId))throw Error('INVALID_ID')
  const p=validatePresentation(record.presentation)
  if(p.consumer!==consumer.toLowerCase())throw Error('WRONG_CONSUMER')
  const id=BigInt(record.guaranteeId)
  const terms=await reader.read('getGuarantee',[id]) as {provider:string;termsHash:string;escrowAmount:bigint;compensation:bigint;maxCohort:number;settlementTime:bigint;joinDeadline:bigint}
  const state=await reader.read('getEvidenceState',[id]) as {policyHash:string;cohortId:string}
  if(!matchesPresentation(p,{...terms,...state}))throw Error('ONCHAIN_CONTEXT_MISMATCH')
  return {guaranteeId:record.guaranteeId,presentation:p}
}
export async function savePresentation(store:EvidenceStore,record:PresentationRecord,consumer:string,reader:Reader) {
  const verified=await verifyPresentation(record,consumer,reader)
  store.freezeSetting(`presentation:${consumer.toLowerCase()}:${record.guaranteeId}`,canonical(verified))
  return verified
}
