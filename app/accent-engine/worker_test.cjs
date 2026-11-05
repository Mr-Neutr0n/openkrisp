'use strict';
const assert = require('node:assert/strict');
const wire = require('./wire.cjs');
const worker = require('./worker.cjs');
const token = Buffer.alloc(16, 0x47), samples = new Float32Array(480).fill(0.25);
const request = n => wire.encode({ token, kind: 'request', sequence: n, samples });
const close = n => wire.encode({ token, kind: 'close', sequence: n });
function execute(bytes, override = {}) {
    const output = [], seen = [];
    let offset = 0, calls = 0, closed = 0;
    const session = {
        process(input) {
            assert.equal(input.length, 480);
            if (++calls === 1) return { samples: new Float32Array(0), framesProcessed: 1, callbackCount: 0, backend: 'accent-direct' };
            return { samples: new Float32Array(input), framesProcessed: 1, callbackCount: 1, backend: 'accent-direct' };
        }, close() { ++closed; return { teardownComplete: true }; }
    };
    const result = worker.runSession({ token, session, read(buffer) {
        const count = Math.min(7, bytes.length - offset);
        bytes.copy(buffer, 0, offset, offset + count); offset += count; return count;
    }, write(buffer) { output.push(Buffer.from(buffer.subarray(0, 3))); return Math.min(buffer.length, 3); }, ...override });
    const parser = new wire.Parser({ token, kinds: ['empty', 'result', 'close'], onFrame: frame => seen.push(frame) });
    for (const part of output) parser.push(part);
    parser.finish();
    return { result, seen, calls, closed };
}
const complete = Buffer.concat([request(0), request(1), close(2)]);
const done = execute(complete);
assert.deepEqual(done.result, { inputFrames: 2, outputFrames: 1, teardownComplete: true });
assert.deepEqual(done.seen.map(x => x.kind), ['empty', 'result', 'close']);
assert.equal(done.closed, 1);
assert.equal(done.seen[1].samples[2], 0.25);
for (const changed of [complete.subarray(0, 11), request(0), Buffer.concat([request(0), request(0)])])
    assert.throws(() => execute(changed));
for (const at of [0, 4, 5, 6, 8, 24, 32]) {
    const bytes = Buffer.from(complete); bytes[at] ^= 0xff;
    assert.throws(() => execute(bytes));
}
const nan = Buffer.from(complete); nan.writeFloatLE(NaN, wire.HEADER_BYTES);
assert.throws(() => execute(nan));
assert.throws(() => wire.encode({ token, kind: 'empty', sequence: 0, samples }));
assert.equal(wire.encode({ token, kind: 'empty', sequence: 0 }).length, 36);
let closedOnFailure = 0;
assert.throws(() => execute(complete, { session: {
    process() { return { samples, framesProcessed: 1, callbackCount: 0, backend: 'accent-direct' }; },
    close() { ++closedOnFailure; return { teardownComplete: true }; }
} }), /Invalid AR native/);
assert.equal(closedOnFailure, 1);
const validConfig = { addonPath: '/external/addon', modelPath: '/external/model', adapterPath: '/owned/adapter',
    adapterSHA256: 'a'.repeat(64), direction: 'outbound', token: token.toString('hex'), parentPID: 123 };
assert.equal(worker.config(validConfig).direction, 'outbound');
for (const change of [{ direction: 'outbound-hvc-lfb' }, { token: 'bad' }, { parentPID: 0 }, { arbitrary: true }])
    assert.throws(() => worker.config({ ...validConfig, ...change }));
async function main() {
    let loaded = 0;
    await assert.rejects(worker.runWorker(validConfig, { deniedNetwork() { throw Error('denied'); },
        loadAdapter() { ++loaded; } }), /denied/);
    assert.equal(loaded, 0);
    await assert.rejects(worker.runWorker(validConfig, { deniedNetwork() {}, identify() { throw Error('hash mismatch'); },
        loadAdapter() { ++loaded; } }), /hash mismatch/);
    assert.equal(loaded, 0);
    console.log('AR wire fragmentation, empty reply, bounds, sequencing, failure cleanup and admission cases passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
