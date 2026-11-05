#!/usr/bin/env node
'use strict';

const fs = require('node:fs');
const identity = require('./identity.cjs');
const wire = require('./wire.cjs');
const KEYS = ['addonPath', 'modelPath', 'adapterPath', 'adapterSHA256', 'direction', 'token', 'parentPID'];
function config(value) {
    if (!value || Array.isArray(value) || Object.keys(value).length !== KEYS.length ||
        KEYS.some(key => !Object.hasOwn(value, key))) throw Error('Invalid AR configuration keys');
    for (const key of ['addonPath', 'modelPath', 'adapterPath']) identity.absolute(value[key], key);
    identity.digest(value.adapterSHA256, 'adapterSHA256');
    if (!Object.hasOwn(identity.MODELS, value.direction) || !/^[0-9a-f]{32}$/.test(value.token) ||
        !Number.isInteger(value.parentPID) || value.parentPID <= 1 || value.parentPID > 2147483647)
        throw Error('Invalid AR direction, token or parent PID');
    return Object.freeze({ ...value });
}
function writeAll(write, bytes) {
    let offset = 0;
    while (offset < bytes.length) {
        let count;
        try { count = write(bytes.subarray(offset)); }
        catch (error) { if (error.code === 'EINTR') continue; throw error; }
        if (!Number.isInteger(count) || count <= 0 || count > bytes.length - offset)
            throw Error('Invalid AR write progress');
        offset += count;
    }
}
function runSession({ token, read, write, session, afterClose = () => {} }) {
    let closed = false, inputFrames = 0, outputFrames = 0;
    const send = frame => writeAll(write, wire.encode({ ...frame, token }));
    function close() {
        if (!closed) {
            closed = true;
            if (session.close()?.teardownComplete !== true) throw Error('AR teardown was not confirmed');
        }
    }
    try {
        const parser = new wire.Parser({ token, kinds: ['request', 'close'], onFrame(frame) {
            if (frame.kind === 'close') {
                close(); afterClose();
                send({ kind: 'close', sequence: frame.sequence });
                return;
            }
            const result = session.process(frame.samples);
            if (!(result?.samples instanceof Float32Array) || result.framesProcessed !== 1 ||
                ![0, 1].includes(result.callbackCount) || result.samples.length !== result.callbackCount * 480 ||
                result.backend !== 'accent-direct') throw Error('Invalid AR native result');
            ++inputFrames;
            if (result.callbackCount) {
                ++outputFrames;
                send({ kind: 'result', sequence: frame.sequence, samples: result.samples });
            } else send({ kind: 'empty', sequence: frame.sequence });
        } });
        const scratch = Buffer.alloc(wire.MAX_FRAME_BYTES);
        for (;;) {
            let count;
            try { count = read(scratch); }
            catch (error) { if (error.code === 'EINTR') continue; throw error; }
            if (!Number.isInteger(count) || count < 0 || count > scratch.length) throw Error('Invalid AR read progress');
            if (!count) break;
            parser.push(scratch.subarray(0, count));
            if (parser.closed) break;
        }
        parser.finish();
        if (!closed) throw Error('AR transport EOF before explicit close');
        return { inputFrames, outputFrames, teardownComplete: true };
    } finally { close(); }
}
// Dependency injection supports owned fixtures. The CLI accepts no gate overrides.
async function runWorker(value, dependencies = {}) {
    value = config(value);
    await (dependencies.deniedNetwork || identity.deniedNetwork)();
    const identify = dependencies.identify || identity.identify;
    const before = identify(value);
    const native = (dependencies.loadAdapter || require)(value.adapterPath);
    if (typeof native?.open !== 'function' || typeof native.watchParent !== 'function') throw Error('Invalid AR adapter');
    const watch = native.watchParent(value.parentPID);
    if (typeof watch?.close !== 'function') throw Error('Invalid AR parent watch');
    let session;
    try {
        session = native.open({ addonPath: value.addonPath, modelPath: value.modelPath,
            sampleRate: 48000, frameSize: 480, suppressionLevel: 100 });
        if (typeof session?.process !== 'function' || typeof session.close !== 'function') throw Error('Invalid AR session');
        const write = dependencies.write || (bytes => fs.writeSync(3, bytes, 0, bytes.length, null));
        const read = dependencies.read || (bytes => fs.readSync(0, bytes, 0, bytes.length, null));
        writeAll(write, Buffer.from(`OKARREADY1 ${value.token} accent-direct 48000 480 ${value.direction} us ${identity.ADDON} ${identity.MODELS[value.direction].sha256} ${value.adapterSHA256} ${identity.NODE}\n`, 'ascii'));
        return runSession({ token: Buffer.from(value.token, 'hex'), read, write, session,
            afterClose() { identity.unchanged(before, identify(value)); } });
    } finally {
        try { if (session && session.close()?.teardownComplete !== true) throw Error('AR teardown was not confirmed'); }
        finally { if (watch.close()?.stopped !== true) throw Error('AR parent watch stop was not confirmed'); }
    }
}
module.exports = { config, writeAll, runSession, runWorker };
if (require.main === module) Promise.resolve().then(() => {
    if (process.argv.length !== 3) throw Error('Expected one immutable JSON AR configuration');
    return runWorker(JSON.parse(process.argv[2]));
}).catch(error => { process.stderr.write('Accent worker failed: ' + String(error.message) + '\n'); process.exitCode = 1; });
