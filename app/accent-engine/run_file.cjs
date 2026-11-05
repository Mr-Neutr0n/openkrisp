#!/usr/bin/env node
'use strict';

// Explicit external inputs only. Invoke original artifacts through REA.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const identity = require('./identity.cjs');
function parse(args) {
    const names = { '--addon': 'addonPath', '--model': 'modelPath', '--adapter': 'adapterPath',
        '--adapter-sha256': 'adapterSHA256', '--node-sha256': 'nodeSHA256', '--direction': 'direction', '--input': 'inputPath',
        '--input-sha256': 'inputSHA256', '--output': 'outputPath' };
    const result = {};
    for (let i = 0; i < args.length; i += 2) {
        const key = names[args[i]];
        if (!key || !args[i + 1] || result[key] !== undefined) throw Error('Unknown, duplicate or incomplete argument');
        result[key] = args[i + 1];
    }
    for (const key of ['inputPath', 'outputPath']) identity.absolute(result[key], key);
    identity.digest(result.inputSHA256, 'inputSHA256');
    return result;
}
async function run(options) {
    if (fs.existsSync(options.outputPath)) throw Error('Choose a new output directory');
    const parent = fs.lstatSync(path.dirname(options.outputPath));
    if (!parent.isDirectory() || parent.isSymbolicLink()) throw Error('Output parent must be a plain directory');
    await identity.deniedNetwork();
    const before = identity.identify(options), inputIdentity = identity.fileIdentity(options.inputPath);
    if (inputIdentity.sha256 !== options.inputSHA256) throw Error('Input SHA256 differs');
    const bytes = fs.readFileSync(options.inputPath);
    if (!bytes.length || bytes.length > 480000 * 4 || bytes.length % (480 * 4))
        throw Error('Input must contain 1 through 1000 whole mono Float32 frames at 48000 Hz');
    const input = new Float32Array(bytes.length / 4);
    for (let i = 0; i < input.length; ++i) {
        input[i] = bytes.readFloatLE(i * 4);
        if (!Number.isFinite(input[i]) || Math.abs(input[i]) > 1) throw Error('Input must be finite normalized audio');
    }
    const adapter = require(options.adapterPath);
    let session, teardownComplete = false, failure;
    const outputs = [], milliseconds = [], callbackFrames = [];
    let constructionMilliseconds = 0;
    const start = performance.now();
    try {
        session = adapter.open({ addonPath: options.addonPath, modelPath: options.modelPath,
            sampleRate: 48000, frameSize: 480, suppressionLevel: 100 });
        constructionMilliseconds = performance.now() - start;
        for (let offset = 0; offset < input.length; offset += 480) {
            const began = performance.now(), result = session.process(input.subarray(offset, offset + 480));
            milliseconds.push(performance.now() - began);
            if (!(result.samples instanceof Float32Array) || result.framesProcessed !== 1 ||
                ![0, 1].includes(result.callbackCount) || result.samples.length !== result.callbackCount * 480 ||
                result.backend !== 'accent-direct') throw Error('Unexpected AR output contract');
            for (const sample of result.samples) if (!Number.isFinite(sample)) throw Error('Nonfinite AR output');
            if (result.callbackCount) callbackFrames.push(offset / 480);
            const encoded = Buffer.alloc(result.samples.length * 4);
            for (let i = 0; i < result.samples.length; ++i) encoded.writeFloatLE(result.samples[i], i * 4);
            outputs.push(encoded);
        }
    } catch (error) { failure = error; }
    finally {
        if (session) {
            try { teardownComplete = session.close().teardownComplete === true; }
            catch (error) { failure = error; }
        }
    }
    const after = identity.identify(options);
    identity.unchanged(before, after);
    identity.unchanged(inputIdentity, identity.fileIdentity(options.inputPath));
    if (failure) throw failure;
    if (!teardownComplete) throw Error('AR teardown incomplete');
    const output = Buffer.concat(outputs);
    const metadata = { schemaVersion: 1, backend: 'installed-ar-direct', direction: options.direction,
        status: 'completed', sampleRate: 48000, frameSize: 480, inputSamples: input.length,
        outputSamples: output.length / 4, callbackCount: callbackFrames.length,
        callbackInputFrames: callbackFrames, constructionMilliseconds,
        processMilliseconds: milliseconds, totalMilliseconds: performance.now() - start,
        teardownComplete, sandboxLoopback: 'EPERM', artifacts: { before, after }, input: inputIdentity,
        outputSHA256: crypto.createHash('sha256').update(output).digest('hex'),
        limits: ['Raw model output is not padded or delay-trimmed.', 'No EOF drain or perceptual accent quality is established.'] };
    fs.mkdirSync(options.outputPath, { mode: 0o700 });
    fs.writeFileSync(path.join(options.outputPath, 'output.f32le'), output, { flag: 'wx', mode: 0o600 });
    fs.writeFileSync(path.join(options.outputPath, 'metadata.json'), JSON.stringify(metadata, null, 2) + '\n', { flag: 'wx', mode: 0o600 });
    return { status: metadata.status, inputSamples: input.length, outputSamples: output.length / 4,
        callbackCount: callbackFrames.length, firstCallbackInputFrame: callbackFrames[0] ?? null,
        constructionMilliseconds, totalMilliseconds: metadata.totalMilliseconds, teardownComplete };
}
module.exports = { parse, run };
if (require.main === module) run(parse(process.argv.slice(2))).then(result => console.log(JSON.stringify(result)))
    .catch(error => { console.error(JSON.stringify({ status: 'failed', error: error.message })); process.exitCode = 1; });
