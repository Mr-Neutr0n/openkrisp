'use strict';
const { Parser, encode, MAX_FRAME_BYTES, SAMPLES } = require('./worker_protocol.cjs');
// Synchronous broker-owned pipe adapter. read(scratch) returns bytes or 0 for EOF.
// write(bytes) returns bytes written. Both may throw EINTR and are retried.
// Callers own descriptors, deadlines and forced termination. No CLI or addon load.
// Each request receives one result at the same sequence. Explicit close receives
// a close acknowledgement only after teardown. Parent must close its request pipe
// immediately after sending close. Worker validates no trailing data through EOF;
// parent validates ACK plus child EOF. Broker must enforce a deadline because
// synchronous blocked IO cannot supervise itself. Clean EOF tears down without ACK.
function runSession({ token, openSession, read, write }) {
  if (![openSession, read, write].every(f => typeof f === 'function')) throw new Error('Invalid session dependencies');
  let session, closeAttempted = false, requests = 0;
  function close() {
    if (closeAttempted) return;
    closeAttempted = true;
    if (!session || typeof session.close !== 'function') throw new Error('Invalid close interface');
    if (session.close()?.teardownComplete !== true) throw new Error('Teardown was not confirmed');
  }
  function retry(operation) {
    for (;;) { try { return operation(); } catch (error) { if (error?.code !== 'EINTR') throw error; } }
  }
  function send(frame) {
    let offset = 0;
    while (offset < frame.length) {
      const count = retry(() => write(frame.subarray(offset)));
      if (!Number.isInteger(count) || count <= 0 || count > frame.length - offset) throw new Error('Invalid write progress');
      offset += count;
    }
  }
  const parser = new Parser({ token, kinds: ['request', 'close'], onFrame(frame) {
    if (frame.kind === 'close') {
      close(); send(encode({ kind: 'close', token, sequence: frame.sequence })); return;
    }
    const result = session.process(frame.samples);
    if (!result || !(result.samples instanceof Float32Array) || result.samples.length !== SAMPLES ||
        result.framesProcessed !== 1 || result.callbackCount !== 1 || result.processorConstructed !== true ||
        result.directProcessInvoked !== true || result.backend !== 'ordinary-nc-direct') throw new Error('Invalid processing result');
    // encode validates every output sample before any frame bytes are written.
    send(encode({ kind: 'result', token, sequence: frame.sequence, samples: result.samples }));
    ++requests;
  } });
  let failure, failed = false;
  try {
    session = openSession();
    if (!session || typeof session.process !== 'function' || typeof session.close !== 'function') throw new Error('Invalid session interface');
    const scratch = Buffer.alloc(MAX_FRAME_BYTES);
    for (;;) {
      const count = retry(() => read(scratch));
      if (!Number.isInteger(count) || count < 0 || count > scratch.length) throw new Error('Invalid read progress');
      if (count === 0) { parser.finish(); break; }
      parser.push(scratch.subarray(0, count));
    }
  } catch (error) { failure = error; failed = true; }
  if (session && !closeAttempted) {
    try { close(); } catch (error) { failure = failed ? new AggregateError([failure, error], 'Session failed and teardown failed') : error; failed = true; }
  }
  if (failed) throw failure;
  return { requests, teardownComplete: true };
}
module.exports = { runSession };
