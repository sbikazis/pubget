import { getGoogleAccessToken, verifyFirebaseIdToken } from "./firebaseAuth";

export interface StorageMigrationEnv {
  MEDIA_BUCKET: R2Bucket;
  FIREBASE_PROJECT_ID: string;
  FIREBASE_STORAGE_BUCKET?: string;
  FIRESTORE_SERVICE_ACCOUNT_EMAIL: string;
  FIRESTORE_SERVICE_ACCOUNT_PRIVATE_KEY: string;
}
type GcsObject = {
  name: string; size: string; generation: string; metageneration?: string;
  contentType?: string; cacheControl?: string; contentDisposition?: string;
  contentEncoding?: string; contentLanguage?: string; updated?: string;
  timeCreated?: string; md5Hash?: string; crc32c?: string;
  metadata?: Record<string, string>;
};
type FsValue = Record<string, unknown>;
type FsDocument = { name: string; fields?: Record<string, FsValue> };
type Status = "pending" | "copying" | "verified" | "failed" | "conflict";
const DATASTORE = "https://www.googleapis.com/auth/datastore";
const GCS_READ = "https://www.googleapis.com/auth/devstorage.read_only";
const MANIFEST = "storageMigrationManifest";
const CONTROL = "storageMigration/control";
const MAX_BYTES = 500 * 1024 * 1024;
const MAX_RETRIES = 5;
const MAX_BATCH = 8;
const MAX_PAGE = 1000;
const OMIT = new Set(["firebasestoragedownloadtokens"]);

