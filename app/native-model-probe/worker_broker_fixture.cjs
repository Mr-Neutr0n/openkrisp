'use strict';
const fs = require('fs');
const { runSession } = require('./worker_session.cjs');
const mode = process.argv[2] || 'normal';
const ready = process.argv[3] || 'fixture-ready';
const token = Buffer.from(process.argv[4] || '000102030405060708090a0b0c0d0e0f', 'hex');
function stall() { for (;;) Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0); }
if (mode === 'ignore-term') process.on('SIGTERM', () => {});
if (mode === 'startup-stall' || mode === 'ignore-term') stall();
if (mode === 'startup-crash') process.exit(7);
if (mode === 'oversized-ready') fs.writeSync(3, 'x'.repeat(513));
else fs.writeSync(3, (mode === 'wrong-ready' ? 'wrong-ready' : ready) + '\n');
let writes = 0;
runSession({token,
  openSession: () => ({
    process(input) {
      if (mode === 'processing-stall') {
        if (process.argv[5]) fs.writeFileSync(process.argv[5], 'entered');
        stall();
      }
      if (mode === 'crash') process.exit(9);
      const samples = Float32Array.from(input, value => value * 0.5);
      return {samples, framesProcessed:1, callbackCount:1, processorConstructed:true,
        directProcessInvoked:true, backend:'ordinary-nc-direct'};
    },
    close() { if (mode === 'close-stall') stall(); return {teardownComplete:true}; },
  }),
  read: scratch => fs.readSync(0, scratch, 0, scratch.length, null),
  write(bytes) {
    ++writes;
    if (mode === 'malformed' && writes === 1) { bytes = Buffer.from(bytes); bytes[0] ^= 1; }
    if (mode === 'trailing' && writes === 1) { fs.writeSync(3, Buffer.concat([bytes, Buffer.from([1])])); return bytes.length; }
    return fs.writeSync(3, bytes);
  },
});
if (mode === 'nonzero-exit') process.exitCode = 12;
