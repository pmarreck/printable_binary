use printable_binary::{decode, encode};

#[test]
fn all_two_byte_inputs_match_only_exact_canonical_glyphs() {
    let two_byte_glyphs: std::collections::HashMap<[u8; 2], u8> = (0u8..=255)
        .filter_map(|byte| {
            let glyph = encode(&[byte]);
            (glyph.len() == 2).then(|| ([glyph[0], glyph[1]], byte))
        })
        .collect();
    for first in 0u8..=255 {
        for second in 0u8..=255 {
            let input = [first, second];
            let expected = match two_byte_glyphs.get(&input) {
                Some(byte) => vec![*byte],
                None => input.to_vec(),
            };
            assert_eq!(decode(&input), expected, "input {input:02x?}");
        }
    }
}
