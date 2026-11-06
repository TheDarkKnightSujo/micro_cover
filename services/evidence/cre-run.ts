/** A local, unsigned execution record. This is not a verified CRE network report. */
export function publicCreRun(value: unknown, consumer: string, id: string) {
  const r=value as {exitCode?:number;broadcast?:boolean;chainWrites?:boolean;matchingPhase3Root?:boolean;output?:{mode?:string;evaluatedAt?:number;evaluation?:{outcome?:string;evidenceRoot?:string;domain?:{chainId?:string;consumer?:string;guaranteeId?:string}}}}
  const e=r?.output?.evaluation,d=e?.domain
  if(r?.exitCode!==0||r.broadcast!==false||r.chainWrites!==false||r.matchingPhase3Root!==true||r.output?.mode!=='READ_ONLY_SIMULATION'||
    d?.chainId!=='5042002'||d.consumer?.toLowerCase()!==consumer.toLowerCase()||d.guaranteeId!==id||
    !['SUCCESS','FAILURE','UNCERTAIN'].includes(e?.outcome??'')||!/^0x[0-9a-f]{64}$/.test(e?.evidenceRoot??'')||!Number.isSafeInteger(r.output.evaluatedAt))throw Error('NO_MATCHING_CRE_RUN')
  return {mode:'LOCAL_CLI_SIMULATION' as const,outcome:e!.outcome!,evidenceRoot:e!.evidenceRoot!,evaluatedAt:r.output.evaluatedAt!,verifiedNetworkReport:false as const,chainWrites:false as const}
}