function reply(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), { status, headers: {
    "content-type": "application/json; charset=utf-8", "cache-control": "no-store",
    "access-control-allow-origin": "*", "access-control-allow-methods": "GET, POST, OPTIONS",
    "access-control-allow-headers": "Authorization, Content-Type",
  }});
}
function encode(value: unknown): FsValue {
  if (value === null) return { nullValue: null };
  if (typeof value === "string") return { stringValue: value };
  if (typeof value === "boolean") return { booleanValue: value };
  if (typeof value === "number") return Number.isInteger(value) ? { integerValue: String(value) } : { doubleValue: value };
  if (Array.isArray(value)) return { arrayValue: { values: value.map(encode) } };
  if (typeof value === "object") {
    const fields: Record<string, FsValue> = {};
    for (const [key, item] of Object.entries(value as Record<string, unknown>)) fields[key] = encode(item);
    return { mapValue: { fields } };
  }
  throw new Error("Unsupported Firestore value.");
}
function decode(value?: FsValue): unknown {
  if (!value) return null;
  if ("stringValue" in value) return value.stringValue;
  if ("integerValue" in value) return Number(value.integerValue);
  if ("doubleValue" in value) return value.doubleValue;
  if ("booleanValue" in value) return value.booleanValue;
  if ("timestampValue" in value) return value.timestampValue;
  if ("mapValue" in value) {
    const fields = (value.mapValue as { fields?: Record<string, FsValue> }).fields ?? {};
    return Object.fromEntries(Object.entries(fields).map(([k,v]) => [k, decode(v)]));
  }
  if ("arrayValue" in value) return ((value.arrayValue as { values?: FsValue[] }).values ?? []).map(decode);
  return null;
}
function plain(doc: FsDocument | null): Record<string, unknown> {
  return Object.fromEntries(Object.entries(doc?.fields ?? {}).map(([k,v]) => [k,decode(v)]));
}
function fsBase(project: string): string {
  return "https://firestore.googleapis.com/v1/projects/" + project + "/databases/(default)/documents";
}
async function token(env: StorageMigrationEnv, scopes: string[]): Promise<string> {
  if (!env.FIRESTORE_SERVICE_ACCOUNT_EMAIL || !env.FIRESTORE_SERVICE_ACCOUNT_PRIVATE_KEY) throw new Error("Service credentials unavailable.");
  return getGoogleAccessToken(env.FIRESTORE_SERVICE_ACCOUNT_EMAIL,
    env.FIRESTORE_SERVICE_ACCOUNT_PRIVATE_KEY.replace(/\\n/g, "\n"), scopes);
}
async function fsFetch(url: string, bearer: string, init: RequestInit = {}): Promise<Response> {
  return fetch(url, { ...init, headers: {
    Authorization: "Bearer " + bearer,
    ...(init.body ? { "content-type": "application/json" } : {}),
    ...init.headers,
  }});
}
async function readDoc(base: string, path: string, bearer: string): Promise<FsDocument | null> {
  const r = await fsFetch(base + "/" + path, bearer);
  if (r.status === 404) return null;
  if (!r.ok) throw new Error("Firestore read failed (" + r.status + ").");
  return await r.json() as FsDocument;
}
async function writeDoc(base: string, path: string, bearer: string, fields: Record<string, unknown>): Promise<void> {
  const r = await fsFetch(base + "/" + path, bearer, { method: "PATCH", body: JSON.stringify({
    fields: Object.fromEntries(Object.entries(fields).map(([k,v]) => [k,encode(v)])),
  })});
  if (!r.ok) throw new Error("Firestore manifest write failed (" + r.status + ").");
}
async function hashText(value: string): Promise<string> {
  const bytes = new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value)));
  return Array.from(bytes, b => b.toString(16).padStart(2,"0")).join("");
}
function validPath(path: string): boolean {
  return path.length > 0 && path.length <= 1024;
}
function metadataMap(input?: Record<string,string>): Record<string,string> {
  const out: Record<string,string> = {};
  for (const [key,value] of Object.entries(input ?? {})) {
    if (!OMIT.has(key.toLowerCase()) && value.length <= 2048) out[key.slice(0,128)] = value;
  }
  return out;
}
function httpMeta(item: GcsObject): Record<string,string> {
  const out: Record<string,string> = {};
  for (const key of ["contentType","cacheControl","contentDisposition","contentEncoding","contentLanguage"] as const) {
    if (item[key]) out[key] = item[key] as string;
  }
  return out;
}
async function gcsList(bucket: string, bearer: string, pageToken: string | null, max: number) {
  const url = new URL("https://storage.googleapis.com/storage/v1/b/" + encodeURIComponent(bucket) + "/o");
  url.searchParams.set("maxResults", String(max)); url.searchParams.set("projection","full");
  if (pageToken) url.searchParams.set("pageToken",pageToken);
  const r = await fetch(url,{headers:{Authorization:"Bearer "+bearer}});
  if (!r.ok) throw new Error("GCS inventory failed ("+r.status+").");
  const body = await r.json() as {items?:GcsObject[];nextPageToken?:string};
  return {items:(body.items ?? []).filter(x => typeof x.name === "string" && x.name.length > 0 && x.name.length <= 1024),next:body.nextPageToken ?? ""};
}
async function batchGet(base: string, bearer: string, items: GcsObject[]) {
  const ids = await Promise.all(items.map(x => hashText(x.name)));
  const names = ids.map(id => base + "/" + MANIFEST + "/" + id);
  const r = await fsFetch(base + ":batchGet",bearer,{method:"POST",body:JSON.stringify({documents:names})});
  if (!r.ok) throw new Error("Manifest lookup failed ("+r.status+").");
  const rows = await r.json() as Array<{found?:FsDocument}>;
  const map = new Map<string,Record<string,unknown>>();
  for (const row of rows) if (row.found) {
    const d=plain(row.found); map.set(String(d.sourcePath ?? ""),d);
  }
  return map;
}
async function upsertPage(base:string,bearer:string,bucket:string,items:GcsObject[]) {
  const previous=await batchGet(base,bearer,items);
  const writes=[];
  for (const item of items) {
    const id=await hashText(item.name), old=previous.get(item.name);
    const same=old?.sourceGeneration===item.generation;
    const verified=same && old?.status==="verified";
    const fields:Record<string,unknown>={
      sourcePath:item.name,sourceBucket:bucket,sourceGeneration:item.generation,
      sourceMetageneration:item.metageneration ?? "",sizeBytes:Number(item.size),
      contentType:item.contentType ?? "application/octet-stream",
      sourceMd5:item.md5Hash ?? "",sourceCrc32c:item.crc32c ?? "",
      sourceUpdatedAt:item.updated ?? item.timeCreated ?? "",
      sourceMetadata:metadataMap(item.metadata),contentMetadata:httpMeta(item),
      status:verified?"verified":same&&old?.status==="failed"&&Number(old?.attempts??0)>=MAX_RETRIES?"failed":"pending",attempts:same?Number(old?.attempts ?? 0):0,
      sourceSha256:verified?old?.sourceSha256 ?? "":"",
      destinationSha256:verified?old?.destinationSha256 ?? "":"",
      verifiedAt:verified?old?.verifiedAt ?? "":"",
      lastError:"",inventoriedAt:new Date().toISOString(),
    };
    writes.push({update:{name:base+"/"+MANIFEST+"/"+id,fields:Object.fromEntries(Object.entries(fields).map(([k,v])=>[k,encode(v)]))}});
  }
  for(let i=0;i<writes.length;i+=400){
    const r=await fsFetch(base+":commit",bearer,{method:"POST",body:JSON.stringify({writes:writes.slice(i,i+400)})});
    if(!r.ok) throw new Error("Manifest batch commit failed ("+r.status+").");
  }
  return items.length;
}
async function getGcsObject(bucket:string,path:string,bearer:string):Promise<GcsObject>{
  const url="https://storage.googleapis.com/storage/v1/b/"+encodeURIComponent(bucket)+"/o/"+encodeURIComponent(path);
  const r=await fetch(url,{headers:{Authorization:"Bearer "+bearer}});
  if(!r.ok) throw new Error("GCS metadata read failed ("+r.status+").");
  return await r.json() as GcsObject;
}
async function patchManifest(base:string,bearer:string,id:string,patch:Record<string,unknown>) {
  const current=plain(await readDoc(base,MANIFEST+"/"+id,bearer));
  await writeDoc(base,MANIFEST+"/"+id,bearer,{...current,...patch});
}

