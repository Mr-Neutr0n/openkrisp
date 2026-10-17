'use strict';
const assert = require('node:assert/strict');
const native = require('./build/native-probe.node');
for (const pid of [undefined, 0, 1, -1, 1.5, NaN, Infinity, 2147483648, process.pid]) {
  assert.throws(() => native.watchParent(pid));
}
assert.throws(() => native.watchParent());
assert.throws(() => native.watchParent(process.ppid, 1));
const watch = native.watchParent(process.ppid);
assert.throws(() => watch.close.call({}));
assert.throws(() => watch.close(1));
assert.deepEqual(watch.close(), { stopped: true });
assert.deepEqual(watch.close(), { stopped: true });
console.log('native parent watch boundary tests passed');
