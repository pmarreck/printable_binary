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
