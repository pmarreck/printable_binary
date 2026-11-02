// Export only Cargo's actual native test artifacts; keep source paths private.
import assert from 'node:assert/strict';
import { readFileSync, mkdirSync, copyFileSync, chmodSync, writeFileSync, constants } from 'node:fs';
import { join, isAbsolute } from 'node:path';

assert(process.env.NIX_BUILD_TOP || process.env.TEST_WORKSPACE, 'export tests in confinement');
const [artifactsFile, metadataFile, root] = process.argv.slice(2);
assert(artifactsFile && metadataFile && root && process.argv.length === 5);
const crate = JSON.parse(readFileSync(metadataFile, 'utf8')).packages.find(pkg => pkg.name === 'printable_binary');
assert(crate, 'independent Cargo metadata must contain the crate');
const artifacts = readFileSync(artifactsFile, 'utf8').trim().split(/\r?\n/).filter(Boolean).map(line => JSON.parse(line))
	.filter(item => item.reason === 'compiler-artifact' && item.profile?.test === true && item.executable != null);
const expected = crate.targets.filter(target => target.test).map(target => `${target.kind[0]}/${target.name}`).sort();
assert(expected.length > 0);
assert.deepEqual(artifacts.map(item => `${item.target.kind[0]}/${item.target.name}`).sort(), expected);
const tests = artifacts.map(item => {
	const name = item.target.name;
	const kind = item.target.kind[0];
	assert.match(name, /^[A-Za-z0-9_-]+$/, 'unsafe Rust target name');
	assert.match(kind, /^[A-Za-z0-9_-]+$/, 'unsafe Rust target kind');
	assert(isAbsolute(item.executable));
	return { name, kind, file: `libexec/rust-tests/${kind}-${name}` };
});
assert.equal(new Set(tests.map(test => test.file)).size, tests.length);
mkdirSync(join(root, 'libexec/rust-tests'), { recursive: true });
mkdirSync(join(root, 'share'), { recursive: true });
for (let index = 0; index < tests.length; index++) {
	const destination = join(root, tests[index].file);
	copyFileSync(artifacts[index].executable, destination, constants.COPYFILE_EXCL);
	chmodSync(destination, 0o755);
}
const write = (name, value) => writeFileSync(join(root, 'share', name), JSON.stringify(value) + '\n', { flag: 'wx' });
write('rust-native-tests.json', { schema: 'printable-binary/rust-native-tests-v1', profile: 'release', native_tests: tests });
write('rust-test-targets.json', { packages: [{ name: crate.name,
	targets: crate.targets.map(({ name, kind, test }) => ({ name, kind, test })) }] });
