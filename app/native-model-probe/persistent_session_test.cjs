'use strict';

// Both paths are host-built fixtures. No original addon, model or audio is used.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const adapter = require(path.resolve(process.argv[2] || path.join(__dirname, 'build/native-probe.node')));
const fixture = path.resolve(process.argv[3] || path.join(__dirname, 'build/persistent-fixture.dylib'));
const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'openkrisp-persistent-fixture-'));
let nextLog = 0;
function setup() {
    const modelPath = path.join(temporary, `events-${nextLog++}`);
    const events = () => fs.existsSync(modelPath) ? fs.readFileSync(modelPath, 'utf8') : '';
    const session = adapter.open({ addonPath: fixture, modelPath, sampleRate: 48000,
        frameSize: 480, suppressionLevel: 37 });
    return { session, events };
}
function batch(frames = 1, value = 0.25) { return new Float32Array(480 * frames).fill(value); }
async function main() {
    const { session, events } = setup();
    assert.equal(events(), 'C');
    const detachedProcess = session.process;
    const detachedClose = session.close;
    assert.throws(() => detachedProcess(batch()));
    assert.throws(() => detachedClose());
    for (const receiver of [{}, null, Object.create(session), { process: detachedProcess, close: detachedClose }]) {
        assert.throws(() => detachedProcess.call(receiver, batch()));
        assert.throws(() => detachedClose.call(receiver));
    }
    assert.equal(events(), 'C');
    const input = batch(2);
    const first = session.process(input);
    assert(first.samples instanceof Float32Array);
    assert.equal(first.framesProcessed, 2);
    assert.equal(first.callbackCount, 2);
    assert.deepEqual(Array.from(first.samples), [...Array(480).fill(1.25), ...Array(480).fill(2.25)]);
    input.fill(99);
    const second = session.process(batch());
    assert.deepEqual(Array.from(second.samples), Array(480).fill(3.25));
    assert.equal(second.framesProcessed, 1);
    assert.equal(second.callbackCount, 1);
    assert.equal(first.samples[0], 1.25);
    assert.equal(events(), 'C');
    assert.deepEqual(session.close(), { teardownComplete: true });
    assert.equal(events(), 'CDU');
    session.close();
    assert.equal(events(), 'CDU');
    assert.throws(() => session.process(batch()), /closed/i);
    assert.equal(second.samples[0], 3.25);

    const valid = setup();
    for (const invalid of [undefined, null, [], new Float64Array(480), batch(0), new Float32Array(481),
        new Float32Array(96480), batch(1, NaN), batch(1, Infinity)]) {
        assert.throws(() => valid.session.process(invalid));
    }
    assert.throws(() => valid.session.process(batch(), batch()));
    assert.equal(valid.session.process(batch()).samples[0], 1.25);
    valid.session.close();
    assert.equal(valid.events(), 'CDU');

    for (const sentinel of [-9001, -9002, -9003, -9004, -9005]) {
        const failed = setup();
        assert.throws(() => failed.session.process(batch(1, sentinel)), /failure|callback|output|sample/i);
        const expectedEvents = sentinel === -9001 ? 'CEDU' : 'CDU';
        assert.equal(failed.events(), expectedEvents, 'native failure must close before returning');
        failed.session.close();
        failed.session.close();
        assert.equal(failed.events(), expectedEvents);
        assert.throws(() => failed.session.process(batch()), /closed/i);
    }

    const destructorCallback = setup();
    destructorCallback.session.process(batch(1, -9006));
    assert.throws(() => destructorCallback.session.close(), /callback outside a process batch/i);
    assert.equal(destructorCallback.events(), 'CDU', 'callback violation must not interrupt cleanup');
    assert.throws(() => destructorCallback.session.close(), /callback outside a process batch/i);
    assert.equal(destructorCallback.events(), 'CDU', 'failed close must not repeat native deletion');
    assert.throws(() => destructorCallback.session.process(batch()), /closed/i);

    const constructionLog = path.join(temporary, 'construct-failure');
    assert.throws(() => adapter.open({ addonPath: fixture, modelPath: constructionLog,
        sampleRate: 48000, frameSize: 480, suppressionLevel: 37 }), /vendor failure/);
    assert.equal(fs.readFileSync(constructionLog, 'utf8'), 'EU');

    const reentrantLog = path.join(temporary, 'reentrant');
    let getterCalls = 0;
    const outer = adapter.open({ addonPath: fixture, modelPath: reentrantLog,
        get sampleRate() {
            ++getterCalls;
            assert.throws(() => adapter.open({}), /already|running|active/i);
            return 48000;
        }, frameSize: 480, suppressionLevel: 37 });
    assert.equal(getterCalls, 1);
    assert.equal(outer.process(batch()).samples[0], 1.25);
    outer.close();
    assert.equal(fs.readFileSync(reentrantLog, 'utf8'), 'CDU');

    assert.equal(typeof global.gc, 'function', 'Run this test with node --expose-gc');
    let abandoned = setup();
    const gcEvents = abandoned.events;
    assert.equal(abandoned.session.process(batch()).samples[0], 1.25);
    abandoned = null;
    for (let attempt = 0; attempt < 100 && gcEvents() !== 'CDU'; ++attempt) {
        global.gc();
        await new Promise(resolve => setImmediate(resolve));
    }
    assert.equal(gcEvents(), 'CDU', 'GC finalizer must release the processor exactly once');
    console.log('host-only persistent native session cases passed');
}
main().finally(() => fs.rmSync(temporary, { recursive: true, force: true })).catch(error => {
    console.error(error);
    process.exitCode = 1;
});
