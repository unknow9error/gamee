import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp,writeFile,readFile,rm} from 'node:fs/promises';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import {generateNarration,inspectNarrationPlan} from '../tool/generate_narration.mjs';

async function fixture(count=4) {
  const root=await mkdtemp(join(tmpdir(),'narration-public-fixture-'));
  const manifestPath=join(root,'manifest.json');
  const manifest={version:1,generation:{modelId:'eleven_v3',voiceId:'OZ0L6eISlOejga3XjDFt'},entries:Array.from({length:count},(_,i)=>({key:`v2_${String(i+1).padStart(2,'0')}`,language:'ru',text:'Выбери картинку.',asset:`audio/narration/v2_${String(i+1).padStart(2,'0')}_ru.mp3`,generated:false}))};
  await writeFile(manifestPath,JSON.stringify(manifest));
  return {root,manifestPath,assetRoot:root};
}
function mockFetch({failPost=false}={}) {
  let active=0,max=0,posts=0;
  const run=async(url,options)=>{
    if(url.endsWith('/v1/models')) return new Response(JSON.stringify([{model_id:'eleven_v3',can_do_text_to_speech:true,languages:[{language_id:'ru'},{language_id:'kk'},{language_id:'en'}]}]));
    if(url.includes('/v1/voices/')) return new Response(JSON.stringify({voice_id:'OZ0L6eISlOejga3XjDFt'}));
    posts++;active++;max=Math.max(max,active);
    assert.equal(options.headers['xi-api-key'],'synthetic-test-only');
    assert.equal(JSON.parse(options.body).language_code,'ru');
    await new Promise(resolve=>setTimeout(resolve,5));active--;
    if(failPost) throw new Error('synthetic transport failure with private-looking details that must never propagate');
    const bytes=Buffer.alloc(700,1);bytes.write('ID3');
    return new Response(bytes,{headers:{'content-type':'audio/mpeg'}});
  };
  return {run,get posts(){return posts},get max(){return max}};
}
test('local plan, bounded paid requests, cache repeat never regenerates',async()=>{
 const fixtureData=await fixture();try{
 const plan=await inspectNarrationPlan(fixtureData);assert.equal(plan.requests,4);
 const fetch=mockFetch();const result=await generateNarration({...fixtureData,apiKey:'synthetic-test-only',maxRequests:4,maxCharacters:1000,fetchImpl:fetch.run});
 assert.equal(result.generated,4);assert.equal(fetch.posts,4);assert.equal(fetch.max,2);
 const cached=await generateNarration({...fixtureData,maxRequests:0,maxCharacters:0,fetchImpl:()=>assert.fail('No network when cached')});assert.equal(cached.cached,4);
 }finally{await rm(fixtureData.root,{recursive:true,force:true})}
});
test('budget rejects before any network',async()=>{
 const fixtureData=await fixture();try{
 await assert.rejects(generateNarration({...fixtureData,apiKey:'synthetic-test-only',maxRequests:1,maxCharacters:1000,fetchImpl:()=>assert.fail('No network over budget')}),/budget/);
 }finally{await rm(fixtureData.root,{recursive:true,force:true})}
});
test('uncertain transport never auto-retries or leaks error details',async()=>{
 const fixtureData=await fixture();try{
 const fetch=mockFetch({failPost:true});
 await assert.rejects(generateNarration({...fixtureData,apiKey:'synthetic-test-only',maxRequests:4,maxCharacters:1000,fetchImpl:fetch.run}),error=>/No automatic retry/.test(error.message)&&!error.message.includes('private-looking'));
 assert.equal(fetch.posts,2);
 await assert.rejects(inspectNarrationPlan(fixtureData),/uncertain/);
 assert.equal((await readFile(fixtureData.manifestPath,'utf8')).includes('synthetic-test-only'),false);
 }finally{await rm(fixtureData.root,{recursive:true,force:true})}
});

function restrictedFetch(reason='missing_permissions',status=401) {
 const normal=mockFetch();
 return {get posts(){return normal.posts},run:async(url,options)=>url.includes('/v1/models')||url.includes('/v1/voices/')
   ?new Response(JSON.stringify({detail:{status:reason,message:'not retained'}}),{status})
   :normal.run(url,options)};
}
test('TTS-only metadata fallback requires explicit opt-in and records provenance',async()=>{
 const fixtureData=await fixture(1);try{
 const restricted=restrictedFetch();
 await assert.rejects(generateNarration({...fixtureData,apiKey:'synthetic-test-only',maxRequests:1,maxCharacters:1000,fetchImpl:restricted.run}),/HTTP 401/);
 assert.equal(restricted.posts,0);
 const result=await generateNarration({...fixtureData,apiKey:'synthetic-test-only',maxRequests:1,maxCharacters:1000,allowRestrictedMetadata:true,fetchImpl:restricted.run});
 assert.equal(result.generated,1);assert.equal(restricted.posts,1);
 const manifest=JSON.parse(await readFile(fixtureData.manifestPath,'utf8'));
 assert.equal(manifest.generation.provenance.metadataDeclared,true);
 assert.equal(manifest.generation.provenance.modelMetadata,'documented');
 assert.equal(manifest.generation.provenance.actualSpeechAsset,true);
 assert.equal(manifest.entries[0].actualSpeechAsset,true);
 }finally{await rm(fixtureData.root,{recursive:true,force:true})}
});
for(const [reason,status] of [['invalid_api_key',401],['missing_permissions',403],['other',401]]){
 test(`opt-in rejects ${reason}/${status} without paid requests`,async()=>{
  const fixtureData=await fixture(1);try{
   const restricted=restrictedFetch(reason,status);
   await assert.rejects(generateNarration({...fixtureData,apiKey:'synthetic-test-only',maxRequests:1,maxCharacters:1000,allowRestrictedMetadata:true,fetchImpl:restricted.run}),new RegExp(`HTTP ${status}`));
   assert.equal(restricted.posts,0);
  }finally{await rm(fixtureData.root,{recursive:true,force:true})}
 });
}
test('restricted metadata cannot declare an arbitrary voice or model',async()=>{
 const fixtureData=await fixture(1);try{
 const restricted=restrictedFetch();
 await assert.rejects(generateNarration({...fixtureData,apiKey:'synthetic-test-only',maxRequests:1,maxCharacters:1000,allowRestrictedMetadata:true,modelId:'eleven_unknown',fetchImpl:restricted.run}),/HTTP 401/);
 await assert.rejects(generateNarration({...fixtureData,apiKey:'synthetic-test-only',maxRequests:1,maxCharacters:1000,allowRestrictedMetadata:true,voiceId:'arbitraryStockVoice123',fetchImpl:restricted.run}),/HTTP 401/);
 assert.equal(restricted.posts,0);
 }finally{await rm(fixtureData.root,{recursive:true,force:true})}
});

