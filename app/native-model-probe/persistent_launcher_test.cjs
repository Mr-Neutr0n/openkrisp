'use strict';
const assert = require('node:assert/strict');
const { persistentAdapter } = require('./run_persistent_probe.cjs');
const options = { input: new Float32Array(48000).fill(0.25), frameSize: 480 };
let opened = 0, closed = 0, sizes = [];
function native(failure) {
  return { open() {
    ++opened;
    return {
      process(input) {
        sizes.push(input.length);
        if (failure === 'throw') throw new Error('process failure');
        const samples = new Float32Array(input);
        if (failure === 'nan') samples[0] = NaN;
        return { samples, framesProcessed: input.length / 480, callbackCount: failure === 'count' ? 0 : input.length / 480,
          processorConstructed: true, directProcessInvoked: true, backend: 'ordinary-nc-direct' };
      },
      close() { ++closed; return { teardownComplete: failure !== 'close' }; },
    };
  } };
}
const result = persistentAdapter(native()).run(options);
assert.equal(opened, 1); assert.equal(closed, 1);
assert.deepEqual(sizes, [480, 8160, 1440, 13920, 24000]);
assert.equal(result.sessionBatches, 5); assert.equal(result.callbackCount, 100);
assert.deepEqual(result.samples, options.input);
options.input.fill(-1); assert.equal(result.samples[0], 0.25);
for (const failure of ['throw', 'nan', 'count', 'close']) {
  const before = closed;
  assert.throws(() => persistentAdapter(native(failure)).run(options));
  assert.equal(closed, before + 1, 'every opened failed session must close');
}
console.log('persistent launcher fixtures passed');
