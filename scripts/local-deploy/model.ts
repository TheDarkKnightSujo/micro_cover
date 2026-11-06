import { encodeDeployData, keccak256, type Abi, type Address, type Hex } from 'viem'

export const EXPECTED_ACCOUNT='0x1d39fc0e5293ab949d63217ffb375357adf3933f' as Address
export const EXPECTED_USDC='0x3600000000000000000000000000000000000000' as Address
export const REVIEWED_CREATION_HASH='0x3ad431344208f00e3c12cce7b6a20baf54c775a5872e5765c2ca8fc2ce28cb1a'
export interface Review {abi:Abi;bytecode:Hex;creationHash:Hex;runtimeHash:Hex;chainId:number;sender:Address;usdc:Address;operator:Address;reviewWindow:number;uncertaintyTimeout:number}
export interface Attempt {id:string;status:'wallet_requested'|'submitted'|'cancelled';creationHash:Hex;nonce:number;hash?:Hex}
export function creationData(review:Review):Hex {
  if(review.chainId!==5042002||review.sender.toLowerCase()!==EXPECTED_ACCOUNT||review.operator.toLowerCase()!==EXPECTED_ACCOUNT||review.usdc.toLowerCase()!==EXPECTED_USDC||review.reviewWindow!==120||review.uncertaintyTimeout!==120)throw Error('Unapproved deployment settings')
  const constructor=review.abi.find(v=>v.type==='constructor')
  if(constructor?.type!=='constructor'||constructor.inputs.map(v=>v.type).join(',')!=='address,address,uint64,uint64')throw Error('Wrong artifact constructor')
  const data=encodeDeployData({abi:review.abi,bytecode:review.bytecode,args:[review.usdc,review.operator,120n,120n]})
  if(keccak256(data)!==review.creationHash||review.creationHash!==REVIEWED_CREATION_HASH)throw Error('Creation data does not match the reviewed Foundry artifact')
  return data
}
export function requireSigner(address:string|undefined,chain:number|undefined){
  if(address?.toLowerCase()!==EXPECTED_ACCOUNT||chain!==5042002)throw Error('Connect expected Account 1 on Arc Testnet 5042002')
}
export function mayStart(attempt:Attempt|null){return !attempt||attempt.status==='cancelled'}