function libraryFetch({reason='voice_not_found',status=400,postStatus=200,postReason='invalid_model_id'}={}) {
 const normal=mockFetch();let posts=0;
 return {get posts(){return posts},run:async(url,options)=>{
  if(url.includes('/v1/voices/'))return new Response(JSON.stringify({detail:{status:reason,message:'not retained'}}),{status});
  if(url.includes('/v1/text-to-speech/')){
   posts++;
   if(postStatus!==200)return new Response(JSON.stringify({detail:{status:postReason,message:'raw response deliberately never retained'}}),{status:postStatus});
  }
  return normal.run(url,options);
 }};
}
test('public library GET miss needs separate opt-in and marks actual asset only after POST success',async()=>{
 const fixtureData=await fixture(1);try{
 const fetch=libraryFetch();
 await assert.rejects(generateNarration({...fixtureData,apiKey:'synthetic-test-only',maxRequests:1,maxCharacters:1000,fetchImpl:fetch.run}),/HTTP 400/);
 assert.equal(fetch.posts,0);
 await generateNarration({...fixtureData,apiKey:'synthetic-test-only',maxRequests:1,maxCharacters:1000,allowPublicLibraryVoice:true,fetchImpl:fetch.run});
 assert.equal(fetch.posts,1);
 const manifest=JSON.parse(await readFile(fixtureData.manifestPath,'utf8'));
 assert.equal(manifest.generation.provenance.voiceMetadata,'documented-library');
 assert.equal(manifest.generation.provenance.publicLibrarySource,'https://elevenlabs.io/app/voice-library?voiceId=OZ0L6eISlOejga3XjDFt');
 assert.equal(manifest.generation.provenance.actualSpeechAsset,true);
 }finally{await rm(fixtureData.root,{recursive:true,force:true})}
});
for(const [reason,status] of [['other',400],['voice_not_found',401],['voice_not_found',404],['missing_permissions',400]]){
 test(`public-library opt-in rejects ${reason}/${status}`,async()=>{
 const fixtureData=await fixture(1);try{
  const fetch=libraryFetch({reason,status});
  await assert.rejects(generateNarration({...fixtureData,apiKey:'synthetic-test-only',maxRequests:1,maxCharacters:1000,allowPublicLibraryVoice:true,fetchImpl:fetch.run}),new RegExp(`HTTP ${status}`));
  assert.equal(fetch.posts,0);
 }finally{await rm(fixtureData.root,{recursive:true,force:true})}
 });
}
test('public-library opt-in rejects arbitrary voice even with exact not-found',async()=>{
 const fixtureData=await fixture(1);try{
 const fetch=libraryFetch();
 await assert.rejects(generateNarration({...fixtureData,apiKey:'synthetic-test-only',voiceId:'anotherVoiceDoesNotGetBypass',maxRequests:1,maxCharacters:1000,allowPublicLibraryVoice:true,fetchImpl:fetch.run}),/HTTP 400/);
 assert.equal(fetch.posts,0);
 }finally{await rm(fixtureData.root,{recursive:true,force:true})}
});
test('concrete POST rejection records only whitelisted code and never marks an actual asset',async()=>{
 const fixtureData=await fixture(1);try{
 const fetch=libraryFetch({postStatus:400});
 await assert.rejects(generateNarration({...fixtureData,apiKey:'synthetic-test-only',maxRequests:1,maxCharacters:1000,allowPublicLibraryVoice:true,fetchImpl:fetch.run}),/No automatic retry/);
 assert.equal(fetch.posts,1);
 const raw=await readFile(fixtureData.manifestPath,'utf8');const manifest=JSON.parse(raw);
 assert.equal(manifest.entries[0].lastErrorCode,'invalid_model_id');
 assert.equal(manifest.generation.provenance.actualSpeechAsset,false);
 assert.equal(raw.includes('raw response'),false);
 }finally{await rm(fixtureData.root,{recursive:true,force:true})}
});
