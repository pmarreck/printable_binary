import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { createCodec } from '../benchmark/textual_size/codec.mjs';

const binary = process.argv[2];
const implementation = process.argv[3] ?? 'Rust';
assert(binary, 'prepared textual example is required');
const glyphs = readFileSync(new URL('../../character_map.txt', import.meta.url), 'utf8')
	.split(/\r?\n/).map(line => line.trim()).filter(line => line && !line.startsWith('##'))
	.map(line => line.split(/\s/)[0]);
const oracle = createCodec(glyphs, { spaces: true, preserveJoiners: true });
const tag = Buffer.from('\uF000ρΤ1_');
const invoke = (mode, input) => spawnSync(binary, [mode], { input, maxBuffer: input.length * 4 + 4096 });
const checked = (mode, input) => {
	const result = invoke(mode, input);
	assert.equal(result.status, 0, result.stderr?.toString('utf8'));
	assert.equal(result.stderr.length, 0);
	return result.stdout;
};
const scalars = [];
for (let cp = 0; cp <= 0x10ffff; cp++) {
	if (cp < 0xd800 || cp > 0xdfff) scalars.push(String.fromCodePoint(cp));
}
const cases = [Buffer.alloc(0), Buffer.from(Array.from({ length: 256 }, (_, byte) => byte)),
	Buffer.from('中文 日本語 한국어 café 👩\u200D🚀 می\u200Cروم e\u0301'),
	Buffer.from(glyphs.join('') + '\uF000ρΤ1_\uF000/ρΒ'),
	Buffer.from([0xc0, 0x80, 0xed, 0xa0, 0x80, 0xf4, 0x90, 0x80, 0x80, 0xe4, 0xb8]),
	Buffer.from(scalars.join(''))];
for (const input of cases) {
	const expected = Buffer.from(oracle.encode(input).payload);
	assert.deepEqual(checked('encode-payload', input), expected);
	assert.deepEqual(checked('decode-payload', expected), input);
	const tagged = Buffer.concat([tag, expected]);
	assert.deepEqual(checked('encode', input), tagged);
	assert.deepEqual(checked('decode', tagged), input);
}
for (const [wire, error] of [
	[Buffer.from('\uF000A'), 'InvalidEscape'], [Buffer.from('\uF000␣'), 'InvalidEscape'],
	[Buffer.from(glyphs[0xe4] + glyphs[0xb8] + glyphs[0xad]), 'NonCanonical'],
	[Buffer.from([0xff]), 'InvalidUtf8'], [Buffer.from('\n'), 'NonCanonical']]) {
	const result = invoke('decode-payload', wire);
	assert.notEqual(result.status, 0);
	assert.equal(result.stdout.length, 0);
	assert.match(result.stderr.toString('utf8'), new RegExp(error));
}
console.log(`PASS: ${implementation} textual codec matches the independent Unicode oracle over every Unicode scalar, arbitrary bytes and canonicality controls`);
