import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';

const binary = process.argv[2];
assert(binary, 'prepared Zig CLI is required');
const tag = '\uF000ρΤ1_';
const input = Buffer.from('中文 日本語 한국어 👩\u200D🚀\n\\"');
const payload = Buffer.from('中文 日本語 한국어 👩\u200D🚀¶⧷ˮ');
const tagged = Buffer.concat([Buffer.from(tag), payload]);
const invoke = (args, data) => spawnSync(binary, args, {
	input: data, maxBuffer: 1024 * 1024,
	env: { ...process.env, PRINTABLE_BINARY_MUTE_STATS: '0' },
});
const ok = (args, data, expected) => {
	const result = invoke(args, data);
	assert.equal(result.status, 0, result.stderr?.toString('utf8'));
	assert.deepEqual(result.stdout, expected);
	assert.match(result.stderr.toString('utf8'), /Input throughput: [0-9]+\.[0-9]{2} MB read/);
};
const rejected = (args, data, diagnostic) => {
	const result = invoke(args, data);
	assert.notEqual(result.status, 0);
	assert.equal(result.stdout.length, 0);
	assert.match(result.stderr.toString('utf8'), diagnostic);
};
ok(['--textual'], input, tagged);
ok(['--textual', '-s'], input, tagged);
ok(['--textual', '-d'], tagged, input);
ok(['--decode-auto'], tagged, input);
ok(['--textual', '--untagged'], input, payload);
ok(['--textual', '--untagged', '-d'], payload, input);
ok(['--decode-auto', '-s'], Buffer.from('legacy space¶'), Buffer.from('legacy space\n'));
ok(['--decode-auto'], Buffer.from('\uF000ρΒ1_·¶'), Buffer.from([0, 10]));
for (const prefix of ['\uF000ρΤ1_', '\uF000ρΒ_', '\uF000ρΤ2_']) {
	rejected(['--textual'], Buffer.from(prefix), /raw-input/);
	const escaped = Buffer.from('\uF000' + prefix);
	ok(['--textual', '--raw-input'], Buffer.from(prefix), Buffer.concat([Buffer.from(tag), escaped]));
	ok(['--textual', '--untagged'], Buffer.from(prefix), escaped);
}
rejected(['--textual', '-d', '--strict'], Buffer.from(tag + '\uF000A'), /invalid encoded input/);
rejected(['--textual', '-d'], payload, /MissingTag/);
rejected(['--decode-auto'], Buffer.from('\uF000ρΤ2_'), /UnsupportedVersion/);
rejected(['--decode-auto', '-S', '--strict'], Buffer.from(tag + '\n'), /invalid encoded input/);
for (const raw of [Buffer.from([0xff, 0, 0xe4, 0xb8]), Buffer.from([0xf4, 0x90, 0x80, 0x80])]) {
	const encoded = invoke(['--textual'], raw);
	assert.equal(encoded.status, 0);
	assert(encoded.stdout.subarray(0, Buffer.byteLength(tag)).equals(Buffer.from(tag)));
	ok(['--decode-auto'], encoded.stdout, raw);
}
for (const args of [
	['--untagged'], ['--raw-input'], ['--textual', '--raw-input', '-d'],
	['--textual', '--decode-auto'], ['--textual', '-C'], ['--textual', '-X'],
	['--textual', '-f'], ['--textual', '-p'], ['--textual', '-t'],
	['--textual', '-n'], ['--textual', '-P', '!'], ['--textual', '-d', '-S'],
]) rejected(args, input, /incompatible|requires/i);
console.log('PASS: Zig textual CLI selection, legacy migration, canonical errors and leading-tag guard');
