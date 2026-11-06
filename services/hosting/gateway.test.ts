import { test,expect } from 'bun:test'
import { mkdtempSync,writeFileSync,rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { gateway } from './gateway'

test('hosted ABI is exactly the existing Foundry ABI',async()=>{
  const hosted=await Bun.file('services/hosting/contract-abi.json').json()
  const compiled=await Bun.file('contracts/out/MicroCover.sol/MicroCover.json').json()
  expect(hosted.abi).toEqual(compiled.abi)
})

test('host gateway serves only dist and reviewed API, strips credentials and rejects cross-origin requests',async()=>{
  const dir=mkdtempSync(join(tmpdir(),'microcover-host-'))
  writeFileSync(join(dir,'index.html'),'public app')
  writeFileSync(join(dir,'.env'),'must never be served')
  let calls=0
  const handler=gateway({dist:dir,upstream:'http://127.0.0.1:8787',origin:'https://demo.onrender.com',fetchUpstream:(async(input,init)=>{
    calls++;expect(String(input)).toStartWith('http://127.0.0.1:8787/api/')
    expect(new Headers(init?.headers).has('cookie')).toBe(false)
    expect(new Headers(init?.headers).has('origin')).toBe(false)
    return new Response('{}',{headers:{'content-type':'application/json'}})
  }) as typeof fetch})
  const req=(path:string,init?:RequestInit)=>new Request('https://demo.onrender.com'+path,init)
  try{
    expect(await(await handler(req('/'))).text()).toBe('public app')
    for(const path of ['/.env','/%2eenv','/services/evidence/demo.ts','/demo-feed/synthetic-status-a/test/1'])expect((await handler(req(path))).status).toBe(404)
    expect((await handler(req('/api/evidence/v1/health',{headers:{origin:'https://evil.example'}}))).status).toBe(403)
    expect((await handler(req('/api/private'))).status).toBe(405)
    expect((await handler(req('/api/evidence/v1/health',{headers:{origin:'https://demo.onrender.com',cookie:'private=value'}}))).status).toBe(200)
    expect(calls).toBe(1)
    expect((await handler(req('/api/arkiv/v1/rpc',{method:'POST',headers:{'content-type':'application/json'},body:'x'.repeat(2000001)}))).status).toBe(413)
    expect(calls).toBe(1)
    const bootstrap=gateway({dist:dir})
    expect((await bootstrap(req('/healthz'))).status).toBe(200)
    expect((await bootstrap(req('/readyz'))).status).toBe(503)
    expect((await bootstrap(req('/api/evidence/v1/policy'))).status).toBe(503)
  }finally{rmSync(dir,{recursive:true,force:true})}
})
