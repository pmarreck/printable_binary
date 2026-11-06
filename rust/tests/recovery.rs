use printable_binary::{recovery, textual, DecodeOptions};

#[test]
fn bytewise_events_preserve_bytes_and_resume_at_the_next_exact_glyph() {
	let wire = ["¶".as_bytes(), &[0xff, 0x80], b"A", &[0xe0], "¶".as_bytes()].concat();
	let mut events = Vec::new();
	let result = recovery::decode_bytewise(&wire, DecodeOptions::default(), |event| {
		events.push((event.input_offset, event.output_offset, event.input_length,
			event.output_length, event.bytes.to_vec()));
		Ok::<_, ()>(())
	}).unwrap();
	assert_eq!(result.bytes, [10, 255, 128, b'A', 224, 10]);
	assert_eq!((result.summary.invalid_events, result.summary.invalid_bytes), (2, 3));
	assert_eq!(events, vec![(2, 1, 2, 2, vec![255, 128]), (5, 4, 1, 1, vec![224])]);
}

#[test]
fn valid_unknown_unicode_is_one_bytewise_event_but_normal_textual_data() {
	let mut events = 0;
	let result = recovery::decode_bytewise("中A".as_bytes(), DecodeOptions::default(), |_| {
		events += 1;
		Ok::<_, ()>(())
	}).unwrap();
	assert_eq!(result.bytes, "中A".as_bytes());
	assert_eq!((events, result.summary.invalid_bytes), (1, 3));
	let result = recovery::decode_textual_payload("中A".as_bytes(), |_| Ok::<_, ()>(())).unwrap();
	assert_eq!(result.bytes, "中A".as_bytes());
	assert_eq!(result.summary.invalid_events, 0);
}

#[test]
fn ignored_transport_whitespace_separates_events_without_changing_output_offsets() {
	let mut events = Vec::new();
	let result = recovery::decode_bytewise(&[255, b' ', 128], DecodeOptions {
		spaces: false, strip_whitespace: true,
	}, |event| {
		events.push((event.input_offset, event.output_offset, event.input_length));
		Ok::<_, ()>(())
	}).unwrap();
	assert_eq!(result.bytes, [255, 128]);
	assert_eq!(events, [(0, 0, 1), (2, 1, 1)]);
}

#[test]
fn textual_recovery_handles_bad_bytes_quotes_and_noncanonical_spellings() {
	let wire = ["中".as_bytes(), &[255, 128], b"A", textual::MARKER.as_bytes(), b"A"].concat();
	let mut events = Vec::new();
	let result = recovery::decode_textual_payload(&wire, |event| {
		events.push((event.input_offset, event.output_offset, event.input_length, event.output_length));
		Ok::<_, ()>(())
	}).unwrap();
	assert_eq!(result.bytes, wire);
	assert_eq!(events, [(3, 3, 2, 2), (6, 6, 3, 3)]);
	let alternate = printable_binary::encode("中".as_bytes());
	let mut events = Vec::new();
	let result = recovery::decode_textual_payload(&alternate, |event| {
		events.push((event.input_length, event.output_length));
		Ok::<_, ()>(())
	}).unwrap();
	assert_eq!(result.bytes, "中".as_bytes());
	assert_eq!(events, [(alternate.len(), 3)]);
	assert!(textual::decode_payload(&alternate).is_err(), "canonical validator must remain strict");
}

#[test]
fn tagged_offsets_include_the_header_and_sink_failure_is_not_swallowed() {
	let wire = [textual::TAG, &[255]].concat();
	let mut offsets = Vec::new();
	let result = recovery::decode_auto(&wire, DecodeOptions::default(), |event| {
		offsets.push((event.input_offset, event.output_offset));
		Ok::<_, ()>(())
	}).unwrap();
	assert_eq!(result.bytes, [255]);
	assert_eq!(offsets, [(textual::TAG.len(), 0)]);
	assert_eq!(recovery::decode_bytewise(&[255], DecodeOptions::default(), |_| Err("sink failed")), Err("sink failed"));
}

#[test]
fn seeded_arbitrary_byte_inputs_have_no_false_positive_textual_errors() {
	for seed in [1u32, 42, 0xdead_beef, 0xffff_ffff] {
		let mut state = seed;
		for length in [0, 1, 2, 3, 4, 31, 255, 4096] {
			let input: Vec<u8> = (0..length).map(|_| {
				state ^= state << 13; state ^= state >> 17; state ^= state << 5;
				state as u8
			}).collect();
			let wire = textual::encode_payload(&input);
			let result = recovery::decode_textual_payload(&wire, |_| Ok::<_, ()>(())).unwrap();
			assert_eq!(result.bytes, input, "seed={seed} length={length}");
			assert_eq!(result.summary.invalid_events, 0, "seed={seed} length={length}");
		}
	}
}

#[test]
fn seeded_wire_mutations_agree_with_the_strict_whole_value_oracle() {
	let mut state = 0x7062_7431u32;
	let mut next = || { state ^= state << 13; state ^= state >> 17; state ^= state << 5; state };
	for case in 0..512 {
		let source: Vec<u8> = (0..(next() as usize % 96)).map(|_| next() as u8).collect();
		let mut wire = textual::encode_payload(&source);
		let index = next() as usize % (wire.len() + 1);
		match case % 4 {
			0 => wire.insert(index, next() as u8),
			1 if index < wire.len() => { wire.remove(index); }
			2 if index < wire.len() => wire[index] ^= 1 << (next() % 8),
			_ => {}
		}
		let mut spans = Vec::new();
		let recovered = recovery::decode_textual_payload(&wire, |event| {
			assert!(event.input_length > 0);
			assert_eq!(event.bytes, &wire[event.input_offset..event.input_offset + event.input_length]);
			spans.push((event.input_offset, event.output_offset, event.input_length, event.output_length));
			Ok::<_, ()>(())
		}).unwrap();
		assert_eq!(recovered.summary.invalid_events, spans.len(), "case={case}");
		assert_eq!(recovered.summary.invalid_bytes, spans.iter().map(|s| s.2).sum(), "case={case}");
		for pair in spans.windows(2) {
			assert!(pair[0].0 + pair[0].2 < pair[1].0, "events must be maximal contiguous regions");
			assert!(pair[0].1 + pair[0].3 <= pair[1].1);
		}
		for span in &spans { assert!(span.1 + span.3 <= recovered.bytes.len()); }
		match textual::decode_payload(&wire) {
			Ok(strict) => { assert_eq!(strict, recovered.bytes, "case={case}"); assert_eq!(spans.len(), 0, "case={case}"); }
			Err(_) => assert!(!spans.is_empty(), "noncanonical input went unreported: case={case} wire={wire:?}"),
		}
	}
}
