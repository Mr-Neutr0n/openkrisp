#!/usr/bin/env node
'use strict';

// Experimental launcher. No vendor module is loaded merely by importing this file.
const fs = require('node:fs');
const fsp = fs.promises;
const path = require('node:path');
const crypto = require('node:crypto');
const net = require('node:net');
const ADDON_SHA256 = 'adde50ff549700fd535fb9cc8e42d45fa36dca02131009ded727a10625ae8755';
const RATE = 48000, FRAME_SIZE = 480, BLOCKS = 100;

function fail(message) { throw new Error(message); }
function parseArguments(args) {
  const names = new Map([['--addon', 'addonPath'], ['--model', 'modelPath'], ['--adapter', 'adapterPath'], ['--output', 'outputPath']]);
  const result = { suppressionLevel: 100, bypass: false };
  const seen = new Set();
  for (let i = 0; i < args.length; ++i) {
    const key = args[i];
    if (seen.has(key)) fail('Duplicate argument: ' + key);
    seen.add(key);
    if (key === '--bypass') { result.bypass = true; continue; }
    if (key === '--suppression-level') {
      const value = args[++i];
      if (value === undefined || value.trim() === '') fail('Missing suppression level');
      result.suppressionLevel = Number(value); continue;
    }
    const name = names.get(key);
    if (!name || !args[i + 1] || args[i + 1].startsWith('--')) fail('Unknown or incomplete argument: ' + key);
    result[name] = args[++i];
  }
  validateOptions(result);
  return result;
}
function validateOptions(options) {
  for (const key of ['addonPath', 'modelPath', 'adapterPath', 'outputPath']) {
    if (typeof options[key] !== 'string' || !path.isAbsolute(options[key]) || options[key].includes('\0')) fail(key + ' must be an explicit absolute path');
  }
  if (typeof options.bypass !== 'boolean' || !Number.isFinite(options.suppressionLevel) || options.suppressionLevel < 0 || options.suppressionLevel > 100) fail('Invalid suppression or bypass setting');
}
async function plainFile(filename) {
  const value = await fsp.lstat(filename);
  if (!value.isFile() || value.isSymbolicLink()) fail('Expected a plain regular file: ' + filename);
}
async function absentOutput(filename) {
  try { await fsp.lstat(filename); fail('Output already exists; choose a new path'); }
  catch (error) { if (error.code !== 'ENOENT') throw error; }
  const parent = await fsp.lstat(path.dirname(filename));
  if (!parent.isDirectory() || parent.isSymbolicLink()) fail('Output parent must be an existing plain directory');
}
async function sha256File(filename) {
  const hash = crypto.createHash('sha256');
  for await (const chunk of fs.createReadStream(filename)) hash.update(chunk);
  return hash.digest('hex');
}
// A refusal, timeout or successful connect does not demonstrate sandbox isolation.
function loopbackCheck() {
  return new Promise(resolve => {
    const socket = new net.Socket();
    let finished = false;
    const done = code => { if (!finished) { finished = true; socket.destroy(); resolve(code); } };
    socket.once('error', error => done(error.code));
    socket.once('connect', () => done('CONNECTED'));
    socket.setTimeout(1000, () => done('TIMEOUT'));
    try { socket.connect({ host: '127.0.0.1', port: 9 }); }
    catch (error) { done(error.code); }
  });
}
function fixture() {
  let state = 0x4c564e43;
  const samples = new Float32Array(FRAME_SIZE * BLOCKS);
  for (let i = 0; i < samples.length; ++i) {
    state ^= state << 13; state ^= state >>> 17; state ^= state << 5;
    const noise = ((state >>> 0) / 4294967296 - 0.5) * 0.08;
    // Integer-period lookup-free tones, plus seeded noise. No recording or microphone.
    const triangle = period => 1 - 4 * Math.abs((i % period) / period - 0.5);
    samples[i] = triangle(160) * 0.15 + triangle(60) * 0.05 + noise;
  }
  return samples;
}
function encoded(samples) {
  const bytes = Buffer.alloc(samples.length * 4);
  for (let i = 0; i < samples.length; ++i) bytes.writeFloatLE(samples[i], i * 4);
  return bytes;
}
function validateResult(result, expectedSamples) {
  if (!result || !(result.samples instanceof Float32Array) || result.samples.length !== expectedSamples ||
      result.framesProcessed !== BLOCKS || result.callbackCount !== BLOCKS || result.processorConstructed !== true ||
      result.directProcessInvoked !== true || result.teardownComplete !== true || result.backend !== 'ordinary-nc-direct') fail('Adapter did not confirm the complete ordinary-NC processing and teardown contract');
  for (const sample of result.samples) if (!Number.isFinite(sample)) fail('Adapter output contains a nonfinite sample');
}
function sameIdentity(a, b) { return a.dev === b.dev && a.ino === b.ino; }
async function publish(outputPath, metadata, output) {
  await fsp.mkdir(outputPath, { mode: 0o700 }); // Exclusive: an existing directory is an error too.
  const identity = await fsp.lstat(outputPath);
  const owned = [];
  try {
    await fsp.chmod(outputPath, 0o700);
    for (const [name, bytes] of [['output.f32le', output], ['metadata.json', Buffer.from(JSON.stringify(metadata, null, 2) + '\n')]]) {
      const filename = path.join(outputPath, name);
      const file = await fsp.open(filename, fs.constants.O_WRONLY | fs.constants.O_CREAT | fs.constants.O_EXCL | fs.constants.O_NOFOLLOW, 0o600);
      try {
        owned.push({ filename, identity: await file.stat() });
        await file.chmod(0o600); await file.writeFile(bytes); await file.sync();
      } finally { await file.close(); }
    }
    const current = await fsp.lstat(outputPath);
    if (!current.isDirectory() || !sameIdentity(identity, current)) fail('Output directory changed before completion');
  } catch (error) {
    let incomplete = false;
    for (const item of owned.reverse()) {
      try {
        const current = await fsp.lstat(item.filename);
        if (!sameIdentity(item.identity, current)) { incomplete = true; continue; }
        await fsp.unlink(item.filename);
      } catch (cleanupError) { if (cleanupError.code !== 'ENOENT') incomplete = true; }
    }
    try {
      const current = await fsp.lstat(outputPath);
      if (!current.isDirectory() || !sameIdentity(identity, current)) incomplete = true;
      else await fsp.rmdir(outputPath);
    } catch (_) { incomplete = true; }
    if (incomplete) fail('Probe output did not complete; inspect partial output at ' + outputPath);
    throw error;
  }
}
// Dependency injection exists for independent fixtures. CLI always uses these defaults;
// there is no command-line or environment override for the digest or sandbox gate.
async function runProbe(options, dependencies = {}) {
  validateOptions(options);
  await absentOutput(options.outputPath);
  const check = dependencies.loopbackCheck || loopbackCheck;
  if (await check() !== 'EPERM') fail('Required sandbox loopback denial was not EPERM; no adapter was loaded');
  for (const key of ['addonPath', 'modelPath', 'adapterPath']) await plainFile(options[key]);
  const hash = dependencies.sha256File || sha256File;
  const before = {};
  for (const key of ['addonPath', 'modelPath', 'adapterPath']) before[key] = await hash(options[key]);
  if (before.addonPath !== ADDON_SHA256) fail('Installed addon SHA256 does not match the reviewed artifact');
  const input = fixture(), inputBytes = encoded(input);
  const load = dependencies.loadAdapter || (filename => require(filename));
  let result, output, processingError;
  try {
    const adapter = await load(options.adapterPath);
    if (!adapter || typeof adapter.run !== 'function') fail('Adapter must export run(options)');
    result = await adapter.run({ addonPath: options.addonPath, modelPath: options.modelPath, input,
      sampleRate: RATE, frameSize: FRAME_SIZE, suppressionLevel: options.suppressionLevel, bypass: options.bypass });
    validateResult(result, FRAME_SIZE * BLOCKS);
    output = encoded(result.samples);
  } catch (error) { processingError = error; }
  const after = {};
  for (const key of ['addonPath', 'modelPath', 'adapterPath']) after[key] = await hash(options[key]);
  for (const key of Object.keys(before)) if (before[key] !== after[key]) fail('Probe artifact changed during processing: ' + key);
  if (processingError) throw processingError;
  const metadata = { schemaVersion: 1, status: 'completed', backend: result.backend,
    sampleRate: RATE, frameSize: FRAME_SIZE, framesProcessed: result.framesProcessed, callbackCount: result.callbackCount,
    samples: FRAME_SIZE * BLOCKS, processorConstructed: true, directProcessInvoked: true, teardownComplete: true,
    suppressionLevel: options.suppressionLevel, bypass: options.bypass,
    fixture: { kind: 'seeded-noise-and-triangle-tones', seed: '0x4c564e43', sha256: crypto.createHash('sha256').update(inputBytes).digest('hex') },
    artifactPaths: { addon: options.addonPath, model: options.modelPath, adapter: options.adapterPath },
    artifacts: { before, after }, sandboxLoopback: 'EPERM',
    output: { filename: 'output.f32le', encoding: 'Float32 little-endian mono', sha256: crypto.createHash('sha256').update(output).digest('hex') },
    limits: ['A loopback denial is a prerequisite check, not a complete network-isolation proof.', 'No perceptual parity or tail preservation is established by this probe.'] };
  await publish(options.outputPath, metadata, output);
  return metadata;
}
module.exports = { runProbe, parseArguments, fixture, ADDON_SHA256 };
if (require.main === module) {
  Promise.resolve().then(() => runProbe(parseArguments(process.argv.slice(2)))).then(metadata => {
    process.stdout.write(JSON.stringify({ status: metadata.status, outputPath: process.argv[process.argv.indexOf('--output') + 1] }) + '\n');
  }).catch(error => { process.stderr.write(JSON.stringify({ status: 'failed', error: error.message }) + '\n'); process.exitCode = 1; });
}
