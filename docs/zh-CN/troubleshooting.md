# 故障排除

[中文](troubleshooting.md) | [English](../troubleshooting.md)

以下消息是插件和 vfox 打印的内容。每条消息都会说明发生了什么以及该怎么做；`vfox --debug <command>` 会显示 vfox 对插件所做操作的更多细节。

## 选择版本

**`Could not resolve version: 9.9.9`**

没有稳定发布版本以你输入的内容开头。运行 `vfox search deno` 查看列表。列表中不包含预发布版本，参见 [versions.md](versions.md)。

**`Deno 0.0.0 has no download for linux/amd64: downloads for this platform start with 0.36.0`**

该发布版本在你的平台上没有压缩包，因此 vfox 无法安装它。消息会说明下载从哪个版本开始，或说明 Deno 没有为该发布版本发布压缩包（例如 1.10.0）。运行 `vfox search deno` 查看有压缩包的发布版本，参见 [platforms.md](platforms.md)。

**`No version given, for example: vfox install deno@2`**

版本为空。请指定一个版本，例如 `latest` 或 `2`。

## 访问 GitHub

发布版本列表和下载内容都来自 GitHub。

**`Failed to fetch Deno releases from https://raw.githubusercontent.com/denoland/deno/main/Releases.md: ...`**

插件无法读取发布版本列表。请检查你的网络能否访问 `raw.githubusercontent.com`，然后重新运行该命令；请求也可能已超时。

**`Failed to fetch Deno releases: HTTP 503`**

GitHub 返回了错误状态。请稍后再试。

**`No Deno versions found in ...; the upstream response may have changed`**

发布版本列表已被读取，但其中没有任何发布版本标题能够被解析。这意味着 Deno 更改了其 `Releases.md` 的格式。请报告该问题，并附上 `vfox --debug search deno` 的输出。

## 下载与校验和

**`Verifying checksum <digest>...`**

这不是问题：vfox 已经拿到了压缩包的 SHA-256 摘要，并会在解压任何内容之前用它检查下载的内容。

**`Cannot verify the download: Deno publishes no checksum for <archive>`**

该发布版本没有校验和文件，Deno 1.46.3 即是如此。安装会在没有校验的情况下继续，并且 vfox 会添加 `WARNING: Checksum is not provided, skip verify...`。安装本身没有问题。

**`Cannot verify the download: could not fetch <address>: ...`**、**`Cannot verify the download: HTTP <status> from <address>`** 或 **`Cannot verify the download: <reason> (<address>)`**

校验和文件无法获取、回应了错误，或者没有为该压缩包注明 SHA-256 摘要。安装会停止，且不会安装任何内容。请稍后再试。如果问题持续出现，请连同完整输出一并报告，因为注明的是另一个压缩包的文件，可能意味着 Deno 改变了发布校验和的方式。

**vfox 下载压缩包时出现 `HTTP 404`**

GitHub 上没有该 Deno 发布版本在你所用平台上的压缩包，而插件在列出该版本时并不知道这一点。除非插件已知 Deno 在该平台上没有压缩包，否则它会列出该版本，因此这是插件尚未掌握的缺口。请安装另一个发布版本，并附上 `vfox --debug install deno@<version>` 的输出报告该问题。各平台有下载的起始发布版本参见 [platforms.md](platforms.md)。

**`Checksum error`**

收到的压缩包不是 Deno 发布的那个，因此 vfox 停止了安装，且没有安装任何内容。请重新运行该命令。如果仍然以同样的方式失败，下载内容可能在传输途中被改动，此时请不要使用那份副本，并报告该问题。

**`fork/exec <path>/deno: permission denied`**

有些发布版本的压缩包没有为 `deno` 设置可执行位，例如 x86_64 Linux 上的 Deno 0.36.0。插件会在解压压缩包后设置该位，因此只有在此之前完成的安装仍然没有它。请使用 `vfox uninstall deno@<版本>` 和 `vfox install deno@<版本>` 重新安装该发布版本，或对消息中指出的文件运行 `chmod +x <路径>`。

## 平台

**`Deno does not support <os> os`** 或 **`Deno does not support <arch> architecture`**

插件没有适用于该平台的 Deno 构建版本，并会在下载任何内容之前停止运行。参见 [platforms.md](platforms.md)。

## 已安装的 Deno

**`the plugin cannot detect SDKs installed elsewhere`**

你的 vfox 版本低于 1.1.0，而该版本是第一个提供 `vfox link --detect` 的版本。请升级 vfox，然后重新运行该命令。

**`vfox use deno@<version>` 选中的 Deno 与你预期的不同**

你的 `PATH` 中的 `deno` 来自 `PATH` 里第一个包含它的目录。运行 `vfox current deno` 查看 vfox 选中了哪个版本，并检查 vfox 是否已接入你的 shell（参见[快速入门](https://vfox.dev/guides/quick-start.html)）。`vfox link --detect deno` 会列出插件找到的 Deno 安装，参见 [link.md](link.md)。
