import { readFileSync } from 'node:fs'
import { createPublicClient, type Abi, type Address } from 'viem'
import { arcTransport } from '../../src/arcTransport'
import { arcTestnet } from 'viem/chains'
import { hash, ZERO, type Activation, type Policy, type Hex } from './model'
import { EvidenceStore } from './store'
import { evaluate, prepareReport } from './evaluator'

export class ChainObserver {
  private client=createPublicClient({chain:arcTestnet,transport:arcTransport()})
  private abi:Abi
  constructor(readonly address:Address,private policy:Policy,private store:EvidenceStore){
    this.abi=(JSON.parse(readFileSync('contracts/out/MicroCover.sol/MicroCover.json','utf8')) as {abi:Abi}).abi
  }
  async read(name:string,args:readonly unknown[]=[]):Promise<unknown>{return this.client.readContract({address:this.address,abi:this.abi,functionName:name,args})}
  async check():Promise<void>{
    if(await this.client.getChainId()!==5042002)throw Error('WRONG_CHAIN')
    if(await this.read('protocolVersion')!==3n)throw Error('PHASE3_DEPLOYMENT_REQUIRED')
    const timeout=await this.read('uncertaintyTimeout')
    if(timeout!==120n)throw Error('DEMO_UNCERTAINTY_CONFIG_MISMATCH')
    if(String(await this.read('usdc')).toLowerCase()!=='0x3600000000000000000000000000000000000000')throw Error('WRONG_TOKEN')
  }
  async activate(id:bigint):Promise<Hex|undefined>{
    const terms=await this.read('getGuarantee',[id]) as {termsHash:Hex;settlementTime:bigint}
    const state=await this.read('getEvidenceState',[id]) as {policyHash:Hex;cohortId:Hex;createdAt:bigint}
    if(state.policyHash===ZERO)return undefined // legacy manual guarantee, no fabricated evidence binding
    if(state.policyHash!==hash(this.policy))throw Error('POLICY_KEYS_OR_RULES_MISMATCH')
    if(terms.termsHash!==this.policy.conditionHash)throw Error('CONDITION_POLICY_MISMATCH')
    const a:Activation={domain:{schema:'microcover-evidence-v1',chainId:'5042002',consumer:this.address.toLowerCase(),guaranteeId:id.toString(),cohortId:state.cohortId,conditionHash:terms.termsHash,policyHash:state.policyHash},policy:this.policy,activatedAt:Number(state.createdAt),outcomeDeadline:Number(terms.settlementTime)}
    return this.store.activate(a)
  }
  async discover():Promise<void>{
    await this.check()
    const next=await this.read('nextGuaranteeId') as bigint
    let cursor=BigInt(this.store.setting(`cursor:${this.address.toLowerCase()}`)??'1')
    for(let count=0;cursor<next&&count<25;cursor++,count++){
      try { await this.activate(cursor) }
      catch(error) {
        // Another provider's unsupported policy cannot block discovery/preparation for ours.
        // Transport/storage failures still retry this cursor and are never silently skipped.
        const code=error instanceof Error?error.message:''
        if(!['POLICY_KEYS_OR_RULES_MISMATCH','CONDITION_POLICY_MISMATCH'].includes(code))throw error
        this.store.setSetting(`unsupported:${this.address.toLowerCase()}:${cursor}`,code)
      }
      this.store.setSetting(`cursor:${this.address.toLowerCase()}`,(cursor+1n).toString())
    }
  }
  async prepare(id:bigint){
    await this.check()
    const key=await this.activate(id)
    if(!key)throw Error('NO_BOUND_EVIDENCE_POLICY')
    const block=await this.client.getBlock({blockTag:'latest'})
    const financial=await this.read('getState',[id]) as {status:number;outcome:number}
    if(financial.outcome!==0||![0,3,5].includes(financial.status))throw Error('FINANCIAL_OUTCOME_ALREADY_ESTABLISHED')
    const state=await this.read('getEvidenceState',[id]) as {nextVerdictNonce:bigint;anchorNonce:bigint;latestEvidenceRoot:Hex}
    const evaluation=evaluate(this.store,key,Number(block.timestamp))
    return{evaluation,report:prepareReport(evaluation,Number(block.timestamp),state.nextVerdictNonce),anchor:{id,root:evaluation.evidenceRoot,policyHash:evaluation.domain.policyHash,cohortId:evaluation.domain.cohortId,nonce:state.anchorNonce+1n},lastAnchoredRoot:state.latestEvidenceRoot}
  }
}
