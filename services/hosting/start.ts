import { existsSync } from 'node:fs'
import { join } from 'node:path'
import { serveEvidence } from '../evidence/server'
import { gateway } from './gateway'
import type { Address } from 'viem'

const directory=process.env.MICROCOVER_EVIDENCE_HOME
if(!directory||!directory.startsWith('/var/data/'))throw Error('PERSISTENT_DISK_PATH_REQUIRED')
if(process.env.MICROCOVER_EVIDENCE_CONTRACT?.toLowerCase()!=='0xdcd11bb347f063b5a876c8816f5a02b8ea0f11e0')throw Error('REVIEWED_PHASE3_ADDRESS_REQUIRED')
const files=['policy.json','evidence.sqlite','synthetic-status-a.pem','synthetic-status-b.pem']
// First boot serves the app while a human securely restores the existing store.
// Never generate replacement feed identities or silently create a new history.
const evidence=files.every(name=>existsSync(join(directory,name)))?serveEvidence(directory,process.env.MICROCOVER_EVIDENCE_CONTRACT as Address):undefined
const hostname=process.env.RENDER_EXTERNAL_HOSTNAME
const server=Bun.serve({hostname:'0.0.0.0',port:Number(process.env.PORT??10000),fetch:gateway({dist:'dist',upstream:evidence?'http://127.0.0.1:8787':undefined,origin:hostname?`https://${hostname}`:undefined})})
console.log(evidence?'MicroCover web and existing evidence store started; verify /readyz.':'MicroCover web started; restore existing evidence store securely, then restart. /readyz remains 503.')
const stop=()=>{server.stop(true);evidence?.stop();process.exit(0)}
process.once('SIGTERM',stop);process.once('SIGINT',stop)
