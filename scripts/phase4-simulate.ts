import { mkdirSync, writeFileSync } from 'node:fs'
import { join, resolve } from 'node:path'
import { spawnSync } from 'node:child_process'

// Only simulation. No --broadcast flag, wallet import, secret read, or onchain write.
const root=resolve('workflows'), cli=join(process.env.LOCALAPPDATA??'', 'Programs/cre/cre.exe')
const mode=process.argv[2]??'success'
const ids:Record<string,string>={failure:'1',success:'2',uncertain:'3',unavailable:'2'}
if(!ids[mode])throw Error('USE_failure_success_uncertain_unavailable')
const id=ids[mode], config={schedule:'*/10 * * * * *',consumer:'0xdcd11bb347f063b5a876c8816f5a02b8ea0f11e0',guaranteeId:id,evidenceUrl:`http://127.0.0.1:8787/api/evidence/v1/guarantees/${id}/${mode==='unavailable'?'deliberately-unavailable':'snapshot'}`}
mkdirSync(join(root,'cre/out'),{recursive:true})
const configPath=join(root,'cre/out',`${mode}.json`)
writeFileSync(configPath,JSON.stringify(config,null,2)+'\n')
const globalModules=spawnSync('npm.cmd',['root','-g'],{encoding:'utf8',shell:true}).stdout.trim()
const result=spawnSync(cli,['workflow','simulate','cre','--target','local-simulation','--trigger-index','0','--non-interactive','--config',configPath],{
  cwd:root,encoding:'utf8',timeout:180000,maxBuffer:2_000_000,env:{...process.env,PATH:join(globalModules,'bun/bin')+';'+process.env.PATH},windowsHide:true,
})
const log=(result.stdout??'')+(result.stderr??'')
mkdirSync('docs/evidence/phase4',{recursive:true})
writeFileSync(`docs/evidence/phase4/${mode}.log`,log)
if(result.status!==0)throw Error(`CRE_SIMULATION_FAILED_${result.status}: see saved log`)
const marker='✓ Workflow Simulation Result:'
const encoded=log.split(marker)[1]?.trim().split(/\r?\n/)[0]
if(!encoded)throw Error('MISSING_SIMULATION_RESULT')
const decoded: unknown=JSON.parse(encoded)
if(typeof decoded!=='string')throw Error('INVALID_SIMULATION_RESULT')
const output=JSON.parse(decoded) as {evaluation?:{outcome:string;evidenceRoot:string};outcome?:string}
const expected={failure:'FAILURE',success:'SUCCESS',uncertain:'UNCERTAIN',unavailable:'UNCERTAIN'}[mode]
if((output.evaluation?.outcome??output.outcome)!==expected)throw Error('UNEXPECTED_CRE_OUTCOME')
let matchingPhase3Root: boolean|null=null
if(output.evaluation){
  const response=await fetch(`http://127.0.0.1:8787/api/evidence/v1/guarantees/${id}`)
  if(!response.ok)throw Error('COMPARISON_API_UNAVAILABLE')
  const phase3=await response.json() as {evaluation:{evidenceRoot:string;outcome:string}}
  matchingPhase3Root=phase3.evaluation.evidenceRoot===output.evaluation.evidenceRoot&&phase3.evaluation.outcome===output.evaluation.outcome
  if(!matchingPhase3Root)throw Error('CRE_PHASE3_DIVERGENCE')
}
writeFileSync(`docs/evidence/phase4/${mode}.json`,JSON.stringify({cli:'1.39.0',sdk:'1.23.0',exitCode:result.status,config,output,matchingPhase3Root,broadcast:false,chainWrites:false},null,2)+'\n')
console.log(`${mode}: CRE exit0, ${expected}, Phase3 comparison ${matchingPhase3Root??'not applicable'}, no broadcast`)
