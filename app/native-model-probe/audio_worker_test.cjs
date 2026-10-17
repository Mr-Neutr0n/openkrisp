'use strict';
const assert=require('node:assert/strict'), fs=require('node:fs'), os=require('node:os'), path=require('node:path'), crypto=require('node:crypto');
const {runWorker,admit,fileHash,ADDON_SHA256,MODEL_SHA256,INBOUND_MODEL_SHA256,validateConfig}=require('./audio_worker.cjs');
const {encode,Parser}=require('./worker_protocol.cjs');
const config={addonPath:'/fixture/addon',modelPath:'/fixture/model',adapterPath:'/fixture/adapter',adapterSha256:'a'.repeat(64),nodeSha256:'b'.repeat(64),token:'19'.repeat(16),suppressionLevel:100,bypass:false,parentPID:process.ppid,modelRole:'outbound',modelSha256:MODEL_SHA256};
function fixture(options={}, selected=config) {
  let loaded=0,opened=0,closed=0,offset=0;const writes=[],events=[];
  const input=options.input || Buffer.alloc(0);
  const deps={
    loopbackCheck:async()=>{events.push('network');return options.network || 'EPERM';},
    fileHash:filename=>{events.push('hash');return options.badHash?'0'.repeat(64):filename===process.execPath?selected.nodeSha256:filename===selected.addonPath?ADDON_SHA256:filename===selected.modelPath?selected.modelSha256:selected.adapterSha256;},
    loadAdapter:()=>{++loaded;events.push('load');return {watchParent(pid){assert.equal(pid,selected.parentPID);events.push('watch');if(options.watchError)throw new Error('parent changed');return {close(){events.push('unwatch');return {stopped:true};}};},open(value){++opened;events.push('open');assert.equal(value.frameSize,480);assert.equal(value.sampleRate,48000);return {
      process(samples){if(options.processError)throw new Error('process failed');return {samples,framesProcessed:1,callbackCount:1,processorConstructed:true,directProcessInvoked:true,backend:'ordinary-nc-direct'};},
      close(){++closed;if(options.closeError)throw new Error('teardown failed');return {teardownComplete:true};},
    };}};},
    read:bytes=>{if(options.readError)throw new Error('read failed');const n=Math.min(bytes.length,input.length-offset);input.copy(bytes,0,offset,offset+n);offset+=n;return n;},
    write:bytes=>{events.push('write');if(options.writeError || (options.protocolWriteError && writes.length))throw new Error('write failed');const n=Math.min(bytes.length,options.writeSize || bytes.length);writes.push(Buffer.from(bytes.subarray(0,n)));return n;},
  };
  return {deps,writes,events,stats:()=>({loaded,opened,closed})};
}
(async()=>{
  for(const change of [{extra:true},{addonPath:'relative'},{modelPath:'/bad\0path'},{adapterSha256:'bad'},{nodeSha256:'C'.repeat(64)},{token:'0'},{suppressionLevel:NaN},{bypass:1},{parentPID:1},{parentPID:1.5}]){
    const f=fixture();await assert.rejects(runWorker({...config,...change},f.deps));assert.equal(f.stats().loaded,0);
  }
  for(const change of [{modelRole:'inbound'},{modelSha256:INBOUND_MODEL_SHA256},
      {modelRole:'unknown'},{modelRole:'__proto__'},{modelRole:null},{modelSha256:'0'.repeat(64)}]) {
    const f=fixture();await assert.rejects(runWorker({...config,...change},f.deps));
    assert.equal(f.stats().loaded,0);assert.deepEqual(f.events,[]);
  }
  for(const missing of ['modelRole','modelSha256']) {
    const incomplete={...config};delete incomplete[missing];assert.throws(()=>validateConfig(incomplete));
  }
  {
    const legacy={...config};delete legacy.modelRole;delete legacy.modelSha256;
    assert.throws(()=>validateConfig(legacy));
  }
  const inbound={...config,modelRole:'inbound',modelSha256:INBOUND_MODEL_SHA256};
  const inboundFixture=fixture({},inbound);
  assert.deepEqual(await runWorker(inbound,inboundFixture.deps),{requests:0,teardownComplete:true});
  assert.equal(Buffer.concat(inboundFixture.writes).toString('ascii'),`OKREADY2 ${config.token} ordinary-nc-direct 48000 480 inbound ${ADDON_SHA256} ${INBOUND_MODEL_SHA256} ${config.adapterSha256} ${config.nodeSha256}\n`);
  const wrongInbound=fixture({},inbound), originalInboundHash=wrongInbound.deps.fileHash;
  wrongInbound.deps.fileHash=p=>p===inbound.modelPath?MODEL_SHA256:originalInboundHash(p);
  await assert.rejects(runWorker(inbound,wrongInbound.deps));assert.equal(wrongInbound.stats().loaded,0);
  for(const options of [{network:'ECONNREFUSED'},{network:'CONNECTED'},{network:'TIMEOUT'},{badHash:true}]){
    const f=fixture(options);await assert.rejects(runWorker(config,f.deps));assert.equal(f.stats().loaded,0);
  }
  for(const filename of [process.execPath,config.addonPath,config.modelPath,config.adapterPath]) {
    const f=fixture(), original=f.deps.fileHash;f.deps.fileHash=p=>p===filename?'f'.repeat(64):original(p);
    await assert.rejects(runWorker(config,f.deps));assert.equal(f.stats().loaded,0);
  }
  const f=fixture({writeSize:7});assert.deepEqual(await runWorker(config,f.deps),{requests:0,teardownComplete:true});
  assert.equal(Buffer.concat(f.writes).toString('ascii'),`OKREADY2 ${config.token} ordinary-nc-direct 48000 480 outbound ${ADDON_SHA256} ${MODEL_SHA256} ${config.adapterSha256} ${config.nodeSha256}\n`);
  assert.deepEqual(f.stats(),{loaded:1,opened:1,closed:1});assert.equal(f.events[0],'network');assert.ok(f.events.indexOf('open')<f.events.indexOf('write'));
  for(const options of [{writeError:true},{readError:true},{processError:true,input:encode({kind:'request',token:Buffer.from(config.token,'hex'),sequence:0,samples:new Float32Array(480)})},{input:Buffer.from('bad')},{writeError:true,closeError:true}]){
    const failure=fixture(options);await assert.rejects(runWorker(config,failure.deps));assert.equal(failure.stats().closed,1);
  }
  const noParent=fixture({watchError:true});await assert.rejects(runWorker(config,noParent.deps));assert.equal(noParent.stats().opened,0);
  assert.ok(f.events.indexOf('watch')<f.events.indexOf('open'));assert.equal(f.events.at(-1),'unwatch');
  const token=Buffer.from(config.token,'hex');
  const input=Buffer.concat([encode({kind:'request',token,sequence:0,samples:new Float32Array(480)}),encode({kind:'close',token,sequence:1})]);
  const complete=fixture({input});assert.equal((await runWorker(config,complete.deps)).requests,1);
  const wire=Buffer.concat(complete.writes), boundary=wire.indexOf(10)+1, decoded=[];
  const parser=new Parser({token,kinds:['result','close'],onFrame:frame=>decoded.push(frame)});
  parser.push(wire.subarray(boundary));parser.finish();assert.deepEqual(decoded.map(f=>f.kind),['result','close']);assert.equal(complete.stats().closed,1);
  const failedWrite=fixture({input,protocolWriteError:true});await assert.rejects(runWorker(config,failedWrite.deps));assert.equal(failedWrite.stats().closed,1);
  const directory=fs.mkdtempSync(path.join(os.tmpdir(),'openkrisp-admission-'));
  try {
    const file=path.join(directory,'plain'),link=path.join(directory,'link');fs.writeFileSync(file,'fixture');fs.symlinkSync(file,link);
    assert.equal(fileHash(file),crypto.createHash('sha256').update('fixture').digest('hex'));
    assert.throws(()=>fileHash(link));assert.throws(()=>fileHash(directory));
    const regularGate=fixture();delete regularGate.deps.fileHash;
    await assert.rejects(admit({...config,addonPath:link},regularGate.deps));assert.equal(regularGate.stats().loaded,0);
  } finally {fs.rmSync(directory,{recursive:true,force:true});}
  console.log('gated audio worker host-only tests passed');
})().catch(error=>{console.error(error);process.exitCode=1;});
