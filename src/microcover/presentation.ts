import { isAddress } from 'viem'
import { hash } from './evidenceCanonical'
import { PRESET_TERMS_HASH } from './terms'

/** Public context only. Financial terms and domain are committed via cohortId at creation. */
export interface Presentation {
  schema: 'microcover-concert-context-v1'
  chainId: '5042002'
  consumer: string
  provider: string
  name: string
  venue: string
  scheduledAt: string
  price: string
  compensation: string
  capacity: number
  termsHash: string
  policyHash: string
}
export function validatePresentation(input: unknown): Presentation {
  if (!input || typeof input !== 'object' || Array.isArray(input)) throw Error('INVALID_PRESENTATION')
  const p = input as Presentation
  const keys = ['schema','chainId','consumer','provider','name','venue','scheduledAt','price','compensation','capacity','termsHash','policyHash']
  if (Object.keys(p).length !== keys.length || Object.keys(p).some(k=>!keys.includes(k)) ||
    p.schema !== 'microcover-concert-context-v1' || p.chainId !== '5042002' ||
    ![p.consumer,p.provider].every(a=>typeof a==='string' && isAddress(a) && a===a.toLowerCase() && !/^0x0{40}$/.test(a)) ||
    ![p.name,p.venue].every(s=>typeof s==='string' && s.trim()===s && s.length>=2 && s.length<=120 && !/[\x00-\x1f<>]/.test(s)) ||
    !/^[1-9]\d{0,11}$/.test(p.scheduledAt) || ![p.price,p.compensation].every(s=>typeof s==='string' && /^[1-9]\d{0,38}$/.test(s) && BigInt(s)<2n**128n) ||
    !Number.isInteger(p.capacity) || p.capacity<1 || p.capacity>100 || p.termsHash!==PRESET_TERMS_HASH || !/^0x[0-9a-f]{64}$/.test(p.policyHash)) throw Error('INVALID_PRESENTATION')
  return p
}
export const presentationCommitment = (p: Presentation) => hash(validatePresentation(p))
export interface PresentationRecord { guaranteeId: string; presentation: Presentation }
export function matchesPresentation(p:Presentation, g:{provider:string;termsHash:string;policyHash:string;cohortId:string;escrowAmount:bigint;compensation:bigint;maxCohort:number;settlementTime:bigint;joinDeadline:bigint}) {
  return p.provider===g.provider.toLowerCase() && p.termsHash===g.termsHash && p.policyHash===g.policyHash && presentationCommitment(p)===g.cohortId && BigInt(p.price)===g.escrowAmount && BigInt(p.compensation)===g.compensation && p.capacity===g.maxCohort && BigInt(p.scheduledAt)===g.settlementTime && g.joinDeadline===g.settlementTime
}
export const roleStorageKey=(chain:number|undefined,address:string)=>`microcover:concert-role:${chain??'unknown'}:${address.toLowerCase()}`
/** Payment-received claims require membership AND the corresponding onchain settlement counter. */
export function bookingStatus(g:{isMember:boolean;outcome:number;status:number;refundedCount:number;beneficiaries:readonly {address:string;paid:boolean}[]},account:string|undefined) {
  if (!account || !g.isMember) return 'You haven’t booked this concert.'
  const index=g.beneficiaries.findIndex(b=>b.address.toLowerCase()===account.toLowerCase())
  if(index<0)return 'Checking your booking'
  if(g.outcome===1)return g.beneficiaries[index].paid?'Refund + compensation received':'Refund + compensation ready — settlement required'
  if(g.outcome===3)return index<g.refundedCount?'Ticket refund received — no compensation':'Ticket refund ready — settlement required'
  if(g.outcome===2)return 'Concert completed — no customer payout'
  if(g.status===5 || g.status===3)return 'Checking the concert outcome'
  return 'You’re booked — waiting for the concert outcome'
}
