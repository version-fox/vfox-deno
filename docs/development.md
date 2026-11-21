# Development

[中文](zh-CN/development.md) | [English](development.md)

## Layout

```
metadata.lua                  plugin name, version, notes and minimum vfox version
hooks/available.lua           vfox search: the stable releases, from Deno's Releases.md
hooks/pre_install.lua         vfox install: resolves the version, the download and its SHA-256
hooks/post_install.lua        nothing to do: the archive unpacks to a folder with deno in it
hooks/env_keys.lua            PATH, the folder the install holds
hooks/pre_use.lua             vfox use: nothing to map, vfox selects the install
hooks/detect.lua              vfox link --detect: finds the Deno installs already on the machine
lib/util.lua                  release and download addresses, and the platform names Deno uses
lib/checksum.lua              reads the digest of a download from Deno's checksum file
lib/detect_deno.lua           the folders to search, and how a Deno is recognised and named
tests/*_test.lua              offline hook tests, run by vfox plugin test
tests/e2e/                    the end-to-end suite, a Go module (see e2e.md)
.devcontainer/                the dev container with the toolchain the workflows pin (see Dev container)
.github/workflows/            lint, license, test, e2e and the plugin release workflows
Injection.lua                 type hints for what vfox injects, never loaded
README.md, docs/              the documentation; README_CN.md and docs/zh-CN/ are the Chinese version
opencode.jsonc                lets OpenCode agent sessions in this repository run git push, gh pr create and gh pr comment without asking
```

vfox loads `metadata.lua`, calls a hook when a command needs it, and puts `PLUGIN` and `RUNTIME` (`osType`, `archType`, `version`) in scope. `osType` and `archType` are Go's `GOOS` and `GOARCH` of the vfox binary, mapped to Deno's names by `lib/util.lua`.

## What runs for a command

| You run                          | Hooks                                                                                     |
| -------------------------------- | ----------------------------------------------------------------------------------------- |
| `vfox search deno`               | `Available`                                                                               |
| `vfox install deno@2`            | `PreInstall` returns the version, the URL and the digest. vfox downloads, verifies and unpacks, then calls `PostInstall` |
| `vfox use deno@2.7.0`            | `PreUse` (nothing to map). `EnvKeys` puts the install folder on `PATH`                    |
| `vfox link --detect deno`        | `Detect` returns the Deno installs already on the machine (`lib/detect_deno.lua`)         |

A few contracts that cost time to find:

- `PreInstall` returns `version` and `url`, and `sha256` where the checksum file gives one. vfox compares the digest with the download, so the key has to be `sha256`, in lower case with nothing around it. `lib/checksum.lua` reads either form Deno publishes: sha256sum's `<digest>  <name>` (Linux and macOS), or the `Algorithm`, `Hash` and `Path` lines of PowerShell's Get-FileHash (Windows). It lower-cases the digest, and returns nothing, with the reason, when it is not sure of it.
- Only a 404 for the checksum file lets the install go on without a digest, and it prints a note: some releases, such as Deno 1.46.3, publish no checksum file. Every other answer must give a digest for this build. A file that cannot be fetched, an error status, or a file that names no digest for the archive raises an error, so the install stops and a download is never installed unverified.
- `version` becomes the name of the install, so it is the release number with no `v` and no build metadata. `PreInstall` accepts a leading `v`, as in `v2.7.0`.
- Versions are matched as whole numbers: `2.1` matches `2.1.10`, `2.1.1` does not. `Available` returns the list newest first, and `latest` is its first entry.
- `Detect` returns a list of `{ version, path, note }`. `path` is the folder that holds the `deno` executable directly, which is what `EnvKeys` puts on `PATH`. The version is what `deno --version` prints, without the build metadata after a plus sign.
- `EnvKeys` sets `PATH` only. Deno needs no other variable.
- `PreUse` and `PostInstall` do nothing. They stay as the documented extension points of the plugin.

## Changing a hook

1. Change the hook or its library in `hooks/` or `lib/`, and keep `hooks/detect.lua`, `lib/detect_deno.lua` and their tests together.
2. Write or update the offline test in `tests/`. Each test file calls `test.load()` from `vfox.test` once, and calls the real hook through what it returns, as in `plugin:PreInstall({ version = "2" })`.
3. Run the checks below. CI runs the same commands.
4. For a change that vfox must see end to end (a new message, a new file layout), add a step to the e2e suite ([e2e.md](e2e.md)).

## Tests

The hook tests run offline under `vfox plugin test`. CI runs them with vfox 1.1.0, the release it pins. The command finds every `tests/**/*_test.lua` and runs each file in a VM of its own:

```bash
vfox plugin test .
vfox plugin test . --file tests/detect_test.lua
```

Run it from the repository root. The VM disables `io.popen` and `os.execute`. The detect tests therefore replace `os.getenv`, `io.open` and `io.popen` with tables that describe the folders, the files and what each `deno --version` prints, so they never touch a real Deno. `test.load` takes the platform (`os`, `arch`), and `RUNTIME.osType` can be changed to try another one, as the Windows and macOS cases do. The `http` option answers the requests of `Available` and `PreInstall`, so no test needs the network.

## Dev container

