'use strict';

// The fixture and adapter are built from this repository. No original files.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const adapter = require(path.resolve(process.argv[2]));
const fixture = path.resolve(process.argv[3]);
const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'openkrisp-ar-fixture-'));
let serial = 0;
function setup() {
    const modelPath = path.join(temporary, `events-${serial++}`);
    const events = () => fs.existsSync(modelPath) ? fs.readFileSync(modelPath, 'utf8') : '';
    const session = adapter.open({ addonPath: fixture, modelPath,
        sampleRate: 48000, frameSize: 480, suppressionLevel: 37 });
    return { session, events };
}
function batch(frames = 1, value = 0.25) { return new Float32Array(480 * frames).fill(value); }
async function main() {
    const { session, events } = setup();
    assert.equal(events(), 'C');
    const detached = session.process;
    for (const receiver of [undefined, {}, Object.create(session)])
        assert.throws(() => detached.call(receiver, batch()));
    const startup = session.process(batch(2));
    assert.equal(startup.framesProcessed, 2);
    assert.equal(startup.callbackCount, 0);
    assert.equal(startup.samples.length, 0);
    const input = batch(3);
    const output = session.process(input);
    assert.equal(output.callbackCount, 3);
    assert.equal(output.framesProcessed, 3);
    assert.deepEqual(Array.from(output.samples), [3.25, 4.25, 5.25].flatMap(x => Array(480).fill(x)));
    input.fill(99);
    assert.equal(output.samples[0], 3.25, 'borrowed callback samples must be copied');
    assert.deepEqual(session.close(), { teardownComplete: true });
    session.close();
    assert.equal(events(), 'CDU', 'release processor before unloading its image exactly once');
    assert.throws(() => session.process(batch()), /closed/);
    for (const invalid of [undefined, null, [], new Float64Array(480), batch(0),
        new Float32Array(481), new Float32Array(480480), batch(1, NaN), batch(1, Infinity)]) {
        const next = setup();
        assert.throws(() => next.session.process(invalid));
        assert.equal(next.session.process(batch(3)).samples[0], 3.25);
        next.session.close();
        assert.equal(next.events(), 'CDU');
    }
    for (const sentinel of [-9001, -9002, -9004, -9005]) {
        const next = setup();
        next.session.process(batch(2));
        assert.throws(() => next.session.process(batch(1, sentinel)), /failure|callback|output|sample/i);
        assert.equal(next.events(), sentinel === -9001 ? 'CEDU' : 'CDU');
        next.session.close();
        assert.throws(() => next.session.process(batch()), /closed/);
    }
    const onDestroy = setup();
    onDestroy.session.process(batch(1, -9006));
    assert.throws(() => onDestroy.session.close(), /callback outside/);
    assert.equal(onDestroy.events(), 'CDU');
    const failureLog = path.join(temporary, 'construct-failure');
    assert.throws(() => adapter.open({ addonPath: fixture, modelPath: failureLog,
        sampleRate: 48000, frameSize: 480, suppressionLevel: 37 }), /vendor failure/);
    assert.equal(fs.readFileSync(failureLog, 'utf8'), 'EU', 'destroy foreign exception before unload');
    const reentrant = path.join(temporary, 'reentrant');
    const outer = adapter.open({ addonPath: fixture, modelPath: reentrant,
        get sampleRate() { assert.throws(() => adapter.open({}), /already.*running/); return 48000; },
        frameSize: 480, suppressionLevel: 37 });
    outer.close();
    assert.equal(fs.readFileSync(reentrant, 'utf8'), 'CDU');
    let abandoned = setup();
    const gcEvents = abandoned.events;
    abandoned = null;
    for (let i = 0; i < 100 && gcEvents() !== 'CDU'; ++i) {
        global.gc(); await new Promise(resolve => setImmediate(resolve));
    }
    assert.equal(gcEvents(), 'CDU');
    console.log('host-only AR startup, borrowed callback, lifetime, exception, receiver and validation cases passed');
}
main().finally(() => fs.rmSync(temporary, { recursive: true, force: true })).catch(error => {
    console.error(error); process.exitCode = 1;
});
