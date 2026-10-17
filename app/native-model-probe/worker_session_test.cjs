'use strict';
const assert = require('node:assert/strict');
const { runSession } = require('./worker_session.cjs');
const { encode, Parser, MAX_FRAME_BYTES } = require('./worker_protocol.cjs');
if (process.argv[2] === '--fixture-child') {
  const fs = require('node:fs');
  runSession({ token: Buffer.alloc(16, 19),
    openSession: () => ({
      process: samples => ({samples, framesProcessed:1, callbackCount:1, processorConstructed:true, directProcessInvoked:true, backend:'ordinary-nc-direct'}),
      close() { fs.appendFileSync(process.argv[3], 'closed\n'); return {teardownComplete:true}; },
    }),
    read: buffer => fs.readSync(0, buffer, 0, buffer.length, null),
    write: buffer => fs.writeSync(1, buffer, 0, buffer.length, null),
  });
  process.exit(0);
}
const token = Buffer.alloc(16, 19), samples = Float32Array.from({length:480}, (_,i) => i / 480);
const request = sequence => encode({kind:'request',token,sequence,samples});
const closeFrame = sequence => encode({kind:'close',token,sequence});
function setup(input, options = {}) {
  let offset=0, closes=0, calls=0, readCalls=0, writeCalls=0, peakRead=0, peakWrite=0;
  const results=[];
  const output = new Parser({token,kinds:['result','close'],onFrame:frame=>results.push(frame)});
  const dependencies = {
    token,
    openSession() { return {
      process(value) { ++calls; if(options.processError) throw new Error('processing failed');
        return options.result || {samples:value,framesProcessed:1,callbackCount:1,processorConstructed:true,directProcessInvoked:true,backend:'ordinary-nc-direct'}; },
      close() { ++closes; if(options.closeError) throw new Error('close failed'); return {teardownComplete: !options.unconfirmed}; },
    }; },
    read(scratch) {
      ++readCalls; peakRead=Math.max(peakRead,scratch.length);
      if(options.readEintr && readCalls===1) throw Object.assign(new Error('interrupted'),{code:'EINTR'});
      if(options.readError) throw new Error('read failed');
      const size=Math.min(options.readSize || 31,input.length-offset,scratch.length);
      input.copy(scratch,0,offset,offset+size);offset+=size;return size;
    },
    write(bytes) {
      ++writeCalls;peakWrite=Math.max(peakWrite,bytes.length);
      if(options.writeEintr && writeCalls===1) throw Object.assign(new Error('interrupted'),{code:'EINTR'});
      if(options.zeroWrite) return 0;
      const size=Math.min(options.writeSize || 13,bytes.length);output.push(bytes.subarray(0,size));return size;
    },
  };
  return {dependencies,results,output,stats:()=>({closes,calls,readCalls,writeCalls,peakRead,peakWrite})};
}
for(const explicit of [false,true]) {
  const fixture=setup(Buffer.concat([request(0),request(1),...(explicit?[closeFrame(2)]:[])]),{readEintr:true,writeEintr:true});
  assert.deepEqual(runSession(fixture.dependencies),{requests:2,teardownComplete:true});fixture.output.finish();
  assert.equal(fixture.stats().closes,1);assert.equal(fixture.results.length,explicit?3:2);
  assert.deepEqual(fixture.results[0].samples,samples);
  assert.equal(fixture.stats().peakRead,MAX_FRAME_BYTES);assert.ok(fixture.stats().peakWrite<=MAX_FRAME_BYTES);
}
for(const options of [{processError:true},{closeError:true},{unconfirmed:true},{zeroWrite:true},{readError:true},
  {result:{samples:new Float32Array(479)}},{result:{samples:new Float32Array(480),framesProcessed:1,callbackCount:2}},
  {result:{samples:Float32Array.from({length:480},()=>NaN),framesProcessed:1,callbackCount:1,processorConstructed:true,directProcessInvoked:true,backend:'ordinary-nc-direct'}}]) {
  const f=setup(request(0),options);assert.throws(()=>runSession(f.dependencies));assert.equal(f.stats().closes,1);
}
const both=setup(request(0),{processError:true,closeError:true});
assert.throws(()=>runSession(both.dependencies),error=>error instanceof AggregateError && error.errors.length===2);assert.equal(both.stats().closes,1);
for(const input of [request(0).subarray(0,100),Buffer.concat([closeFrame(0),request(1)]),request(1)]) {
  const f=setup(input);assert.throws(()=>runSession(f.dependencies));assert.equal(f.stats().closes,1);
}
const empty=setup(Buffer.alloc(0));assert.equal(runSession(empty.dependencies).requests,0);assert.equal(empty.stats().closes,1);
// Consume a large input without retaining result frames in the runner or fake IO.
const many=setup(Buffer.concat(Array.from({length:2000},(_,i)=>request(i))),{readSize:MAX_FRAME_BYTES,writeSize:MAX_FRAME_BYTES});
let delivered=0;many.dependencies.write=bytes=>{++delivered;return bytes.length;};
assert.equal(runSession(many.dependencies).requests,2000);assert.equal(delivered,2000);assert.equal(many.stats().closes,1);
for (const value of [undefined, null, false, 0, '']) for (const source of ['read','write','process','close']) {
  const f=setup(request(0));
  if(source === 'process' || source === 'close') {
    const original=f.dependencies.openSession;
    f.dependencies.openSession=()=>{const session=original();return {...session,[source](){if(source==='close'){session.close();}throw value;}};};
  } else f.dependencies[source]=()=>{throw value;};
  let caught=false;
  try { runSession(f.dependencies); } catch(error) {caught=true;assert.equal(error,value);}
  assert.equal(caught,true);assert.equal(f.stats().closes,1);
}
async function realPipes() {
  const {spawn} = require('node:child_process');
  const fs = require('node:fs'), os = require('node:os'), path = require('node:path');
  const directory=fs.mkdtempSync(path.join(os.tmpdir(),'openkrisp-worker-pipe-'));
  try {
    for (const explicit of [true,false]) {
      const log=path.join(directory,String(explicit));
      const child=spawn(process.execPath,[__filename,'--fixture-child',log],{stdio:['pipe','pipe','pipe']});
      let stderr='', bytes=0; const received=[];
      const decoder=new Parser({token,kinds:['result','close'],onFrame:frame=>received.push(frame)});
      const finished=new Promise((resolve,reject)=>{
        const deadline=setTimeout(()=>{child.kill('SIGKILL');reject(new Error('Pipe fixture deadline'));},5000);
        child.on('error',error=>{clearTimeout(deadline);reject(error);});
        child.stdout.on('data',chunk=>{try{bytes+=chunk.length;assert.ok(bytes<=MAX_FRAME_BYTES*3);decoder.push(chunk);}catch(error){child.kill('SIGKILL');reject(error);}});
        child.stderr.on('data',chunk=>{stderr+=chunk.toString();if(stderr.length>4096)child.kill('SIGKILL');});
        child.on('close',(code,signal)=>{clearTimeout(deadline);try{assert.equal(code,0,stderr);assert.equal(signal,null);decoder.finish();resolve();}catch(error){reject(error);}});
      });
      const input=Buffer.concat([request(0),request(1),...(explicit?[closeFrame(2)]:[])]);
      for(let offset=0;offset<input.length;offset+=17) {
        if(!child.stdin.write(input.subarray(offset,offset+17))) await new Promise(resolve=>child.stdin.once('drain',resolve));
        await new Promise(resolve=>setImmediate(resolve));
      }
      child.stdin.end();await finished;
      assert.equal(received.length,explicit?3:2);assert.deepEqual(received[1].samples,samples);
      assert.equal(fs.readFileSync(log,'utf8'),'closed\n');
    }
  } finally {fs.rmSync(directory,{recursive:true,force:true});}
}
realPipes().then(()=>console.log('synchronous bounded worker session and OS pipe tests passed')).catch(error=>{console.error(error);process.exitCode=1;});
