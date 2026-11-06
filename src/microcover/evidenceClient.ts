import { useQuery } from '@tanstack/react-query'
import { isAddressEqual, type Address, type Hex } from 'viem'
import { hash } from './evidenceCanonical'
import { PRESET_TERMS_HASH } from './terms'
import type { GuaranteeView } from './useGuarantee'

export const EVIDENCE_DISCLOSURE = 'Both demo feeds are controlled by the same team; not independent sources.'
const base = ((import.meta.env as Record<string,string|undefined>|undefined)?.VITE_EVIDENCE_API_URL?.trim() || 'http://127.0.0.1:8787').replace(/\/$/,'')
const hex = (v:unknown):v is Hex => typeof v==='string' && /^0x[0-9a-f]{64}$/.test(v)
const record = (v:unknown):Record<string,unknown> => { if(!v||typeof v!=='object'||Array.isArray(v))throw Error('Invalid evidence response');return v as Record<string,unknown> }
const integer = (v:unknown):bigint => { if(typeof v!=='string'||! /^(0|[1-9]\d*)$/.test(v))throw Error('Invalid evidence integer');return BigInt(v) }
export async function evidenceGet(path:string,signal?:AbortSignal):Promise<unknown> {
  const response=await fetch(base+'/api/evidence/v1/'+path,{signal,credentials:'omit',cache:'no-store'})
  if(!response.ok)throw Error('Evidence service is unavailable or this guarantee is not supported. No onchain dispute was opened.')
  return response.json()
}
export interface PublicPolicy { policy:Record<string,unknown>; policyHash:Hex; consumer:Address }
export function validatePublicPolicy(input:unknown,contract:Address):PublicPolicy {
  const r=record(input),p=record(r.policy)
  const sources=Array.isArray(p.sources)?p.sources.map(record):[]
  if(r.chainError!==''||typeof r.consumer!=='string'||!isAddressEqual(r.consumer as Address,contract)||!hex(r.policyHash)||hash(p)!==r.policyHash||p.conditionHash!==PRESET_TERMS_HASH||p.version!=='synthetic-unanimous-v1'||p.intervalSeconds!==10||p.freshnessSeconds!==60||p.cutoff!=='RECEIVED_BY_OUTCOME_DEADLINE'||p.disclosure!==EVIDENCE_DISCLOSURE||sources.length!==2||sources.some((s,i)=>s.id!==['synthetic-status-a','synthetic-status-b'][i]||s.group!=='team-controlled'||s.weight!==1||typeof s.publicKeyDer!=='string'||!/^302a300506032b6570032100[0-9a-f]{64}$/.test(s.publicKeyDer))||sources[0].publicKeyDer===sources[1].publicKeyDer)throw Error('Evidence policy, key identity or deployment mismatch. Creation is disabled.')
  return {policy:p,policyHash:r.policyHash,consumer:contract}
}
export const useEvidencePolicy=(contract:Address|undefined)=>useQuery({queryKey:['evidence-policy',contract],enabled:!!contract,queryFn:async({signal})=>validatePublicPolicy(await evidenceGet('policy',signal),contract!),refetchInterval:10000,retry:1})

export interface Snapshot {
  evaluation:{domain:Record<string,unknown>;outcome:string;reason:string;coveredSources:number;requiredSources:number;successSupportBps:number;failureSupportBps:number;evidenceRoot:Hex;receiptRoot:Hex;receiptCount:number;asOf:number;sources:{id:string;status:string|null;reason:string;usable:boolean}[]}
  receipts:{sequence:number;sourceId:string;receivedAt:number;sourceTimestamp:number|null;kind:string;payloadHash:Hex|null;hash:Hex;previousHash:Hex}[]
  nextCursor:number
}
export function validateDomain(input:unknown,g:GuaranteeView,contract:Address):void {
  const d=record(input)
  if(d.schema!=='microcover-evidence-v1'||d.chainId!=='5042002'||d.consumer!==contract.toLowerCase()||d.guaranteeId!==g.forId.toString()||d.cohortId!==g.cohortId||d.policyHash!==g.policyHash||d.conditionHash!==g.termsHash)throw Error('Evidence domain mismatch')
}
export function validateSnapshot(input:unknown,g:GuaranteeView,contract:Address):Snapshot {
  const s=record(input),e=record(s.evaluation)
  validateDomain(e.domain,g,contract)
  if(!hex(e.evidenceRoot)||!hex(e.receiptRoot)||!['SUCCESS','FAILURE','UNCERTAIN'].includes(String(e.outcome))||e.requiredSources!==2||e.sourceGroupCount!==1||e.independentSourcesClaimed!==false||!Array.isArray(e.sources)||e.sources.length!==2||!Array.isArray(s.receipts)||s.receipts.length>100||!Number.isSafeInteger(s.nextCursor))throw Error('Invalid evidence snapshot')
  return s as unknown as Snapshot
}
export interface PreparedReport {chainId:bigint;consumer:Address;guaranteeId:bigint;cohortId:Hex;policyHash:Hex;evidenceRoot:Hex;outcome:number;evaluatedAt:bigint;validUntil:bigint;nonce:bigint}
export function validatePrepared(input:unknown,g:GuaranteeView,contract:Address):PreparedReport {
  const p=record(input),e=record(p.evaluation),r=record(p.report)
  validateDomain(e.domain,g,contract)
  const sources=Array.isArray(e.sources)?e.sources.map(record):[]
  const expectedStatus=r.outcome===2?'FULFILLED':'CANCELLED'
  if(e.requiredSources!==2||e.coveredSources!==2||e.sourceGroupCount!==1||e.independentSourcesClaimed!==false||e.totalWeight!==2||sources.length!==2||sources.some((s,i)=>s.id!==['synthetic-status-a','synthetic-status-b'][i]||s.usable!==true||s.status!==expectedStatus))throw Error('Both authenticated source identities must establish this result')
  if(!hex(r.evidenceRoot)||r.evidenceRoot!==e.evidenceRoot||r.evidenceRoot===`0x${'0'.repeat(64)}`||r.consumer!==contract.toLowerCase()||integer(r.chainId)!==5042002n||integer(r.guaranteeId)!==g.forId||r.policyHash!==g.policyHash||r.cohortId!==g.cohortId||integer(r.nonce)!==g.nextVerdictNonce||!(e.outcome==='SUCCESS'&&r.outcome===2||e.outcome==='FAILURE'&&r.outcome===1))throw Error('Unestablished or mismatched evidence verdict')
  const evaluatedAt=integer(r.evaluatedAt),validUntil=integer(r.validUntil)
  if(evaluatedAt<g.settlementTime||validUntil<evaluatedAt||validUntil>evaluatedAt+60n)throw Error('Invalid report window')
  return {chainId:5042002n,consumer:contract,guaranteeId:g.forId,cohortId:g.cohortId,policyHash:g.policyHash,evidenceRoot:r.evidenceRoot,outcome:r.outcome,evaluatedAt,validUntil,nonce:g.nextVerdictNonce}
}
