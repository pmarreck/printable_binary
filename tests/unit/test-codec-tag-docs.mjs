// Rendered private-use glyphs are not a reliable way to copy wire headers.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const contract = readFileSync('docs/CODEC_MODES.md', 'utf8');
const rows = [...contract.matchAll(/^\| (Bytewise|Textual) \| `([^`]+)` \| `([^`]+)` \|$/gm)]
	.map(([, mode, escaped, hex]) => ({ mode, escaped, hex }));
const expected = [['Bytewise', 'Β'], ['Textual', 'Τ']].map(([mode, letter]) => {
	const bytes = Buffer.from('\uF000ρ' + letter + '1_');
	assert.equal(bytes.length, 9);
	return {
		mode,
		escaped: '\\u{f000}ρ' + letter + '1_',
		hex: [...bytes].map(byte => byte.toString(16).padStart(2, '0')).join(' '),
	};
});
assert.deepEqual(rows, expected, 'document both complete headers, including the hidden marker bytes');
assert(readFileSync('README.md', 'utf8').includes(expected[1].escaped), 'README must show the escaped textual header');
console.log('PASS: documented tag spellings include U+F000 and exact nine-byte UTF-8 headers');
