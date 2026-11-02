import assert from 'node:assert/strict';
import { isUtf8 } from 'node:buffer';
import { readFileSync } from 'node:fs';
import PrintableBinary from '../../../js/printable_binary.js';
import { createCodec, scalarAt } from './codec.mjs';
import { fixtures, measure, textBlock, verifyReference } from './study.mjs';

const glyphs = readFileSync(new URL('../../../character_map.txt', import.meta.url), 'utf8')
	.split(/\r?\n/).map(line => line.trim()).filter(line => line && !line.startsWith('##'))
	.map(line => line.split(/\s/)[0]);
assert.equal(glyphs.length, 256);
assert.equal(new Set(glyphs).size, 256);
assert.deepEqual(scalarAt(Buffer.from('中'), 0), { length: 3, text: '中' });

const codec = createCodec(glyphs);
const original = new PrintableBinary();
const marker = '\uF000';
const variants = ['pb-fallback', 'hex-escape'];
const allBytes = Buffer.from(Array.from({ length: 256 }, (_, index) => index));
assert.equal(codec.bytewise(allBytes), original.encode(allBytes));
for (const variant of variants) {
	for (const input of [Buffer.alloc(0), allBytes, Buffer.from('中文 日本語 한국어 café'),
		Buffer.from(glyphs.join('') + marker + 'xFF'), Buffer.from([0, 27, 0xff, 0x80]),
		Buffer.from('\u0080\u0085\u202E\u00A0\u200D👩')]) {
		const result = codec.encode(input, variant);
		assert.deepEqual(codec.decode(result.payload, variant), input);
		assert.equal(result.stats.payload_bytes, Buffer.byteLength(result.payload));
		assert.equal(result.stats.input_bytes, input.length);
		assert.equal(result.stats.ascii_bytes + result.stats.preserved_bytes +
			result.stats.quoted_bytes + result.stats.unicode_mapped_bytes + result.stats.invalid_bytes, input.length);
		assert.equal(result.stats.ascii_output_bytes + result.stats.preserved_bytes +
			result.stats.quoted_bytes + result.stats.quote_overhead_bytes +
			result.stats.unicode_mapped_output_bytes + result.stats.invalid_output_bytes, result.stats.payload_bytes);
		assert(!/[\p{Cc}\p{Cf}\p{White_Space}]/u.test(result.payload));
	}
	assert.equal(codec.encode(Buffer.from('\n'), variant).payload, '¶');
	assert.equal(codec.encode(Buffer.from('¶'), variant).payload, marker + '¶');
	assert.equal(codec.encode(Buffer.from(marker), variant).payload, marker + marker);
	assert.equal(codec.encode(Buffer.from('中'), variant).payload, '中');
	for (const glyph of glyphs) {
		if (Buffer.byteLength(glyph) > 1) {
			assert.equal(codec.encode(Buffer.from(glyph), variant).payload, marker + glyph);
		}
	}
	const controls = Buffer.from(Array.from({ length: 160 }, (_, codepoint) => codepoint)
		.filter(codepoint => codepoint < 32 || codepoint >= 127).map(codepoint => String.fromCodePoint(codepoint)).join(''));
	assert.equal(codec.encode(controls, variant).payload, codec.bytewise(controls));
	assert.equal(codec.encode(Buffer.from('e\u0301'), variant).payload, 'e\u0301');
	assert.throws(() => codec.decode(codec.bytewise(Buffer.from('中')), variant), /canonical/i);
	assert.throws(() => codec.decode(marker + 'A', variant), /escape/i);
	assert.throws(() => codec.decode(marker, variant), /escape/i);
	assert.throws(() => codec.decode('\uD800', variant), /Unicode|UTF/i);
	assert.throws(() => codec.decode('\n', variant), /canonical/i);
	for (const byte of allBytes) {
		const input = Buffer.from([byte]);
		assert.deepEqual(codec.decode(codec.encode(input, variant).payload, variant), input);
	}
}
assert.equal(codec.encode(Buffer.from([0xff]), 'hex-escape').payload, marker + 'xFF');
assert.equal(codec.encode(Buffer.from([0xff]), 'pb-fallback').payload, glyphs[255]);
assert.throws(() => codec.decode(marker + 'x41', 'hex-escape'), /canonical/i);
assert.throws(() => codec.decode(marker + 'xFF', 'pb-fallback'), /escape/i);
assert.throws(() => codec.encode(allBytes, 'unknown'), /variant/i);

