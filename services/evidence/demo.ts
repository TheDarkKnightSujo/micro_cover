import { createPublicKey, generateKeyPairSync, sign } from 'node:crypto'
import { existsSync, readFileSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'
import { canonical, hash, SOURCE_IDS, validatePolicy, type Activation, type Envelope, type Policy, type SourceId } from './model'
import { EvidenceStore, privateDirectory } from './store'
import { PRESET_TERMS_HASH } from '../../src/microcover/terms'

export const MODES=['success','failure','conflict','unknown','unavailable','invalid','stale'] as const
export type Mode=typeof MODES[number]
export function initDemo(directory:string):Policy {
  const dir=privateDirectory(directory)
  if(existsSync(join(dir,'policy.json'))||SOURCE_IDS.some(id=>existsSync(join(dir,`${id}.pem`)))) throw Error('DEMO_ALREADY_INITIALIZED')
  const policy:Policy={version:'synthetic-unanimous-v1',conditionHash:PRESET_TERMS_HASH,disclosure:'Both demo feeds are controlled by the same team; not independent sources.',intervalSeconds:10,freshnessSeconds:60,cutoff:'RECEIVED_BY_OUTCOME_DEADLINE',sources:SOURCE_IDS.map(id=>{
    const pair=generateKeyPairSync('ed25519')
    writeFileSync(join(dir,`${id}.pem`),pair.privateKey.export({format:'pem',type:'pkcs8'}),{flag:'wx',mode:0o600})
    return{id,group:'team-controlled',weight:1,publicKeyDer:pair.publicKey.export({format:'der',type:'spki'}).toString('hex')}
  })}
  writeFileSync(join(dir,'policy.json'),canonical(policy)+'\n',{flag:'wx',mode:0o600})
  return policy
}
export function loadPolicy(directory:string):Policy {
  const policy=JSON.parse(readFileSync(join(privateDirectory(directory),'policy.json'),'utf8')) as Policy
  validatePolicy(policy)
  for(const source of policy.sources){const publicDer=createPublicKey(readFileSync(join(directory,`${source.id}.pem`))).export({format:'der',type:'spki'}).toString('hex');if(publicDer!==source.publicKeyDer)throw Error('DEMO_KEY_IDENTITY_MISMATCH')}
  return policy
}
/** Two explicitly team-controlled authenticated fixtures, not external independent sources. */
export function fixtureResponse(directory:string, store:EvidenceStore, sourceId:SourceId, a:Activation, slot:number, now:number):Envelope {
  const mode=store.setting(`fixture:${hash(a.domain)}`)??'unknown'
  if(!MODES.includes(mode as Mode))throw Error('INVALID_FIXTURE_MODE')
  if(mode==='unavailable'&&sourceId==='synthetic-status-b')throw Error('SIMULATED_FEED_UNAVAILABLE')
  const status=mode==='failure'?'CANCELLED':mode==='unknown'?'UNKNOWN':mode==='conflict'&&sourceId==='synthetic-status-b'?'CANCELLED':'FULFILLED'
  const payload:Envelope['payload']={domain:a.domain,sourceId,sourceTimestamp:mode==='stale'?Math.max(a.activatedAt,now-61):now,nonce:String(slot),status}
  const signature=mode==='invalid'&&sourceId==='synthetic-status-b'?'0'.repeat(128):sign(null,Buffer.from(canonical(payload)),readFileSync(join(directory,`${sourceId}.pem`))).toString('hex')
  return{payload,signature}
}
