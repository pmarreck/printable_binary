use printable_binary::{
    decode, decode_into_with_options, decode_with_options, encode, encode_into_with_options,
    encode_with_options, DecodeOptions, EncodeOptions,
};

#[test]
fn spaces_mode_only_changes_the_space_byte_and_has_a_unique_image() {
    let mut image = std::collections::HashSet::new();
    for byte in 0u8..=255 {
        let options = EncodeOptions { spaces: true };
        let encoded = encode_with_options(&[byte], options);
        let expected = if byte == b' ' {
            vec![b' ']
        } else {
            encode(&[byte])
        };
        assert_eq!(encoded, expected, "byte {byte}");
        assert!(
            image.insert(encoded.clone()),
            "duplicate glyph for byte {byte}"
        );
        let decoded = decode_with_options(
            &encoded,
            DecodeOptions {
                spaces: true,
                strip_whitespace: true,
            },
        );
        assert_eq!(decoded, [byte], "byte {byte}");
        assert_eq!(encode_with_options(&decoded, options), encoded);
    }
}

#[test]
fn default_options_preserve_the_existing_codec() {
    let bytes: Vec<u8> = (0u8..=255).collect();
    assert_eq!(
        encode_with_options(&bytes, EncodeOptions::default()),
        encode(&bytes)
    );
    let encoded = encode(&bytes);
    assert_eq!(
        decode_with_options(&encoded, DecodeOptions::default()),
        decode(&encoded)
    );
    assert_eq!(decode(b" \t\r\n"), b" \t\r\n");
}

#[test]
fn whitespace_options_classify_all_four_transport_bytes() {
    for spaces in [false, true] {
        for strip_whitespace in [false, true] {
            for byte in [b' ', b'\t', b'\r', b'\n'] {
                let expected = if strip_whitespace && !(spaces && byte == b' ') {
                    vec![]
                } else {
                    vec![byte]
                };
                assert_eq!(
                    decode_with_options(
                        &[byte],
                        DecodeOptions {
                            spaces,
                            strip_whitespace
                        }
                    ),
                    expected
                );
            }
        }
    }
}

#[test]
fn into_variants_clear_previous_data_and_match_owned_results() {
    let mut output = vec![0xff; 100];
    let encode_options = EncodeOptions { spaces: true };
    encode_into_with_options(b" A\x00", &mut output, encode_options);
    assert_eq!(output, encode_with_options(b" A\x00", encode_options));
    let encoded = output.clone();
    let decode_options = DecodeOptions {
        spaces: true,
        strip_whitespace: true,
    };
    decode_into_with_options(&encoded, &mut output, decode_options);
    assert_eq!(output, b" A\x00");
    encode_into_with_options(b"", &mut output, encode_options);
    assert!(output.is_empty());
    decode_into_with_options(b"", &mut output, decode_options);
    assert!(output.is_empty());
}
