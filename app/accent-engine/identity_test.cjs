'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const identity = require('./identity.cjs');
const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'openkrisp-ar-identities-'));
try {
    const fixture = path.join(temporary, 'fixture');
    fs.writeFileSync(fixture, 'owned fixture');
    const value = identity.fileIdentity(fixture);
    assert.equal(value.size, 13);
    assert.equal(value.sha256.length, 64);
    identity.unchanged(value, identity.fileIdentity(fixture));
    fs.appendFileSync(fixture, ' changed');
    assert.throws(() => identity.unchanged(value, identity.fileIdentity(fixture)));
    fs.symlinkSync(fixture, path.join(temporary, 'symlink'));
    assert.throws(() => identity.fileIdentity(path.join(temporary, 'symlink')));
    assert.throws(() => identity.fileIdentity(temporary));
    for (const direction of ['outbound-hvc-lfb', 'nc-inbound-mwb', 'unverified'])
        assert.throws(() => identity.identify({ direction }));
    const options = { direction: 'outbound', addonPath: '/owned/addon', adapterPath: '/owned/adapter',
        modelPath: '/external/ar_inbound_wb_c_3.12.0_1.0.kef', adapterSHA256: 'a'.repeat(64) };
    assert.throws(() => identity.identify(options), /filename.*direction/);
    assert.notEqual(identity.MODELS.outbound.sha256, identity.MODELS.inbound.sha256);
    assert.throws(() => identity.digest('1'.repeat(63), 'fixture'));
    assert.throws(() => identity.absolute('relative', 'fixture'));
    console.log('AR identity direction, hash, change, path and symlink cases passed');
} finally { fs.rmSync(temporary, { recursive: true, force: true }); }
