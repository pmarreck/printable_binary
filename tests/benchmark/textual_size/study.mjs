// Deterministic size accounting only: no timing or production-format claim.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { deflateSync } from 'node:zlib';
import { pathToFileURL } from 'node:url';
import { spawnSync } from 'node:child_process';
import PrintableBinary from '../../../js/printable_binary.js';
import { createCodec } from './codec.mjs';

export function textBlock(text, size) {
	const chars = Array.from(text);
	if (!chars.length || !Number.isSafeInteger(size) || size < 1) throw new Error('Invalid text block');
	const parts = [];
	let bytes = 0, index = 0;
	while (bytes + Buffer.byteLength(chars[index % chars.length]) <= size) {
		const char = chars[index++ % chars.length];
		parts.push(char);
		bytes += Buffer.byteLength(char);
	}
	return Buffer.from(parts.join('') + '.'.repeat(size - bytes));
}

export function fixtures(random) {
	const blockSize = 1024;
	if (random.length < blockSize * 4 || random.length % (blockSize * 4) !== 0) {
		throw new Error('Random input must contain a positive multiple of 4096 bytes');
	}
	const texts = {
		ascii: 'INFO request_id=123 status="ok" path=/api/items count=42\n',
		cjk: '中文日志 数据正常。日本語のテキスト。한국어 문장입니다。\n',
		latin: 'Français déjà vu; Español niño y corazón; Deutsch Grüße; română ă; Polski ź.\n',
		multilingual: 'INFO 中文数据 日本語 한국어 café Grüße κόσμος мир مرحبا 🌍🚀 status="ok"\n',
		collision: 'ă',
	};
	const blocks = Object.fromEntries(Object.entries(texts).map(([name, text]) => [name, textBlock(text, blockSize)]));
	const cases = [];
	const count = random.length / blockSize;
	for (const [name, block] of Object.entries(blocks)) {
		for (const fraction of name === 'cjk' ? [0, 25, 50, 75, 100] : [50, 100]) {
			const parts = [];
			let textBytes = 0;
			for (let index = 0; index < count; index++) {
				if (Math.floor((index + 1) * fraction / 100) > Math.floor(index * fraction / 100)) {
					parts.push(block);
					textBytes += blockSize;
				} else parts.push(random.subarray(index * blockSize, (index + 1) * blockSize));
			}
			cases.push({ name: `${name}-${fraction}`, input: Buffer.concat(parts), intentional_text_bytes: textBytes });
		}
	}
	const mixed = cases.find(test => test.name === 'multilingual-50').input;
	cases.push({ name: 'deflate-mixed', input: deflateSync(mixed), intentional_text_bytes: null });
	cases.push({ name: 'deflate-random', input: deflateSync(random), intentional_text_bytes: null });
	return cases;
}

export function measure(glyphs, cases) {
	const codec = createCodec(glyphs);
	const original = new PrintableBinary();
	return cases.map(test => {
		const baseline = codec.bytewise(test.input);
		assert.equal(baseline, original.encode(test.input));
		assert.deepEqual(Buffer.from(original.decode(baseline)), test.input);
		const variants = {};
		for (const variant of ['pb-fallback', 'hex-escape']) {
			const { payload, stats } = codec.encode(test.input, variant);
			assert.deepEqual(codec.decode(payload, variant), test.input);
			variants[variant] = { ...stats, tagged_bytes: stats.payload_bytes + 9 };
		}
		return { name: test.name, input_bytes: test.input.length,
			intentional_text_bytes: test.intentional_text_bytes,
			input_sha256: createHash('sha256').update(test.input).digest('hex'),
			bytewise_bytes: Buffer.byteLength(baseline), variants };
	});
}

export function verifyReference(cli, cases, codec, spawn = spawnSync) {
	for (const test of cases) {
		const encoded = spawn(cli, ['--no-double-encode-check'], { input: test.input,
			env: { ...process.env, PRINTABLE_BINARY_MUTE_STATS: '1' }, maxBuffer: test.input.length * 4 + 4096 });
		assert.equal(encoded.status, 0, `Independent bytewise CLI must succeed for ${test.name}: ${encoded.stderr?.toString('utf8')} ${encoded.error ?? ''}`);
		assert.equal(encoded.stderr.length, 0);
		assert.equal(encoded.stdout.toString('utf8'), codec.bytewise(test.input));
	}
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
	const args = process.argv.slice(2);
	if (args.length !== 0 && (args.length !== 2 || args[0] !== '--reference')) {
		throw new Error('Usage: textual-size-study [--reference PREPARED_BYTEWISE_CLI] < SEEDED_BYTES');
	}
	const glyphs = readFileSync(new URL('../../../character_map.txt', import.meta.url), 'utf8')
		.split(/\r?\n/).map(line => line.trim()).filter(line => line && !line.startsWith('##'))
		.map(line => line.split(/\s/)[0]);
	const random = readFileSync(0);
	const cases = fixtures(random);
	if (args.length) verifyReference(args[1], cases, createCodec(glyphs));
	const result = { schema: 'textual-size-study/v1', experimental: true,
		policy: 'Cc, Cf and White_Space encoded bytewise; other Unicode preserved; all nonidentity PB glyphs and U+F000 quoted',
		runtime: { node: process.versions.node, unicode: process.versions.unicode, zlib: process.versions.zlib },
		random_bytes: random.length, random_sha256: createHash('sha256').update(random).digest('hex'),
		independent_cli_checked: args.length === 2,
		textual_tag_bytes: 9, rows: measure(glyphs, cases) };
	console.log(JSON.stringify(result));
}
