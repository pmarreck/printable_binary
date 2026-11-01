# PrintableBinary CI

Mechatron Prime CI builds and checks the exact commit received through the
repository's dedicated GitHub push webhook. The shared
[setup and operations guide](https://github.com/pmarreck/mechatron-prime/blob/yolo/MECHATRON_PRIME_CI.md)
is the authority for service configuration, provisioning, and the dynamic badge.

## Repository contract

[`.mechatron-prime/targets`](.mechatron-prime/targets) lists the canonical Linux
package and every required Linux Nix check. The documentation check compares
this manifest with the actual flake check names, including newly added checks.

Run `./test` before committing. It reaches the complete required Nix check graph.
Compilation, dependency setup, queue wait, and test execution are separate costs;
a cached check does not establish fresh execution time.

On an authorized CI host, provision only this repository's dedicated webhook:

```bash
mechatron-ci provision --project printable_binary --dry-run --json
mechatron-ci provision --project printable_binary --json
```

After pushing, verify that the remote branch matches the local commit, then
inspect that exact commit rather than an unrelated build or an older green badge:

```bash
git fetch origin yolo
git rev-parse HEAD origin/yolo
mechatron-ci queue --project printable_binary --commit COMMIT_SHA --json
mechatron-ci log --project printable_binary --commit COMMIT_SHA --json
```

Keep credentials, host configuration, and private service addresses outside this
repository. Preserve unrelated webhooks and repository settings.
