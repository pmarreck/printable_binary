//! Recovery is deliberately broader than canonical validation. Unknown wire
//! bytes are preserved, never repaired. Diagnostics borrow spans from the input;
//! the decoder retains no event list, and sink failures propagate immediately.
use crate::{textual, DecodeOptions};

#[derive(Clone, Copy, Debug, Default, Eq, PartialEq)]
pub struct Summary {
	pub invalid_events: usize,
	pub invalid_bytes: usize,
}

impl Summary {
	pub fn exit_code(self) -> u8 { self.invalid_events.min(255) as u8 }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct ErrorEvent<'a> {
	pub input_offset: usize,
	pub output_offset: usize,
	pub input_length: usize,
	pub output_length: usize,
	pub bytes: &'a [u8],
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Decoded {
	pub bytes: Vec<u8>,
	pub summary: Summary,
}

#[derive(Debug, Eq, PartialEq)]
pub enum Error<E> { Framing(textual::DecodeError), Sink(E) }

impl<E: std::fmt::Display> std::fmt::Display for Error<E> {
	fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
		match self { Self::Framing(e) => e.fmt(f), Self::Sink(e) => e.fmt(f) }
	}
}
impl<E: std::error::Error + 'static> std::error::Error for Error<E> {}

fn mapped(input: &[u8]) -> Option<(u8, usize)> {
	let first = *input.first()?;
	let length = crate::utf8_len(first);
	let bytes = input.get(..length)?;
	let value = match length {
		1 => crate::DECODE_1[first as usize],
		2 if (0xc2..=0xdf).contains(&first) && bytes[1] & 0xc0 == 0x80 =>
			crate::DECODE_2[(first & 0x1f) as usize][(bytes[1] & 0x3f) as usize],
		3 => {
			let key = (first as u32) << 16 | (bytes[1] as u32) << 8 | bytes[2] as u32;
			crate::DECODE_3.binary_search_by_key(&key, |&(key, _)| key)
				.map(|index| crate::DECODE_3[index].1 as i16).unwrap_or(-1)
		},
		_ => -1,
	};
	(value >= 0).then_some((value as u8, length))
}

