import { describe, expect, test } from 'bun:test'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { creationData, requireSigner, mayStart, EXPECTED_ACCOUNT, REVIEWED_CREATION_HASH, type Review, type Attempt } from '../../scripts/local-deploy/model'
import { browserDeploymentReview } from '../../scripts/phase3-local'
import { keccak256, type Hex, type Abi } from 'viem'

describe('human local deployment safety',()=>{
  test('exact Foundry artifact and all four arguments match the frozen review',()=>{
    const review=browserDeploymentReview()
    expect(keccak256(creationData(review))).toBe(REVIEWED_CREATION_HASH)
    const artifact=JSON.parse(readFileSync(resolve('contracts/out/MicroCover.sol/MicroCover.json'),'utf8')) as {bytecode:{object:Hex};abi:Abi}
    expect(review.bytecode).toBe(artifact.bytecode.object)
    expect(review.abi).toEqual(artifact.abi)
  })
  test('wrong chain, signer, token, timing and mutated code cannot be presented as approved',()=>{
    const review=browserDeploymentReview()
    for(const patch of [{chainId:1},{sender:'0x0000000000000000000000000000000000000001'},{operator:'0x0000000000000000000000000000000000000001'},{usdc:'0x0000000000000000000000000000000000000001'},{reviewWindow:121},{uncertaintyTimeout:121},{bytecode:review.bytecode+'00'},{creationHash:'0x'+'00'.repeat(32)},{abi:review.abi.filter(v=>v.type!=='constructor')}]){
      expect(()=>creationData({...review,...patch} as Review)).toThrow()
    }
    expect(()=>requireSigner(EXPECTED_ACCOUNT,5042002)).not.toThrow()
    expect(()=>requireSigner(EXPECTED_ACCOUNT,1)).toThrow()
    expect(()=>requireSigner(undefined,5042002)).toThrow()
    expect(()=>requireSigner('0x0000000000000000000000000000000000000001',5042002)).toThrow()
  })
  test('unresolved wallet requests and submitted hashes stay locked across page reload',()=>{
    const attempt:Attempt={id:'example',status:'wallet_requested',creationHash:REVIEWED_CREATION_HASH,nonce:20}
    expect(mayStart(null)).toBe(true)
    expect(mayStart(JSON.parse(JSON.stringify(attempt)) as Attempt)).toBe(false)
    expect(mayStart({...attempt,status:'submitted',hash:'0x'+'01'.repeat(32) as `0x${string}`})).toBe(false)
    expect(mayStart({...attempt,status:'cancelled'})).toBe(true)
  })
})
