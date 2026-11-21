# 版本

[中文](versions.md) | [English](../versions.md)

版本是 Deno 的发布版本号，例如 `2.7.0`。插件接受你所需要的那部分版本号，并安装以你输入的内容开头的最新稳定发布版本。

## 如何书写版本

| 你输入                   | 你得到                                                |
| ------------------------ | ----------------------------------------------------- |
| `latest`                 | 最新的稳定发布版本                                    |
| `2`                      | 最新的 2.x 发布版本                                   |
| `2.7`                    | 最新的 2.7.x 发布版本，例如 `2.7.14`                  |
| `2.7.0`                  | 正好是 2.7.0                                          |
| `v2.7.0`                 | 与 `2.7.0` 相同，带有标签所用的 `v`                   |
| `2.7.99`、`9.9.9`        | 如果不存在该编号的发布版本，则报错                    |

编号按整体匹配：`2.1` 表示 2.1.x，而 `2.1.1` 绝不会匹配到 2.1.10。预发布版本（例如 `2.2.0-rc.1`）不在列表中，因此这里无法按名称安装。

## 搜索

```bash
vfox search deno
```

列表来自 Deno 的 `Releases.md` 中的发布版本标题，从新到旧排列。Deno 完成某个发布版本之后，该版本才会出现在列表中，因此刚刚打上标签的发布版本可能需要一点时间才会出现。

列表只包含在你的平台上有下载的发布版本。Deno 为各平台提供压缩包的起始发布版本各不相同，而 Deno 从未为 1.10.0 发布压缩包。因此，列表在 x86_64 的 Linux、macOS 和 Windows 上从 0.36.0 开始，在 arm64 的 macOS 上从 1.6.0 开始，在 arm64 的 Linux 上从 1.40.3 开始，在 arm64 的 Windows 上从 2.6.8 开始。对于没有下载的发布版本，`vfox install` 会说明原因，例如 `Deno 0.35.0 has no download for linux/amd64: downloads for this platform start with 0.36.0`。参见 [platforms.md](platforms.md)。

## 安装与使用

```bash
vfox install deno@2.7.0
vfox list deno
vfox use --global deno@2.7.0
deno --version
vfox uninstall deno@2.7.0
```

安装的版本以其发布版本号 `2.7.0` 命名。`deno --version` 的输出会显示更长的字符串，例如 `deno 2.7.0+fb4db33`：加号之后的部分是构建元数据，vfox 不会把它放入名称中。

如果该版本已经安装，`vfox install` 会提示这一点且不会下载任何内容，因此在执行 `vfox install deno@2.7.0` 之后再执行 `vfox install deno@v2.7.0` 是无害的。

## 校验和

Deno 会在每个压缩包旁边发布一个 SHA-256 校验和文件，插件会把摘要传给 vfox。vfox 随后会在解压之前检查下载的内容，并打印该摘要：

```text
Verifying checksum f1ca687ba8545105ba5809688ef659d96fe4272acc11e8b4800657cdb0045b7d...
```

没有发布校验和文件的发布版本会在未经校验的情况下安装。Deno 对这类文件返回 `404`，例如 Deno 1.46.3。插件会说明这一点，vfox 也会发出警告：

```text
Cannot verify the download: Deno publishes no checksum for deno-x86_64-unknown-linux-gnu.zip
WARNING: Checksum is not provided, skip verify...
```

除此之外，对校验和文件的任何其他回应都会让安装停止，且不会安装任何内容。这包括无法获取的文件、`503` 之类的错误状态，以及没有为该压缩包注明 SHA-256 摘要的文件（例如注明的是另一个压缩包）。提示信息以 `Cannot verify the download:` 开头，重新运行安装即可再试一次。绝不会因为校验和无法读取，就安装一份未经校验的下载。

## 来自其他来源的已安装 Deno

机器上已有的 Deno 可以作为一个版本使用，而不必下载，参见[已安装的 Deno](link.md)。
