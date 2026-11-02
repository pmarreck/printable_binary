import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, readFileSync, statSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';

assert(process.env.NIX_BUILD_TOP || process.env.TEST_WORKSPACE, 'run export controls in confinement');
const scratch = mkdtempSync(join(process.env.TMPDIR, 'rust-test-export.'));
const fixture = join(scratch, 'native-fixture');
writeFileSync(fixture, 'native artifact fixture\n');
const targets = ['lib', 'bin', 'test'].map((kind, index) => ({ name: `target-${index}`, kind: [kind], test: true }));
targets.push({ name: 'ignored-example', kind: ['example'], test: false });
const artifacts = targets.filter(target => target.test).map(target => ({
	reason: 'compiler-artifact', profile: { test: true }, target, executable: fixture,
}));
const run = (label, entries, inventory = targets) => {
	const records = join(scratch, `${label}.ndjson`);
	const metadata = join(scratch, `${label}.json`);
	const output = join(scratch, label);
	writeFileSync(records, entries.map(item => JSON.stringify(item)).join('\n'));
	writeFileSync(metadata, JSON.stringify({ packages: [{ name: 'printable_binary', targets: inventory }] }));
	const result = spawnSync(process.execPath, ['tests/integration/export-rust-tests.mjs', records, metadata, output], { encoding: 'utf8' });
	return { result, output, metadata };
};
const ignored = [
	{ ...artifacts[0], reason: 'compiler-message' },
	{ ...artifacts[0], profile: { test: false } },
	{ ...artifacts[0], executable: null },
];
const positive = run('valid', [...artifacts, ...ignored]);
assert.equal(positive.result.status, 0, positive.result.stderr);
assert.equal(positive.result.stdout, '');
assert.equal(positive.result.stderr, '');
for (const target of targets.filter(target => target.test)) {
	const file = join(positive.output, 'libexec/rust-tests', `${target.kind[0]}-${target.name}`);
	assert.equal(readFileSync(file, 'utf8'), 'native artifact fixture\n');
	assert.equal(statSync(file).mode & 0o777, 0o755);
}
assert.deepEqual(JSON.parse(readFileSync(join(positive.output, 'share/rust-test-targets.json'))), {
	packages: [{ name: 'printable_binary', targets }],
});
// A producer that omits metadata must not supply its own expected inventory.
writeFileSync(join(positive.output, 'share/rust-test-targets.json'), JSON.stringify({
	packages: [{ name: 'printable_binary', targets: targets.filter(target => target.test) }],
}));
for (const role of ['source', 'package']) {
	const checked = spawnSync(process.execPath, ['tests/integration/test-rust-prepared.mjs',
		positive.output, positive.metadata, role], { encoding: 'utf8' });
	assert.notEqual(checked.status, 0);
	assert.equal(checked.stdout, '');
	assert.match(checked.stderr, /retain the independent Cargo target metadata/);
}
for (let omitted = 0; omitted < artifacts.length; omitted++) {
	const rejected = run(`omitted-${omitted}`, artifacts.filter((_, index) => index !== omitted));
	assert.notEqual(rejected.result.status, 0);
	assert(!existsSync(rejected.output));
}
for (const [label, entries, inventory] of [['duplicate', [...artifacts, artifacts[0]], targets], ['empty', [], []]]) {
	const rejected = run(label, entries, inventory);
	assert.notEqual(rejected.result.status, 0);
	assert(!existsSync(rejected.output));
}
const hostile = { name: '../escape', kind: ['test'], test: true };
const unsafe = run('unsafe-name', [{ ...artifacts[0], target: hostile }], [hostile]);
assert.notEqual(unsafe.result.status, 0);
assert.match(unsafe.result.stderr, /unsafe Rust target name/);
assert(!existsSync(unsafe.output));
console.log('PASS: Rust test export retains all native roles, ignores non-tests and rejects incomplete, duplicate or unsafe inventories');
