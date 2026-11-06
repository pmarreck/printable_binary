import assert from 'node:assert/strict';
import PrintableBinary from '../../js/printable_binary.js';

const pb = new PrintableBinary();
const error = (input_offset, output_offset, bytes) => ({
  type: 'error', input_offset, output_offset, input_length: bytes.length,
  output_length: bytes.length, bytes,
});
const check = (input, expected, events, options = {}) => {
  const seen = [];
  const result = pb.decodeReport(input, options, event => {
    assert.equal(event.bytes.buffer, input.buffer, 'diagnostics borrow original wire bytes');
    seen.push({ ...event, bytes: Array.from(event.bytes) });
  });
  assert.deepEqual(Array.from(result.bytes), expected);
  assert.deepEqual(seen, events);
  assert.deepEqual(result.summary, {
    invalid_events: events.length,
    invalid_bytes: events.reduce((sum, event) => sum + event.input_length, 0),
  });
  assert.deepEqual(pb.decode(input, options), result.bytes, 'convenience decoder shares recovery semantics');
};
check(Uint8Array.of(0xe0, 0xc2, 0xb6), [0xe0, 10], [error(0, 0, [0xe0])]);
check(Uint8Array.of(255, 128, 65, 0), [255, 128, 65, 0], [error(0, 0, [255, 128]), error(3, 3, [0])]);
check(Uint8Array.of(0xc2, 32, 0xb6), [0xc2, 0xb6], [error(0, 0, [0xc2]), error(2, 1, [0xb6])], { stripWhitespace: true });
check(Uint8Array.of(255, 32, 128), [255, 32, 128], [error(7, 0, [255]), error(9, 2, [128])], { spaces: true, inputOffset: 7 });
check(new TextEncoder().encode('¶\uffffA'), [10, 0xef, 0xbf, 0xbf, 65], [error(2, 1, [0xef, 0xbf, 0xbf])]);
check(new Uint8Array(), [], []);
const sentinel = new Error('diagnostic sink failed');
assert.throws(() => pb.decodeReport(Uint8Array.of(255), {}, () => { throw sentinel; }), error => error === sentinel);
for (const text of ['\ud800', '\udc00', 'A\ud800B']) {
  assert.throws(() => pb.decode(text), /unpaired.*surrogate/i);
  assert.throws(() => pb.encodeString(text), /unpaired.*surrogate/i);
}
const map = pb.getMappings().map(entry => entry.mapping);
map[10] = '💩';
const custom = new PrintableBinary({ map });
assert.deepEqual(Array.from(custom.decode(new TextEncoder().encode('💩'))), [10]);
const all = Uint8Array.from({ length: 256 }, (_, byte) => byte);
assert.deepEqual(pb.decode(pb.encode(all)), all, 'exhaustive byte-map inverse');
for (const options of [{}, { spaces: true }, { stripWhitespace: true }, { spaces: true, stripWhitespace: true }]) {
  const input = Uint8Array.of(255, 32, 0xe0, 0xc2, 0xb6, 9, 128, 65);
  const syncEvents = [], asyncEvents = [];
  const sync = pb.decodeReport(input, options, event => syncEvents.push(event));
  const asynchronous = await pb.decodeReportAsync(input, options, async event => {
    assert.equal(event.bytes.buffer, input.buffer);
    await Promise.resolve();
    asyncEvents.push(event);
  });
  assert.deepEqual(asynchronous, sync, 'sync and async report paths share byte and summary semantics');
  assert.deepEqual(asyncEvents, syncEvents, 'sync and async paths share exact borrowed events');
}
let enterFirst;
const firstEntered = new Promise(resolve => { enterFirst = resolve; });
let releaseFirst;
const firstReleased = new Promise(resolve => { releaseFirst = resolve; });
let callbacks = 0, completedCallbacks = 0;
const sequential = pb.decodeReportAsync(Uint8Array.of(255, 65, 128), {}, async () => {
  callbacks++;
  if (callbacks === 1) { enterFirst(); await firstReleased; }
  completedCallbacks++;
});
await firstEntered;
assert.equal(callbacks, 1, 'a pending sink prevents scanning the next event');
assert.equal(completedCallbacks, 0);
releaseFirst();
const sequentialResult = await sequential;
assert.equal(callbacks, 2);
assert.equal(sequentialResult.summary.invalid_events, 2);
let failedCallbacks = 0;
await assert.rejects(pb.decodeReportAsync(Uint8Array.of(255, 65, 128), {}, async () => {
  failedCallbacks++;
  throw sentinel;
}), error => error === sentinel);
assert.equal(failedCallbacks, 1, 'an asynchronous sink rejection aborts before another callback');
console.log('PASS: JavaScript raw-byte recovery, borrowed spans, sink failures and UTF-16 validation');
