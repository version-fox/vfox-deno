# 端到端测试

[中文](e2e.md) | [English](../e2e.md)

离线钩子测试（在 `vfox plugin test` 下运行的 `tests/*_test.lua`）用假的响应和假的目录来检查钩子。端到端测试套件则按用户实际接触插件的方式进行检查：它安装真正的 vfox，从 zip 添加插件，并通过用户会运行的命令驱动 `vfox`，所用的是 GitHub 上 Deno 的真实发布版本。

该套件是 `tests/e2e` 中的一个 Go 模块，只使用标准库。它直接在宿主机上原生运行，不使用容器。除非 `VFOX_BIN` 指向你已有的 vfox 二进制文件，否则测试会下载固定版本的 vfox 发布版本，并在运行其中任何内容之前检查它的 SHA-256 摘要。

## 持续集成中的运行

**E2E** 工作流（`.github/workflows/e2e.yml`）会在四个运行器上，于 `tests/e2e` 中运行 `go test -v -timeout 55m -run TestE2E ./...`：

| 运行器             | 平台          |
| ------------------ | ------------- |
| `ubuntu-latest`    | Linux amd64   |
| `ubuntu-26.04-arm` | Linux arm64   |
| `windows-latest`   | Windows amd64 |
| `windows-11-arm`   | Windows arm64 |

## 隔离

每次运行都会获得一个临时根目录，测试结束时会删除它：

- `VFOX_HOME` 是一个名称中包含空格的目录，就像 Windows 用户的主目录经常包含空格那样。
- `HOME` 和 `USERPROFILE` 指向一个假的主目录，`DENO_INSTALL` 指向它自己的目录。
- `PATH` 是固定的系统目录列表（Linux 上为 `/usr/bin:/bin`，Windows 上为 `C:\Windows\System32;C:\Windows`），因此宿主机上安装的 Deno 绝不会被意外找到。
- 激活 shell 时使用的变量（`__VFOX_*`）会被去掉，因为该套件从不激活 vfox。
- 其他一切都会被继承，因此代理、令牌和 `SYSTEMROOT` 依然有效。

子进程在根目录下的一个空工作目录中运行。每个 vfox 命令的时限为 15 分钟。

## 步骤

`TestE2E` 按顺序、在同一个隔离环境中运行以下步骤。每个步骤都是一个子测试，因此失败时会指出是哪一步，并显示 vfox 命令的输出。如果设置失败，整个运行会停止。之后不需要失败步骤结果的步骤仍会运行。

1. **设置。** 下载 vfox 并检查其固定的 SHA-256，或从 `VFOX_BIN` 获取。它的版本必须为 1.1.0 或更高。插件会从 `metadata.lua`、`hooks/` 和 `lib/` 打包成一个 zip，然后由 `vfox add deno --source` 添加。
2. **信息。** `vfox info deno` 会打印一个指向本 README 的链接。
3. **搜索。** `vfox search deno` 列出 2.7.0。
4. **最新的 2.x。** `vfox install deno@2` 安装最新的 2.x 发布版本。它的输出必须显示 `Verifying checksum` 并附带十六进制摘要，且不能出现 `Checksum is not provided`。然后 `vfox current deno` 必须报告该发布版本。vfox 只在某个版本正在使用时才报告当前版本，而该套件既不运行 `vfox use`，也不做 shell 激活。因此，该发布版本会写在工作目录的一个临时 `.vfox.toml` 中，该步骤随后会将其删除。
5. **固定的发布版本。** `vfox install deno@2.7.0` 安装 2.7.0，并验证校验和。通过 `vfox exec` 运行的 Deno 必须报告 2.7.0，允许 `+` 之后带构建元数据。它的可执行文件必须位于 `VFOX_HOME` 之内。在 Windows 上，命令是 `deno.exe`，因为 vfox 1.1.0 的 `exec` 在那里只按完整的文件名查找命令。
6. **前导 v。** `vfox install deno@v2.7.0` 以 0 退出，并且精确地指明 2.7.0，无论它是安装该发布版本还是发现它已安装。
7. **未知版本。** `vfox install deno@9.9.9` 以 `Could not resolve version` 失败。这个失败是预期的结果，因此该步骤不会重试。
8. **检测与链接。** 2.7.0 的二进制文件被复制到 `$DENO_INSTALL/bin`，并卸载 vfox 自己的副本。`vfox link --detect -y deno` 必须找到该副本并将其链接为 2.7.0，且输出中不能提及 `VFOX_HOME`。随后 `vfox list deno` 必须显示该链接，`vfox exec` 必须运行该副本，而 `vfox uninstall` 只能删除链接，并保留二进制文件。参见 [link.md](link.md)。
9. **清理。** 卸载仍然安装着的每个版本。这是尽力而为的：失败会被记录，临时根目录无论如何都会被删除。

## 重试

网络调用会被重试，因此一次瞬时失败不会导致整个运行失败：

- `vfox search`、`vfox install` 和 `vfox exec`（它会安装缺失的版本）在以非零代码退出时会被重试。vfox 自身的下载在传输错误以及应答不是 200 时会被重试。
- 每次失败的尝试的输出都会被记录。第一次失败后暂停 10 秒，第二次失败后暂停 20 秒，依此类推。
- `E2E_RETRY_ATTEMPTS` 设置尝试次数，默认为 3。如果该值不是至少为 1 的整数，运行会失败，因此拼写错误不会关闭重试。

步骤 7 是预期的失败，因此从不重试。

## 运行

在 `tests/e2e` 中，使用你已有的 vfox 1.1.0 二进制文件：

```bash
VFOX_BIN=/path/to/vfox go test -v -timeout 40m -run TestE2E ./...
```

如果没有设置 `VFOX_BIN`，会下载适用于宿主机的固定版本 vfox。固定版本覆盖 amd64 和 arm64 上的 Linux 与 Windows，其他宿主机需要设置 `VFOX_BIN`。

| 变量                 | 含义                                                       | 默认值       |
| -------------------- | ---------------------------------------------------------- | ------------ |
| `VFOX_BIN`           | 要测试的 vfox 二进制文件的绝对路径，代替下载的版本         | 固定版本的下载 |
| `E2E_RETRY_ATTEMPTS` | 每次网络调用的尝试次数，参见[重试](#重试)                  | `3`          |

模块的单元测试既不需要网络，也不需要 vfox，并且在 `-short` 下运行：

```bash
go test -short ./...
```

## 在临时容器中

在 Linux 上，干净的容器最接近全新的 CI 运行器。检出的代码以只读方式挂载，并在容器内复制一份，因此运行时不会向你的检出目录写入任何内容：

```bash
docker run --rm -v "$PWD:/repo:ro" golang:1.27.3 \
  bash -c 'cp -r /repo /work && cd /work/tests/e2e && go test -v -count=1 -timeout 40m -run TestE2E ./...'
```

[开发容器](development.md#开发容器) 拥有相同的 Go 和 vfox，也可以运行该套件。Windows 容器无法在这里运行，因此 E2E 工作流中的 Windows 作业是这些平台的检查手段。

## 编写步骤

新的检查项放入 `tests/e2e/e2e_test.go`，并按它必须运行的顺序排列。应检查 vfox 命令实际打印的输出，使用它实际打印的字符串，而不是猜测。当 Deno 打印的值带有构建元数据时，比较的是 `+` 之前的部分。该套件是仓库中唯一依赖网络的部分，因此请尽量减少它的请求，并且只重试那些可能因网络原因失败的请求。
