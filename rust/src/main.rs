// Minimal CLI for cross-impl verification + the transport smoke path.
// (Provisional surface — the full CLI is a "specifics" decision still pending.)
// Default: encode stdin->stdout. `-d`/`--decode`: decode stdin->stdout.
use printable_binary::{decode, encode};
use std::io::{Read, Write};
use std::time::Instant;

fn stats_enabled() -> bool {
    !matches!(
        std::env::var("PRINTABLE_BINARY_MUTE_STATS").ok().as_deref(),
        Some("1" | "true" | "yes")
    )
}

fn main() {
    let mut decode_mode = false;
    for argument in std::env::args().skip(1) {
        match argument.as_str() {
            "-d" | "--decode" => decode_mode = true,
            "-h" | "--help" => {
                println!("Usage: printable-binary-rs [-d|--decode] [--about]\nEncode or decode stdin to stdout.");
                return;
            }
            "--about" => {
                let pf = match (std::env::consts::OS, std::env::consts::ARCH) {
                    ("linux", "x86_64") => "linux-amd64",
                    ("linux", "aarch64") => "linux-arm64",
                    ("macos", "aarch64") => "macos-arm64",
                    ("windows", "x86_64") => "mswin-amd64",
                    ("windows", "aarch64") => "mswin-arm64",
                    _ => panic!("unsupported compilation platform"),
                };
                let variant = if cfg!(target_env = "gnu") {
                    " VARIANT=gnu"
                } else if cfg!(target_env = "musl") {
                    " VARIANT=musl"
                } else {
                    ""
                };
                println!(
                    "printable-binary {} (Rust) Encode bytes as printable UTF-8; PF={pf}{variant}",
                    env!("CARGO_PKG_VERSION")
                );
                return;
            }
            _ => {}
        }
    }
    let started_at = Instant::now();
    let mut input = Vec::new();
    std::io::stdin()
        .read_to_end(&mut input)
        .expect("read stdin");
    let input_bytes_read = input.len();
    let out = if decode_mode {
        decode(&input)
    } else {
        encode(&input)
    };
    let mut stdout = std::io::stdout().lock();
    stdout.write_all(&out).expect("write stdout");
    stdout.flush().expect("flush stdout");

    if stats_enabled() {
        let elapsed_seconds = started_at.elapsed().as_secs_f64().max(0.0005);
        let megabytes = input_bytes_read as f64 / 1_000_000.0;
        eprintln!(
            "Input throughput: {megabytes:.2} MB read in {elapsed_seconds:.3} s ({:.2} MB/s)",
            megabytes / elapsed_seconds
        );
    }
}
