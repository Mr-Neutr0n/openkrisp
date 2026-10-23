'use strict';
// Own stateful NC oracle. Bias makes leading-zero warmup observable.
const fs = require('fs');
const {runSession} = require('../native-model-probe/worker_session.cjs');
const token = Buffer.from(process.argv[2], 'hex');
const mode = process.argv[3] || 'normal';
const trace = process.argv[4];
let state = 0;
const record = value => {if(trace)fs.appendFileSync(trace, value+'\n');};
fs.writeSync(3, 'stateful-nc-ready\n');
runSession({token,
  openSession: () => ({
    process(input) {
      const samples = new Float32Array(480);
      for(let i=0;i<480;i++) {
        state = Math.fround(Math.fround(Math.fround(state*.25) + Math.fround(input[i]*.5)) + 1/4096);
        samples[i] = state;
      }
      return {samples,framesProcessed:1,callbackCount:1,processorConstructed:true,directProcessInvoked:true,backend:'ordinary-nc-direct'};
    },
    close() {record('close');if(mode==='bad-close')throw new Error('own close failure');return {teardownComplete:true};},
  }),
  read: scratch => fs.readSync(0,scratch,0,scratch.length,null),
  write: bytes => fs.writeSync(3,bytes),
});
