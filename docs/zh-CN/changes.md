# 变更记录

[中文](changes.md) | [English](../changes.md)

以下记录每个发布版本的变更，按用户所能察觉到的方式描述。GitHub 的发布页面会列出拉取请求。

## 未发布

- 在 Linux 和 macOS 上，`vfox install` 解压压缩包后会为 `deno` 设置可执行位。Deno 0.36.0 的 Linux 压缩包没有设置该位，因此 `vfox exec deno@0.36.0 -- deno --version` 曾以 `permission denied` 失败；现在它会打印 `deno 0.36.0`。此变更之前完成的安装仍然没有该位，参见 [troubleshooting.md](troubleshooting.md)。

## 0.2.2 (2026-11-21)

- `vfox search deno` 只列出在你的平台上有下载的发布版本。此前列表中包含没有下载的发布版本：在 x86_64 的 Linux 上，380 个中有 71 个；在 arm64 的 Windows 上，有 349 个。对于其中的版本，`vfox install` 会说明原因，而不是在下载时失败。
- `vfox link --detect deno` 会采用机器上已有的 Deno，而不是再下载一份：检查的位置包括 Deno 安装脚本的目录、Cargo、Homebrew、asdf、mise、Windows 上的 Scoop 和 winget、Program Files，以及 `PATH` 中的每个目录。它需要 vfox 1.1.0 或更高版本。参见 [link.md](link.md)。
- 每次下载都会与 Deno 在其旁边发布的 SHA-256 摘要进行核对，vfox 会打印它所核对的摘要。没有校验和文件的发布版本（例如 Deno 1.46.3）会安装，并附带一条说明，表示无法校验。如果校验和文件无法获取，或没有注明摘要，安装则会停止，因此不会有任何内容在未经校验的情况下被安装。
- `vfox info deno` 会显示指向本 README 的链接，其中说明了用法。
- 文档同时提供英文和中文版本，并包括插件各部分以及端到端测试套件的指南。

## 0.2.1 (2026-09-12)

- 当无法读取 Deno 的发布版本列表时，插件会报告失败，并附上它所请求的地址，而不是因 nil 值而崩溃。

## 0.2.0 (2025-09-29)

- `vfox install deno@2` 会安装最新的 2.x 发布版本，`vfox install deno@2.7` 会安装最新的 2.7.x 发布版本。
- 与任何发布版本都不匹配的版本会以 `Could not resolve version: <version>` 失败。如果某个精确的发布版本同样能被某个前缀匹配，则优先选择该精确版本。

## 0.1.1 (2024-04-01)

- 持续集成已更新。

## 0.1.0 (2024-03-28)

- 插件的首个发布版本，用于从 GitHub 发布版本中安装 Deno。
