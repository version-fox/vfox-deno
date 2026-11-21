# E2E tests

[中文](zh-CN/e2e.md) | [English](e2e.md)

The offline hook tests (`tests/*_test.lua` under `vfox plugin test`) check the hooks against fake responses and fake folders. The end-to-end suite checks the plugin the way a user meets it: it installs the real vfox, adds the plugin from a zip, and drives `vfox` through the commands a user runs, against Deno's releases on GitHub.

The suite is a Go module in `tests/e2e` that uses only the standard library. It runs natively on the host, with no container. Unless `VFOX_BIN` names a vfox binary you already have, the test downloads the pinned vfox release and checks its SHA-256 digest before it runs anything from it.

## What runs in CI

The **E2E** workflow (`.github/workflows/e2e.yml`) runs `go test -v -timeout 55m -run TestE2E ./...` in `tests/e2e` on four runners:

| Runner             | Platform    |
| ------------------ | ----------- |
| `ubuntu-latest`    | Linux amd64 |
| `ubuntu-26.04-arm` | Linux arm64 |
| `windows-latest`   | Windows amd64 |
| `windows-11-arm`   | Windows arm64 |

## Isolation

Each run gets one temporary root, which is removed when the test ends:

- `VFOX_HOME` is a folder whose name contains a space, as a Windows user's home often does.
- `HOME` and `USERPROFILE` point to a fake home, and `DENO_INSTALL` to a folder of its own.
- `PATH` is a fixed list of system folders (`/usr/bin:/bin` on Linux, `C:\Windows\System32;C:\Windows` on Windows), so a Deno installed on the host is never found by accident.
- Shell activation variables (`__VFOX_*`) are dropped, because the suite never activates vfox.
- Everything else is inherited, so proxies, tokens and `SYSTEMROOT` still apply.

Child processes run in an empty working folder inside the root. Each vfox command has a 15-minute limit.

## The steps

`TestE2E` runs these steps in order, against one isolated environment. Each step is a subtest, so a failure names the step and shows the output of the vfox command. A failed setup stops the run. A later step that does not need the failed one still runs.

1. **Setup.** vfox is downloaded and checked against its pinned SHA-256, or taken from `VFOX_BIN`. It must be 1.1.0 or later. The plugin is packed from `metadata.lua`, `hooks/` and `lib/` into a zip, and `vfox add deno --source` adds it.
2. **Info.** `vfox info deno` prints a link to this README.
3. **Search.** `vfox search deno` lists 2.7.0.
4. **Latest 2.x.** `vfox install deno@2` installs the newest 2.x release. Its output must show `Verifying checksum` with a hexadecimal digest, and must not show `Checksum is not provided`. `vfox current deno` must then report that release. vfox reports a current version only where one is in use, and the suite runs neither `vfox use` nor shell activation. So the release is named in a `.vfox.toml` in the temporary working folder, which the step removes again.
5. **Pinned release.** `vfox install deno@2.7.0` installs 2.7.0 with a verified checksum. Deno run through `vfox exec` must report 2.7.0, with build metadata after a plus sign allowed. Its executable must lie inside `VFOX_HOME`. On Windows the command is `deno.exe`, because vfox 1.1.0's `exec` finds a command there only by its full file name.
6. **Leading v.** `vfox install deno@v2.7.0` exits 0 and names exactly 2.7.0, whether it installs the release or finds it installed.
7. **Unknown version.** `vfox install deno@9.9.9` fails with `Could not resolve version`. The failure is the expected outcome, so this step does not retry it.
8. **Detect and link.** The 2.7.0 binary is copied to `$DENO_INSTALL/bin`, and vfox's own copy is uninstalled. `vfox link --detect -y deno` must find and link the copy as 2.7.0, without mentioning `VFOX_HOME`. Then `vfox list deno` must show the link, `vfox exec` must run that copy, and `vfox uninstall` must remove the link only, leaving the binary in place. See [link.md](link.md).
9. **First Linux release.** `vfox install deno@0.36.0` installs the first release with a download for Linux with x86_64, whose archive leaves `deno` without the execute bit. The first line that `vfox exec deno@0.36.0 -- deno --version` prints must be `deno 0.36.0`. The step runs only on Linux with x86_64: on Windows there is no execute bit to check, and on Linux with arm64 this release has no download.
10. **Cleanup.** Every version that is still installed is uninstalled. This is best effort: a failure is logged, and the temporary root is removed either way.

## Retries

Network calls are retried, so a transient failure does not fail the run:

- `vfox search`, `vfox install` and `vfox exec` (which installs a missing version) are retried when they exit with a non-zero code. The download of vfox itself is retried on transfer errors and on answers other than 200.
- Each failed attempt's output is logged. The pause after the first failure is 10 seconds, after the second 20 seconds, and so on.
- `E2E_RETRY_ATTEMPTS` sets the number of attempts, 3 by default. A value that is not a whole number of at least 1 fails the run, so a typo cannot turn retries off.

Step 7 is an expected failure, so it is never retried.

## Running it

From `tests/e2e`, with a vfox 1.1.0 binary you already have:

```bash
VFOX_BIN=/path/to/vfox go test -v -timeout 40m -run TestE2E ./...
```

Without `VFOX_BIN`, the pinned vfox for the host is downloaded. The pins cover Linux and Windows on amd64 and arm64, and any other host needs `VFOX_BIN`.

| Variable             | Meaning                                                                 | Default             |
| -------------------- | ----------------------------------------------------------------------- | ------------------- |
| `VFOX_BIN`           | absolute path of the vfox binary to test with, instead of the download  | the pinned download |
| `E2E_RETRY_ATTEMPTS` | attempts for each network call, see [Retries](#retries)                 | `3`                 |

The unit tests of the module need neither network nor vfox, and run under `-short`:

```bash
go test -short ./...
```

## In a temporary container

On Linux, a clean container is the closest thing to a fresh CI runner. The checkout is mounted read-only and copied inside the container, so the run writes nothing into your checkout:

```bash
docker run --rm -v "$PWD:/repo:ro" golang:1.27.3 \
  bash -c 'cp -r /repo /work && cd /work/tests/e2e && go test -v -count=1 -timeout 40m -run TestE2E ./...'
```

The [dev container](development.md#dev-container) has the same Go and vfox, and runs the suite too. A Windows container cannot run here, so the Windows jobs of the E2E workflow are the check for those platforms.

## Writing a step

A new check goes into `tests/e2e/e2e_test.go`, in the order it has to run. Check the output the vfox command prints, with the strings it really prints, and not with a guess. Where Deno prints a value with build metadata, compare the part before the plus sign. The suite is the only part of the repository that depends on the network, so keep its requests few and retry only the ones that can fail for network reasons.