// Native Node UTF-8 validation is independent of the prototype's RFC boundary logic.
for (let pair = 0; pair < 65536; pair++) {
	const input = Buffer.from([pair >>> 8, pair & 255]);
	const first = scalarAt(input, 0);
	const recognized = first !== null && (first.length === 2 || scalarAt(input, 1) !== null);
	assert.equal(recognized, isUtf8(input), `two-byte classifier ${pair.toString(16)}`);
}
for (const bytes of [[0xe0, 0xa0, 0x80], [0xed, 0x9f, 0xbf], [0xf0, 0x90, 0x80, 0x80],
	[0xf4, 0x8f, 0xbf, 0xbf], [0xe0, 0x9f, 0xbf], [0xed, 0xa0, 0x80],
	[0xf0, 0x8f, 0xbf, 0xbf], [0xf4, 0x90, 0x80, 0x80], [0xf5, 0x80, 0x80, 0x80],
	[0xe4, 0xb8], [0xf0, 0x90, 0x80]]) {
	const input = Buffer.from(bytes);
	assert.equal(scalarAt(input, 0)?.length === input.length, isUtf8(input));
	for (const variant of variants) {
		assert.deepEqual(codec.decode(codec.encode(input, variant).payload, variant), input);
	}
}
console.log('PASS: experimental textual size codecs, exact mapping oracle, canonicality controls, and UTF-8 boundaries');

// Fractions count source bytes, not characters or accidental UTF-8 in random data.
const pool = Buffer.alloc(4096, 0xff);
assert.throws(() => fixtures(Buffer.alloc(4095)), /4096/);
for (const test of fixtures(pool)) {
	if (test.intentional_text_bytes !== null) {
		const percent = Number(test.name.split('-').at(-1));
		assert.equal(test.input.length, pool.length);
		assert.equal(test.intentional_text_bytes * 100, pool.length * percent);
	}
}
for (const size of [1, 2, 3, 4, 1024]) {
	const block = textBlock('中文🚀', size);
	assert.equal(block.length, size);
	assert(isUtf8(block));
}
const rows = measure(glyphs, fixtures(pool));
const randomRow = rows.find(row => row.name === 'cjk-0');
assert.equal(randomRow.variants['hex-escape'].payload_bytes, pool.length * 6);
assert.equal(randomRow.variants['pb-fallback'].payload_bytes, randomRow.bytewise_bytes);
const cjkRow = rows.find(row => row.name === 'cjk-100');
assert(cjkRow.variants['pb-fallback'].tagged_bytes < cjkRow.bytewise_bytes);
const collisionRow = rows.find(row => row.name === 'collision-100');
assert(collisionRow.variants['pb-fallback'].tagged_bytes > collisionRow.bytewise_bytes);
console.log('PASS: size-study exact fractions, UTF-8 boundaries, byte ledger and both directions of size tradeoff');

const calls = [];
const referenceCase = [{ name: 'reference-vector', input: Buffer.from('A') }];
const success = { status: 0, stdout: Buffer.from('A'), stderr: Buffer.alloc(0) };
verifyReference('prepared reference', referenceCase, codec, (program, args, options) => {
	calls.push({ program, args, input: options.input, mute: options.env.PRINTABLE_BINARY_MUTE_STATS });
	return success;
});
assert.deepEqual(calls, [{ program: 'prepared reference', args: ['--no-double-encode-check'],
	input: Buffer.from('A'), mute: '1' }]);
for (const failure of [{ ...success, status: 7 }, { ...success, stdout: Buffer.from('B') },
	{ ...success, stderr: Buffer.from('unexpected warning') }]) {
	assert.throws(() => verifyReference('prepared reference', referenceCase, codec, () => failure));
}
console.log('PASS: independent reference arguments, exact bytes, unsuccessful exit and unexpected diagnostics');

const v1 = createCodec(glyphs, { spaces: true, preserveJoiners: true });
for (const text of ['ordinary spaces', '👩\u200D🚀 می\u200Cروم', '␣ e\u0301 \uFE0F']) {
	assert.equal(v1.encode(Buffer.from(text)).payload, text);
	assert.deepEqual(v1.decode(text), Buffer.from(text));
}
assert.throws(() => v1.decode(marker + '␣'), /escape/);
console.log('PASS: production-v1 oracle preserves ordinary spaces, joiners and inactive space glyphs');
