'use strict';

// Loads only our shim. Every dlopen attempt names a nonexistent file in a new
// test-owned temporary directory. No original addon or model path is used.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const adapter = require(path.resolve(process.argv[2] || path.join(__dirname, 'build/native-probe.node')));
const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'openkrisp-native-validation-'));
try {
    const baseline = () => ({
        addonPath: path.join(temporary, 'nonexistent-image.node'),
        modelPath: path.join(temporary, 'nonexistent-model.kef'),
        input: new Float32Array(480), sampleRate: 48000, frameSize: 480,
    });
    const mutations = [
        value => { value.sampleRate = 32000; },
        value => { value.frameSize = 0; },
        value => { value.input = new Float64Array(480); },
        value => { value.input = new Float32Array(0); },
        value => { value.input = new Float32Array(481); },
        value => { value.input = new Float32Array(96480); },
        value => { value.input[0] = NaN; },
        value => { value.input[479] = Infinity; },
        value => { value.suppressionLevel = -1; },
        value => { value.suppressionLevel = 101; },
        value => { value.bypass = 1; },
        value => { value.addonPath = 'relative'; },
        value => { value.modelPath = '/tmp/a\0b'; },
        value => { value.modelPath = '/tmp/\ud800'; },
    ];
    for (const mutate of mutations) {
        const value = baseline(); mutate(value);
        assert.throws(() => adapter.run(value));
    }
    assert.throws(() => adapter.run());
    assert.throws(() => adapter.run(null));
    assert.throws(() => adapter.run(baseline(), 1));
    const thrown = new Error('getter fixture');
    const getter = baseline();
    Object.defineProperty(getter, 'sampleRate', { get() { throw thrown; } });
    assert.throws(() => adapter.run(getter), error => error === thrown);
    assert.throws(() => adapter.run(baseline()), /Cannot load the selected native image:.*dlopen/s);
    assert.throws(() => adapter.run({}), /Expected a number/);
    console.log('20 host-only native shim validation cases passed');
} finally {
    fs.rmSync(temporary, { recursive: true, force: true });
}
