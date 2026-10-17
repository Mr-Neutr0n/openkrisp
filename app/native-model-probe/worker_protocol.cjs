'use strict';
// Framing does not authenticate a worker or establish admitted session readiness.
// uint64 sequences never wrap. Open a new session before exhaustion.
// One session token per worker. Each direction has its own sequence starting at 0.
// A request contains one 480-sample frame. Its result uses the corresponding
// sequence in the other direction. Close consumes the next sequence, has no
// payload, and terminates that direction. Transport owns request/result pairing.
const MAGIC = 0x50574b4f; // bytes OKWP
const VERSION = 1, HEADER_BYTES = 36, SAMPLES = 480, PAYLOAD_BYTES = SAMPLES * 4;
const MAX_FRAME_BYTES = HEADER_BYTES + PAYLOAD_BYTES;
const KINDS = Object.freeze({ request: 1, result: 2, close: 3 });
function tokenBytes(token) {
  if (!Buffer.isBuffer(token) || token.length !== 16) throw new Error('Session token must be 16 bytes');
  return Buffer.from(token);
}
const MAX_SEQUENCE = 0xffffffffffffffffn;
function validSequence(sequence) {
  if (typeof sequence === 'number' && Number.isSafeInteger(sequence)) sequence = BigInt(sequence);
  if (typeof sequence !== 'bigint' || sequence < 0n || sequence > MAX_SEQUENCE) throw new Error('Invalid sequence');
  return sequence;
}
function encode({ kind, token, sequence, samples }) {
  token = tokenBytes(token); sequence = validSequence(sequence);
  const code = KINDS[kind];
  if (!Object.hasOwn(KINDS, kind)) throw new Error('Invalid kind');
  const close = kind === 'close';
  if (close ? samples !== undefined : !(samples instanceof Float32Array) || samples.length !== SAMPLES) throw new Error('Invalid samples');
  const frame = Buffer.alloc(HEADER_BYTES + (close ? 0 : PAYLOAD_BYTES));
  frame.writeUInt32LE(MAGIC, 0); frame[4] = VERSION; frame[5] = code;
  token.copy(frame, 8); frame.writeBigUInt64LE(sequence, 24); frame.writeUInt32LE(frame.length - HEADER_BYTES, 32);
  if (!close) for (let i = 0; i < SAMPLES; ++i) {
    if (!Number.isFinite(samples[i])) throw new Error('Nonfinite sample');
    frame.writeFloatLE(samples[i], HEADER_BYTES + i * 4);
  }
  return frame;
}
// push delivers frames synchronously through onFrame and never accumulates an
// unbounded output array. The parser retains one fixed maximum-sized buffer.
// onFrame must complete synchronously and must not call push or finish.
// Any input, parse, callback or reentry error poisons it, even if a callback
// catches the reentry error. Call finish on transport EOF.
class Parser {
  constructor({ token, kinds, onFrame, firstSequence = 0 }) {
    this.token = tokenBytes(token); firstSequence = validSequence(firstSequence);
    if (!Array.isArray(kinds) || !kinds.length || kinds.some(k => !Object.hasOwn(KINDS, k))) throw new Error('Invalid allowed kinds');
    if (typeof onFrame !== 'function') throw new Error('Missing onFrame');
    this.kinds = new Set(kinds.map(k => KINDS[k])); this.onFrame = onFrame;
    this.next = firstSequence; this.storage = Buffer.alloc(MAX_FRAME_BYTES);
    this.used = 0; this.target = HEADER_BYTES; this.failed = false; this.closed = false; this.ended = false; this.peak = 0; this.active = false;
  }
  get retainedBytes() { return this.used; }
  get capacityBytes() { return this.storage.length; }
  get peakRetainedBytes() { return this.peak; }
  push(chunk) {
    if (this.failed || this.ended) throw new Error('Parser unavailable');
    if (this.active) { this.failed = true; throw new Error('Parser reentry'); }
    this.active = true;
    try {
      if (!Buffer.isBuffer(chunk)) throw new Error('Expected Buffer');
      let offset = 0;
      while (offset < chunk.length) {
        if (this.closed) throw new Error('Data after close');
        const count = Math.min(this.target - this.used, chunk.length - offset);
        chunk.copy(this.storage, this.used, offset, offset + count);
        offset += count; this.used += count; this.peak = Math.max(this.peak, this.used);
        if (this.used !== this.target) continue;
        if (this.target === HEADER_BYTES) {
          const b = this.storage, code = b[5], size = b.readUInt32LE(32);
          if (b.readUInt32LE(0) !== MAGIC || b[4] !== VERSION || b.readUInt16LE(6) !== 0) throw new Error('Invalid header');
          if (!this.kinds.has(code) || !b.subarray(8, 24).equals(this.token)) throw new Error('Invalid kind or token');
          if (this.next > MAX_SEQUENCE || b.readBigUInt64LE(24) !== this.next) throw new Error('Out-of-order sequence');
          if (size !== (code === KINDS.close ? 0 : PAYLOAD_BYTES)) throw new Error('Invalid payload size');
          this.target += size;
          if (size) continue;
        }
        const code = this.storage[5], sequence = this.next++;
        let samples;
        if (code !== KINDS.close) {
          samples = new Float32Array(SAMPLES);
          for (let i = 0; i < SAMPLES; ++i) {
            const sample = this.storage.readFloatLE(HEADER_BYTES + i * 4);
            if (!Number.isFinite(sample)) throw new Error('Nonfinite sample');
            samples[i] = sample;
          }
        } else this.closed = true;
        this.used = 0; this.target = HEADER_BYTES;
        this.onFrame({ kind: Object.keys(KINDS).find(k => KINDS[k] === code), sequence, samples });
        if (this.failed) throw new Error('Parser unavailable after reentry');
      }
    } catch (error) { this.failed = true; throw error; }
    finally { this.active = false; }
  }
  finish() {
    if (this.failed || this.ended) throw new Error('Parser unavailable');
    if (this.active) { this.failed = true; throw new Error('Parser reentry'); }
    this.ended = true;
    if (this.used) { this.failed = true; throw new Error('Truncated EOF'); }
    // Clean EOF is framing-valid; transport decides whether close was required.
  }
}
module.exports = { encode, Parser, KINDS, HEADER_BYTES, PAYLOAD_BYTES, MAX_FRAME_BYTES, SAMPLES };
