// Retained native tests must match Cargo's independent target inventory.
import assert from 'node:assert/strict';
import { readFileSync, realpathSync, lstatSync } from 'node:fs';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';

assert(process.env.NIX_BUILD_TOP || process.env.TEST_WORKSPACE, 'run prepared tests in confinement');
const root = realpathSync(process.argv[2]);
const metadata = JSON.parse(readFileSync(process.argv[3], 'utf8'));
const manifest = JSON.parse(readFileSync(join(root, 'share/rust-native-tests.json'), 'utf8'));
const crate = metadata.packages.find(pkg => pkg.name === 'printable_binary');
assert(crate, 'Cargo metadata must include the crate');
assert.deepEqual(JSON.parse(readFileSync(join(root, 'share/rust-test-targets.json'), 'utf8')), {
	packages: [{ name: crate.name, targets: crate.targets.map(({ name, kind, test }) => ({ name, kind, test })) }],
}, 'retain the independent Cargo target metadata without source-local paths');
const expected = crate.targets.filter(target => target.test)
	.map(target => `${target.kind[0]}/${target.name}`).sort();
assert(expected.length > 0, 'an empty native test inventory cannot pass');
assert.equal(manifest.schema, 'printable-binary/rust-native-tests-v1');
assert.equal(manifest.profile, 'release');
function checkInventory(tests) {
	const actual = tests.map(test => `${test.kind}/${test.name}`).sort();
	assert.deepEqual(actual, expected, 'retained tests must cover every Cargo test target exactly once');
	assert.equal(new Set(tests.map(test => test.file)).size, actual.length);
}
checkInventory(manifest.native_tests);
for (let omitted = 0; omitted < expected.length; omitted++) {
	assert.throws(() => checkInventory(manifest.native_tests.filter((_, index) => index !== omitted)));
}
assert.throws(() => checkInventory([...manifest.native_tests, manifest.native_tests[0]]));

function executable(relative) {
	assert.match(relative, /^(bin|libexec)\/[A-Za-z0-9_/-]+$/);
	const parts = relative.split('/');
	let path = root;
	for (let index = 0; index < parts.length; index++) {
		assert(parts[index] && parts[index] !== '..');
		path = join(path, parts[index]);
		const stat = lstatSync(path);
		assert(!stat.isSymbolicLink(), 'artifact components must not escape through symlinks');
		if (index < parts.length - 1) assert(stat.isDirectory());
		else assert(stat.isFile() && (stat.mode & 0o111), 'retained artifact must be executable');
	}
	return path;
}
for (const test of manifest.native_tests) {
	assert.match(test.kind, /^[A-Za-z0-9_-]+$/);
	assert.match(test.name, /^[A-Za-z0-9_-]+$/);
	assert.equal(test.file, `libexec/rust-tests/${test.kind}-${test.name}`);
	const result = spawnSync(executable(test.file), [], { encoding: 'utf8', maxBuffer: 1024 * 1024 });
	assert.equal(result.status, 0, `${test.name}: ${result.error ?? ''}\n${result.stdout}\n${result.stderr}`);
}
for (const relative of ['bin/printable-binary-rs', 'libexec/textual-example', 'libexec/printable-binary-reference']) executable(relative);
console.log(`PASS: all ${expected.length} retained Rust native test targets execute; CLI/reference artifacts are available`);
