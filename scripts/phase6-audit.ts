import { readFileSync, writeFileSync, mkdirSync } from 'node:fs'
import { execFileSync } from 'node:child_process'
import { createPublicClient, http, keccak256, parseAbi, type Abi, type Address, type Hex } from 'viem'
import { validateRuntime } from './phase3-local'
import { checkHistory, loadArkivHistory } from '../src/microcover/arkivClient'
import type { GuaranteeView } from '../src/microcover/useGuarantee'

// Read-only audit of the existing demo. No wallet transport or transaction method.
const address='0xdcd11bb347f063b5a876c8816f5a02b8ea0f11e0' as Address
const usdc='0x3600000000000000000000000000000000000000' as Address
const operator='0x1d39fc0e5293ab949d63217ffb375357adf3933f'
const artifact=JSON.parse(readFileSync('contracts/out/MicroCover.sol/MicroCover.json','utf8')) as {
  abi:Abi;metadata:{sources:Record<string,{keccak256:Hex}>};
  deployedBytecode:{object:Hex;immutableReferences:Parameters<typeof validateRuntime>[2]}
}
for(const [file,source] of Object.entries(artifact.metadata.sources)){
  if(keccak256(new Uint8Array(readFileSync(file)))!==source.keccak256)throw Error(`STALE_ARTIFACT: ${file}`)
}
const client=createPublicClient({transport:http('https://rpc.testnet.arc.io')})
if(await client.getChainId()!==5042002)throw Error('WRONG_CHAIN')
const block=await client.getBlock()
const read=(functionName:string,args:readonly unknown[]=[]):Promise<unknown>=>client.readContract({address,abi:artifact.abi,functionName,args,blockNumber:block.number})
const code=await client.getCode({address,blockNumber:block.number})
if(!code)throw Error('NO_RUNTIME')
validateRuntime(artifact.deployedBytecode.object,code,artifact.deployedBytecode.immutableReferences)
const configuration:Record<string,unknown>=Object.fromEntries(await Promise.all(['protocolVersion','usdc','demoOperator','reviewWindow','uncertaintyTimeout','nextGuaranteeId'].map(async name=>[name,await read(name)]))) as Record<string,unknown>
if(configuration.protocolVersion!==3n||String(configuration.usdc).toLowerCase()!==usdc||String(configuration.demoOperator).toLowerCase()!==operator||configuration.reviewWindow!==120n||configuration.uncertaintyTimeout!==120n||configuration.nextGuaranteeId!==4n)throw Error('DEMO_CONFIGURATION_CHANGED')
const guarantees=[]
let obligations=0n
for(const id of [1n,2n,3n]){
  const terms=await read('getGuarantee',[id]) as {termsHash:Hex;settlementTime:bigint}
  const state=await read('getState',[id]) as {status:number;outcome:number;bondHeld:bigint;escrowHeld:bigint;reservedCompensation:bigint}
  const evidence=await read('getEvidenceState',[id]) as Pick<GuaranteeView,'policyHash'|'cohortId'|'createdAt'|'latestEvidenceRoot'>
  const response=await fetch(`http://127.0.0.1:8787/api/evidence/v1/guarantees/${id}`)
  if(!response.ok)throw Error('EVIDENCE_UNAVAILABLE')
  const collected=await response.json() as {evaluation:{outcome:string;evidenceRoot:Hex}}
  const expected=['FAILURE','SUCCESS','UNCERTAIN'][Number(id)-1]
  const capture=JSON.parse(readFileSync(`docs/evidence/phase4/${['failure','success','uncertain'][Number(id)-1]}.json`,'utf8')) as {output:{evaluation:{outcome:string;evidenceRoot:Hex}}}
  if(state.status!==2||state.outcome!==Number(id)||state.bondHeld!==0n||state.escrowHeld!==0n||state.reservedCompensation!==0n)throw Error(`UNSETTLED_DEMO_${id}`)
  if(collected.evaluation.outcome!==expected||capture.output.evaluation.outcome!==expected||capture.output.evaluation.evidenceRoot!==collected.evaluation.evidenceRoot)throw Error(`CRE_SNAPSHOT_DIVERGENCE_${id}`)
  obligations+=state.bondHeld+state.escrowHeld
  guarantees.push({id,terms,state,evidence,evaluation:collected.evaluation,capturedCreMatches:true})
}
const balance=await client.readContract({address:usdc,abi:parseAbi(['function balanceOf(address) view returns(uint256)']),functionName:'balanceOf',args:[address],blockNumber:block.number})
if(balance!==obligations)throw Error('LEDGER_MISMATCH')
const live=await loadArkivHistory('2'),g=guarantees[1]
const integrity=checkHistory(live.rows.map(r=>r.record),address,{...g.evidence,forId:2n,termsHash:g.terms.termsHash,settlementTime:g.terms.settlementTime} as GuaranteeView)
if(live.rows.length!==19||!integrity.anchored||integrity.outcome!=='SUCCESS')throw Error('ARKIV_DIVERGENCE')
const git=(args:string[])=>execFileSync('git',args,{encoding:'utf8'}).trim()
const files=git(['ls-files','--cached','--others','--exclude-standard','-z']).split('\0').filter(Boolean).sort()
const sourceFingerprint=keccak256(new TextEncoder().encode(files.filter(f=>!f.startsWith('docs/evidence/phase6/')).map(f=>`${f}:${keccak256(new Uint8Array(readFileSync(f)))}`).join('\n')))
const proof={verifiedAt:new Date().toISOString(),baseCommit:git(['rev-parse','HEAD']),dirty:!!git(['status','--porcelain']),sourceFingerprint,chainId:5042002,address,block:block.number,configuration,runtimeHash:keccak256(code),guarantees,balance,obligations,arkiv:{count:live.rows.length,root:integrity.evidenceRoot,anchorMatches:true,query:live.query},broadcast:false,studioReconciled:false,publicHostingVerified:false}
mkdirSync('docs/evidence/phase6',{recursive:true})
writeFileSync('docs/evidence/phase6/live-audit.json',JSON.stringify(proof,(_:string,v:unknown)=>typeof v==='bigint'?v.toString():v,2)+'\n')
console.log(JSON.stringify({block:String(block.number),closedGuarantees:3,balance:String(balance),obligations:String(obligations),arkivEntities:live.rows.length,capturedCreMatches:true,broadcast:false}))
