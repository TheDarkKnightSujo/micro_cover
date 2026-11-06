/** Separate human-only helper. Never imported by the production app/config. */
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { readFileSync, writeFileSync, existsSync } from 'node:fs'
import { resolve, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { randomUUID } from 'node:crypto'
import { createPublicClient, http, type Hex } from 'viem'
import { arcTestnet } from 'viem/chains'
import { browserDeploymentReview } from './phase3-local'
import { EXPECTED_ACCOUNT, mayStart, type Attempt } from './local-deploy/model'

const root=resolve(dirname(fileURLToPath(import.meta.url)),'..')
const origin='http://127.0.0.1:5174'
const attemptPath=resolve(root,'contracts/out/phase3-local-browser-attempt.json')
const client=createPublicClient({chain:arcTestnet,transport:http('https://rpc.testnet.arc.io')})
const load=():Attempt|null=>existsSync(attemptPath)?JSON.parse(readFileSync(attemptPath,'utf8')) as Attempt:null
let claiming=false
export default defineConfig(({command})=>{
  if(command!=='serve')throw Error('Local deployment helper cannot be built or published')
  browserDeploymentReview() // Refuse stale/mismatched artifacts before opening a server.
  return {
    root:resolve(root,'scripts/local-deploy'),envDir:false,publicDir:false,
    plugins:[react(),{name:'local-deployment-only',configureServer(server){
      server.middlewares.use((req,res,next)=>{void (async()=>{
        if(!req.url?.startsWith('/__local/'))return next()
        res.setHeader('Cache-Control','no-store')
        res.setHeader('Content-Type','application/json')
        const reply=(code:number,value:unknown)=>{res.statusCode=code;res.end(JSON.stringify(value))}
        if(req.headers.host!=='127.0.0.1:5174'||(req.headers.origin&&req.headers.origin!==origin))return reply(403,{error:'Loopback origin only'})
        try {
          if(req.method==='GET'&&req.url==='/__local/review')return reply(200,browserDeploymentReview())
          if(req.method==='GET'&&req.url==='/__local/attempt')return reply(200,load())
          if(req.method!=='POST'||req.headers.origin!==origin||req.headers['content-type']!=='application/json')return reply(403,{error:'Same-origin JSON POST required'})
          let text='';for await(const chunk of req){text+=String(chunk);if(text.length>2048)throw Error('Request too large')}
          const body=JSON.parse(text) as {id?:string;hash?:string;code?:number}
          if(req.url==='/__local/start'){
            if(claiming||!mayStart(load()))return reply(409,{error:'Existing attempt: inspect the saved hash or wallet activity. No automatic retry.'})
            claiming=true
            try {
              const review=browserDeploymentReview()
              const [chain,latest,pending,code]=await Promise.all([client.getChainId(),client.getTransactionCount({address:EXPECTED_ACCOUNT}),client.getTransactionCount({address:EXPECTED_ACCOUNT,blockTag:'pending'}),client.getCode({address:EXPECTED_ACCOUNT})])
              if(chain!==5042002||latest!==20||pending!==20||(code&&code!=='0x'))throw Error('Sender nonce/code changed or pending transaction exists; inspect before deployment')
              const attempt:Attempt={id:randomUUID(),status:'wallet_requested',creationHash:review.creationHash,nonce:20}
              writeFileSync(attemptPath,JSON.stringify(attempt,null,2)+'\n')
              return reply(200,attempt)
            } finally {claiming=false}
          }
          const attempt=load()
          if(!attempt||attempt.id!==body.id)throw Error('Attempt ID mismatch')
          if(req.url==='/__local/hash'){
            if(!body.hash||!/^0x[0-9a-fA-F]{64}$/.test(body.hash)||attempt.status==='cancelled'||(attempt.hash&&attempt.hash!==body.hash))throw Error('Invalid transaction hash or attempt')
            attempt.hash=body.hash as Hex;attempt.status='submitted'
          } else if(req.url==='/__local/cancel'&&body.code===4001&&attempt.status==='wallet_requested')attempt.status='cancelled'
          else return reply(400,{error:'Unknown action; ambiguous errors leave deployment locked'})
          writeFileSync(attemptPath,JSON.stringify(attempt,null,2)+'\n');return reply(200,attempt)
        }catch(error){return reply(400,{error:error instanceof Error?error.message:'Local helper failed'})}
      })()})
    }}],
    resolve:{alias:{'@':resolve(root,'src')},dedupe:['react','react-dom']},
    server:{host:'127.0.0.1',port:5174,strictPort:true,cors:false,allowedHosts:['127.0.0.1'],fs:{allow:[root]}},
  }
})
