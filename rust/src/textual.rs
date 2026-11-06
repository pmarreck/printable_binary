//! Textual v1: arbitrary bytes, preserved Unicode, and canonical martini quoting.

pub const MARKER: &str = "\u{f000}";
pub const TAG: &[u8] = "\u{f000}ρΤ1_".as_bytes();

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum ErrorKind {
	InvalidUtf8,
	InvalidEscape,
	NonCanonical,
	MissingTag,
	MalformedTag,
	UnsupportedVersion,
	MismatchedTag,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct DecodeError {
	pub kind: ErrorKind,
	pub offset: usize,
}

impl std::fmt::Display for DecodeError {
	fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
		write!(f, "{:?} at encoded byte {}", self.kind, self.offset)
	}
}
impl std::error::Error for DecodeError {}

const MARKER_CHAR: char = '\u{f000}';
const BYTEWISE_NAMESPACE: &[u8] = "\u{f000}ρΒ".as_bytes();
const TEXTUAL_NAMESPACE: &[u8] = "\u{f000}ρΤ".as_bytes();
const BYTEWISE_END: &[u8] = "\u{f000}/ρΒ".as_bytes();
const TEXTUAL_END: &[u8] = "\u{f000}/ρΤ".as_bytes();

/// Recognize the reserved opener namespace even if its version is malformed.
pub fn has_reserved_prefix(input: &[u8]) -> bool {
	input.starts_with(BYTEWISE_NAMESPACE) || input.starts_with(TEXTUAL_NAMESPACE)
}

fn glyph(byte: u8) -> &'static [u8] {
	if byte == b' ' {
		return b" ";
	}
	let (offset, length) = crate::ENCODE[byte as usize];
	&crate::MAP_DATA[offset as usize..offset as usize + length as usize]
}

// The input here is already a validated UTF-8 scalar. Space replaces ␣ in the
// textual alphabet, so literal ␣ no longer needs quoting in this mode.
fn mapped(bytes: &[u8]) -> Option<u8> {
	let value = match bytes.len() {
		1 if bytes[0] == b' ' => return Some(b' '),
		1 => crate::DECODE_1[bytes[0] as usize],
		2 => crate::DECODE_2[(bytes[0] & 0x1f) as usize][(bytes[1] & 0x3f) as usize],
		3 => {
			let key = (bytes[0] as u32) << 16 | (bytes[1] as u32) << 8 | bytes[2] as u32;
			crate::DECODE_3
				.binary_search_by_key(&key, |&(key, _)| key)
				.map(|index| crate::DECODE_3[index].1 as i16)
				.unwrap_or(-1)
		}
		_ => -1,
	};
	(value >= 0 && value != b' ' as i16).then_some(value as u8)
}

fn sensitive(character: char) -> bool {
	let cp = character as u32;
	crate::textual_policy::SENSITIVE_RANGES
		.binary_search_by(|&(first, last)| {
			if last < cp {
				std::cmp::Ordering::Less
			} else if first > cp {
				std::cmp::Ordering::Greater
			} else {
				std::cmp::Ordering::Equal
			}
		})
		.is_ok()
}

// The one authoritative spelling of a source unit, shared by encoding and
// recovery validation. A unit is one valid scalar or one malformed source byte.
pub(crate) fn encode_unit(bytes: &[u8], character: Option<char>, output: &mut [u8; 12]) -> usize {
	let mut length = 0;
	let mut append = |part: &[u8]| {
		output[length..length + part.len()].copy_from_slice(part);
		length += part.len();
	};
	match character {
		None => append(glyph(bytes[0])),
		Some(c) if c.is_ascii() => append(glyph(c as u8)),
		Some(MARKER_CHAR) => { append(MARKER.as_bytes()); append(bytes); },
		Some(c) if sensitive(c) => { for &byte in bytes { append(glyph(byte)); } },
		Some(_) => {
			if mapped(bytes).is_some() { append(MARKER.as_bytes()); }
			append(bytes);
		},
	}
	length
}

/// Encode arbitrary bytes as a canonical, untagged textual payload. Source is
/// always raw; literal markers/tags are quoted rather than interpreted.
pub fn encode_payload(input: &[u8]) -> Vec<u8> {
	let mut output = Vec::with_capacity(input.len().saturating_mul(3));
	let mut unit = [0u8; 12];
	for chunk in input.utf8_chunks() {
		for (offset, character) in chunk.valid().char_indices() {
			let bytes = &chunk.valid().as_bytes()[offset..offset + character.len_utf8()];
			let length = encode_unit(bytes, Some(character), &mut unit);
			output.extend_from_slice(&unit[..length]);
		}
		for &byte in chunk.invalid() {
			output.extend_from_slice(glyph(byte));
		}
	}
	output
}

