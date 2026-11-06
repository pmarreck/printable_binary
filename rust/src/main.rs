//! CLI adapter: automatic recovery, injected diagnostics and raw stdout.
use printable_binary::{recovery, textual, DecodeOptions, EncodeOptions};
use std::io::{Read, Write};
use std::process::ExitCode;
use std::time::Instant;

#[derive(Default)]
struct Options {
	decode: bool, spaces: bool, strip: bool, textual: bool, auto: bool,
	untagged: bool, raw_input: bool, strict: bool, ndjson: bool,
}
fn stats_enabled() -> bool {
	!matches!(std::env::var("PRINTABLE_BINARY_MUTE_STATS").ok().as_deref(), Some("1" | "true" | "yes"))
}
fn about() {
	let pf = match (std::env::consts::OS, std::env::consts::ARCH) {
		("linux", "x86_64") => "linux-amd64", ("linux", "aarch64") => "linux-arm64",
		("macos", "aarch64") => "macos-arm64", ("windows", "x86_64") => "mswin-amd64",
		("windows", "aarch64") => "mswin-arm64", _ => panic!("unsupported compilation platform"),
	};
	let variant = if cfg!(target_env = "gnu") { " VARIANT=gnu" }
		else if cfg!(target_env = "musl") { " VARIANT=musl" } else { "" };
	println!("printable-binary {} (Rust) Encode bytes as printable UTF-8; PF={pf}{variant}", env!("CARGO_PKG_VERSION"));
}
fn event(writer: &mut impl Write, event: recovery::ErrorEvent<'_>, ndjson: bool) -> std::io::Result<()> {
	if ndjson {
		write!(writer, "{{\"type\":\"error\",\"input_offset\":{},\"output_offset\":{},\"input_length\":{},\"output_length\":{},\"hex\":\"",
			event.input_offset, event.output_offset, event.input_length, event.output_length)?;
	} else {
		write!(writer, "Error: invalid encoded input input_offset={} output_offset={} input_length={} output_length={} hex=",
			event.input_offset, event.output_offset, event.input_length, event.output_length)?;
	}
	const HEX: &[u8] = b"0123456789abcdef";
	let mut buffer = [0u8; 512];
	for chunk in event.bytes.chunks(256) {
		for (index, &byte) in chunk.iter().enumerate() {
			buffer[index * 2] = HEX[(byte >> 4) as usize];
			buffer[index * 2 + 1] = HEX[(byte & 15) as usize];
		}
		writer.write_all(&buffer[..chunk.len() * 2])?;
	}
	writer.write_all(if ndjson { b"\"}\n" } else { b"\n" })
}
fn run(args: &[String], stderr: &mut impl Write) -> Result<u8, Box<dyn std::error::Error>> {
	let mut options = Options::default();
	for argument in args {
		match argument.as_str() {
			"-d" | "--decode" => options.decode = true,
			"-s" | "--spaces" => options.spaces = true,
			"-S" | "--strip-whitespace" => options.strip = true,
			"--textual" => options.textual = true,
			"--decode-auto" => { options.auto = true; options.decode = true; },
			"--untagged" => options.untagged = true,
			"--raw-input" => options.raw_input = true,
			"--strict" => options.strict = true,
			"--ndjson-stderr" => options.ndjson = true,
			"--no-double-encode-check" => {}, // This minimal encoder does not run that heuristic.
			"-h" | "--help" => {
				println!("Usage: printable-binary-rs [-d|--decode] [-s|--spaces] [--strip-whitespace]\n  --textual          Unicode-preserving codec (tagged by default)\n  --decode-auto      Tagged textual/bytewise or legacy bytewise decode\n  --untagged         Explicit untagged textual payload\n  --raw-input        Encode literal leading tags\n  --strict           Reject invalid decoded input without emitting payload\n  --ndjson-stderr    JSON error events and final summary\n  --about            Version and compilation target");
				return Ok(0);
			},
			"--about" => { about(); return Ok(0); },
			_ => return Err("unknown option".into()),
		}
	}
	if options.textual && options.auto || (options.untagged || options.raw_input) && !options.textual
		|| options.raw_input && options.decode || options.strict && !options.decode
		|| options.textual && options.strip {
		return Err("incompatible codec options".into());
	}
	let started = Instant::now();
	let mut input = Vec::new();
	std::io::stdin().read_to_end(&mut input)?;
	let decode_options = DecodeOptions { spaces: options.spaces, strip_whitespace: options.strip };
	let result = if options.decode {
		let emit = |item: recovery::ErrorEvent<'_>| event(stderr, item, options.ndjson);
		if options.auto { recovery::decode_auto(&input, decode_options, emit)? }
		else if options.textual {
			if options.untagged { recovery::decode_textual_payload(&input, emit)? }
			else { recovery::decode_textual(&input, emit)? }
		} else { recovery::decode_bytewise(&input, decode_options, emit)? }
	} else {
		let bytes = if options.textual {
			if !options.untagged && !options.raw_input && textual::has_reserved_prefix(&input) {
				return Err("input starts with a reserved tag; use --raw-input for literal input".into());
			}
			if options.untagged { textual::encode_payload(&input) } else { textual::encode(&input) }
		} else { printable_binary::encode_with_options(&input, EncodeOptions { spaces: options.spaces }) };
		recovery::Decoded { bytes, summary: recovery::Summary::default() }
	};
	let suppress = options.strict && result.summary.invalid_events != 0;
	let mut stdout = std::io::stdout().lock();
	if !suppress { stdout.write_all(&result.bytes)?; }
	stdout.flush()?;
	let elapsed = started.elapsed().as_secs_f64().max(0.0005);
	let mb = input.len() as f64 / 1_000_000.0;
	if options.ndjson {
		writeln!(stderr, "{{\"type\":\"summary\",\"invalid_events\":{},\"invalid_bytes\":{},\"input_bytes\":{},\"output_bytes\":{},\"complete\":true,\"elapsed_seconds\":{},\"input_mbps\":{},\"debug\":{}}}",
			result.summary.invalid_events, result.summary.invalid_bytes, input.len(),
			if suppress { 0 } else { result.bytes.len() }, elapsed, mb / elapsed, cfg!(debug_assertions))?;
	} else {
		if result.summary.invalid_events != 0 {
			writeln!(stderr, "Invalid input: {} events, {} bytes", result.summary.invalid_events, result.summary.invalid_bytes)?;
		}
		if stats_enabled() { writeln!(stderr, "Input throughput: {mb:.2} MB read in {elapsed:.3} s ({:.2} MB/s)", mb / elapsed)?; }
	}
	Ok(result.summary.exit_code())
}
fn json_string(input: &str) -> String {
	let mut output = String::new();
	for character in input.chars() {
		match character {
			'"' => output.push_str("\\\""), '\\' => output.push_str("\\\\"),
			c if c <= '\u{1f}' => output.push_str(&format!("\\u{:04x}", c as u32)),
			c => output.push(c),
		}
	}
	output
}
fn main() -> ExitCode {
	let args: Vec<String> = std::env::args().skip(1).collect();
	let ndjson = args.iter().any(|arg| arg == "--ndjson-stderr");
	let mut stderr = std::io::stderr().lock();
	if cfg!(debug_assertions) && !ndjson { let _ = writeln!(stderr, "\x1b[33mDEBUG BUILD!\x1b[0m"); }
	match run(&args, &mut stderr) {
		Ok(status) => ExitCode::from(status),
		Err(error) => {
			if ndjson {
				let _ = writeln!(stderr, "{{\"type\":\"error\",\"fatal\":true,\"message\":\"{}\"}}", json_string(&error.to_string()));
				let _ = writeln!(stderr, "{{\"type\":\"summary\",\"complete\":false,\"invalid_events\":null,\"invalid_bytes\":null}}");
			} else { let _ = writeln!(stderr, "Error: {error}"); }
			ExitCode::FAILURE
		},
	}
}
