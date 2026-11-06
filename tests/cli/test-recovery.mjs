import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { readFileSync, openSync, closeSync } from 'node:fs';

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
	assert.equal(lines.length, events.length, 'one line per contiguous error event');
	for (let i = 0; i < events.length; i++) {
		const { hex: actualHex, ...actual } = lines[i];
		const { hex: expectedHex, ...expected } = events[i];
		assert.deepEqual(actual, expected);
		assert.equal(actualHex.length, expectedHex.length, 'full hex, including events larger than the formatting buffer');
		assert(actualHex === expectedHex, 'exact offending wire bytes');
	}
	assert.equal(summary.type, 'summary');
	assert.equal(summary.complete, true, 'successful recovery reports complete totals');
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
for (const size of [255, 256, 257, 65539]) {
	const large = Buffer.alloc(size, 255);
	check(large, large, [error(0, 0, large.toString('hex'))]);
}
if (['Rust', 'Zig'].includes(implementation)) {
	const tag = Buffer.from('\uf000ρΤ1_');
	const input = Buffer.concat([tag, Buffer.from('中'), Buffer.from([255, 128]), Buffer.from('A')]);
	check(input, Buffer.concat([Buffer.from('中'), Buffer.from([255, 128]), Buffer.from('A')]),
		[error(tag.length + 3, 3, 'ff80')], ['--textual']);
	check(Buffer.from('中'), Buffer.from('中'), [], ['--textual', '--untagged']);
	check(Buffer.from('\uf000A'), Buffer.from('\uf000A'), [error(0, 0, 'ef8080')], ['--textual', '--untagged']);
	check(Buffer.from('\n"'), Buffer.from('\n"'), [error(0, 0, '0a22')], ['--textual', '--untagged']);
}
if (['Zig', 'FFI', 'C', 'Ape', 'WASM', 'Node', 'LuaJIT', 'Roc'].includes(implementation)) {
	check(Buffer.from([65, 65, 65, 65, 255, 128, 66]), Buffer.from([255, 128, 66]), [error(4, 0, 'ff80')], ['--start', '4']);
}

// Independent word-matching oracle, not the production UTF-8/table algorithm.
// Fixed xorshift32 seed makes failures reproducible without external entropy.
const words = readFileSync(new URL('../../character_map.txt', import.meta.url), 'utf8')
	.split('\n').filter(line => line.trim() && !line.startsWith('##'))
	.map(line => Buffer.from(line.trim().split(/\s+/)[0]));
assert.equal(words.length, 256);
const reference = (wire, spaces, strip) => {
	const output = [], events = [];
	let source = 0, start = null;
	const close = () => {
		if (start) events.push(error(start.input, start.output, wire.subarray(start.input, source).toString('hex'), output.length - start.output));
		start = null;
	};
	while (source < wire.length) {
		const byte = wire[source];
		const ignored = strip && [32, 9, 13, 10].includes(byte) && !(spaces && byte === 32);
		const mapped = spaces && byte === 32 ? 32 : words.findIndex(word => wire.subarray(source, source + word.length).equals(word));
		if (ignored || mapped >= 0) {
			close();
			if (ignored) source++;
			else { output.push(mapped); source += spaces && byte === 32 ? 1 : words[mapped].length; }
		} else {
			start ??= { input: source, output: output.length };
			output.push(byte); source++;
		}
	}
	close();
	return { output: Buffer.from(output), events };
};
let state = 0x7062_7431;
const next = () => { state ^= state << 13; state ^= state >>> 17; state ^= state << 5; return state >>> 0; };
const pieces = [];
for (let i = 0; i < 768; i++) {
	const value = next();
	pieces.push(value & 1 ? words[value >>> 8 & 255] : Buffer.from([value & 255, value >>> 16 & 255]));
}
pieces.push(Buffer.from('中👩\u200d🚀\uf000'), Buffer.from([0xf4, 0x90, 0x80, 0x80, 0xe0, 0xc2, 0xb6, 0, 32, 255]));
const wire = Buffer.concat(pieces);
for (const spaces of [false, true]) for (const strip of [false, true]) {
	const expected = reference(wire, spaces, strip);
	check(wire, expected.output, expected.events, [...(spaces ? ['--spaces'] : []), ...(strip ? ['--strip-whitespace'] : [])]);
}

const fatal = args => {
	const result = spawnSync(binary, ['--ndjson-stderr', ...args], {
		input: Buffer.from('A'), maxBuffer: 1024 * 1024,
		env: { ...process.env, PRINTABLE_BINARY_MUTE_STATS: '1' },
	});
	assert.equal(result.status, 1, `${implementation}: fatal command ${JSON.stringify(args)} must fail: ${result.stderr}`);
	assert.equal(result.stdout.length, 0);
	const records = result.stderr.toString('utf8').trimEnd().split('\n').map(line => JSON.parse(line));
	const summary = records.pop();
	assert.equal(summary.type, 'summary');
	assert.equal(summary.complete, false);
	for (const field of ['invalid_events', 'invalid_bytes', 'input_bytes', 'output_bytes']) assert.equal(summary[field], null);
	assert(records.length > 0);
	for (const record of records) { assert.equal(record.type, 'error'); assert.equal(record.fatal, true); }
};
fatal(['--recovery-test-invalid-option']);
fatal(['-d', '.']);
fatal(['-d', '--hexlike']);
fatal(['--container']);
fatal(['--passthrough']);
fatal(['--strict']);
const human = spawnSync(binary, ['-d'], { input: Buffer.from([255, 128]),
	env: { ...process.env, PRINTABLE_BINARY_MUTE_STATS: '1' } });
assert.equal(human.status, 1);
assert.deepEqual(human.stdout, Buffer.from([255, 128]));
assert.match(human.stderr.toString('utf8'), /input_offset=0 output_offset=0 input_length=2 output_length=2.*hex=ff80/);
assert.match(human.stderr.toString('utf8'), /Invalid input: 1 events, 2 bytes/);
if (process.platform === 'linux') {
	const full = openSync('/dev/full', 'w');
	try {
		for (const stdio of [['pipe', full, 'pipe'], ['pipe', 'pipe', full]]) {
			const result = spawnSync(binary, ['-d', '--ndjson-stderr'], {
				input: Buffer.from('A'), stdio, env: { ...process.env, PRINTABLE_BINARY_MUTE_STATS: '1' },
			});
			assert.equal(result.status, 1, `${implementation}: failed output or diagnostic sink must be fatal`);
		}
	} finally { closeSync(full); }
}
console.log(`PASS: ${implementation} recovery events, dual spans, exact hex, NDJSON and saturated exit status`);