/// Encode raw bytes with the canonical textual v1 opener. Library input is
/// explicitly raw and unconditional; CLI double-encoding guards are separate.
pub fn encode(input: &[u8]) -> Vec<u8> {
	let payload = encode_payload(input);
	let mut output = Vec::with_capacity(TAG.len() + payload.len());
	output.extend_from_slice(TAG);
	output.extend_from_slice(&payload);
	output
}

/// Strictly decode a canonical textual payload. Invalid UTF-8, invalid quoting,
/// and alternate bytewise spellings are errors, never silent repair.
pub fn decode_payload(input: &[u8]) -> Result<Vec<u8>, DecodeError> {
	let text = std::str::from_utf8(input).map_err(|error| DecodeError {
		kind: ErrorKind::InvalidUtf8,
		offset: error.valid_up_to(),
	})?;
	let mut output = Vec::with_capacity(input.len());
	let mut chars = text.char_indices();
	while let Some((offset, character)) = chars.next() {
		if character == MARKER_CHAR {
			let (quoted_offset, quoted) = chars.next().ok_or(DecodeError {
				kind: ErrorKind::InvalidEscape,
				offset,
			})?;
			let bytes = &input[quoted_offset..quoted_offset + quoted.len_utf8()];
			if quoted != MARKER_CHAR && !(quoted.len_utf8() > 1 && mapped(bytes).is_some()) {
				return Err(DecodeError {
					kind: ErrorKind::InvalidEscape,
					offset,
				});
			}
			output.extend_from_slice(bytes);
		} else {
			let bytes = &input[offset..offset + character.len_utf8()];
			if let Some(byte) = mapped(bytes) {
				output.push(byte);
			} else {
				output.extend_from_slice(bytes);
			}
		}
	}
	let canonical = encode_payload(&output);
	if canonical != input {
		let offset = canonical
			.iter()
			.zip(input)
			.position(|(a, b)| a != b)
			.unwrap_or(canonical.len().min(input.len()));
		return Err(DecodeError {
			kind: ErrorKind::NonCanonical,
			offset,
		});
	}
	Ok(output)
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub(crate) enum Kind {
	Bytewise,
	Textual,
}

// Whole-value framing for typed log fields. Mixed-region excerpt parsing is a
// separate adapter, not an implicit recursive operation in the payload codec.
pub(crate) fn frame(input: &[u8]) -> Result<Option<(Kind, &[u8], usize)>, DecodeError> {
	let (kind, namespace, ending, other_ending) = if input.starts_with(TEXTUAL_NAMESPACE) {
		(Kind::Textual, TEXTUAL_NAMESPACE, TEXTUAL_END, BYTEWISE_END)
	} else if input.starts_with(BYTEWISE_NAMESPACE) {
		(
			Kind::Bytewise,
			BYTEWISE_NAMESPACE,
			BYTEWISE_END,
			TEXTUAL_END,
		)
	} else {
		return Ok(None);
	};
	let version = &input[namespace.len()..];
	let suffix_length = match version {
		[b'_', ..] => 1,
		[b'1', b'_', ..] => 2,
		[b'1'] | [] => {
			return Err(DecodeError {
				kind: ErrorKind::MalformedTag,
				offset: namespace.len(),
			})
		}
		[b'1', next, ..] if !next.is_ascii_digit() => {
			return Err(DecodeError {
				kind: ErrorKind::MalformedTag,
				offset: namespace.len() + 1,
			})
		}
		[digit, ..] if digit.is_ascii_digit() => {
			return Err(DecodeError {
				kind: ErrorKind::UnsupportedVersion,
				offset: namespace.len(),
			})
		}
		_ => {
			return Err(DecodeError {
				kind: ErrorKind::MalformedTag,
				offset: namespace.len(),
			})
		}
	};
	let start = namespace.len() + suffix_length;
	let body = &input[start..];
	if body.ends_with(other_ending) {
		return Err(DecodeError {
			kind: ErrorKind::MismatchedTag,
			offset: input.len() - other_ending.len(),
		});
	}
	let end = if body.ends_with(ending) {
		input.len() - ending.len()
	} else {
		input.len()
	};
	Ok(Some((kind, &input[start..end], start)))
}

/// Decode one tagged textual value. A matching trailing closer is accepted;
/// framing aliases do not broaden the strict canonical payload language.
pub fn decode(input: &[u8]) -> Result<Vec<u8>, DecodeError> {
	match frame(input)? {
		Some((Kind::Textual, payload, start)) => decode_payload(payload).map_err(|mut error| {
			error.offset += start;
			error
		}),
		Some(_) => Err(DecodeError {
			kind: ErrorKind::MismatchedTag,
			offset: 0,
		}),
		None => Err(DecodeError {
			kind: ErrorKind::MissingTag,
			offset: 0,
		}),
	}
}
