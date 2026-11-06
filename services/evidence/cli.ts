import { isAddress, type Address } from 'viem'
import { initDemo, MODES } from './demo'
import { hash } from './model'
import { EvidenceStore, privateDirectory } from './store'
import { serveEvidence } from './server'

const directory=process.env.MICROCOVER_EVIDENCE_HOME
const command=process.argv[2]
async function main(){
  if(!directory)throw Error('SET_MICROCOVER_EVIDENCE_HOME_OUTSIDE_CHECKOUT')
  privateDirectory(directory)
  if(command==='init-demo'){
    const policy=initDemo(directory)
    console.log(JSON.stringify({policyHash:hash(policy),disclosure:policy.disclosure,privateKeys:'Generated locally outside checkout; never printed.'}))
  }else if(command==='serve'){
    const address=process.env.MICROCOVER_EVIDENCE_CONTRACT
    if(address&&!isAddress(address))throw Error('INVALID_CONTRACT_ADDRESS')
    const port=Number(process.env.MICROCOVER_EVIDENCE_PORT??'8787')
    if(port!==8787)throw Error('DEMO_PORT_MUST_BE_8787')
    const app=serveEvidence(directory,address as Address|undefined,port)
    console.log('Synthetic evidence service listening on http://127.0.0.1:8787; no wallet signing or transactions.')
    const stop=()=>{app.stop();process.exit(0)}
    process.once('SIGINT',stop);process.once('SIGTERM',stop)
  }else if(command==='set-mode'){
    const id=process.argv[3],mode=process.argv[4]
    if(!/^[1-9]\d{0,17}$/.test(id??'')||!MODES.includes(mode as typeof MODES[number]))throw Error('USAGE_set-mode_GUARANTEE_ID_MODE')
    const store=new EvidenceStore(directory)
    try{
      const address=process.env.MICROCOVER_EVIDENCE_CONTRACT?.toLowerCase()
      const a=store.activations().find(a=>a.domain.guaranteeId===id&&a.domain.consumer===address)
      if(!a)throw Error('WAIT_FOR_CHAIN_ACTIVATION_FIRST')
      if(mode==='stale'&&a.outcomeDeadline-a.activatedAt<=60)throw Error('WINDOW_TOO_SHORT_FOR_STALE_FIXTURE')
      store.setSetting(`fixture:${hash(a.domain)}`,mode)
      console.log(JSON.stringify({guaranteeId:id,mode,synthetic:true}))
    }finally{store.close()}
  }else throw Error('USAGE_init-demo_OR_serve_OR_set-mode')
}
main().catch(error=>{console.error(error instanceof Error&&/^[A-Za-z0-9_]+$/.test(error.message)?error.message:'EVIDENCE_COMMAND_FAILED');process.exitCode=1})
