# Versions

[中文](zh-CN/versions.md) | [English](versions.md)

A version is a Deno release number, such as `2.7.0`. The plugin accepts as much of the number as you need and installs the newest stable release that starts with what you typed.

## Writing a version

| You type                 | You get                                               |
| ------------------------ | ----------------------------------------------------- |
| `latest`                 | the newest stable release                             |
| `2`                      | the newest 2.x release                                |
| `2.7`                    | the newest 2.7.x release, such as `2.7.14`            |
| `2.7.0`                  | exactly 2.7.0                                         |
| `v2.7.0`                 | the same as `2.7.0`, with the `v` that tags carry     |
| `2.7.1`, `9.9.9`         | an error if no release with that number exists        |

A number is matched whole: `2.1` means 2.1.x, and `2.1.1` is never 2.1.10. Pre-releases such as `2.2.0-rc.1` are not in the list, so they cannot be installed by name here.

## Searching

```bash
vfox search deno
```

The list comes from the release headings in Deno's `Releases.md`, newest first. A release shows up there when Deno has finished it, so a release that was just tagged may take a little while to appear.

The list shows only the releases that have a download for your platform. Deno's archives start at a different release on each platform, and Deno published no archive for 1.10.0. So the list starts at 0.36.0 on Linux, macOS and Windows with x86_64, at 1.6.0 on macOS with arm64, at 1.40.3 on Linux with arm64, and at 2.6.8 on Windows with arm64. `vfox install` of a release that has no download says so, for example `Deno 0.35.0 has no download for linux/amd64: downloads for this platform start with 0.36.0`. See [platforms.md](platforms.md).

## Installing and using

```bash
vfox install deno@2.7.0
vfox list deno
vfox use --global deno@2.7.0
deno --version
vfox uninstall deno@2.7.0
```

An install is named after its release number, `2.7.0`. The `deno --version` output prints a longer string such as `deno 2.7.0+fb4db33`: the part after the plus sign is build metadata, and vfox does not put it in the name.

If the version is installed already, `vfox install` says so and downloads nothing, so `vfox install deno@v2.7.0` after `vfox install deno@2.7.0` is harmless.

## Checksums

Deno publishes a SHA-256 checksum file next to each archive, and the plugin passes its digest to vfox. vfox then checks the download before it unpacks it, and prints the digest:

```text
Verifying checksum f1ca687ba8545105ba5809688ef659d96fe4272acc11e8b4800657cdb0045b7d...
```

Releases that publish no checksum file install without verification. Deno answers `404` for such a file, as it does for Deno 1.46.3. The plugin says so, and vfox warns as well:

```text
Cannot verify the download: Deno publishes no checksum for deno-x86_64-unknown-linux-gnu.zip
WARNING: Checksum is not provided, skip verify...
```

Any other answer for the checksum file stops the install, and nothing is installed. That covers a file that cannot be fetched, an error status such as `503`, and a file that names no SHA-256 digest for this archive, such as one for another archive. The message begins with `Cannot verify the download:`, and running the install again is the way to retry. A download is never installed unverified because its checksum could not be read.

## Installed Deno from another source

A Deno that is already on the machine can be used as a version instead of a download, see [Already installed Deno](link.md).
