'use strict';

const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const net = require('node:net');
const ADDON = 'adde50ff549700fd535fb9cc8e42d45fa36dca02131009ded727a10625ae8755';
const NODE = '1ef99ea25fe70c9b67e7efe768ef8ee22148d3cabc703db6131b57aeb617d040';
const MODELS = Object.freeze({
    outbound: Object.freeze({ filename: 'ar_outbound_wb_c_ma_3.11.0_1.0.kef',
        sha256: '8ada1e4c3d2b3ef3c1440e39dfdfb825c7b0a4c0695c9e0ba6b06b576f124855' }),
    inbound: Object.freeze({ filename: 'ar_inbound_wb_c_3.12.0_1.0.kef',
        sha256: '73a59147ba88d0075e6a688f3cc641c5a46a6ffbb591c2f386b3affdb3e781df' })
});
function absolute(value, name) {
    if (typeof value !== 'string' || !path.isAbsolute(value) || value.includes('\0'))
        throw Error(name + ' must be an explicit absolute path');
    return value;
}
function digest(value, name) {
    if (typeof value !== 'string' || !/^[0-9a-f]{64}$/.test(value)) throw Error(name + ' must be a SHA256');
    return value;
}
function fileIdentity(filename) {
    absolute(filename, 'filename');
    const descriptor = fs.openSync(filename, fs.constants.O_RDONLY | fs.constants.O_NOFOLLOW);
    try {
        const before = fs.fstatSync(descriptor);
        if (!before.isFile() || before.size > 200_000_000) throw Error('Expected a bounded regular file');
        const hash = crypto.createHash('sha256');
        const buffer = Buffer.allocUnsafe(65536);
        for (;;) {
            const count = fs.readSync(descriptor, buffer, 0, buffer.length, null);
            if (!count) break;
            hash.update(buffer.subarray(0, count));
        }
        const after = fs.fstatSync(descriptor);
        for (const key of ['dev', 'ino', 'size', 'mtimeMs', 'ctimeMs'])
            if (before[key] !== after[key]) throw Error('File changed while hashing');
        return { sha256: hash.digest('hex'), size: after.size, dev: after.dev, ino: after.ino };
    } finally { fs.closeSync(descriptor); }
}
function identify(options) {
    const model = MODELS[options.direction];
    if (!model) throw Error('direction must be outbound or inbound');
    for (const key of ['addonPath', 'modelPath', 'adapterPath']) absolute(options[key], key);
    digest(options.adapterSHA256, 'adapterSHA256');
    if (path.basename(options.modelPath) !== model.filename) throw Error('AR filename does not match direction');
    const result = { node: fileIdentity(fs.realpathSync(process.execPath)),
        addon: fileIdentity(options.addonPath), model: fileIdentity(options.modelPath),
        adapter: fileIdentity(options.adapterPath) };
    for (const [key, expected] of [['node', NODE], ['addon', ADDON], ['model', model.sha256], ['adapter', options.adapterSHA256]])
        if (result[key].sha256 !== expected) throw Error('Unreviewed AR ' + key + ' SHA256');
    return result;
}
function unchanged(before, after) {
    if (JSON.stringify(before) !== JSON.stringify(after)) throw Error('AR artifacts changed during processing');
}
function deniedNetwork() {
    return new Promise((resolve, reject) => {
        const socket = new net.Socket();
        const done = code => { socket.destroy(); code === 'EPERM' ? resolve() : reject(Error('Required sandbox denial was not EPERM: ' + code)); };
        socket.once('error', error => done(error.code));
        socket.once('connect', () => done('CONNECTED'));
        socket.setTimeout(1000, () => done('TIMEOUT'));
        socket.connect({ host: '127.0.0.1', port: 9 });
    });
}
module.exports = { ADDON, NODE, MODELS, absolute, digest, fileIdentity, identify, unchanged, deniedNetwork };
