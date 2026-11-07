import { resolve, sep } from 'node:path'

// Expose only the reviewed public API, never the fixture signer or local files.
export function gateway(options:{dist:string;upstream?:string;origin?:string;localOrigins?:readonly string[];fetchUpstream?:typeof fetch}) {
  const root=resolve(options.dist)
  let windowStart=Date.now(),requests=0
  return async(request:Request):Promise<Response>=>{
    const url=new URL(request.url)
    const headers={'cache-control':'no-store','x-content-type-options':'nosniff','referrer-policy':'strict-origin-when-cross-origin'}
    const reply=(body:string,status:number)=>new Response(body,{status,headers})
    if(url.pathname==='/healthz')return reply('MicroCover web process running',200)
    if(url.pathname==='/readyz'){
      if(!options.upstream)return reply('Evidence storage restore required',503)
      try{
        const res=await(options.fetchUpstream??fetch)(options.upstream+'/api/evidence/v1/health',{signal:AbortSignal.timeout(3000)})
        const data=await res.json() as {chainError?:string}
        return reply(res.ok&&data.chainError===''?'ready':'Evidence chain check unavailable',res.ok&&data.chainError===''?200:503)
      }catch{return reply('Evidence unavailable',503)}
    }
    if(url.pathname.startsWith('/api/')){
      const origin=request.headers.get('origin')
      if(origin&&origin!==(options.origin??url.origin)&&!options.localOrigins?.includes(origin))return reply('Origin not allowed',403)
      const presentationPath=/^\/api\/evidence\/v1\/presentations(?:\/[1-9]\d{0,17})?$/.test(url.pathname)
      const allowedRead=presentationPath||/^\/api\/evidence\/v1\/(health|policy|guarantees\/[1-9]\d{0,17}(\/(prepare|snapshot|cre))?)$/.test(url.pathname)||/^\/api\/arkiv\/v1\/guarantees\/[1-9]\d{0,17}(\/queue)?$/.test(url.pathname)
      const allowedPost=(url.pathname==='/api/arkiv/v1/rpc'||url.pathname==='/api/evidence/v1/presentations')&&request.method==='POST'
      if(!(allowedRead&&request.method==='GET')&&!allowedPost)return reply('Not permitted',405)
      if(!options.upstream)return reply('Evidence storage restore required',503)
      // Global budget also limits callers that rotate/spoof proxy IP headers.
      if(Date.now()-windowStart>=60000){windowStart=Date.now();requests=0}
      if(++requests>600)return reply('Retry later',429)
      let body:string|undefined
      if(allowedPost){
        if(!request.headers.get('content-type')?.startsWith('application/json'))return reply('JSON required',415)
        if(Number(request.headers.get('content-length'))>2000000)return reply('Body too large',413)
        const reader=request.body?.getReader();const parts:Uint8Array[]=[];let size=0
        if(reader)for(;;){const chunk=await reader.read();if(chunk.done)break;size+=chunk.value.length;if(size>2000000){await reader.cancel();return reply('Body too large',413)}parts.push(chunk.value)}
        body=await new Blob(parts as BlobPart[]).text()
      }
      try{
        // No cookies, browser Origin, authorization, Host or arbitrary headers reach loopback.
        const res=await(options.fetchUpstream??fetch)(options.upstream+url.pathname+url.search,{method:request.method,body,headers:body?{'content-type':'application/json'}:{},signal:AbortSignal.timeout(25000)})
        return new Response(res.body,{status:res.status,headers:{...headers,'content-type':'application/json'}})
      }catch{return reply('Evidence unavailable',503)}
    }
    if(request.method!=='GET'&&request.method!=='HEAD')return reply('Not permitted',405)
    let path:string
    try{path=decodeURIComponent(url.pathname)}catch{return reply('Invalid path',400)}
    if(path.split(/[\\/]/).some(p=>p.startsWith('.')||p.includes('\0')))return reply('Not found',404)
    const target=resolve(root,'.'+path)
    if(!target.startsWith(root+sep)){
      if(path!=='/')return reply('Not found',404)
    }
    const file=Bun.file(path==='/'?resolve(root,'index.html'):target)
    if(!await file.exists())return reply('Not found',404)
    return new Response(request.method==='HEAD'?null:file,{headers:{...headers,'content-type':file.type,'cache-control':path.startsWith('/assets/')?'public, max-age=31536000, immutable':'no-cache'}})
  }
}