// Incremental SHA-256 implementation: bounded memory regardless of object size.
const K=Uint32Array.from([0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb3,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2]);
class Sha256 {
  h=Uint32Array.from([0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19]);
  buf=new Uint8Array(64); used=0; length=0n;
  update(x:Uint8Array){this.length+=BigInt(x.length);let p=0;if(this.used){const n=Math.min(64-this.used,x.length);this.buf.set(x.subarray(0,n),this.used);this.used+=n;p=n;if(this.used===64){this.block(this.buf);this.used=0;}}while(p+64<=x.length){this.block(x.subarray(p,p+64));p+=64;}if(p<x.length){this.buf.set(x.subarray(p),0);this.used=x.length-p;}}
  finish(){const bits=this.length*8n;this.buf[this.used++]=128;if(this.used>56){this.buf.fill(0,this.used);this.block(this.buf);this.used=0;}this.buf.fill(0,this.used,56);const v=new DataView(this.buf.buffer);v.setUint32(56,Number((bits>>32n)&0xffffffffn));v.setUint32(60,Number(bits&0xffffffffn));this.block(this.buf);const out=new Uint8Array(32),o=new DataView(out.buffer);for(let i=0;i<8;i++)o.setUint32(i*4,this.h[i]);return Array.from(out,b=>b.toString(16).padStart(2,"0")).join("");}
  block(b:Uint8Array){const w=new Uint32Array(64),v=new DataView(b.buffer,b.byteOffset,64),r=(x:number,n:number)=>(x>>>n)|(x<<(32-n));for(let i=0;i<16;i++)w[i]=v.getUint32(i*4);for(let i=16;i<64;i++){const x=w[i-15],y=w[i-2],s0=r(x,7)^r(x,18)^(x>>>3),s1=r(y,17)^r(y,19)^(y>>>10);w[i]=(w[i-16]+s0+w[i-7]+s1)>>>0;}let [a,b0,c,d,e,f,g,h]=this.h;for(let i=0;i<64;i++){const s1=r(e,6)^r(e,11)^r(e,25),ch=(e&f)^(~e&g),t1=(h+s1+ch+K[i]+w[i])>>>0,s0=r(a,2)^r(a,13)^r(a,22),maj=(a&b0)^(a&c)^(b0&c),t2=(s0+maj)>>>0;h=g;g=f;f=e;e=(d+t1)>>>0;d=c;c=b0;b0=a;a=(t1+t2)>>>0;}this.h[0]=(this.h[0]+a)>>>0;this.h[1]=(this.h[1]+b0)>>>0;this.h[2]=(this.h[2]+c)>>>0;this.h[3]=(this.h[3]+d)>>>0;this.h[4]=(this.h[4]+e)>>>0;this.h[5]=(this.h[5]+f)>>>0;this.h[6]=(this.h[6]+g)>>>0;this.h[7]=(this.h[7]+h)>>>0;}
}
async function digestBody(body:ReadableStream<Uint8Array>){
 const hash=new Sha256();let size=0;
 const hashed=body.pipeThrough(new TransformStream<Uint8Array,Uint8Array>({
  transform(chunk,controller){size+=chunk.length;hash.update(chunk);controller.enqueue(chunk);}
 }));
 await hashed.pipeTo(new WritableStream({write(){}}));
 return {size,sha256:hash.finish()};
}
function hashBody(body:ReadableStream<Uint8Array>){
 const hash=new Sha256();let size=0;
 const [pass,hashInput]=body.tee();
 const hashed=hashInput.pipeThrough(new TransformStream<Uint8Array,Uint8Array>({
  transform(chunk,controller){size+=chunk.length;hash.update(chunk);controller.enqueue(chunk);}
 }));
 const result=(async()=>{await hashed.pipeTo(new WritableStream({write(){}}));return {size,sha256:hash.finish()};})();
 return {stream:pass,result};
}
async function copyObject(env:StorageMigrationEnv,base:string,fsToken:string,gcsToken:string,doc:FsDocument,dryRun:boolean){
 const d=plain(doc),path=String(d.sourcePath??""),generation=String(d.sourceGeneration??""),size=Number(d.sizeBytes),id=doc.name.split("/").pop()??"";
 if(!validPath(path)||!generation||!Number.isSafeInteger(size)||size<0||size>MAX_BYTES){
  if(!dryRun)await patchManifest(base,fsToken,id,{status:"failed",lastError:"Unsupported object metadata.",attempts:Number(d.attempts??0)+1});
  return {path,status:"failed",reason:"unsupported-metadata"};
 }
 if(dryRun)return {path,status:"would-copy",sizeBytes:size};
 if(Number(d.attempts??0)>=MAX_RETRIES)return {path,status:"failed",reason:"retry-limit-reached"};
 const latest=await getGcsObject(String(d.sourceBucket),path,gcsToken);
 if(latest.generation!==generation||Number(latest.size)!==size||String(latest.metageneration??"")!==String(d.sourceMetageneration??"")){
  await patchManifest(base,fsToken,id,{status:"failed",lastError:"Source generation changed; run inventory again.",attempts:Number(d.attempts??0)+1});
  return {path,status:"failed",reason:"source-changed"};
 }
 const existing=await env.MEDIA_BUCKET.head(path);
 if(existing&&existing.customMetadata?.migrationSourceGeneration!==generation){
  await patchManifest(base,fsToken,id,{status:"conflict",lastError:"R2 key already exists and is not owned by this migration."});
  return {path,status:"conflict",reason:"destination-exists"};
 }
 if(existing && d.status==="verified" && existing.size===size && d.destinationSha256){
  const already=await env.MEDIA_BUCKET.get(path);
  if(already){const digest=await digestBody(already.body);if(digest.sha256===d.destinationSha256&&digest.size===size)return {path,status:"verified",skipped:true,sizeBytes:size,sha256:digest.sha256};}
 }
 await patchManifest(base,fsToken,id,{status:"copying",lastAttemptAt:new Date().toISOString(),lastError:""});
 const url=new URL("https://storage.googleapis.com/storage/v1/b/"+encodeURIComponent(String(d.sourceBucket))+"/o/"+encodeURIComponent(path));
 url.searchParams.set("alt","media");url.searchParams.set("ifGenerationMatch",generation);
 const source=await fetch(url,{headers:{Authorization:"Bearer "+gcsToken}});
 if(!source.ok||!source.body){
  const attempts=Number(d.attempts??0)+1;
  await patchManifest(base,fsToken,id,{status:"failed",attempts,lastError:"GCS download failed ("+source.status+")."});
  return {path,status:"failed",reason:"source-http-"+source.status};
 }
 const sourceHash=hashBody(source.body);
 const custom=metadataMap(d.sourceMetadata as Record<string,string>);
 await env.MEDIA_BUCKET.put(path,sourceHash.stream,{
  httpMetadata:{
   contentType:String(d.contentType??"application/octet-stream"),
   ...(d.contentMetadata as Record<string,string>??{}),
  },
  customMetadata:{...custom,migrationSource:"firebase-storage",migrationSourceGeneration:generation,migrationSourceBucket:String(d.sourceBucket)},
 });
 const src=await sourceHash.result;
 const object=await env.MEDIA_BUCKET.get(path);
 if(!object){await patchManifest(base,fsToken,id,{status:"failed",attempts:Number(d.attempts??0)+1,lastError:"R2 object missing after write."});return {path,status:"failed",reason:"r2-missing"};}
 const dst=await digestBody(object.body),head=await env.MEDIA_BUCKET.head(path);
 if(src.size!==size||dst.size!==size||head?.size!==size||src.sha256!==dst.sha256){
  await env.MEDIA_BUCKET.delete(path);
  await patchManifest(base,fsToken,id,{status:"failed",attempts:Number(d.attempts??0)+1,lastError:"SHA-256 or size verification mismatch; partial R2 object removed."});
  return {path,status:"failed",reason:"verification-mismatch"};
 }
 await patchManifest(base,fsToken,id,{status:"verified",sourceSha256:src.sha256,destinationSha256:dst.sha256,verifiedAt:new Date().toISOString(),lastError:""});
 return {path,status:"verified",sizeBytes:size,sha256:src.sha256};
}
async function authorizeAdmin(request:Request,env:StorageMigrationEnv){
 const raw=request.headers.get("authorization")??"",m=raw.match(/^Bearer\s+(.+)$/i);
 if(!m)return false;
 const now=Math.floor(Date.now()/1000);
 const auth=await verifyFirebaseIdToken(m[1],env.FIREBASE_PROJECT_ID,fetch,now,300);
 return auth?.claims.email_verified===true&&auth.claims.admin===true&&typeof auth.claims.auth_time==="number"&&now-auth.claims.auth_time<=300;
}


