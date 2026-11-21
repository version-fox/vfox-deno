# vfox-deno

[中文](README_CN.md) | [English](README.md)

Deno plugin for [vfox](https://vfox.dev/).

It installs Deno releases from the [denoland/deno](https://github.com/denoland/deno) GitHub releases, verifies each download against Deno's SHA-256 checksum where one is published, and can adopt a Deno that is already on the machine instead of downloading another copy.

## Install

After installing [vfox](https://github.com/version-fox/vfox), add the plugin, install a Deno, and select it:

```bash
vfox add deno
vfox install deno@2
vfox use --global deno@2
deno --version
```

`deno --version` shows the Deno that is selected. For `deno` to be on the `PATH`, vfox has to be hooked into your shell, see its [quick start](https://vfox.dev/guides/quick-start.html).

`vfox search deno` lists the stable releases that have a download for your platform, newest first.

## Versions

A version is a Deno release number. Write as much of it as you need; the plugin takes the newest release that starts with what you typed:

```bash
vfox install deno@latest       # newest stable release
vfox install deno@2            # newest 2.x
vfox install deno@2.7          # newest 2.7.x
vfox install deno@2.7.0        # exactly 2.7.0
vfox install deno@v2.7.0       # the same, with the v that tags carry
```

Pre-releases are not listed, so they cannot be installed by name here. See [docs/versions.md](docs/versions.md) for installing, using, searching and the installed names.

## Platforms

| Operating system | CPU                   | Deno build                          |
| ---------------- | --------------------- | ----------------------------------- |
| Linux            | x86_64, arm64         | `unknown-linux-gnu` (glibc)         |
| macOS            | x86_64 (Intel), arm64 | `apple-darwin`                      |
| Windows          | x86_64, arm64         | `pc-windows-msvc` (arm64 from 2.6.8) |

Other operating systems and CPUs are not supported. See [docs/platforms.md](docs/platforms.md) for the builds, the first version of each and the limits.

## Already installed Deno

If Deno is already on the machine — from the Deno install script, Cargo, Homebrew, asdf, mise, Scoop, winget or somewhere on `PATH` — `vfox link --detect deno` adopts it instead of downloading another copy. It needs vfox 1.1.0 or later. See [docs/link.md](docs/link.md) for where it looks, what names it gives the installs, and how to link one by hand.

## Documentation

**Using the plugin**

- [Versions](docs/versions.md): how to write a version, and installing, using, searching and the installed names
- [Platforms](docs/platforms.md): which builds exist for which operating system and CPU, and from which version
- [Already installed Deno](docs/link.md): adopting the Deno on the machine with `vfox link --detect deno`
- [Troubleshooting](docs/troubleshooting.md): the messages the plugin prints and what to do about them
- [Changes](docs/changes.md): what each release changed

**Working on the plugin**

- [Development](docs/development.md): how the plugin works, how to change it, test it and release it
- [E2E tests](docs/e2e.md): the end-to-end suite on Ubuntu and Windows

## Thanks

- [Deno](https://deno.com/), whose releases this plugin installs
- [vfox](https://github.com/version-fox/vfox), the version manager this plugin extends
