import { readFileSync } from 'node:fs'
import { gateway } from './gateway'

// Reuse the existing collector on loopback. Never open the database a second time.
const response=await fetch('http://127.0.0.1:8787/api/evidence/v1/policy',{signal:AbortSignal.timeout(5000)})
if(!response.ok)throw Error('START_EXISTING_EVIDENCE_SERVICE_FIRST')
const policy=await response.json() as {consumer?:string;policyHash?:string}
if(policy.consumer?.toLowerCase()!=='0xdcd11bb347f063b5a876c8816f5a02b8ea0f11e0'||policy.policyHash!=='0x390c151a55ce5c1e9861f5781528a38864fdc389edaee853de2fdb6f4d8e9d3d')throw Error('EXISTING_EVIDENCE_DOMAIN_MISMATCH')
let lastOrigin='',handler:ReturnType<typeof gateway>
const server=Bun.serve({hostname:'127.0.0.1',port:10000,fetch(request){
  let origin='https://not-configured.invalid'
  try{
    const candidate=readFileSync('.local-hosting/origin.txt','utf8').trim()
    if(/^https:\/\/[a-z0-9-]+\.trycloudflare\.com$/.test(candidate))origin=candidate
  }catch{ /* API browser requests stay closed until the exact tunnel URL is saved. */ }
  if(!handler||origin!==lastOrigin){lastOrigin=origin;handler=gateway({dist:'dist',upstream:'http://127.0.0.1:8787',origin,localOrigins:['http://127.0.0.1:10000','http://localhost:10000']})}
  return handler(request)
}})
console.log('Production gateway listening on http://127.0.0.1:10000; reusing existing collector. Only dist and reviewed public API are served.')
const stop=()=>{server.stop(true);process.exit(0)}
process.once('SIGTERM',stop);process.once('SIGINT',stop)
