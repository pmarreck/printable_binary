import assert from 'node:assert/strict';
import fs from 'node:fs';
import { spawn, spawnSync } from 'node:child_process';

const [binary, implementation = 'codec'] = process.argv.slice(2);
assert(binary, 'prepared Node/Lua CLI required');
const run = (input, args = [], options = {}) => {
  const result = spawnSync(binary, args, {
    input, maxBuffer: 2 * 1024 * 1024,
    env: { ...process.env, PRINTABLE_BINARY_MUTE_STATS: '1', DEBUG: '1' },
    ...options,
  });
  assert.equal(result.error, undefined, `${implementation}: spawn must complete`);
  const lines = result.stderr.toString('utf8').trimEnd().split('\n').map(line => JSON.parse(line));
  const summary = lines.pop();
  assert.equal(summary.type, 'summary');
  return { ...result, lines, summary };
};
const clean = (input, expected, args = []) => {
  const result = run(input, ['--ndjson-stderr', ...args]);
  assert.equal(result.status, 0);
  assert.deepEqual(result.stdout, expected);
  assert.deepEqual(result.lines, []);
  assert.equal(result.summary.complete, true);
  assert.equal(result.summary.invalid_events, 0);
  assert.equal(result.summary.invalid_bytes, 0);
  assert.equal(result.summary.input_bytes, input.length);
  assert.equal(result.summary.output_bytes, expected.length);
  return result.summary;
};
assert.equal(clean(Buffer.from('A'), Buffer.from('A'), ['-d', '--passthrough']).warnings.length, 1);
assert.equal(clean(Buffer.from('\n  A'), Buffer.from('  A'), ['-d', '--spaces', '--strip-whitespace']).warnings.length, 1);
clean(Buffer.from([0, 10]), Buffer.from('·¶'), ['--no-double-encode-check']);
for (const selection of [['--start', '4'], ['--start', '-3'], ['--range', '4-6']]) {
  const result = run(Buffer.from([65, 65, 65, 65, 255, 128, 66]), ['-d', '--ndjson-stderr', ...selection]);
  assert.equal(result.status, 1);
  assert.deepEqual(result.stdout, Buffer.from([255, 128, 66]));
  assert.deepEqual(result.lines, [{ type: 'error', input_offset: 4, output_offset: 0,
    input_length: 2, output_length: 2, hex: 'ff80' }]);
  assert.equal(result.summary.complete, true);
  assert.equal(result.summary.input_bytes, 7);
  assert.equal(result.summary.output_bytes, 3);
}
const fatal = (args, options = {}) => {
  const result = run(Buffer.from('A'), [...args, '--ndjson-stderr'], options);
  assert.equal(result.status, 1, `fatal arguments: ${JSON.stringify(args)}`);
  assert.equal(result.summary.complete, false);
  for (const field of ['invalid_events', 'invalid_bytes', 'input_bytes', 'output_bytes']) {
    assert.equal(result.summary[field], null, `fatal ${field} cannot claim completed totals`);
  }
  assert(result.lines.some(line => line.type === 'error' && line.fatal === true));
  return result;
};
for (const args of [
  ['--unknown-option'], ['--strict'], ['--help'], ['--about'], ['--mappings-json'],
  ['-d', '--hexlike'], ['-d', '--container'], ['--passthrough'],
  ['-d', '--start', 'nope'], ['-d', '--end', '2junk'], ['-d', '--range', '1-nope'],
  ['-d', '--start', '1.5'], ['-f=0x1'], ['-f=1x0'],
  ['-d', new URL('./missing-recovery-input', import.meta.url).pathname],
]) {
  const result = fatal(args);
  assert.equal(result.stdout.length, 0, 'fatal options/read errors do not emit payload');
}
if (process.platform === 'linux') {
  const output = fs.openSync('/dev/full', 'w');
  try { fatal(['-d'], { stdio: ['pipe', output, 'pipe'] }); }
  finally { fs.closeSync(output); }
}
if (implementation === 'Node') {
  // Readable stays paused until the first diagnostic arrives and a bounded
  // delay has elapsed. Several MiB of stderr exceeds the pipe plus readable
  // buffers, so this exercises real backpressure without timing repetitions.
  const count = 32768;
  const input = Buffer.alloc(count * 2);
  for (let index = 0; index < count; index++) { input[index * 2] = 255; input[index * 2 + 1] = 65; }
  await new Promise((resolve, reject) => {
    const child = spawn(binary, ['-d', '--ndjson-stderr'], {
      stdio: ['pipe', 'pipe', 'pipe'],
      env: { ...process.env, PRINTABLE_BINARY_MUTE_STATS: '1' },
    });
    let drainTimer, draining = false, earlyExit = false, pending = '', events = 0, summary;
    const payload = [];
    const fail = error => { child.kill(); reject(error); };
    const watchdog = setTimeout(() => fail(new Error('paused diagnostic pipe watchdog expired')), 30000);
    child.once('error', fail);
    child.once('exit', () => { if (!draining) earlyExit = true; });
    child.stdout.on('data', chunk => payload.push(chunk));
    child.stderr.once('readable', () => {
      drainTimer = setTimeout(() => {
        draining = true;
        child.stderr.on('data', chunk => {
          pending += chunk.toString('utf8');
          let end;
          while ((end = pending.indexOf('\n')) >= 0) {
            const line = pending.slice(0, end);
            pending = pending.slice(end + 1);
            try {
              const record = JSON.parse(line);
              if (record.type === 'summary') summary = record;
              else {
                assert.deepEqual(record, { type: 'error', input_offset: events * 2, output_offset: events * 2,
                  input_length: 1, output_length: 1, hex: 'ff' });
                events++;
              }
            } catch (error) { fail(error); }
          }
        });
        child.stderr.resume();
      }, 100);
    });
    child.once('close', (status, signal) => {
      clearTimeout(watchdog);
      clearTimeout(drainTimer);
      try {
        assert.equal(earlyExit, false, 'producer must wait for the paused diagnostic reader');
        assert.equal(signal, null);
        assert.equal(status, 255, 'backpressure cannot become an input or fatal transport error');
        assert.equal(pending, '', 'every diagnostic line must finish');
        assert.equal(events, count, 'all error events must survive the paused pipe');
        assert.equal(summary?.complete, true);
        assert.equal(summary.invalid_events, count);
        assert.equal(summary.invalid_bytes, count);
        assert.equal(summary.input_bytes, input.length);
        assert.equal(summary.output_bytes, input.length);
        assert.deepEqual(Buffer.concat(payload), input);
        resolve();
      } catch (error) { reject(error); }
    });
    child.stdin.end(input);
  });
}
console.log(`PASS: ${implementation} recovery adapter ranges, warnings, encoding, fatal options and inherited I/O`);
