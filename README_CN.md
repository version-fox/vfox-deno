# vfox-deno

[中文](README_CN.md) | [English](README.md)

[vfox](https://vfox.dev/) 的 Deno 插件。

它从 [denoland/deno](https://github.com/denoland/deno) 的 GitHub 发布版本中安装 Deno，在 Deno 发布了 SHA-256 校验和的情况下，用它来校验每次下载的内容；它还可以采用机器上已经存在的 Deno，而不必再下载一份副本。

## 安装

安装 [vfox](https://github.com/version-fox/vfox) 之后，添加插件、安装一个 Deno 并选中它：

```bash
vfox add deno
vfox install deno@2
vfox use --global deno@2
deno --version
```

`deno --version` 显示当前选中的 Deno。要让 `deno` 位于 `PATH` 中，必须把 vfox 接入你的 shell，参见其[快速入门](https://vfox.dev/guides/quick-start.html)。

`vfox search deno` 会列出稳定发布版本，最新的排在最前面。

## 版本

版本就是 Deno 的发布版本号。你可以只写所需的那一部分；插件会选取以你输入的内容开头的最新发布版本：

```bash
vfox install deno@latest       # 最新的稳定版
vfox install deno@2            # 最新的 2.x
vfox install deno@2.7          # 最新的 2.7.x
vfox install deno@2.7.0        # 恰好是 2.7.0
vfox install deno@v2.7.0       # 同上，带有标签中常见的 v 前缀
```

预发布版本不会被列出，因此这里无法按名称安装它们。关于安装、使用、搜索以及安装后的名称，参见 [docs/zh-CN/versions.md](docs/zh-CN/versions.md)。

## 平台

| 操作系统 | CPU                    | Deno 构建版本                        |
| -------- | ---------------------- | ----------------------------------- |
| Linux    | x86_64、arm64          | `unknown-linux-gnu`（glibc）        |
| macOS    | x86_64（Intel）、arm64 | `apple-darwin`                      |
| Windows  | x86_64、arm64          | `pc-windows-msvc`（2.6.8 起支持 arm64） |

不支持其他操作系统和 CPU。关于各个构建版本、每个构建版本首次出现的版本以及限制，参见 [docs/zh-CN/platforms.md](docs/zh-CN/platforms.md)。

## 已安装的 Deno

如果机器上已经有 Deno（来自 Deno 安装脚本、Cargo、Homebrew、asdf、mise、Scoop、winget，或 `PATH` 中的某个位置），`vfox link --detect deno` 会采用它，而不是再下载一份。它需要 vfox 1.1.0 或更高版本。关于它查找的位置、它为安装的版本取什么名称，以及如何手动链接，参见 [docs/zh-CN/link.md](docs/zh-CN/link.md)。

## 文档

**使用插件**

- [版本](docs/zh-CN/versions.md)：如何书写版本，以及安装、使用、搜索和安装后的名称
- [平台](docs/zh-CN/platforms.md)：各操作系统和 CPU 分别有哪些构建版本，以及从哪个版本开始提供
- [已安装的 Deno](docs/zh-CN/link.md)：用 `vfox link --detect deno` 采用机器上的 Deno
- [故障排除](docs/zh-CN/troubleshooting.md)：插件输出的消息，以及对应的处理方法
- [变更记录](docs/zh-CN/changes.md)：每个发布版本改了什么

**开发插件**

- [开发](docs/zh-CN/development.md)：插件如何工作，如何修改、测试和发布它
- [E2E 测试](docs/zh-CN/e2e.md)：在 Ubuntu 和 Windows 上运行的端到端测试套件

## 发布本插件

维护者可以在默认分支上通过 **Actions → Plugin → Run workflow** 进行发布，输入一个不带 `v` 前缀的稳定版插件版本号。共享工作流会更新 `metadata.lua`，创建版本提交和标签，并在本仓库中发布 ZIP 文件和清单。无需本地标签，也无需额外的发布令牌。拉取请求只运行检查；PR 标题不再触发发布。

已有版本标签的推送受支持，前提是 `PLUGIN.version` 已与该标签匹配。如果发布失败，重新运行原先失败的任务即可继续。

该工作流跟随共享发布工具的 `@v1` 版本。更新该工具本身不会发布本插件。关于包约定和首次推出时的要求，参见[共享工作流文档](https://github.com/version-fox/plugin-manifest-action)。

## 致谢

- [Deno](https://deno.com/)，本插件安装的正是它的发布版本
- [vfox](https://github.com/version-fox/vfox)，本插件所扩展的版本管理工具
