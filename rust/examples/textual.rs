//! Small adapter used by differential checks and API examples; stdout is data.
use std::io::{Read, Write};

fn main() -> Result<(), Box<dyn std::error::Error>> {
	let mut input = Vec::new();
	std::io::stdin().read_to_end(&mut input)?;
	let output = match std::env::args().nth(1).as_deref() {
		Some("encode") => printable_binary::textual::encode(&input),
		Some("encode-payload") => printable_binary::textual::encode_payload(&input),
		Some("decode") => printable_binary::decode_auto(&input)?,
		Some("decode-payload") => printable_binary::textual::decode_payload(&input)?,
		_ => return Err("expected encode, encode-payload, decode or decode-payload".into()),
	};
	std::io::stdout().write_all(&output)?;
	Ok(())
}
