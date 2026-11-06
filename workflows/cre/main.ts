import { CronCapability, EVMClient, HTTPClient, Runner, handler, encodeCallMsg, bytesToHex, prepareReportRequest, LAST_FINALIZED_BLOCK_NUMBER, consensusIdenticalAggregation, type Runtime, type HTTPSendRequester } from '@chainlink/cre-sdk'
import { decodeFunctionResult, encodeFunctionData, encodeAbiParameters, parseAbiParameters, zeroAddress, type Address, type Abi } from 'viem'
import { evaluateBoundSnapshot, type Snapshot, type Binding } from './snapshot'
import { prepareReport, type Evaluation } from '../../services/evidence/core'
import { consumerAbi } from './consumerAbi'

type Config = { schedule: string; consumer: Address; guaranteeId: string; evidenceUrl: string }
function fetchSnapshot(requester: HTTPSendRequester, url: string, binding: Binding, now: number): string {
  const response=requester.sendRequest({url,method:'GET'}).result()
  if(response.statusCode!==200)throw Error('EVIDENCE_HTTP_UNAVAILABLE')
  const snapshot=JSON.parse(new TextDecoder().decode(response.body)) as Snapshot
  // Evaluate in node mode; consensus observes only the compact decision/root,
  // not a receipt log that can exceed CRE's 25kb consensus observation limit.
  return JSON.stringify(evaluateBoundSnapshot(snapshot,binding,now))
}
function onCron(runtime: Runtime<Config>): string {
  const c=runtime.config
  if(!/^0x[0-9a-f]{40}$/.test(c.consumer)||!/^\d+$/.test(c.guaranteeId))throw Error('INVALID_CONFIG')
  const evm=new EVMClient(3034092155422581607n) // Official Arc Testnet selector.
  const read=(name:string,args:readonly unknown[]=[])=>{
    const result=evm.callContract(runtime,{call:encodeCallMsg({from:zeroAddress,to:c.consumer,data:encodeFunctionData({abi:consumerAbi as Abi,functionName:name,args})}),blockNumber:LAST_FINALIZED_BLOCK_NUMBER}).result()
    return decodeFunctionResult({abi:consumerAbi as Abi,functionName:name,data:bytesToHex(result.data)})
  }
  if(read('protocolVersion')!==3n||String(read('usdc')).toLowerCase()!=='0x3600000000000000000000000000000000000000')throw Error('WRONG_PROTOCOL')
  const id=BigInt(c.guaranteeId)
  const terms=read('getGuarantee',[id]) as {termsHash:`0x${string}`;settlementTime:bigint}
  const evidence=read('getEvidenceState',[id]) as {policyHash:`0x${string}`;cohortId:`0x${string}`;createdAt:bigint;nextVerdictNonce:bigint}
  try {
    const evaluatedAt=Math.floor(runtime.now().getTime()/1000)
    const binding={consumer:c.consumer,guaranteeId:c.guaranteeId,cohortId:evidence.cohortId,policyHash:evidence.policyHash,conditionHash:terms.termsHash,createdAt:Number(evidence.createdAt),outcomeDeadline:Number(terms.settlementTime)}
    const raw=new HTTPClient().sendRequest(runtime,fetchSnapshot,consensusIdenticalAggregation<string>())(c.evidenceUrl,binding,evaluatedAt).result()
    const e=JSON.parse(raw) as Evaluation
    const report=e.outcome==='UNCERTAIN'?null:prepareReport(e,evaluatedAt,evidence.nextVerdictNonce)
    const payload=report?encodeAbiParameters(parseAbiParameters('(uint256 chainId,address consumer,uint256 guaranteeId,bytes32 cohortId,bytes32 policyHash,bytes32 evidenceRoot,uint8 outcome,uint64 evaluatedAt,uint64 validUntil,uint256 nonce)'),[report]):null
    const simulatedReport=payload?runtime.report(prepareReportRequest(payload)).result():null
    const result=JSON.stringify({schema:'microcover-cre-simulation-v1',mode:'READ_ONLY_SIMULATION',evaluation:e,report,receiverPayload:payload,simulationReport:simulatedReport?bytesToHex(simulatedReport.rawReport()):null,nextVerdictNonce:evidence.nextVerdictNonce.toString(),evaluatedAt,validUntil:evaluatedAt+60,authority:'Simulation report only, not production DON authentication. No onchain write. Existing human demo operator must separately review and sign.'},(_,v)=>typeof v==='bigint'?v.toString():v)
    runtime.log(result)
    return result
  }catch {
    const result=JSON.stringify({schema:'microcover-cre-simulation-v1',mode:'READ_ONLY_SIMULATION',chainId:'5042002',consumer:c.consumer,guaranteeId:c.guaranteeId,outcome:'UNCERTAIN',reason:'EVIDENCE_UNAVAILABLE_OR_INVALID',report:null})
    runtime.log(result);return result
  }
}
export async function main(){const runner=await Runner.newRunner<Config>();await runner.run(c=>[handler(new CronCapability().trigger({schedule:c.schedule}),onCron)])}
