use printable_binary::textual::{self, ErrorKind, MARKER, TAG};
use printable_binary::{
	decode_auto, decode_auto_with_options, encode_with_options, DecodeOptions, EncodeOptions,
};

fn glyph(byte: u8) -> Vec<u8> {
	printable_binary::encode(&[byte])
}

#[test]
fn textual_preserves_unicode_spaces_joiners_and_normalization_form() {
	for input in [
		"中文 日本語 한국어 café",
		"👩\u{200d}🚀 می\u{200c}روم",
		"e\u{301} \u{fe0f}",
	] {
		assert_eq!(textual::encode_payload(input.as_bytes()), input.as_bytes());
		assert_eq!(
			textual::decode_payload(input.as_bytes()).unwrap(),
			input.as_bytes()
		);
	}
	assert_eq!(textual::encode_payload(b"\0\n\x1b\"\\"), "·¶⎋ˮ⧷".as_bytes());
	assert_eq!(
		textual::encode_payload("\u{0080}\u{0085}\u{202e}\u{00a0}".as_bytes()),
		printable_binary::encode("\u{0080}\u{0085}\u{202e}\u{00a0}".as_bytes())
	);
}

#[test]
fn every_active_replacement_glyph_and_marker_have_one_literal_spelling() {
	for byte in 0u16..=255 {
		let mapped = glyph(byte as u8);
		if mapped.len() > 1 && byte != 32 {
			let mut quoted = MARKER.as_bytes().to_vec();
			quoted.extend_from_slice(&mapped);
			assert_eq!(textual::encode_payload(&mapped), quoted);
			assert_eq!(textual::decode_payload(&quoted).unwrap(), mapped);
		}
	}
	assert_eq!(
		textual::encode_payload(MARKER.as_bytes()),
		MARKER.repeat(2).as_bytes()
	);
	assert_eq!(textual::encode_payload("␣".as_bytes()), "␣".as_bytes());
	for count in 0..12 {
		let raw = format!("{}ρΤ1_", MARKER.repeat(count));
		assert_eq!(
			decode_auto(&textual::encode(raw.as_bytes())).unwrap(),
			raw.as_bytes()
		);
	}
}

#[test]
fn malformed_bytes_remain_distinct_from_unicode_controls() {
	assert_eq!(textual::encode_payload(&[0x80]), glyph(0x80));
	assert_eq!(
		textual::encode_payload("\u{80}".as_bytes()),
		printable_binary::encode("\u{80}".as_bytes())
	);
	assert_ne!(
		textual::encode_payload(&[0x80]),
		textual::encode_payload("\u{80}".as_bytes())
	);
	for input in [
		&b"\xc0\x80"[..],
		&b"\xed\xa0\x80"[..],
		&b"\xf4\x90\x80\x80"[..],
		&b"\xe4\xb8"[..],
		&b"\xff\0\x1b\xf0\x90\x80"[..],
	] {
		assert_eq!(
			textual::decode_payload(&textual::encode_payload(input)).unwrap(),
			input
		);
	}
}

#[test]
fn aliases_and_unnecessary_quotes_are_rejected() {
	assert_eq!(
		textual::decode_payload(&printable_binary::encode("中".as_bytes()))
			.unwrap_err()
			.kind,
		ErrorKind::NonCanonical
	);
	for text in [
		format!("{MARKER}A"),
		MARKER.to_owned(),
		format!("{MARKER}␣"),
	] {
		assert_eq!(
			textual::decode_payload(text.as_bytes()).unwrap_err().kind,
			ErrorKind::InvalidEscape
		);
	}
	assert_eq!(
		textual::decode_payload(b"\n").unwrap_err().kind,
		ErrorKind::NonCanonical
	);
	assert_eq!(
		textual::decode_payload(&[0xff]).unwrap_err().kind,
		ErrorKind::InvalidUtf8
	);
}

#[test]
fn tagged_values_and_legacy_log_values_are_unambiguous() {
	let raw = "Windows path C:\\中文 日本語\n".as_bytes();
	let tagged = textual::encode(raw);
	assert!(tagged.starts_with(TAG));
	assert_eq!(textual::decode(&tagged).unwrap(), raw);
	let options = DecodeOptions {
		spaces: true,
		strip_whitespace: false,
	};
	assert_eq!(decode_auto_with_options(&tagged, options).unwrap(), raw);
	let legacy = encode_with_options(raw, EncodeOptions { spaces: true });
	assert_eq!(decode_auto_with_options(&legacy, options).unwrap(), raw);
	for opener in ["\u{f000}ρΤ_", "\u{f000}ρΤ1_"] {
		let framed = format!("{opener}中文\u{f000}/ρΤ");
		assert_eq!(decode_auto(framed.as_bytes()).unwrap(), "中文".as_bytes());
	}
	for version in ["0_", "01_", "2_", "123456789_"] {
		assert_eq!(
			decode_auto(format!("{MARKER}ρΤ{version}").as_bytes())
				.unwrap_err()
				.kind,
			ErrorKind::UnsupportedVersion
		);
	}
	for suffix in ["", "1", "x_"] {
		assert_eq!(
			decode_auto(format!("{MARKER}ρΤ{suffix}").as_bytes())
				.unwrap_err()
				.kind,
			ErrorKind::MalformedTag
		);
	}
	let bytewise = format!("{MARKER}ρΒ1_{}", String::from_utf8(glyph(0)).unwrap());
	assert_eq!(decode_auto(bytewise.as_bytes()).unwrap(), &[0]);
	assert_eq!(
		textual::decode(b"plain").unwrap_err().kind,
		ErrorKind::MissingTag
	);
	assert_eq!(
		textual::decode(format!("{MARKER}ρΤ1_\n").as_bytes())
			.unwrap_err()
			.offset,
		TAG.len()
	);
}

#[test]
fn all_one_and_two_byte_inputs_round_trip_with_canonical_outputs() {
	let mut single = std::collections::HashSet::new();
	for byte in 0..=255 {
		let encoded = textual::encode_payload(&[byte]);
		assert!(single.insert(encoded.clone()));
		assert_eq!(textual::decode_payload(&encoded).unwrap(), &[byte]);
	}
	for pair in 0u32..=65535 {
		let input = [(pair >> 8) as u8, pair as u8];
		let encoded = textual::encode_payload(&input);
		assert!(encoded.len() <= 3 * input.len());
		let decoded = textual::decode_payload(&encoded).unwrap();
		assert_eq!(decoded, input);
		assert_eq!(textual::encode_payload(&decoded), encoded);
	}
}

#[test]
fn all_unicode_scalars_round_trip_in_one_message() {
	let source: String = (0..=0x10ffff).filter_map(char::from_u32).collect();
	let encoded = textual::encode_payload(source.as_bytes());
	assert!(encoded.len() <= source.len() * 3);
	assert_eq!(
		textual::decode_payload(&encoded).unwrap(),
		source.as_bytes()
	);
}
