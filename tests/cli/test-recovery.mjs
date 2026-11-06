import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';

const [binary, implementation = 'codec'] = process.argv.slice(2);
assert(binary, 'prepared CLI required');
const error = (input_offset, output_offset, hex, output_length = hex.length / 2) => ({
	type: 'error', input_offset, output_offset, input_length: hex.length / 2, output_length, hex,
});
const check = (input, output, events, args = []) => {
	const result = spawnSync(binary, ['-d', '--ndjson-stderr', ...args], {
		input, maxBuffer: 8 * 1024 * 1024,
		env: { ...process.env, PRINTABLE_BINARY_MUTE_STATS: '1' },
	});
	assert.equal(result.status, Math.min(events.length, 255), `${implementation}: ${result.stderr}`);
	const emitted = args.includes('--strict') && events.length ? Buffer.alloc(0) : output;
	assert.deepEqual(result.stdout, emitted);
	const lines = result.stderr.toString('utf8').trimEnd().split('\n').map(line => JSON.parse(line));
	const summary = lines.pop();
	assert.deepEqual(lines, events);
	assert.equal(summary.type, 'summary');
	assert.equal(summary.invalid_events, events.length);
	assert.equal(summary.invalid_bytes, events.reduce((n, event) => n + event.input_length, 0));
	assert.equal(summary.input_bytes, input.length);
	assert.equal(summary.output_bytes, emitted.length);
};
check(Buffer.alloc(0), Buffer.alloc(0), []);
check(Buffer.from([255, 128]), Buffer.from([255, 128]), [error(0, 0, 'ff80')]);
check(Buffer.from([255, 128]), Buffer.from([255, 128]), [error(0, 0, 'ff80')], ['--strict']);
check(Buffer.from('¶\uffffA'), Buffer.concat([Buffer.from([10]), Buffer.from('\uffffA')]), [error(2, 1, 'efbfbf')]);
check(Buffer.from([0xe0, 0xc2, 0xb6]), Buffer.from([0xe0, 10]), [error(0, 0, 'e0')]);
check(Buffer.from([255, 32, 128]), Buffer.from([255, 128]), [error(0, 0, 'ff'), error(2, 1, '80')], ['--strip-whitespace']);
check(Buffer.from(' A␣'), Buffer.from(' A '), [], ['--spaces']);
const repeated = Buffer.from(Array.from({ length: 300 }, () => [255, 65]).flat());
check(repeated, repeated, Array.from({ length: 300 }, (_, index) => error(index * 2, index * 2, 'ff')));
const large = Buffer.alloc(65539, 255);
check(large, large, [error(0, 0, large.toString('hex'))]);
if (['Rust', 'Zig'].includes(implementation)) {
	const tag = Buffer.from('\uf000ρΤ1_');
	const input = Buffer.concat([tag, Buffer.from('中'), Buffer.from([255, 128]), Buffer.from('A')]);
	check(input, Buffer.concat([Buffer.from('中'), Buffer.from([255, 128]), Buffer.from('A')]),
		[error(tag.length + 3, 3, 'ff80')], ['--textual']);
	check(Buffer.from('中'), Buffer.from('中'), [], ['--textual', '--untagged']);
	check(Buffer.from('\uf000A'), Buffer.from('\uf000A'), [error(0, 0, 'ef8080')], ['--textual', '--untagged']);
	check(Buffer.from('\n"'), Buffer.from('\n"'), [error(0, 0, '0a22')], ['--textual', '--untagged']);
}
console.log(`PASS: ${implementation} recovery events, dual spans, exact hex, NDJSON and saturated exit status`);