async function acquireLease(base:string,bearer:string):Promise<string>{
 const start=await fsFetch(base+":beginTransaction",bearer,{method:"POST",body:JSON.stringify({options:{readWrite:{}}})});
 if(!start.ok)throw new Error("Could not start migration lease transaction.");
 const transaction=(await start.json() as {transaction?:string}).transaction;
 if(!transaction)throw new Error("Firestore returned no transaction.");
 const read=await fsFetch(base+"/"+CONTROL+"?transaction="+encodeURIComponent(transaction),bearer);
 const doc=read.status===404?null:read.ok?await read.json() as FsDocument:null;
 if(read.status!==404&&!read.ok)throw new Error("Could not read migration lease.");
 const data=plain(doc),until=Date.parse(String(data.leaseUntil??""));
 if(Number.isFinite(until)&&until>Date.now()){
  await fsFetch(base+":rollback",bearer,{method:"POST",body:JSON.stringify({transaction})});
  throw new Error("Another migration request currently holds the lease.");
 }
 const lease=crypto.randomUUID(),fields={...data,leaseToken:lease,leaseUntil:new Date(Date.now()+900000).toISOString()};
 const write:Record<string,unknown>={update:{name:base+"/"+CONTROL,fields:Object.fromEntries(Object.entries(fields).map(([k,v])=>[k,encode(v)]))}};
 if(!doc)write.currentDocument={exists:false};
 const committed=await fsFetch(base+":commit",bearer,{method:"POST",body:JSON.stringify({transaction,writes:[write]})});
 if(!committed.ok)throw new Error("Migration lease acquisition conflicted.");
 return lease;
}
async function releaseLease(base:string,bearer:string,lease:string):Promise<void>{
 try{
  const start=await fsFetch(base+":beginTransaction",bearer,{method:"POST",body:JSON.stringify({options:{readWrite:{}}})});
  if(!start.ok)return;
  const transaction=(await start.json() as {transaction?:string}).transaction;if(!transaction)return;
  const read=await fsFetch(base+"/"+CONTROL+"?transaction="+encodeURIComponent(transaction),bearer);
  if(!read.ok)return;
  const doc=await read.json() as FsDocument,data=plain(doc);
  if(data.leaseToken!==lease){await fsFetch(base+":rollback",bearer,{method:"POST",body:JSON.stringify({transaction})});return;}
  const fields={...data,leaseToken:"",leaseUntil:""};
  const committed=await fsFetch(base+":commit",bearer,{method:"POST",body:JSON.stringify({transaction,writes:[{update:{name:base+"/"+CONTROL,fields:Object.fromEntries(Object.entries(fields).map(([k,v])=>[k,encode(v)]))}}]})});
  if(!committed.ok)console.error("Migration lease release failed",committed.status);
 }catch(error){console.error("Migration lease release failed",error);}
}

