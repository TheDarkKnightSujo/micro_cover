/** Synthetic test helpers: ephemeral keys only, never real or committed signing credentials. */
import { generateKeyPairSync, sign, type KeyObject } from 'node:crypto'
import { canonical, hash, SOURCE_IDS, type Activation, type Envelope, type ExplicitStatus, type Policy, type SourceId } from './model'
import { PRESET_TERMS_HASH } from '../../src/microcover/terms'
import { mkdirSync, realpathSync, rmSync } from 'node:fs'
import { basename, dirname, join } from 'node:path'

/** A disposable sibling test store: this laptop's OS temp lives inside a home dotfiles Git repo. */
export function testTempRoot() {
  const root=join(dirname(process.cwd()),'.microcover-evidence-test-temp')
  mkdirSync(root,{recursive:true})
  return realpathSync(root)
}

/** Delete only a verified immediate temporary test directory, never a computed workspace path. */
export function removeTestDirectory(path:string) {
  const actual=realpathSync(path)
  if(dirname(actual)!==testTempRoot() || !/^microcover-[a-z-]+-test-/.test(basename(actual))) throw Error('UNSAFE_TEST_CLEANUP')
  rmSync(actual,{recursive:true,force:true})
}

export function testActivation(id = '1', consumer = `0x${'12'.repeat(20)}`) {
  const keys = new Map<SourceId,KeyObject>()
  const policy: Policy = {
    version: 'synthetic-unanimous-v1',
    conditionHash: PRESET_TERMS_HASH,
    disclosure: 'Both demo feeds are controlled by the same team; not independent sources.',
    intervalSeconds:10, freshnessSeconds:60, cutoff:'RECEIVED_BY_OUTCOME_DEADLINE',
    sources: SOURCE_IDS.map(id => {
      const pair = generateKeyPairSync('ed25519')
      keys.set(id,pair.privateKey)
      return { id, group:'team-controlled', weight:1, publicKeyDer:pair.publicKey.export({format:'der',type:'spki'}).toString('hex') }
    }),
  }
  const a: Activation = { domain:{schema:'microcover-evidence-v1',chainId:'5042002',consumer,guaranteeId:id,cohortId:hash(['cohort',id]),conditionHash:PRESET_TERMS_HASH,policyHash:hash(policy)},policy,activatedAt:1000,outcomeDeadline:1100 }
  const envelope = (sourceId: SourceId, nonce:string, timestamp:number, status:ExplicitStatus = 'FULFILLED'): Envelope => {
    const payload = {domain:a.domain,sourceId,nonce,sourceTimestamp:timestamp,status}
    return { payload, signature:sign(null,Buffer.from(canonical(payload)),keys.get(sourceId)!).toString('hex') }
  }
  return {a,keys,envelope}
}