struct Events { start: Option<(usize, usize)>, summary: Summary }
impl Events {
	fn new() -> Self { Self { start: None, summary: Summary::default() } }
	fn reject(&mut self, input: usize, output: usize) {
		if self.start.is_none() { self.start = Some((input, output)); }
	}
	fn close<E>(&mut self, input: &[u8], end: usize, output_end: usize, base: usize,
		emit: &mut impl FnMut(ErrorEvent<'_>) -> Result<(), E>) -> Result<(), E> {
		if let Some((start, output_start)) = self.start.take() {
			let length = end - start;
			emit(ErrorEvent { input_offset: base + start, output_offset: output_start,
				input_length: length, output_length: output_end - output_start, bytes: &input[start..end] })?;
			self.summary.invalid_events += 1;
			self.summary.invalid_bytes += length;
		}
		Ok(())
	}
}

/// Decode into a cleared reusable buffer. Whitespace explicitly ignored by the
/// selected profile separates events and never changes original input offsets.
pub fn decode_bytewise_into<E>(input: &[u8], output: &mut Vec<u8>, options: DecodeOptions,
	emit: impl FnMut(ErrorEvent<'_>) -> Result<(), E>) -> Result<Summary, E> {
	bytewise_at(input, output, options, 0, emit)
}

fn bytewise_at<E>(input: &[u8], output: &mut Vec<u8>, options: DecodeOptions, base: usize,
	mut emit: impl FnMut(ErrorEvent<'_>) -> Result<(), E>) -> Result<Summary, E> {
	output.clear(); output.reserve(input.len());
	let mut events = Events::new();
	let mut position = 0;
	while position < input.len() {
		let byte = input[position];
		let ignored = options.strip_whitespace && matches!(byte, b' ' | b'\t' | b'\r' | b'\n')
			&& !(options.spaces && byte == b' ');
		let recognized = if options.spaces && byte == b' ' { Some((b' ', 1)) }
			else { mapped(&input[position..]) };
		if ignored || recognized.is_some() {
			events.close(input, position, output.len(), base, &mut emit)?;
			if ignored { position += 1; }
			else if let Some((value, length)) = recognized { output.push(value); position += length; }
		} else {
			events.reject(position, output.len());
			output.push(byte); position += 1;
		}
	}
	events.close(input, position, output.len(), base, &mut emit)?;
	Ok(events.summary)
}

pub fn decode_bytewise<E>(input: &[u8], options: DecodeOptions,
	emit: impl FnMut(ErrorEvent<'_>) -> Result<(), E>) -> Result<Decoded, E> {
	let mut bytes = Vec::with_capacity(input.len());
	let summary = bytewise_at(input, &mut bytes, options, 0, emit)?;
	Ok(Decoded { bytes, summary })
}

fn scalar(input: &[u8]) -> Option<&str> {
	let first = *input.first()?;
	let length = match first { 0..=0x7f => 1, 0xc2..=0xdf => 2, 0xe0..=0xef => 3, 0xf0..=0xf4 => 4, _ => return None };
	std::str::from_utf8(input.get(..length)?).ok()
}

struct Token { consumed: usize, bytes: [u8; 4], length: usize }
fn token(input: &[u8]) -> Token {
	let mut result = Token { consumed: 1, bytes: [input[0], 0, 0, 0], length: 1 };
	let Some(text) = scalar(input) else { return result; };
	let bytes = text.as_bytes();
	result.consumed = bytes.len(); result.length = bytes.len();
	result.bytes[..bytes.len()].copy_from_slice(bytes);
	if text == textual::MARKER {
		if let Some(next) = scalar(&input[bytes.len()..]) {
			let next_bytes = next.as_bytes();
			let quoted_glyph = next_bytes.len() > 1 && mapped(next_bytes).is_some_and(|(byte, _)| byte != b' ');
			if next == textual::MARKER || quoted_glyph {
				result.consumed += next_bytes.len(); result.length = next_bytes.len();
				result.bytes[..next_bytes.len()].copy_from_slice(next_bytes);
			}
		}
	} else if bytes == b" " { /* Literal spaces are fixed textual policy. */ }
	else if let Some((byte, _)) = mapped(bytes).filter(|(byte, _)| *byte != b' ') {
		result.bytes[0] = byte; result.length = 1;
	}
	result
}

// At most four mapped tokens can form one recovered UTF-8 scalar. Invalid
// prefixes consume just their first token; lookahead never steals a valid start.
fn unit(input: &[u8]) -> Token {
	let first = token(input);
	if first.length != 1 || first.bytes[0] < 128 { return first; }
	let wanted = match first.bytes[0] { 0xc2..=0xdf => 2, 0xe0..=0xef => 3, 0xf0..=0xf4 => 4, _ => return first };
	let mut combined = Token { consumed: first.consumed, bytes: first.bytes, length: 1 };
	while combined.length < wanted {
		if combined.consumed == input.len() { return first; }
		let next = token(&input[combined.consumed..]);
		if next.length != 1 || next.bytes[0] & 0xc0 != 0x80 { return first; }
		combined.bytes[combined.length] = next.bytes[0];
		combined.length += 1; combined.consumed += next.consumed;
	}
	if std::str::from_utf8(&combined.bytes[..wanted]).is_ok() { combined } else { first }
}

fn textual_at<E>(input: &[u8], base: usize,
	mut emit: impl FnMut(ErrorEvent<'_>) -> Result<(), E>) -> Result<Decoded, E> {
	let mut output = Vec::with_capacity(input.len());
	let mut events = Events::new();
	let mut position = 0;
	while position < input.len() {
		let unit = unit(&input[position..]);
		let bytes = &unit.bytes[..unit.length];
		let character = std::str::from_utf8(bytes).ok().and_then(|s| s.chars().next());
		let mut canonical = [0u8; 12];
		let length = textual::encode_unit(bytes, character, &mut canonical);
		if canonical[..length] == input[position..position + unit.consumed] {
			events.close(input, position, output.len(), base, &mut emit)?;
		} else { events.reject(position, output.len()); }
		output.extend_from_slice(bytes); position += unit.consumed;
	}
	events.close(input, position, output.len(), base, &mut emit)?;
	Ok(Decoded { bytes: output, summary: events.summary })
}

pub fn decode_textual_payload<E>(input: &[u8], emit: impl FnMut(ErrorEvent<'_>) -> Result<(), E>) -> Result<Decoded, E> {
	textual_at(input, 0, emit)
}

pub fn decode_textual<E>(input: &[u8], emit: impl FnMut(ErrorEvent<'_>) -> Result<(), E>) -> Result<Decoded, Error<E>> {
	match textual::frame(input).map_err(Error::Framing)? {
		Some((textual::Kind::Textual, payload, start)) => textual_at(payload, start, emit).map_err(Error::Sink),
		value => Err(Error::Framing(textual::DecodeError {
			kind: if value.is_some() { textual::ErrorKind::MismatchedTag } else { textual::ErrorKind::MissingTag }, offset: 0,
		})),
	}
}

pub fn decode_auto<E>(input: &[u8], options: DecodeOptions,
	emit: impl FnMut(ErrorEvent<'_>) -> Result<(), E>) -> Result<Decoded, Error<E>> {
	match textual::frame(input).map_err(Error::Framing)? {
		Some((textual::Kind::Textual, payload, start)) => textual_at(payload, start, emit).map_err(Error::Sink),
		value => {
			let (payload, start) = value.map(|(_, payload, start)| (payload, start)).unwrap_or((input, 0));
			let mut bytes = Vec::with_capacity(payload.len());
			let summary = bytewise_at(payload, &mut bytes, options, start, emit).map_err(Error::Sink)?;
			Ok(Decoded { bytes, summary })
		},
	}
}
