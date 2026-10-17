#!/usr/bin/env node
'use strict';
const { runProbe, parseArguments } = require('./run_probe.cjs');

// This wrapper runs only after runProbe's identity and network-denial gates.
// Irregular batches exercise one model's state across API calls.
function persistentAdapter(native) {
  if (!native || typeof native.open !== 'function') throw new Error('Adapter must export open(options)');
  return {
    run(options) {
      const output = new Float32Array(options.input.length);
      const partitions = [1, 17, 3, 29, 50];
      const session = native.open(options);
      if (!session || typeof session.process !== 'function' || typeof session.close !== 'function') {
        if (session && typeof session.close === 'function') session.close();
        throw new Error('Invalid persistent session interface');
      }
      let offset = 0, frames = 0, callbacks = 0, batches = 0;
      let failure;
      try {
        for (const requestedFrames of partitions) {
          if (offset === options.input.length) break;
          const count = Math.min(requestedFrames * options.frameSize, options.input.length - offset);
          const result = session.process(options.input.subarray(offset, offset + count));
          if (!result || !(result.samples instanceof Float32Array) || result.samples.length !== count ||
              result.framesProcessed !== count / options.frameSize || result.callbackCount !== count / options.frameSize ||
              result.processorConstructed !== true || result.directProcessInvoked !== true || result.backend !== 'ordinary-nc-direct') {
            throw new Error('Persistent batch contract failed');
          }
          for (const sample of result.samples) if (!Number.isFinite(sample)) throw new Error('Persistent batch is nonfinite');
          output.set(result.samples, offset);
          offset += count; frames += result.framesProcessed; callbacks += result.callbackCount; ++batches;
        }
        if (offset !== options.input.length) throw new Error('Persistent fixture partition did not cover input');
      } catch (error) { failure = error; }
      try {
        if (session.close()?.teardownComplete !== true) throw new Error('Persistent teardown was not confirmed');
      } catch (error) { failure = error; }
      if (failure) throw failure;
      return { samples: output, framesProcessed: frames, callbackCount: callbacks,
        processorConstructed: true, directProcessInvoked: true, teardownComplete: true,
        backend: 'ordinary-nc-direct', sessionBatches: batches };
    },
  };
}
module.exports = { persistentAdapter };
if (require.main === module) {
  Promise.resolve().then(() => runProbe(parseArguments(process.argv.slice(2)), {
    loadAdapter: filename => persistentAdapter(require(filename)),
  })).then(metadata => {
    process.stdout.write(JSON.stringify({ status: metadata.status, execution: metadata.execution }) + '\n');
  }).catch(error => {
    process.stderr.write(JSON.stringify({ status: 'failed', error: error.message }) + '\n');
    process.exitCode = 1;
  });
}
