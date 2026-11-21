# Changes

[中文](zh-CN/changes.md) | [English](changes.md)

What changed in each release, as a user notices it. GitHub's release pages list the pull requests.

## Unreleased

- `vfox link --detect deno` adopts a Deno that is already on the machine instead of downloading another copy: the Deno install script's folder, Cargo, Homebrew, asdf, mise, Scoop and winget on Windows, Program Files, and every folder on `PATH`. It needs vfox 1.1.0 or later. See [link.md](link.md).
- Each download is checked against the SHA-256 digest that Deno publishes next to it, and vfox prints the digest it checked. A release with no checksum file (Deno 1.46.3, for one) installs with a note that it could not be verified. If the checksum file cannot be fetched or does not name a digest, the install stops instead, so nothing is installed unverified.
- `vfox info deno` shows a link to this README, where the usage is described.
- The documentation is in English and Chinese, with a guide to each part of the plugin and to the end-to-end suite.

## 0.2.1 (2026-09-12)

- When Deno's release list cannot be read, the plugin reports the failure, with the address it asked, instead of crashing on a nil value.

## 0.2.0 (2025-09-29)

- `vfox install deno@2` installs the newest 2.x release, and `vfox install deno@2.7` the newest 2.7.x release.
- A version that matches no release fails with `Could not resolve version: <version>`. An exact release is preferred over a prefix that also matches it.

## 0.1.1 (2024-04-01)

- The continuous integration was updated.

## 0.1.0 (2024-03-28)

- The first release of the plugin, which installs Deno from its GitHub releases.