export function isVerifiedManifestRecord(key:string,data:Record<string,unknown>):boolean{
 return data.sourcePath===key&&data.status==="verified"&&
  typeof data.sourceGeneration==="string"&&typeof data.destinationSha256==="string"&&
  data.destinationSha256.length===64;
}
export async function isVerifiedMigratedObject(key:string,env:StorageMigrationEnv):Promise<boolean>{
 try{
  const id=await hashText(key);
  const bearer=await token(env,[DATASTORE]);
  const doc=await readDoc(fsBase(env.FIREBASE_PROJECT_ID),MANIFEST+"/"+id,bearer);
  return isVerifiedManifestRecord(key,plain(doc));
 }catch{return false;}
}

export async function handleStorageMigrationRequest(request:Request,env:StorageMigrationEnv):Promise<Response|null>{
 const url=new URL(request.url);
 if(!url.pathname.startsWith("/_admin/storage-migration"))return null;
 if(request.method==="OPTIONS")return new Response(null,{status:204,headers:{"access-control-allow-origin":"*","access-control-allow-methods":"GET, POST, OPTIONS","access-control-allow-headers":"Authorization, Content-Type"}});
 if(!await authorizeAdmin(request,env))return reply({error:"Recent verified administrator authentication required."},403);
 if(!env.FIREBASE_STORAGE_BUCKET)return reply({error:"FIREBASE_STORAGE_BUCKET is not configured."},503);
 const base=fsBase(env.FIREBASE_PROJECT_ID);
 let fsToken:string,gcsToken:string;
 try{[fsToken,gcsToken]=await Promise.all([token(env,[DATASTORE]),token(env,[GCS_READ])]);}
 catch{return reply({error:"Migration service credentials unavailable."},503);}
 if(url.pathname==="/_admin/storage-migration/status"&&request.method==="GET"){
  try{return reply({control:plain(await readDoc(base,CONTROL,fsToken)),manifestCollection:MANIFEST});}
  catch{return reply({error:"Could not read migration status."},503);}
 }
 if(request.method!=="POST")return reply({error:"Method not allowed."},405);
 let body:Record<string,unknown>;try{body=await request.json() as Record<string,unknown>;}catch{return reply({error:"Invalid JSON."},400);}
 const dryRun=body.dryRun===true;
 const mutating=["/_admin/storage-migration/inventory","/_admin/storage-migration/copy","/_admin/storage-migration/retry","/_admin/storage-migration/reset-copy-cursor"].includes(url.pathname);
 let lease="";
 if(mutating&&!dryRun){try{lease=await acquireLease(base,fsToken);}catch(e){return reply({error:e instanceof Error?e.message:"Migration is locked."},409);}}
 try{
 if(url.pathname==="/_admin/storage-migration/inventory"){
  try{
   const control=plain(await readDoc(base,CONTROL,fsToken));
   const selectedPageToken=dryRun?String(body.pageToken??"")||null:String(control.inventoryPageToken??"")||null;
   const page=await gcsList(env.FIREBASE_STORAGE_BUCKET,gcsToken,selectedPageToken,Math.max(1,Math.min(MAX_PAGE,Number(body.pageSize)||MAX_PAGE)));
   const count=dryRun?0:await upsertPage(base,fsToken,env.FIREBASE_STORAGE_BUCKET,page.items);
   if(!dryRun)await writeDoc(base,CONTROL,fsToken,{...control,inventoryPageToken:page.next,inventoryComplete:!page.next,lastInventoryAt:new Date().toISOString(),lastInventoryPageCount:page.items.length,inventoriedObjectCount:Number(control.inventoriedObjectCount??0)+count});
   return reply({dryRun,pageCount:page.items.length,manifestUpserts:count,inventoryComplete:!page.next,nextPageToken:dryRun?page.next:undefined,sample:page.items.slice(0,10).map(x=>({name:x.name,size:Number(x.size),contentType:x.contentType??"application/octet-stream"}))});
  }catch(e){return reply({error:e instanceof Error?e.message:"Inventory failed."},503);}
 }
 if(url.pathname==="/_admin/storage-migration/copy"||url.pathname==="/_admin/storage-migration/retry"){
  const retry=url.pathname.endsWith("/retry"),limit=Math.max(1,Math.min(MAX_BATCH,Number(body.limit)||MAX_BATCH));
  try{
   const control=plain(await readDoc(base,CONTROL,fsToken));
   if(!retry){
    const staleQuery={from:[{collectionId:MANIFEST}],where:{fieldFilter:{field:{fieldPath:"status"},op:"EQUAL",value:{stringValue:"copying"}}},limit:MAX_BATCH};
    const staleResponse=await fsFetch(base+":runQuery",fsToken,{method:"POST",body:JSON.stringify({structuredQuery:staleQuery})});
    if(staleResponse.ok){
     const staleRows=await staleResponse.json() as Array<{document?:FsDocument}>;
     for(const row of staleRows){
      if(!row.document)continue;
      const stale=plain(row.document),attempted=Date.parse(String(stale.lastAttemptAt??""));
      if(!Number.isFinite(attempted)||Date.now()-attempted>15*60*1000){
       const staleId=row.document.name.split("/").pop()??"",attempts=Number(stale.attempts??0)+1;
       await patchManifest(base,fsToken,staleId,{status:"failed",attempts,lastError:"Recovered an interrupted copy attempt."});
      }
     }
    }
   }
   const query:Record<string,unknown>={from:[{collectionId:MANIFEST}],where:{fieldFilter:{field:{fieldPath:"status"},op:"EQUAL",value:{stringValue:retry?"failed":"pending"}}},orderBy:[{field:{fieldPath:"__name__"},direction:"ASCENDING"}],limit:retry?limit*10:limit};
   if(!retry&&control.copyCursor)query.startAt={values:[{referenceValue:String(control.copyCursor)}],before:false};
   const q=await fsFetch(base+":runQuery",fsToken,{method:"POST",body:JSON.stringify({structuredQuery:query})});
   if(!q.ok)throw new Error("Manifest query failed ("+q.status+").");
   const rows=await q.json() as Array<{document?:FsDocument}>,docs=rows.flatMap(x=>x.document?[x.document]:[]).filter(doc=>!retry||Number(plain(doc).attempts??0)<MAX_RETRIES).slice(0,limit);
   const results=[];
   for(const doc of docs){
    try{results.push(await copyObject(env,base,fsToken,gcsToken,doc,dryRun));}
    catch(error){
     const data=plain(doc),id=doc.name.split("/").pop()??"",attempts=Number(data.attempts??0)+1;
     if(!dryRun)await patchManifest(base,fsToken,id,{status:"failed",attempts,lastError:"Copy attempt failed; retry is bounded."});
     results.push({path:data.sourcePath,status:"failed",reason:"copy-attempt-failed",attempts});
    }
   }
   if(!dryRun&&docs.length&&!retry)await writeDoc(base,CONTROL,fsToken,{...control,copyCursor:docs[docs.length-1].name,lastCopyAt:new Date().toISOString()});
   return reply({dryRun,operation:retry?"retry":"copy",processed:results.length,verified:results.filter(x=>x.status==="verified").length,failed:results.filter(x=>x.status==="failed").length,conflicts:results.filter(x=>x.status==="conflict").length,results});
  }catch(e){return reply({error:e instanceof Error?e.message:"Copy failed."},503);}
 }
 if(url.pathname==="/_admin/storage-migration/reset-copy-cursor"){
  try{const control=plain(await readDoc(base,CONTROL,fsToken));await writeDoc(base,CONTROL,fsToken,{...control,copyCursor:""});return reply({ok:true});}
  catch{return reply({error:"Could not reset cursor."},503);}
 }
 return reply({error:"Unknown migration operation."},404);
 } finally { if(lease) await releaseLease(base,fsToken,lease); }
}
export const storageMigrationTestHooks={Sha256,hashBody,digestBody,validPath,metadataMap,MAX_RETRIES,copyObject,isVerifiedManifestRecord,gcsList,acquireLease};
