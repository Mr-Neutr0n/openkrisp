#!/usr/bin/env node
'use strict';
const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto'), net = require('node:net');
const {runSession} = require('./worker_session.cjs');
const ADDON_SHA256 = 'adde50ff549700fd535fb9cc8e42d45fa36dca02131009ded727a10625ae8755';
const MODEL_SHA256 = '12110c114a3c6c4e2a00c26b22d06463239d096da9f7b71a948fd3a7005b355d';
// Caller must use the reviewed deny-network sandbox profile and clear NODE_OPTIONS
// before Node starts. Broker must also clear NODE_PATH and DYLD injection variables,
// permitting only the reviewed DYLD_LIBRARY_PATH needed for installed libraries.
// EPERM is only a prerequisite, not proof of full isolation. Hashing precedes
// require/native.open path reopening and does not atomically bind loaded images.
// Caller owns fd0 requests, fd3 responses, fd1/2 redirection and kill deadlines.
const KEYS = ['addonPath','modelPath','adapterPath','adapterSha256','nodeSha256','token','suppressionLevel','bypass','parentPID'];
function validateConfig(config) {
  if (!config || typeof config !== 'object' || Array.isArray(config) || Object.keys(config).length !== KEYS.length || KEYS.some(k=>!Object.hasOwn(config,k))) throw new Error('Invalid config keys');
  for (const key of ['addonPath','modelPath','adapterPath']) if (typeof config[key] !== 'string' || !path.isAbsolute(config[key]) || config[key].includes('\0')) throw new Error('Invalid absolute path');
  for (const key of ['adapterSha256','nodeSha256']) if (typeof config[key] !== 'string' || !/^[0-9a-f]{64}$/.test(config[key])) throw new Error('Invalid SHA256');
  if (typeof config.token !== 'string' || !/^[0-9a-f]{32}$/.test(config.token)) throw new Error('Invalid token');
  if (typeof config.bypass !== 'boolean' || !Number.isFinite(config.suppressionLevel) || config.suppressionLevel<0 || config.suppressionLevel>100) throw new Error('Invalid processing options');
  if (!Number.isInteger(config.parentPID) || config.parentPID <= 1 || config.parentPID > 2147483647) throw new Error('Invalid expected parent PID');
  return Object.freeze({...config});
}
function fileHash(filename) {
  const stat=fs.lstatSync(filename);
  if (!stat.isFile() || stat.isSymbolicLink()) throw new Error('Expected regular nonsymlink file');
  const fd=fs.openSync(filename,fs.constants.O_RDONLY|fs.constants.O_NOFOLLOW);
  try {
    const opened=fs.fstatSync(fd);
    if(!opened.isFile() || opened.dev!==stat.dev || opened.ino!==stat.ino) throw new Error('File identity changed');
    const hash=crypto.createHash('sha256'), scratch=Buffer.alloc(65536);
    for(;;) { const n=fs.readSync(fd,scratch,0,scratch.length,null);if(!n)break;hash.update(scratch.subarray(0,n)); }
    return hash.digest('hex');
  } finally {fs.closeSync(fd);}
}
function loopbackCheck() {
  return new Promise(resolve=>{
    const socket=new net.Socket();let done=false;
    const finish=code=>{if(!done){done=true;socket.destroy();resolve(code);}};
    socket.once('error',e=>finish(e.code));socket.once('connect',()=>finish('CONNECTED'));socket.setTimeout(1000,()=>finish('TIMEOUT'));
    try{socket.connect({host:'127.0.0.1',port:9});}catch(e){finish(e.code);}
  });
}
// Injection is for host-only tests. CLI supplies no overrides or environment gates.
async function admit(config, dependencies={}) {
  config=validateConfig(config);
  if(await (dependencies.loopbackCheck || loopbackCheck)() !== 'EPERM') throw new Error('Required network denial was not EPERM');
  const hash=dependencies.fileHash || fileHash;
  const identities=[['addonPath',ADDON_SHA256],['modelPath',MODEL_SHA256],['adapterPath',config.adapterSha256]];
  if(hash(process.execPath)!==config.nodeSha256) throw new Error('Node identity mismatch');
  for(const [key,expected] of identities) if(hash(config[key])!==expected) throw new Error(key+' identity mismatch');
  return config;
}
function writeAll(write,bytes) {
  let offset=0;
  while(offset<bytes.length) {
    let n;
    try {n=write(bytes.subarray(offset));}catch(e){if(e?.code==='EINTR')continue;throw e;}
    if(!Number.isInteger(n)||n<=0||n>bytes.length-offset)throw new Error('Invalid readiness write progress');
    offset+=n;
  }
}
async function runWorker(config, dependencies={}) {
  config=await admit(config,dependencies);
  const native=(dependencies.loadAdapter || require)(config.adapterPath);
  if(!native || typeof native.open!=='function' || typeof native.watchParent!=='function')throw new Error('Adapter must export open and watchParent');
  const write=dependencies.write || (bytes=>fs.writeSync(3,bytes,0,bytes.length,null));
  const read=dependencies.read || (bytes=>fs.readSync(0,bytes,0,bytes.length,null));
  const watch = native.watchParent(config.parentPID);
  if (!watch || typeof watch.close !== 'function') throw new Error('Invalid parent watch');
  try { return runSession({token:Buffer.from(config.token,'hex'),read,write,openSession(){
    const session=native.open({addonPath:config.addonPath,modelPath:config.modelPath,sampleRate:48000,frameSize:480,suppressionLevel:config.suppressionLevel,bypass:config.bypass});
    try {
      if(!session || typeof session.process!=='function' || typeof session.close!=='function')throw new Error('Invalid session interface');
      const ready=`OKREADY1 ${config.token} ordinary-nc-direct 48000 480 ${ADDON_SHA256} ${MODEL_SHA256} ${config.adapterSha256} ${config.nodeSha256}\n`;
      writeAll(write,Buffer.from(ready,'ascii'));
      return session;
    } catch(error) {
      if(session && typeof session.close==='function') {
        try{if(session.close()?.teardownComplete!==true)throw new Error('Teardown was not confirmed');}
        catch(teardown){throw new AggregateError([error,teardown],'Readiness failed and teardown failed');}
      }
      throw error;
    }
  }}); } finally {
    if (watch.close()?.stopped !== true) throw new Error('Parent watch stop was not confirmed');
  }
}
module.exports={validateConfig,admit,runWorker,fileHash,ADDON_SHA256,MODEL_SHA256};
if(require.main===module) {
  Promise.resolve().then(()=>{
    if(process.argv.length!==3)throw new Error('Expected one JSON config argument');
    return runWorker(JSON.parse(process.argv[2]));
  }).catch(error=>{process.stderr.write('Audio worker failed: '+String(error?.message || error)+'\n');process.exitCode=1;});
}
