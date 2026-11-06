/** Read-only deployment preparation/verification. Never imports a signer or broadcasts. */
import { readFileSync, writeFileSync, existsSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { createPublicClient, http, encodeDeployData, formatUnits, getContractAddress, isAddress, keccak256, type Abi, type Address, type Hex } from 'viem'
import { arcTestnet } from 'viem/chains'

const RPC='https://rpc.testnet.arc.io'
const USDC='0x3600000000000000000000000000000000000000' as Address
const OPERATOR='0x1d39fc0e5293ab949d63217ffb375357adf3933f' as Address
const CHAIN=5042002
const ROOT=resolve(dirname(fileURLToPath(import.meta.url)),'..')
const ARTIFACT=resolve(ROOT,'contracts/out/MicroCover.sol/MicroCover.json')
const PLAN=resolve(ROOT,'contracts/out/phase3-local-plan.json')
const VERIFIED=resolve(ROOT,'contracts/out/phase3-local-verified.json')
const client=createPublicClient({chain:arcTestnet,transport:http(RPC,{timeout:30000,retryCount:1})})
const json=(v:unknown)=>JSON.stringify(v,(_key:string,value:unknown):unknown=>typeof value==='bigint'?value.toString():value,2)+'\n'
function requireCheck(ok:unknown,code:string):asserts ok { if(!ok)throw Error(code) }
interface Artifact {
  abi:Abi;bytecode:{object:Hex};deployedBytecode:{object:Hex;immutableReferences:Record<string,{start:number;length:number}[]>};
  metadata:{compiler:{version:string};settings:{optimizer:{enabled:boolean;runs:number};evmVersion:string};sources:Record<string,{keccak256:Hex}>}
}
interface Plan {
  kind:'UNSIGNED_LOCAL_PREFLIGHT';chainId:number;rpc:string;sender:Address;usdc:Address;operator:Address;reviewWindow:number;uncertaintyTimeout:number;
  constructorTypes:string[];creationHash:Hex;runtimeHash:Hex;expectedRuntime:Hex;sourceHashes:Record<string,Hex>;gasEstimate:string;gasLimit:string;estimatedFeePerGas:string;estimatedGasCostUSDC:string;nativeBalanceUSDC:string;observedBlock:string
}
function artifact():Artifact {
  const a=JSON.parse(readFileSync(ARTIFACT,'utf8')) as Artifact
  const constructor=a.abi.find(v=>v.type==='constructor')
  requireCheck(constructor?.type==='constructor'&&constructor.inputs.map(v=>v.type).join(',')==='address,address,uint64,uint64','WRONG_CONSTRUCTOR_ABI')
  requireCheck(a.metadata.compiler.version.startsWith('0.8.28+')&&a.metadata.settings.evmVersion==='cancun'&&a.metadata.settings.optimizer.enabled&&a.metadata.settings.optimizer.runs===200,'COMPILER_CONFIG_CHANGED')
  for(const [file,source] of Object.entries(a.metadata.sources)) {
    requireCheck(keccak256(new Uint8Array(readFileSync(resolve(ROOT,file))))===source.keccak256,'STALE_ARTIFACT_REBUILD_REQUIRED')
  }
  return a
}
const creation=(a:Artifact)=>encodeDeployData({abi:a.abi,bytecode:a.bytecode.object,args:[USDC,OPERATOR,120n,120n]})
/** Check every non-immutable byte and restrict each immutable group to its expected value. */
export function validateRuntime(template:Hex,actual:Hex,references:Artifact['deployedBytecode']['immutableReferences'],usdc=USDC,operator=OPERATOR):void {
  requireCheck(template.length===actual.length,'RUNTIME_LENGTH_MISMATCH')
  let patched=template.slice(2).toLowerCase()
  const remote=actual.slice(2).toLowerCase()
  const allowed=new Map([[usdc.slice(2).toLowerCase().padStart(64,'0'),1],[operator.slice(2).toLowerCase().padStart(64,'0'),1],[(120n).toString(16).padStart(64,'0'),2]])
  requireCheck(Object.keys(references).length===4,'UNEXPECTED_IMMUTABLE_LAYOUT')
  for(const slots of Object.values(references)) {
    requireCheck(slots.length>0,'EMPTY_IMMUTABLE_GROUP')
    const value=remote.slice(slots[0].start*2,(slots[0].start+32)*2)
    const count=allowed.get(value)??0
    requireCheck(count>0,'WRONG_IMMUTABLE_VALUE')
    allowed.set(value,count-1)
    for(const slot of slots) {
      requireCheck(slot.length===32&&remote.slice(slot.start*2,(slot.start+32)*2)===value,'INCONSISTENT_IMMUTABLE')
      patched=patched.slice(0,slot.start*2)+value+patched.slice((slot.start+32)*2)
    }
  }
  requireCheck([...allowed.values()].every(v=>v===0)&&patched===remote,'COMPILED_RUNTIME_MISMATCH')
}
async function network(){
  requireCheck(await client.getChainId()===CHAIN,'WRONG_RPC_CHAIN')
  requireCheck(await client.readContract({address:USDC,abi:[{type:'function',name:'decimals',stateMutability:'view',inputs:[],outputs:[{type:'uint8'}]}],functionName:'decimals'})===6,'WRONG_USDC_DECIMALS')
}
async function prepare(senderText:string|undefined){
  requireCheck(senderText&&isAddress(senderText),'PUBLIC_SENDER_ADDRESS_REQUIRED')
  await network()
  const a=artifact(),sender=senderText,data=creation(a)
  const block=await client.getBlock({blockTag:'latest'})
  const [gas,balance,fee,simulation]=await Promise.all([
    client.estimateGas({account:sender,data}),client.getBalance({address:sender}),client.getGasPrice(),client.call({account:sender,data,blockNumber:block.number}),
  ])
  requireCheck(simulation.data&&simulation.data!=='0x','CREATION_SIMULATION_DID_NOT_RETURN_RUNTIME')
  validateRuntime(a.deployedBytecode.object,simulation.data,a.deployedBytecode.immutableReferences)
  const limit=(gas*120n+99n)/100n
  requireCheck(balance>gas*fee,'INSUFFICIENT_NATIVE_TEST_USDC_FOR_ESTIMATED_GAS')
  const plan:Plan={kind:'UNSIGNED_LOCAL_PREFLIGHT',chainId:CHAIN,rpc:RPC,sender,usdc:USDC,operator:OPERATOR,reviewWindow:120,uncertaintyTimeout:120,
    constructorTypes:['address','address','uint64','uint64'],creationHash:keccak256(data),runtimeHash:keccak256(simulation.data),expectedRuntime:simulation.data,
    sourceHashes:Object.fromEntries(Object.entries(a.metadata.sources).map(([file,v])=>[file,v.keccak256])),gasEstimate:gas.toString(),gasLimit:limit.toString(),estimatedFeePerGas:fee.toString(),estimatedGasCostUSDC:formatUnits(gas*fee,18),nativeBalanceUSDC:formatUnits(balance,18),observedBlock:block.number.toString()}
  writeFileSync(PLAN,json(plan))
  const {expectedRuntime:_runtime,sourceHashes:_sources,...display}=plan
  console.log(json({...display,transactionValue:'0 USDC',broadcast:false,signingStep:'Human runs Foundry with browser wallet or encrypted keystore; review network, contract creation, zero value and gas fee before confirming. Fee estimate is not a maximum.'}))
}
/** Public deployment material only; consumed by the separate loopback Vite helper. */
export function browserDeploymentReview(){
  const a=artifact(),plan=JSON.parse(readFileSync(PLAN,'utf8')) as Plan,data=creation(a)
  requireCheck(plan.kind==='UNSIGNED_LOCAL_PREFLIGHT'&&plan.chainId===CHAIN&&plan.sender.toLowerCase()===OPERATOR.toLowerCase(),'WRONG_BROWSER_DEPLOYMENT_PLAN')
  requireCheck(plan.usdc.toLowerCase()===USDC.toLowerCase()&&plan.operator.toLowerCase()===OPERATOR.toLowerCase()&&plan.reviewWindow===120&&plan.uncertaintyTimeout===120,'WRONG_BROWSER_CONSTRUCTOR_SETTINGS')
  requireCheck(plan.creationHash===keccak256(data)&&Object.entries(a.metadata.sources).every(([file,v])=>plan.sourceHashes[file]===v.keccak256),'PLAN_SOURCE_OR_CREATION_CHANGED')
  validateRuntime(a.deployedBytecode.object,plan.expectedRuntime,a.deployedBytecode.immutableReferences)
  requireCheck(keccak256(plan.expectedRuntime)===plan.runtimeHash,'PLAN_RUNTIME_HASH_CHANGED')
  return {abi:a.abi,bytecode:a.bytecode.object,creationHash:plan.creationHash,runtimeHash:plan.runtimeHash,chainId:CHAIN,sender:OPERATOR,usdc:USDC,operator:OPERATOR,reviewWindow:120,uncertaintyTimeout:120}
}
async function verify(txText:string|undefined){
  requireCheck(txText&&/^0x[0-9a-fA-F]{64}$/.test(txText),'DEPLOYMENT_TRANSACTION_HASH_REQUIRED')
  await network()
  const a=artifact(),plan=JSON.parse(readFileSync(PLAN,'utf8')) as Plan,data=creation(a)
  requireCheck(plan.kind==='UNSIGNED_LOCAL_PREFLIGHT'&&plan.chainId===CHAIN&&plan.creationHash===keccak256(data),'PLAN_OR_SOURCE_CHANGED_REPREPARE_REQUIRED')
  requireCheck(Object.entries(a.metadata.sources).every(([file,v])=>plan.sourceHashes[file]===v.keccak256),'PLAN_SOURCE_HASH_CHANGED')
  const txHash=txText as Hex
  const [tx,receipt]=await Promise.all([client.getTransaction({hash:txHash}),client.getTransactionReceipt({hash:txHash})])
  requireCheck(receipt.status==='success','DEPLOYMENT_RECEIPT_FAILED')
  requireCheck(tx.chainId===CHAIN&&tx.to===null&&tx.from.toLowerCase()===plan.sender.toLowerCase()&&tx.value===0n,'WRONG_CREATION_DOMAIN_SENDER_OR_VALUE')
  requireCheck(tx.input.toLowerCase()===data.toLowerCase(),'CREATION_INPUT_OR_FOUR_CONSTRUCTOR_ARGUMENTS_MISMATCH')
  const address=receipt.contractAddress
  requireCheck(address&&address.toLowerCase()!== '0xa1e621497040d845fe4dc952dc524b88231ade16','MISSING_OR_HISTORICAL_CONTRACT_ADDRESS')
  requireCheck(getContractAddress({from:tx.from,nonce:BigInt(tx.nonce)}).toLowerCase()===address.toLowerCase(),'CREATE_ADDRESS_MISMATCH')
  const [block,latest,priorCode,code,latestCode]=await Promise.all([
    client.getBlock({blockNumber:receipt.blockNumber}),client.getBlockNumber(),client.getCode({address,blockNumber:receipt.blockNumber-1n}),client.getCode({address,blockNumber:receipt.blockNumber}),client.getCode({address}),
  ])
  requireCheck(block.hash===receipt.blockHash&&latest>=receipt.blockNumber+1n,'WAIT_FOR_CANONICAL_RECEIPT_AND_TWO_CONFIRMATIONS')
  requireCheck(!priorCode||priorCode==='0x','ADDRESS_ALREADY_HAD_CODE')
  requireCheck(code&&code!=='0x'&&code===latestCode&&code===plan.expectedRuntime&&keccak256(code)===plan.runtimeHash,'DEPLOYED_CODE_DOES_NOT_MATCH_SIMULATED_COMPILED_SOURCE')
  validateRuntime(a.deployedBytecode.object,code,a.deployedBytecode.immutableReferences)
  const names=['protocolVersion','usdc','demoOperator','reviewWindow','uncertaintyTimeout','MAX_COHORT','MAX_SETTLEMENT_BATCH','EVIDENCE_FRESHNESS','nextGuaranteeId']
  const expected=['3',USDC.toLowerCase(),OPERATOR.toLowerCase(),'120','120','100','20','60','1']
  const checks:Record<string,string>={}
  for(let i=0;i<names.length;i++) {
    const value=await client.readContract({address,abi:a.abi,functionName:names[i],blockNumber:receipt.blockNumber})
    const current=await client.readContract({address,abi:a.abi,functionName:names[i]})
    requireCheck(String(value).toLowerCase()===expected[i]&&String(current).toLowerCase()===expected[i],`CONFIGURATION_MISMATCH_${names[i]}`)
    checks[names[i]]=String(value)
  }
  const finalReceipt=await client.getTransactionReceipt({hash:txHash})
  requireCheck(finalReceipt.blockHash===receipt.blockHash,'RECEIPT_REORG_RETRY')
  const proof={kind:'READ_ONLY_LOCAL_DEPLOYMENT_VERIFICATION',chainId:CHAIN,rpc:RPC,address,transactionHash:txHash,sender:tx.from,receiptStatus:receipt.status,blockNumber:receipt.blockNumber,blockHash:receipt.blockHash,confirmations:latest-receipt.blockNumber+1n,
    exactCreationInputAndFourArgs:true,codeAbsentInPriorBlock:true,fullRuntimeMatch:true,runtimeBytes:(code.length-2)/2,runtimeKeccak256:keccak256(code),configuration:checks,creationHash:plan.creationHash,sourceHashes:plan.sourceHashes,studioReconciled:false,phase2Preserved:true}
  const proofPath=resolve(ROOT,`docs/evidence/phase3-deployment-${txHash.slice(2,14)}.json`)
  if(!existsSync(proofPath))writeFileSync(proofPath,json(proof),{flag:'wx'})
  writeFileSync(VERIFIED,json(proof))
  console.log(json(proof))
}
if(import.meta.main){
  const [command,arg]=process.argv.slice(2)
  const run=command==='prepare'?prepare(arg):command==='verify'?verify(arg):Promise.reject(Error('USE_prepare_PUBLIC_ADDRESS_OR_verify_TRANSACTION_HASH'))
  run.catch(e=>{console.error(e instanceof Error?e.message:'LOCAL_CHECK_FAILED');process.exitCode=1})
}