`.devcontainer/` builds a Linux development environment with the toolchain the workflows pin: Go 1.27.3 for the end-to-end suite, stylua 2.5.2, lua-language-server 3.19.1, vfox 1.1.0, skywalking-eyes 0.9.0 and actionlint 1.7.12. `.devcontainer/install-tools.sh` checks each download against the SHA-256 digest GitHub publishes for it.

Open the folder with any Dev Containers tool, such as **Dev Containers: Reopen in Container** in VS Code, or build the image and run the checks in a container of your own:

```bash
docker build -t vfox-deno-dev .devcontainer
docker run --rm -v "$PWD:/work" -w /work vfox-deno-dev bash -c 'stylua --check . && vfox plugin test .'
```

The image is multi-arch, so it runs on linux/amd64 and linux/arm64 hosts. The end-to-end suite runs in it too, see [e2e.md](e2e.md).

## Checks

These are the commands of the lint, license and test workflows. Each one runs the same way on a local machine, with the versions CI pins: stylua 2.5.2, LuaLS 3.19.1, skywalking-eyes 0.9.0 and actionlint 1.7.12.

```bash
# Lua formatting and static analysis (.github/workflows/lint.yml).
stylua --check .
lua-language-server --check . --checklevel=Warning

# Go formatting, vet and the unit tests of the e2e module (.github/workflows/lint.yml).
cd tests/e2e
test -z "$(gofmt -l .)"
go vet ./...
go test -short ./...
cd ../..

# Offline hook tests (.github/workflows/test.yml).
vfox plugin test .

# License headers (.github/workflows/license.yml). Docker only, the image CI uses.
docker run --rm -v "$PWD:/work" -w /work apache/skywalking-eyes:0.9.0 header check

# Workflow files (the lint-workflows job of the lint workflow).
docker run --rm -v "$PWD:/repo" -w /repo rhysd/actionlint:1.7.12 -color
```

`stylua` and `lua-language-server` can also be run from Docker or from their release archives. The header check reads `.licenserc.yaml`, which requires the text of `Copyright 2026 Han Li and contributors` and the Apache 2.0 notice in every Lua, Go, YAML, TOML and JSONC file. JSON, Markdown and `go.sum` are not checked.

## Continuous integration

| Workflow        | File                            | What it checks                                                                 |
| --------------- | ------------------------------- | ------------------------------------------------------------------------------ |
| Lint            | `lint.yml`                      | gofmt, go vet and unit tests of `tests/e2e`; stylua; LuaLS; actionlint        |
| License         | `license.yml`                   | license headers with SkyWalking Eyes                                           |
| Test Plugin     | `test.yml`                      | the offline hook tests with the pinned vfox 1.1.0                              |
| E2E             | `e2e.yml`                       | the end-to-end suite on Ubuntu (amd64, arm64) and Windows (amd64, arm64)       |
| Plugin          | `publish.yaml`                  | the shared check on pull requests, and the release on a tag or a manual run    |

## Pinned tools

Each version is written in the workflows and in the dev container that use it. Change a version in all of them, and in this table.

| Tool                | Version | Where it is pinned                                                      |
| ------------------- | ------- | ----------------------------------------------------------------------- |
| vfox                | 1.1.0   | `test.yml` (with its SHA-256), `tests/e2e/vfox.go` and `.devcontainer/` |
| Go                  | 1.27.3  | `lint.yml`, `e2e.yml` and `.devcontainer/Dockerfile`                    |
| stylua              | 2.5.2   | `lint.yml` and `.devcontainer/install-tools.sh`                         |
| lua-language-server | 3.19.1  | `lint.yml` and `.devcontainer/install-tools.sh`                         |
| skywalking-eyes     | 0.9.0   | `license.yml` and `.devcontainer/install-tools.sh`                      |
| actionlint          | 1.7.12  | `lint.yml` and `.devcontainer/install-tools.sh`                         |
| Deno under test     | 2.7.0   | `tests/e2e/e2e_test.go`                                                 |

## Releasing

A maintainer publishes from **Actions → Plugin → Run workflow** on the default branch, entering a stable plugin version without the `v` prefix. The shared workflow, [plugin-manifest-action](https://github.com/version-fox/plugin-manifest-action), updates `metadata.lua`, creates the version commit and the tag, and publishes the ZIP and the manifest in this repository. No local tag or extra release token is needed. Pull requests run the checks only.

Pushing a version tag publishes too, when `PLUGIN.version` already matches the tag. If publication fails, re-run the failed job to resume it.

### After a release

Documentation marks what is newer than the last release as "Unreleased" ("未发布" in Chinese). Once the release is out, move those entries in [changes.md](changes.md) under the new version, with the date of the release, in both languages.

## Writing the docs

English pages are in `docs/`, the Chinese ones in `docs/zh-CN/` under the same names (the Chinese README is `README_CN.md`). Each page starts with a link to the other language. A new page goes into the Documentation list of both READMEs.

To try a branch of the plugin from a zip, pack the same files the e2e suite packs and register them with `vfox add`:

```bash
zip -r /tmp/deno-plugin.zip metadata.lua hooks lib
vfox add deno --source /tmp/deno-plugin.zip
```
