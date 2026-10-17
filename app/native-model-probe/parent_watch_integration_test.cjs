'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
const {spawn}=require('node:child_process');
if(process.argv[2]==='--grandchild') {
  // This loads only our host adapter. No original addon or model is accessed.
  const native=require(process.argv[3]);
  const watch=native.watchParent(Number(process.argv[4]));
  if(process.argv[5]==='stopped')assert.equal(watch.close().stopped,true);
  fs.writeSync(1,Buffer.from('R'));
  fs.readSync(0,Buffer.alloc(1),0,1,null); // Main JS thread remains blocked.
  watch.close();fs.writeSync(1,Buffer.from('S'));process.exit(0);
} else if(process.argv[2]==='--intermediate') {
  const grandchild=spawn(process.execPath,[__filename,'--grandchild',process.argv[3],String(process.pid),process.argv[4]],{stdio:[3,1,2]});
  grandchild.on('error',error=>{fs.writeSync(2,String(error));process.exit(1);});
  setInterval(()=>{},1000);
} else {
  const adapter=process.argv[2];
  if(!adapter || !require('node:path').isAbsolute(adapter))throw new Error('Expected absolute host adapter path');
  const delay=ms=>new Promise(resolve=>setTimeout(resolve,ms));
  function bounded(promise,ms,label) {
    let timer;
    return Promise.race([promise,new Promise((_,reject)=>{timer=setTimeout(()=>reject(new Error(label+' deadline')),ms);})]).finally(()=>clearTimeout(timer));
  }
  async function check(mode) {
    const parent=spawn(process.execPath,[__filename,'--intermediate',adapter,mode],{stdio:['ignore','pipe','pipe','pipe']});
    // Keep requests on fd3: Node destroys ChildProcess.stdin on parent exit.
    const requests=parent.stdio[3];
    let output='',stderr='',exitObserved=false,eofObserved=false,ioError;
    let resolveReady,rejectReady;
    const ready=new Promise((resolve,reject)=>{resolveReady=resolve;rejectReady=reject;});
    const exited=new Promise(resolve=>parent.once('exit',(code,signal)=>{exitObserved=true;resolve({code,signal});}));
    const eof=new Promise(resolve=>parent.stdout.once('end',()=>{eofObserved=true;resolve();}));
    parent.on('error',error=>{ioError=error;rejectReady(error);});
    // EPIPE is expected if the guarded grandchild exits before stdin is closed.
    requests.on('error',error=>{if(error.code!=='EPIPE'){ioError=error;rejectReady(error);}});
    parent.stdout.on('data',chunk=>{
      output+=chunk.toString('ascii');
      if(output.length>2){ioError=new Error('Unexpected fixture output');rejectReady(ioError);}
      if(output.startsWith('R'))resolveReady();
    });
    parent.stderr.on('data',chunk=>{stderr=(stderr+chunk.toString()).slice(0,4096);});
    try {
      await bounded(ready,3000,'readiness');assert.equal(output,'R',stderr);
      // Signal only the ChildProcess we own. Never signal the reparented PID.
      assert.equal(parent.kill('SIGKILL'),true);
      const exit=await bounded(exited,3000,'owned parent exit');
      assert.equal(exit.signal,'SIGKILL');assert.equal(exitObserved,true);
      if(mode==='stopped') {
        await delay(150);assert.equal(eofObserved,false,'Stopped watcher must leave blocked child alive');assert.equal(output,'R');
        requests.end();await bounded(eof,3000,'stopped child EOF');assert.equal(output,'RS');
      } else {
        await bounded(eof,3000,'active guard pipe EOF');assert.equal(output,'R','Active guard must exit while readSync is blocked');
      }
      if(ioError)throw ioError;
      console.log(JSON.stringify({mode,ownedParentExit:true,pipeEOF:true,output}));
    } finally {
      // Closing the only writer unblocks the grandchild even when assertions fail.
      // Reap only the owned intermediate. Do not signal a reparented grandchild.
      requests.end();
      if(!exitObserved)parent.kill('SIGKILL');
      await bounded(exited,3000,'cleanup parent exit');
      await bounded(eof,3000,'cleanup grandchild pipe EOF');
    }
  }
  (async()=>{await check('active');await check('stopped');console.log('native blocked-JS parent watch integration passed');})().catch(error=>{console.error(error);process.exitCode=1;});
}
