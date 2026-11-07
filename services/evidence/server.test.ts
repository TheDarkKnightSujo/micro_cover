import { expect, test } from 'bun:test'
import { mkdtempSync, readFileSync, readdirSync } from 'node:fs'
import { testTempRoot } from './test-support'
import { join } from 'node:path'
import { initDemo, loadPolicy } from './demo'
import { serveEvidence } from './server'
import { hash } from './model'
import { removeTestDirectory } from './test-support'
import { Collector } from './collector'
import { evaluate } from './evaluator'
import { PRESET_TERMS_HASH } from '../../src/microcover/terms'
import type { Activation } from './model'

test('loopback API exposes public policy only, has no administrative/raw-payload endpoint and blocks other origins',async()=>{
  const dir=mkdtempSync(join(testTempRoot(),'microcover-http-test-'))
  const p=initDemo(dir);expect(()=>initDemo(dir)).toThrow('ALREADY_INITIALIZED');expect(hash(loadPolicy(dir))).toBe(hash(p))
  const app=serveEvidence(dir,undefined,0)
  try{
    const base=`http://127.0.0.1:${app.server.port}`
    const response=await fetch(base+'/api/evidence/v1/policy',{headers:{origin:'http://127.0.0.1:5173'}})
    expect(response.status).toBe(200)
    const text=await response.text();expect(text).toContain('PHASE3_ADDRESS_NOT_CONFIGURED');expect(text).not.toContain('PRIVATE KEY')
    expect(response.headers.get('access-control-allow-origin')).toBe('http://127.0.0.1:5173')
    const preflight={origin:'http://127.0.0.1:5173','access-control-request-method':'POST','access-control-request-headers':'content-type'}
    const allowed=await fetch(base+'/api/arkiv/v1/rpc',{method:'OPTIONS',headers:preflight})
    expect(allowed.status).toBe(204)
    expect(allowed.headers.get('access-control-allow-methods')).toBe('POST')
    expect(allowed.headers.get('access-control-allow-headers')).toBe('content-type')
    expect(allowed.headers.get('access-control-allow-origin')).toBe(preflight.origin)
    expect((await fetch(base+'/api/arkiv/v1/rpc',{method:'OPTIONS',headers:{...preflight,origin:'https://untrusted.example'}})).status).toBe(403)
    expect((await fetch(base+'/api/arkiv/v1/rpc',{method:'OPTIONS',headers:{...preflight,'access-control-request-headers':'authorization'}})).status).toBe(403)
    expect((await fetch(base+'/api/evidence/v1/policy',{headers:{origin:'https://untrusted.example'}})).status).toBe(403)
    expect((await fetch(base+'/api/evidence/v1/policy',{method:'POST'})).status).toBe(405)
    expect((await fetch(base+'/api/evidence/v1/raw')).status).toBe(404)
    expect((await fetch(base+'/api/evidence/v1/presentations',{method:'POST',headers:{'content-type':'application/json'},body:'{}'})).status).toBe(503)
    expect((await fetch(base+'/api/evidence/v1/presentations/1')).status).toBe(503)
    expect((await fetch(base+'/api/evidence/v1/guarantees/1')).status).toBe(503)
    const privateKey=readFileSync(join(dir,readdirSync(dir).find(n=>n.endsWith('.pem'))!),'utf8')
    expect(text).not.toContain(privateKey)
  }finally{app.stop();removeTestDirectory(dir)}
})

test('real HTTP demo feeds authenticate into the persistent collector; conflict remains uncertain',async()=>{
  const dir=mkdtempSync(join(testTempRoot(),'microcover-http-test-'))
  const policy=initDemo(dir)
  const app=serveEvidence(dir,undefined,0)
  const now=Math.floor(Date.now()/1000)
  // Test-only synthetic activation; production discovery reads the deployed terms.
  const a:Activation={domain:{schema:'microcover-evidence-v1',chainId:'5042002',consumer:`0x${'12'.repeat(20)}`,guaranteeId:'1',cohortId:hash('test-cohort'),conditionHash:PRESET_TERMS_HASH,policyHash:hash(policy)},policy,activatedAt:now,outcomeDeadline:now+30}
  const key=app.store.activate(a)
  app.store.setSetting(`fixture:${key}`,'conflict')
  try{
    const collector=new Collector(app.store,async(source,_a,slot)=>{
      const response=await fetch(`http://127.0.0.1:${app.server.port}/demo-feed/${source}/${key}/${slot}`)
      expect(response.ok).toBe(true)
      return response.json()
    },()=>Math.floor(Date.now()/1000))
    await collector.tick()
    const receipts=app.store.verified(key)
    expect(receipts).toHaveLength(2)
    expect(receipts.every(r=>r.kind==='OBSERVATION'&&r.signature!==null)).toBe(true)
    const result=evaluate(app.store,key,a.outcomeDeadline)
    expect(result.outcome).toBe('UNCERTAIN')
    expect(result.reason).toBe('CONFLICTING_STATUSES')
  }finally{app.stop();removeTestDirectory(dir)}
})
