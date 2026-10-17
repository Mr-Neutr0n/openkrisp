'use strict';
const assert = require('node:assert/strict');
const { encode, Parser, HEADER_BYTES, MAX_FRAME_BYTES } = require('./worker_protocol.cjs');
const token = Buffer.from('00112233445566778899aabbccddeeff', 'hex');
const samples = Float32Array.from({ length: 480 }, (_, i) => (i - 240) / 240);
const frame = sequence => encode({ kind: 'request', token, sequence, samples });
const parser = (onFrame = () => {}, extra = {}) => new Parser({ token, kinds: ['request', 'close'], onFrame, ...extra });
for (const step of [1, 2, 7, 31, 32, 33, 479, 1920, 1952, 99999]) {
  const seen = [], p = parser(f => seen.push(f));
  const stream = Buffer.concat([frame(0), frame(1), encode({ kind: 'close', token, sequence: 2 })]);
  for (let i = 0; i < stream.length; i += step) p.push(stream.subarray(i, i + step));
  p.finish(); assert.equal(seen.length, 3); assert.deepEqual(seen[0].samples, samples);
  assert.equal(seen[2].kind, 'close'); assert.equal(p.retainedBytes, 0);
  assert.equal(p.capacityBytes, MAX_FRAME_BYTES); assert.ok(p.peakRetainedBytes <= MAX_FRAME_BYTES);
}
// Every nonempty proper prefix must fail EOF, including a complete header.
for (let n = 1; n < MAX_FRAME_BYTES; ++n) {
  const p = parser(); p.push(frame(0).subarray(0, n)); assert.throws(() => p.finish(), /Truncated/);
}
parser().finish();
assert.throws(() => encode({ kind: '__proto__', token, sequence: 0, samples }));
assert.throws(() => parser(() => {}, { kinds: ['toString'] }));
const mutations = [
  b => { b[0] ^= 1; }, b => { b[4] = 2; }, b => { b[5] = 255; },
  b => { b[6] = 1; }, b => { b[8] ^= 1; }, b => b.writeBigUInt64LE(1n, 24),
  b => b.writeUInt32LE(0xffffffff, 32), b => b.writeUInt32LE(1916, 32),
  b => b.writeFloatLE(NaN, HEADER_BYTES), b => b.writeFloatLE(Infinity, HEADER_BYTES),
  b => b.writeFloatLE(-Infinity, HEADER_BYTES),
];
for (const mutate of mutations) {
  const b = frame(0); mutate(b); const p = parser();
  assert.throws(() => p.push(b)); assert.throws(() => p.push(frame(0)), /unavailable/);
  assert.ok(p.peakRetainedBytes <= MAX_FRAME_BYTES);
}
for (const wrong of [0, 2, 0xffffffff]) {
  const p = parser(); p.push(frame(0)); assert.throws(() => p.push(frame(wrong)), /sequence/);
}
assert.throws(() => parser().push(encode({ kind: 'result', token, sequence: 0, samples })));
const closed = parser(); closed.push(encode({ kind: 'close', token, sequence: 0 })); assert.throws(() => closed.push(frame(1)), /after close/);
const max = parser(() => {}, { firstSequence: 0xffffffffffffffffn }); max.push(frame(0xffffffffffffffffn)); assert.throws(() => max.push(frame(0)), /sequence/);
for (const sequence of [-1, 2 ** 64, 0x10000000000000000n, 1.5, NaN]) assert.throws(() => frame(sequence));
for (const value of [NaN, Infinity, -Infinity]) { const bad = samples.slice(); bad[1] = value; assert.throws(() => encode({ kind: 'request', token, sequence: 0, samples: bad })); }
assert.throws(() => encode({ kind: 'close', token, sequence: 0, samples }));
assert.throws(() => encode({ kind: 'request', token, sequence: 0, samples: new Float32Array(479) }));
assert.throws(() => parser(() => { throw new Error('consumer'); }).push(frame(0)), /consumer/);
// Deterministic malformed header fuzz, each case guaranteed to violate magic.
let seed = 0x17a012;
for (let run = 0; run < 1000; ++run) {
  const b = Buffer.alloc(HEADER_BYTES);
  for (let i = 0; i < b.length; ++i) { seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0; b[i] = seed >>> 24; }
  b[0] = 0; const p = parser(); assert.throws(() => p.push(b)); assert.equal(p.peakRetainedBytes, HEADER_BYTES);
}
// Many frames in one chunk cannot grow parser storage with chunk length.
let count = 0; const p = parser(() => ++count);
p.push(Buffer.concat(Array.from({ length: 2000 }, (_, i) => frame(i)))); p.finish();
assert.equal(count, 2000); assert.equal(p.capacityBytes, MAX_FRAME_BYTES); assert.equal(p.peakRetainedBytes, MAX_FRAME_BYTES);
for (const action of ['push', 'finish']) for (const catchInside of [false, true]) {
  let delivered = 0;
  const reentrant = parser(() => {
    ++delivered;
    const call = () => action === 'push' ? reentrant.push(frame(1)) : reentrant.finish();
    if (catchInside) assert.throws(call, /reentry/); else call();
  });
  assert.throws(() => reentrant.push(Buffer.concat([frame(0), frame(1)])), /reentry/);
  assert.equal(delivered, 1); assert.equal(reentrant.active, false);
  assert.throws(() => reentrant.push(frame(1)), /unavailable/);
  assert.throws(() => reentrant.finish(), /unavailable/);
}
const badInput = parser();
assert.throws(() => badInput.push('bad'), /Buffer/);
assert.throws(() => badInput.push(frame(0)), /unavailable/);
assert.equal(badInput.active, false);
console.log('bounded worker protocol codec tests passed');
