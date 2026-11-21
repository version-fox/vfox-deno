# Platforms

[中文](zh-CN/platforms.md) | [English](platforms.md)

The plugin picks the Deno build for the platform vfox runs on. The name of each build is Deno's own, and it is what vfox downloads:

| Operating system | CPU            | Deno build                          | Notes                                                    |
| ---------------- | -------------- | ----------------------------------- | -------------------------------------------------------- |
| Linux            | x86_64 (amd64) | `deno-x86_64-unknown-linux-gnu.zip` | glibc                                                    |
| Linux            | arm64          | `deno-aarch64-unknown-linux-gnu.zip` | glibc                                                   |
| macOS            | x86_64 (amd64) | `deno-x86_64-apple-darwin.zip`      | Intel Macs                                               |
| macOS            | arm64          | `deno-aarch64-apple-darwin.zip`     | Apple silicon                                            |
| Windows          | x86_64 (amd64) | `deno-x86_64-pc-windows-msvc.zip`   |                                                          |
| Windows          | arm64          | `deno-aarch64-pc-windows-msvc.zip`  | from Deno 2.6.8; older releases have no build for it     |

## Limits

- **Linux without glibc.** Deno's releases contain no musl build, so Alpine and other musl systems are not supported. The plugin installs the glibc build there, which may not run.
- **Older releases.** Deno's archives for a platform start at a release that depends on the platform: 0.36.0 on x86_64 Linux, macOS and Windows, 1.6.0 on macOS arm64, 1.40.3 on Linux arm64 and 2.6.8 on Windows arm64. Deno 1.10.0 has no archive on any platform. `vfox search deno` leaves the earlier releases out, and `vfox install` of one stops with the reason before it downloads anything. Install a release from the list instead.
- **Other CPUs and systems.** The plugin stops with `Deno does not support <os> os` or `Deno does not support <arch> architecture` before it downloads anything.

## Requirements

The plugin needs vfox 0.3.0 or later. [Already installed Deno](link.md) needs vfox 1.1.0 or later, because it uses the `link --detect` command that vfox 1.1.0 added. The end-to-end suite and the offline tests use vfox 1.1.0, see [development.md](development.md).
