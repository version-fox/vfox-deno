# 平台

[中文](platforms.md) | [English](../platforms.md)

插件会为 vfox 运行所在的平台选择对应的 Deno 构建版本。每个构建版本的名称都是 Deno 自己的，它也正是 vfox 所下载的内容：

| 操作系统 | CPU             | Deno 构建版本                       | 说明                                                     |
| -------- | --------------- | ----------------------------------- | -------------------------------------------------------- |
| Linux    | x86_64（amd64） | `deno-x86_64-unknown-linux-gnu.zip` | glibc                                                    |
| Linux    | arm64           | `deno-aarch64-unknown-linux-gnu.zip` | glibc                                                   |
| macOS    | x86_64（amd64） | `deno-x86_64-apple-darwin.zip`      | 基于 Intel 的 Mac                                        |
| macOS    | arm64           | `deno-aarch64-apple-darwin.zip`     | Apple 芯片                                               |
| Windows  | x86_64（amd64） | `deno-x86_64-pc-windows-msvc.zip`   |                                                          |
| Windows  | arm64           | `deno-aarch64-pc-windows-msvc.zip`  | 自 Deno 2.6.8 起；更早的发布版本没有对应的构建版本       |

## 限制

- **没有 glibc 的 Linux。** Deno 的发布版本中没有 musl 构建，因此 Alpine 以及其他使用 musl 的系统不受支持。插件会在这些系统上安装 glibc 构建版本，它可能无法运行。
- **2.6.8 之前的 Windows arm64。** Deno 2.6.7 及更早版本没有 Windows arm64 构建版本，因此 GitHub 上没有对应的压缩包，vfox 的下载会失败。请改为安装 2.6.8 或更高版本；`vfox search deno` 会列出这些版本。
- **其他 CPU 和系统。** 插件会在下载任何内容之前停止运行，并显示 `Deno does not support <os> os` 或 `Deno does not support <arch> architecture`。

## 要求

插件需要 vfox 0.3.0 或更高版本。[已安装的 Deno](link.md) 需要 vfox 1.1.0 或更高版本，因为它使用了 vfox 1.1.0 新增的 `link --detect` 命令。端到端测试套件和离线测试使用 vfox 1.1.0，参见 [development.md](development.md)。
