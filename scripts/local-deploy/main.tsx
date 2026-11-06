import { useEffect, useRef, useState } from 'react'
import { createRoot } from 'react-dom/client'
import { WagmiProvider, useAccount, useWalletClient, useSwitchChain } from 'wagmi'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { ConnectKitProvider, ConnectKitButton } from 'connectkit'
import { createPublicClient, http, keccak256, formatUnits, type Hex } from 'viem'
import { arcTestnet } from 'viem/chains'
import { config } from '../../src/config'
import { creationData, EXPECTED_ACCOUNT, requireSigner, mayStart, type Review, type Attempt } from './model'
import './style.css'

const rpc=createPublicClient({chain:arcTestnet,transport:http('https://rpc.testnet.arc.io')})
const storageKey='microcover-phase3-local-deployment-hash'
async function api<T>(path:string,body?:unknown):Promise<T>{
  const response=await fetch(`/__local/${path}`,body===undefined?{cache:'no-store'}:{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)})
  const data:unknown=await response.json()
  if(!response.ok)throw Error(String(data&&typeof data==='object'&&'error' in data?data.error:'Local server unavailable'))
  return data as T
}
function rejected(error:unknown):boolean {
  const seen=new Set<unknown>();let current=error
  while(current&&typeof current==='object'&&!seen.has(current)){
    seen.add(current)
    if('code' in current&&current.code===4001)return true
    current='cause' in current?current.cause:undefined
  }
  return false
}
function Deployment(){
  const account=useAccount(),wallet=useWalletClient(),switcher=useSwitchChain()
  const [material,setMaterial]=useState<Review>()
  const [attempt,setAttempt]=useState<Attempt|null>(null)
  const [loaded,setLoaded]=useState(false)
  const [hash,setHash]=useState<Hex>()
  const [estimate,setEstimate]=useState<{gas:bigint;limit:bigint;fee:bigint;at:number}>()
  const [accepted,setAccepted]=useState(false)
  const [busy,setBusy]=useState(false)
  const [message,setMessage]=useState('Loading reviewed deployment material…')
  const [saveError,setSaveError]=useState(false)
  const inFlight=useRef(false)
  useEffect(()=>{
    void Promise.all([api<Review>('review'),api<Attempt|null>('attempt')]).then(([review,saved])=>{
      creationData(review);setMaterial(review);setAttempt(saved)
      const local=localStorage.getItem(storageKey)
      if(saved?.hash)setHash(saved.hash)
      else if(local&&/^0x[0-9a-fA-F]{64}$/.test(local))setHash(local as Hex)
      setLoaded(true);setMessage('Connect Account 1 on Arc Testnet, then run the unsigned review.')
    }).catch(e=>setMessage(String(e)))
  },[])
  const signerReady=account.address?.toLowerCase()===EXPECTED_ACCOUNT&&account.chainId===5042002&&!!wallet.data
  const locked=!loaded||!mayStart(attempt)||!!hash
  const review=async()=>{
    if(inFlight.current||locked||!material)return
    inFlight.current=true;setBusy(true);setEstimate(undefined);setAccepted(false)
    try{
      requireSigner(account.address,account.chainId)
      const data=creationData(material)
      const [chain,nonce,pending,gas,fee,result,balance]=await Promise.all([
        rpc.getChainId(),rpc.getTransactionCount({address:EXPECTED_ACCOUNT}),rpc.getTransactionCount({address:EXPECTED_ACCOUNT,blockTag:'pending'}),
        rpc.estimateGas({account:EXPECTED_ACCOUNT,data,value:0n}),rpc.getGasPrice(),rpc.call({account:EXPECTED_ACCOUNT,data,value:0n}),rpc.getBalance({address:EXPECTED_ACCOUNT}),
      ])
      if(chain!==5042002||nonce!==20||pending!==20)throw Error('Nonce changed or a pending transaction exists. Stop and inspect; nothing sent.')
      if(!result.data||keccak256(result.data)!==material.runtimeHash)throw Error('Unsigned runtime simulation mismatch')
      const limit=(gas*120n+99n)/100n
      if(balance<limit*fee)throw Error('Insufficient native test USDC for reviewed gas limit estimate')
      setEstimate({gas,limit,fee,at:Date.now()});setMessage('Unsigned review passed. Review every setting, then explicitly deploy and confirm personally in MetaMask.')
    }catch(e){setMessage(String(e))}finally{inFlight.current=false;setBusy(false)}
  }
  const saveHash=async(id:string,txHash:Hex)=>{
    try{setAttempt(await api<Attempt>('hash',{id,hash:txHash}));setSaveError(false)}
    catch{setSaveError(true);setMessage('Transaction hash received. Server save failed: copy/download the hash now. Do not deploy again.')}
  }
  const deploy=async()=>{
    if(inFlight.current||locked||!material||!estimate||!accepted||!wallet.data)return
    inFlight.current=true;setBusy(true)
    let started:Attempt|undefined
    let submitted=false
    try{
      requireSigner(account.address,account.chainId)
      const addresses=await wallet.data.getAddresses()
      requireSigner(addresses[0],await wallet.data.getChainId())
      creationData(material)
      if(Date.now()-estimate.at>60000)throw Error('Unsigned review expired. Run it again before deployment.')
      started=await api<Attempt>('start',{});setAttempt(started)
      setMessage('One deployment request is being sent to MetaMask. Personally review and confirm, or cancel. Do not reload or retry.')
      const txHash=await wallet.data.deployContract({abi:material.abi,bytecode:material.bytecode,args:[material.usdc,material.operator,120n,120n],account:EXPECTED_ACCOUNT,chain:arcTestnet,value:0n,gas:estimate.limit,nonce:20})
      submitted=true;setHash(txHash)
      setMessage('Transaction hash received; deployment is NOT independently verified. Copy it for the read-only verifier. Main app configuration is unchanged.')
      try{localStorage.setItem(storageKey,txHash)}catch{setMessage('Hash received. Browser storage failed; copy/download it now. Deployment remains locked.')}
      await saveHash(started.id,txHash)
    }catch(e){
      if(started&&!submitted&&rejected(e)){
        try{setAttempt(await api<Attempt>('cancel',{id:started.id,code:4001}));setMessage('Cancelled in MetaMask. No successful submission claimed.')}
        catch{setMessage('Cancellation could not be saved. Attempt remains locked; inspect before any retry.')}
      }else setMessage(`${String(e)}${started?' Attempt remains locked: inspect wallet/activity and transaction records before any retry.':''}`)
    }finally{setEstimate(undefined);setAccepted(false);inFlight.current=false;setBusy(false)}
  }
  const download=()=>{
    if(!hash)return
    const url=URL.createObjectURL(new Blob([JSON.stringify({transactionHash:hash,chainId:5042002,sender:EXPECTED_ACCOUNT,creationHash:material?.creationHash,verified:false},null,2)],{type:'application/json'}))
    const link=document.createElement('a');link.href=url;link.download='microcover-phase3-deployment-submission.json';link.click();URL.revokeObjectURL(url)
  }
  return <main><h1>Local Phase 3 deployment</h1><p>This temporary helper uses the reviewed Foundry artifact. It never changes the main app address. Arc Testnet only.</p>
    <ConnectKitButton/><p>Connected: {account.address??'none'} · chain {account.chainId??'none'}</p>
    {account.isConnected&&account.chainId!==5042002&&<button onClick={()=>switcher.switchChain({chainId:5042002})}>Switch to Arc Testnet</button>}
    <dl><dt>Network</dt><dd>Arc Testnet · 5042002</dd><dt>Required sender / immutable demo operator</dt><dd>{EXPECTED_ACCOUNT}</dd><dt>USDC constructor argument</dt><dd>0x3600000000000000000000000000000000000000</dd><dt>Success review / separate uncertainty timeout</dt><dd>120 seconds / 120 seconds</dd><dt>Transaction value</dt><dd>0 USDC (gas fee only)</dd><dt>Encoded creation-data hash</dt><dd>{material?.creationHash??'Not verified'}</dd><dt>Expected nonce</dt><dd>20; any change blocks this helper</dd>
    <dt>Gas estimate / gas limit (20% margin)</dt><dd>{estimate?`${estimate.gas} / ${estimate.limit}`:'Run unsigned review'}</dd><dt>Estimated fee using gas limit</dt><dd>{estimate?`${formatUnits(estimate.limit*estimate.fee,18)} native test USDC; MetaMask shows the final fee`:'Not estimated'}</dd></dl>
    <button disabled={!signerReady||locked||busy} onClick={()=>void review()}>1. Run unsigned review</button>
    <label><input type="checkbox" checked={accepted} disabled={!estimate||locked||busy} onChange={e=>setAccepted(e.target.checked)}/>I reviewed the network, sender, four constructor arguments, creation hash, value and gas estimate.</label>
    <button disabled={!signerReady||locked||busy||!estimate||!accepted} onClick={()=>void deploy()}>2. Deploy — confirm personally in MetaMask</button>
    <p role="status">{message}</p>
    {attempt&&!mayStart(attempt)&&<p>Saved attempt: {attempt.status}. Deployment stays locked across reloads and tabs.</p>}
    {hash&&<section><h2>Submitted transaction — verification pending</h2><p className="hash">{hash}</p><a href={`https://testnet.arcscan.app/tx/${hash}`} target="_blank" rel="noreferrer">View transaction</a><button onClick={()=>void navigator.clipboard.writeText(hash)}>Copy hash</button><button onClick={download}>Download submission record</button>{saveError&&attempt&&<button onClick={()=>void saveHash(attempt.id,hash)}>Retry saving this hash only</button>}<p>Send this hash to the agent for receipt, creation-input, runtime and configuration verification. Do not fund or use the new contract yet.</p></section>}
  </main>
}
createRoot(document.getElementById('root')!).render(<WagmiProvider config={config}><QueryClientProvider client={new QueryClient()}><ConnectKitProvider><Deployment/></ConnectKitProvider></QueryClientProvider></WagmiProvider>)
