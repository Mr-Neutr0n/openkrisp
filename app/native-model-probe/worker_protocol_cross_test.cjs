'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { Parser, encode } = require('./worker_protocol.cjs');

const binary = process.argv[2];
assert(binary, 'Pass the native protocol test executable');
const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'openkrisp-wire-cross-'));
function native(...args) {
  const result = spawnSync(binary, args, { encoding: 'utf8', timeout: 10000, maxBuffer: 65536 });
  assert.ifError(result.error);
  assert.equal(result.status, 0, result.stderr);
}
try {
  const filename = path.join(directory, 'fixture.bin');
  const token = Buffer.from(Array.from({ length: 16 }, (_, i) => i));
  const samples = Float32Array.from({ length: 480 }, (_, i) => i * 0.125);
  const expected = Buffer.concat([
    encode({ kind: 'request', token, sequence: 0n, samples }),
    encode({ kind: 'close', token, sequence: 1n }),
  ]);
  native('--emit', filename);
  const emitted = fs.readFileSync(filename);
  assert.deepEqual(emitted, expected, 'Native and JavaScript bytes must match');
  const frames = [];
  const parser = new Parser({ token, kinds: ['request', 'close'], onFrame: frame => frames.push(frame) });
  for (let offset = 0; offset < emitted.length; offset += 13) parser.push(emitted.subarray(offset, offset + 13));
  parser.finish();
  assert.equal(frames.length, 2);
  assert.deepEqual(frames[0].samples, samples);
  assert.equal(frames[0].sequence, 0n);
  assert.equal(frames[1].kind, 'close');
  assert.equal(frames[1].sequence, 1n);
  fs.writeFileSync(filename, expected);
  native('--check', filename);
  console.log('C++ and Node worker protocol compatibility passed');
} finally {
  fs.rmSync(directory, { recursive: true, force: true });
}
