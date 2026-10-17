'use strict';
// Independent files and injected adapters only. No vendor path or socket is used.
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');
const { runProbe, parseArguments, fixture, ADDON_SHA256 } = require('./run_probe.cjs');

async function main() {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), 'labvoice-launcher-fixture-'));
  try {
    for (const name of ['addon', 'model', 'adapter']) await fs.writeFile(path.join(root, name), 'independent-' + name);
    const options = output => parseArguments([
      '--addon', path.join(root, 'addon'), '--model', path.join(root, 'model'),
      '--adapter', path.join(root, 'adapter'), '--output', path.join(root, output)
    ]);
    const actualHash = async filename => crypto.createHash('sha256').update(await fs.readFile(filename)).digest('hex');
    // Substitute only the identity check for the synthetic addon. The CLI has no such override.
    const hash = async filename => filename === path.join(root, 'addon') ? ADDON_SHA256 : actualHash(filename);
    let loaded = 0;
    const adapter = {
      run: request => ({ samples: new Float32Array(request.input), framesProcessed: 100, callbackCount: 100,
        processorConstructed: true, directProcessInvoked: true, teardownComplete: true, backend: 'ordinary-nc-direct' })
    };
    const dependencies = { loopbackCheck: async () => 'EPERM', sha256File: hash,
      loadAdapter: () => { loaded++; return adapter; } };
    const absent = filename => assert.rejects(fs.stat(filename), { code: 'ENOENT' });

    for (const code of ['ECONNREFUSED', 'EACCES', 'TIMEOUT', 'CONNECTED']) {
      await assert.rejects(runProbe(options('denied-' + code), { ...dependencies, loopbackCheck: async () => code }), /not EPERM/);
      await absent(path.join(root, 'denied-' + code));
    }
    assert.equal(loaded, 0, 'sandbox denial must precede adapter loading');
    await assert.rejects(runProbe(options('wrong-hash'), { ...dependencies, sha256File: actualHash }), /SHA256/);
    assert.equal(loaded, 0, 'wrong addon identity must precede adapter loading');
    await absent(path.join(root, 'wrong-hash'));
    await fs.mkdir(path.join(root, 'exists'));
    await assert.rejects(runProbe(options('exists'), dependencies), /already exists/);
    assert.equal(loaded, 0);

    assert.throws(() => parseArguments(['--addon', 'relative']), /explicit|incomplete/);
    const invalid = options('invalid'); invalid.suppressionLevel = NaN;
    await assert.rejects(runProbe(invalid, dependencies), /Invalid suppression/);
    const samples = fixture();
    assert.equal(samples.length, 48000);
    assert(samples.every(Number.isFinite));
    assert.deepEqual(samples, fixture(), 'fixture must be deterministic');

    for (const [name, change] of [
      ['nan', result => { result.samples[2] = NaN; }],
      ['count', result => { result.callbackCount = 99; }],
      ['teardown', result => { result.teardownComplete = false; }],
      ['constructed', result => { result.processorConstructed = false; }]
    ]) {
      await assert.rejects(runProbe(options(name), { ...dependencies,
        loadAdapter: () => ({ run: request => { const result = adapter.run(request); change(result); return result; } }) }));
      await absent(path.join(root, name));
    }
    let modelHashes = 0;
    await assert.rejects(runProbe(options('changed'), { ...dependencies,
      sha256File: async filename => filename.endsWith('/model') && ++modelHashes > 1 ? 'f'.repeat(64) : hash(filename) }), /changed during/);
    await absent(path.join(root, 'changed'));

    const completed = await runProbe(options('success'), dependencies);
    assert.equal(completed.status, 'completed');
    assert.equal((await fs.stat(path.join(root, 'success'))).mode & 0o777, 0o700);
    for (const name of ['metadata.json', 'output.f32le']) {
      assert.equal((await fs.stat(path.join(root, 'success', name))).mode & 0o777, 0o600);
    }
    const output = await fs.readFile(path.join(root, 'success', 'output.f32le'));
    assert.equal(output.length, 48000 * 4);
    for (let i = 0; i < samples.length; ++i) assert.equal(output.readFloatLE(i * 4), samples[i]);
    const metadataPath = path.join(root, 'success', 'metadata.json');
    const retained = await fs.readFile(metadataPath), metadata = JSON.parse(retained);
    assert.equal(metadata.backend, 'ordinary-nc-direct');
    assert.equal(metadata.processorActive, undefined, 'construction must not claim SDK activation');
    assert.equal(metadata.artifacts.before.addonPath, ADDON_SHA256);
    assert.deepEqual(metadata.artifacts.before, metadata.artifacts.after);
    assert.equal(metadata.output.sha256, crypto.createHash('sha256').update(output).digest('hex'));
    await assert.rejects(runProbe(options('success'), dependencies), /already exists/);
    assert.deepEqual(await fs.readFile(metadataPath), retained, 'existing success must remain unchanged');
    console.log('launcher independent fixtures passed');
  } finally {
    await fs.rm(root, { recursive: true, force: true });
  }
}
main().catch(error => { console.error(error); process.exitCode = 1; });
