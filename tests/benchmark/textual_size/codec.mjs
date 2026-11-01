// Experimental size-study codec, not a production format or public API.
export function scalarAt(input, offset) {
	const a = input[offset], b = input[offset + 1];
	const tail = index => input[index] >= 0x80 && input[index] <= 0xbf;
	let length;
	if (a <= 0x7f) length = 1;
	else if (a >= 0xc2 && a <= 0xdf && tail(offset + 1)) length = 2;
	else if (((a === 0xe0 && b >= 0xa0 && b <= 0xbf) ||
		((a >= 0xe1 && a <= 0xec || a >= 0xee && a <= 0xef) && tail(offset + 1)) ||
		(a === 0xed && b >= 0x80 && b <= 0x9f)) && tail(offset + 2)) length = 3;
	else if (((a === 0xf0 && b >= 0x90 && b <= 0xbf) ||
		(a >= 0xf1 && a <= 0xf3 && tail(offset + 1)) ||
		(a === 0xf4 && b >= 0x80 && b <= 0x8f)) && tail(offset + 2) && tail(offset + 3)) length = 4;
	else return null;
	return { length, text: Buffer.from(input.subarray(offset, offset + length)).toString('utf8') };
}

export function createCodec(glyphs) {
	const marker = '\uF000';
	if (glyphs.length !== 256 || new Set(glyphs).size !== 256 || glyphs.includes(marker) ||
		glyphs.some(glyph => !glyph.isWellFormed() || Array.from(glyph).length !== 1)) {
		throw new Error('Invalid character map');
	}
	const reverse = new Map(glyphs.map((glyph, byte) => [glyph, byte]));
	const sizes = glyphs.map(glyph => Buffer.byteLength(glyph));
	const hex = glyphs.map((_, byte) => marker + 'x' + byte.toString(16).toUpperCase().padStart(2, '0'));
	const sensitive = /[\p{Cc}\p{Cf}\p{White_Space}]/u;
	const variantCheck = variant => {
		if (!['pb-fallback', 'hex-escape'].includes(variant)) throw new Error('Unknown variant');
	};
	const bytesCheck = input => {
		if (!(input instanceof Uint8Array)) throw new TypeError('Expected bytes');
	};
	function bytewise(input) {
		bytesCheck(input);
		return Array.from(input, byte => glyphs[byte]).join('');
	}
	function encode(input, variant = 'pb-fallback') {
		variantCheck(variant);
		bytesCheck(input);
		const parts = [];
		const stats = Object.fromEntries(['ascii_bytes', 'ascii_output_bytes', 'preserved_bytes',
			'quoted_bytes', 'quote_overhead_bytes', 'unicode_mapped_bytes', 'unicode_mapped_output_bytes',
			'invalid_bytes', 'invalid_output_bytes', 'multibyte_utf8_bytes'].map(name => [name, 0]));
		stats.input_bytes = input.length;
		for (let offset = 0; offset < input.length;) {
			const scalar = scalarAt(input, offset);
			if (scalar === null) {
				const byte = input[offset++];
				parts.push(variant === 'pb-fallback' ? glyphs[byte] : hex[byte]);
				stats.invalid_bytes++;
				stats.invalid_output_bytes += variant === 'pb-fallback' ? sizes[byte] : 6;
				continue;
			}
			const { length, text } = scalar;
			if (length === 1) {
				parts.push(glyphs[input[offset]]);
				stats.ascii_bytes++;
				stats.ascii_output_bytes += sizes[input[offset]];
			} else {
				stats.multibyte_utf8_bytes += length;
				if (sensitive.test(text)) {
					for (const byte of input.subarray(offset, offset + length)) {
						parts.push(glyphs[byte]);
						stats.unicode_mapped_output_bytes += sizes[byte];
					}
					stats.unicode_mapped_bytes += length;
				} else if (text === marker || reverse.has(text)) {
					parts.push(marker, text);
					stats.quoted_bytes += length;
					stats.quote_overhead_bytes += 3;
				} else {
					parts.push(text);
					stats.preserved_bytes += length;
				}
			}
			offset += length;
		}
		const payload = parts.join('');
		stats.payload_bytes = Buffer.byteLength(payload);
		return { payload, stats };
	}
	function decode(payload, variant = 'pb-fallback') {
		variantCheck(variant);
		if (typeof payload !== 'string' || !payload.isWellFormed()) throw new Error('Invalid Unicode input');
		const chars = Array.from(payload);
		const result = Buffer.alloc(payload.length * 4);
		let offset = 0;
		for (let index = 0; index < chars.length; index++) {
			const char = chars[index];
			if (char === marker) {
				const quoted = chars[++index];
				if (quoted === marker || (reverse.has(quoted) && Buffer.byteLength(quoted) > 1)) {
					offset += result.write(quoted, offset, 'utf8');
				} else if (variant === 'hex-escape' && quoted === 'x' &&
					/^[0-9A-F]{2}$/.test((chars[index + 1] ?? '') + (chars[index + 2] ?? ''))) {
					result[offset++] = Number.parseInt(chars[index + 1] + chars[index + 2], 16);
					index += 2;
				} else throw new Error('Invalid or incomplete escape');
			} else if (reverse.has(char)) result[offset++] = reverse.get(char);
			else offset += result.write(char, offset, 'utf8');
		}
		const decoded = Buffer.from(result.subarray(0, offset));
		if (encode(decoded, variant).payload !== payload) throw new Error('Noncanonical textual representation');
		return decoded;
	}
	return { bytewise, encode, decode };
}
