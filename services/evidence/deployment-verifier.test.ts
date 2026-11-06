import { expect, test } from 'bun:test'
import type { Hex } from 'viem'
import { validateRuntime } from '../../scripts/phase3-local'

test('deployment runtime verification rejects changed executable bytes and incorrect immutable bindings',()=>{
  const references={a:[{start:0,length:32},{start:128,length:32}],b:[{start:32,length:32}],c:[{start:64,length:32}],d:[{start:96,length:32}]}
  const usdc='3600000000000000000000000000000000000000'.padStart(64,'0')
  const operator='1d39fc0e5293ab949d63217ffb375357adf3933f'.padStart(64,'0')
  const seconds='78'.padStart(64,'0')
  const template=('0x'+'00'.repeat(160)+'6001600055') as Hex
  const runtime=('0x'+usdc+operator+seconds+seconds+usdc+'6001600055') as Hex
  expect(()=>validateRuntime(template,runtime,references)).not.toThrow()
  expect(()=>validateRuntime(template,(runtime.slice(0,-2)+'56') as Hex,references)).toThrow('COMPILED_RUNTIME_MISMATCH')
  expect(()=>validateRuntime(template,runtime.replace(seconds,'79'.padStart(64,'0')) as Hex,references)).toThrow('WRONG_IMMUTABLE_VALUE')
  expect(()=>validateRuntime(template,(runtime.slice(0,2+128*2)+operator+'6001600055') as Hex,references)).toThrow('INCONSISTENT_IMMUTABLE')
  expect(()=>validateRuntime(template,runtime.replace(operator,usdc) as Hex,references)).toThrow('WRONG_IMMUTABLE_VALUE')
  expect(()=>validateRuntime(template,('0x'+runtime.slice(2,-2)) as Hex,references)).toThrow('RUNTIME_LENGTH_MISMATCH')
})
