# Troubleshooting

[中文](zh-CN/troubleshooting.md) | [English](troubleshooting.md)

The messages below are what the plugin and vfox print. Each one says what happened and what to do; `vfox --debug <command>` shows more of what vfox does with the plugin.

## Choosing a version

**`Could not resolve version: 9.9.9`**

No stable release starts with what you typed. Run `vfox search deno` for the list. Pre-releases are not in it, see [versions.md](versions.md).

**`No version given, for example: vfox install deno@2`**

The version was empty. Name one, such as `latest` or `2`.

## Reaching GitHub

The releases list and the downloads come from GitHub.

**`Failed to fetch Deno releases from https://raw.githubusercontent.com/denoland/deno/main/Releases.md: ...`**

The plugin could not read the list of releases. Check that `raw.githubusercontent.com` is reachable from your network, and run the command again; the request may have timed out.

**`Failed to fetch Deno releases: HTTP 503`**

GitHub answered with an error status. Try again later.

**`No Deno versions found in ...; the upstream response may have changed`**

The release list was read, but no release heading in it could be parsed. This means Deno changed the format of its `Releases.md`. Please report it, with the output of `vfox --debug search deno`.

## Downloads and checksums

**`Verifying checksum <digest>...`**

Not a problem: vfox has the SHA-256 digest of the archive and checks the download against it before it unpacks anything.

**`Cannot verify the download: Deno publishes no checksum for <archive>`**

The release has no checksum file, as Deno 1.46.3 has none. The install goes on without verification, and vfox adds `WARNING: Checksum is not provided, skip verify...`. Nothing is wrong with the install.

**`Cannot verify the download: could not fetch <address>: ...`**, **`Cannot verify the download: HTTP <status> from <address>`** or **`Cannot verify the download: <reason> (<address>)`**

The checksum file could not be fetched, answered with an error, or names no SHA-256 digest for this archive. The install stops and nothing is installed. Try again later. If it keeps happening, report it with the full output, because a file that names another archive can mean Deno changed how it publishes checksums.

**`HTTP 404` while vfox downloads the archive**

GitHub has no archive for this Deno release on your platform. The usual cause is Windows arm64 with a release before 2.6.8. See [platforms.md](platforms.md) and install a newer release.

**`Checksum error`**

The archive that arrived is not the one Deno published, so vfox stopped the install and installed nothing. Run the command again. If it fails the same way, the download may have been altered on the way, so do not use that copy; report it.

## Platforms

**`Deno does not support <os> os`** or **`Deno does not support <arch> architecture`**

The plugin has no Deno build for this platform, and it stops before downloading anything. See [platforms.md](platforms.md).

## Already installed Deno

**`the plugin cannot detect SDKs installed elsewhere`**

Your vfox is older than 1.1.0, which is the first to offer `vfox link --detect`. Upgrade vfox, then run the command again.

**`vfox use deno@<version>` picks a different Deno from the one you expect**

The `deno` on your `PATH` comes from the first folder in `PATH` that holds it. Run `vfox current deno` to see what vfox selected, and check that vfox is hooked into your shell (see the [quick start](https://vfox.dev/guides/quick-start.html)). `vfox link --detect deno` lists the Deno installs the plugin found, see [link.md](link.md).
