import { readFileSync } from 'node:fs'
import { createPublicClient, decodeEventLog, http, type Abi, type Address } from 'viem'
import { arcTestnet } from 'viem/chains'
import { EvidenceStore } from './store'
import { activationKey, enqueueHistory, queuedHistory, snapshotRecords } from './arkiv-outbox'
import { publicRecord, type HistoryKind } from '../../src/microcover/arkivRecords'
import { readArkiv } from './arkiv-reader'

async function main(){
  const [command,id,from]=process.argv.slice(2)
  const consumer=process.env.MICROCOVER_EVIDENCE_CONTRACT?.toLowerCase() as Address|undefined
  if(!consumer||!/^0x[0-9a-f]{40}$/.test(consumer)||!id||! /^[1-9]\d{0,17}$/.test(id))throw Error('USAGE_queue_OR_query_ID_FROM_BLOCK')
  if(command==='query'){
    console.log(JSON.stringify(await readArkiv(consumer,id,from as HistoryKind|undefined),null,2));return
  }
  if(command!=='queue'||!from||! /^\d+$/.test(from)||!process.env.MICROCOVER_EVIDENCE_HOME)throw Error('USAGE_queue_ID_FROM_BLOCK')
  const store=new EvidenceStore(process.env.MICROCOVER_EVIDENCE_HOME)
  try{
    const a=store.activations().find(a=>a.domain.consumer===consumer&&a.domain.guaranteeId===id)
    if(!a||Date.now()/1000<a.outcomeDeadline)throw Error('FROZEN_DEADLINE_SNAPSHOT_REQUIRED')
    const client=createPublicClient({chain:arcTestnet,transport:http('https://rpc.testnet.arc.io')})
    const abi=(JSON.parse(readFileSync('contracts/out/MicroCover.sol/MicroCover.json','utf8')) as {abi:Abi}).abi
    if(await client.getChainId()!==5042002||await client.readContract({address:consumer,abi,functionName:'protocolVersion'})!==3n)throw Error('ARC_DOMAIN_MISMATCH')
    const head=await client.getBlockNumber(),start=BigInt(from)
    if(start>head||head-start>100000n)throw Error('BOUNDED_SCAN_REQUIRED_MAX_100000_BLOCKS')
    const records=snapshotRecords(a,store.verified(activationKey(a)))
    const timestamps=new Map<bigint,number>()
    for(let block=start;block<=head;block+=1000n){
      const logs=await client.getLogs({address:consumer,fromBlock:block,toBlock:block+999n<head?block+999n:head})
      for(const log of logs){
        let decoded
        try{decoded=decodeEventLog({abi,data:log.data,topics:log.topics})}catch{continue}
        const args=decoded.args as unknown as Record<string,unknown>
        if(args.id!==BigInt(id))continue
        if(!timestamps.has(log.blockNumber))timestamps.set(log.blockNumber,Number((await client.getBlock({blockNumber:log.blockNumber})).timestamp))
        // Every reference is read from an actual Arc log; no local display strings/payloads.
        const publicArgs=JSON.parse(JSON.stringify(args,(_,v)=>typeof v==='bigint'?v.toString():v)) as unknown
        records.push(publicRecord(a,'ARC_EVENT',{schema:'microcover-arc-event-v1',domain:a.domain,event:decoded.eventName,
          transactionHash:log.transactionHash,blockNumber:String(log.blockNumber),logIndex:log.logIndex,receiptTimestamp:timestamps.get(log.blockNumber),args:publicArgs}))
      }
    }
    enqueueHistory(store,records)
    console.log(JSON.stringify({guaranteeId:id,source:'VERIFIED_LOCAL_RECEIPTS_AND_ARC_LOGS',queued:queuedHistory(store,consumer,id).length,writes:0,signatures:0}))
  }finally{store.close()}
}
main().catch(()=>{console.error('ARKIV_COMMAND_FAILED_CHECK_CONFIG_OR_NETWORK_NO_WRITE_ATTEMPTED');process.exitCode=1})
