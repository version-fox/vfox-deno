# 开发

[中文](development.md) | [English](../development.md)

## 目录结构

```
metadata.lua                  plugin name, version, notes and minimum vfox version
hooks/available.lua           vfox search: the stable releases, from Deno's Releases.md
hooks/pre_install.lua         vfox install: resolves the version, the download and its SHA-256
hooks/post_install.lua        nothing to do: the archive unpacks to a folder with deno in it
hooks/env_keys.lua            PATH, the folder the install holds
hooks/pre_use.lua             vfox use: nothing to map, vfox selects the install
hooks/detect.lua              vfox link --detect: finds the Deno installs already on the machine
lib/util.lua                  release and download addresses, and the platform names Deno uses
lib/checksum.lua              reads the digest of a download from Deno's checksum file
lib/detect_deno.lua           the folders to search, and how a Deno is recognised and named
tests/*_test.lua              offline hook tests, run by vfox plugin test
tests/e2e/                    the end-to-end suite, a Go module (see e2e.md)
.devcontainer/                the dev container with the toolchain the workflows pin (see Dev container)
.github/workflows/            lint, license, test, e2e and the plugin release workflows
Injection.lua                 type hints for what vfox injects, never loaded
README.md, docs/              the documentation; README_CN.md and docs/zh-CN/ are the Chinese version
opencode.jsonc                lets OpenCode agent sessions in this repository run git push, gh pr create and gh pr comment without asking
```

vfox 会加载 `metadata.lua`，在某个命令需要时调用对应的钩子，并把 `PLUGIN` 和 `RUNTIME`（`osType`、`archType`、`version`）放入作用域。`osType` 和 `archType` 是 vfox 二进制文件的 Go `GOOS` 和 `GOARCH`，并由 `lib/util.lua` 映射为 Deno 的名称。

## 每条命令会运行什么

| 你运行的命令                     | 调用的钩子                                                                                 |
| -------------------------------- | ----------------------------------------------------------------------------------------- |
| `vfox search deno`               | `Available`                                                                               |
| `vfox install deno@2`            | `PreInstall` 返回版本、URL 和摘要。vfox 下载、校验并解压，然后调用 `PostInstall`          |
| `vfox use deno@2.7.0`            | `PreUse`（无需映射）。`EnvKeys` 把安装目录放入 `PATH`                                      |
| `vfox link --detect deno`        | `Detect` 返回机器上已有的 Deno 安装（`lib/detect_deno.lua`）                               |

有几条约定，找起来很费时间：

- `PreInstall` 返回 `version` 和 `url`，如果校验和文件给出了摘要，还会返回 `sha256`。vfox 会把摘要与下载的内容进行比较，因此键名必须正好是小写的 `sha256`，前后不能有其他内容。`lib/checksum.lua` 能读取 Deno 发布的两种形式：sha256sum 的 `<digest>  <name>`（Linux 和 macOS），以及 PowerShell 的 Get-FileHash 中的 `Algorithm`、`Hash` 和 `Path` 行（Windows）。它会把摘要转为小写；如果无法确定该摘要，则不返回任何内容，并给出原因。
- 只有 404 的校验和文件才会让安装在没有摘要的情况下继续，并打印一条说明：有些发布版本（例如 Deno 1.46.3）不发布校验和文件。其他任何回应都必须为此构建给出摘要。无法获取文件、错误状态，或文件中没有为该压缩包注明摘要，都会引发错误，因此安装会停止，下载的内容绝不会在未经校验的情况下被安装。
- `version` 会成为安装版本的名称，因此它是不带 `v` 且不带构建元数据的发布版本号。`PreInstall` 接受开头的 `v`，例如 `v2.7.0`。
- 版本按整体编号匹配：`2.1` 会匹配 `2.1.10`，`2.1.1` 则不会。`Available` 按从新到旧的顺序返回列表，`latest` 是列表中的第一项。
- `Detect` 返回 `{ version, path, note }` 的列表。`path` 是直接包含 `deno` 可执行文件的目录，这正是 `EnvKeys` 放入 `PATH` 的内容。版本即 `deno --version` 所打印的内容，但不包括加号之后的构建元数据。
- `EnvKeys` 只设置 `PATH`。Deno 不需要其他变量。
- `PreUse` 和 `PostInstall` 不做任何事。它们作为插件中有文档说明的扩展点保留下来。

## 修改钩子

1. 修改 `hooks/` 或 `lib/` 中的钩子或其库，并让 `hooks/detect.lua`、`lib/detect_deno.lua` 及其测试保持同步。
2. 在 `tests/` 中编写或更新离线测试。每个测试文件都从 `vfox.test` 调用一次 `test.load()`，并通过其返回值调用真正的钩子，例如 `plugin:PreInstall({ version = "2" })`。
3. 运行下面的检查。CI 运行的是同样的命令。
4. 对于必须让 vfox 端到端看到的变更（例如新消息、新的文件布局），请在端到端测试套件中添加一个步骤（[e2e.md](e2e.md)）。

## 测试

离线钩子测试通过 `vfox plugin test` 运行。CI 使用其固定的发布版本 vfox 1.1.0 来运行它们。该命令会找到每个 `tests/**/*_test.lua` 文件，并在各自独立的虚拟机中运行每个文件：

```bash
vfox plugin test .
vfox plugin test . --file tests/detect_test.lua
```

请在仓库根目录下运行它。该虚拟机会禁用 `io.popen` 和 `os.execute`。因此，检测测试会用描述目录、文件以及每个 `deno --version` 输出内容的表，替换 `os.getenv`、`io.open` 和 `io.popen`，所以它们绝不会接触真正的 Deno。`test.load` 接受平台（`os`、`arch`）作为参数，并且可以修改 `RUNTIME.osType` 来尝试另一种平台，正如 Windows 和 macOS 的测试用例所做的那样。`http` 选项会应答 `Available` 和 `PreInstall` 发出的请求，因此没有任何测试需要网络。

## 开发容器

`.devcontainer/` 构建一个 Linux 开发环境，装有工作流固定的工具链：端到端测试套件使用的 Go 1.27.3，以及 stylua 2.5.2、lua-language-server 3.19.1、vfox 1.1.0、skywalking-eyes 0.9.0 和 actionlint 1.7.12。`.devcontainer/install-tools.sh` 会用 GitHub 为每个下载文件发布的 SHA-256 摘要进行校验。

用任何 Dev Containers 工具打开该目录即可，例如 VS Code 中的 **Dev Containers: Reopen in Container**；也可以自行构建镜像，并在容器中运行检查：

```bash
docker build -t vfox-deno-dev .devcontainer
docker run --rm -v "$PWD:/work" -w /work vfox-deno-dev bash -c 'stylua --check . && vfox plugin test .'
```

该镜像是多架构的，可以在 linux/amd64 和 linux/arm64 主机上运行。端到端测试套件也能在其中运行，见 [e2e.md](e2e.md)。

## 检查

以下是 Lint、License 和测试工作流中的命令。每一条都可以在本地机器上以相同的方式运行，并使用 CI 所固定的版本：stylua 2.5.2、LuaLS 3.19.1、skywalking-eyes 0.9.0 和 actionlint 1.7.12。

```bash
# Lua 格式化与静态分析（.github/workflows/lint.yml）。
stylua --check .
lua-language-server --check . --checklevel=Warning

# Go 的格式化、vet，以及 e2e 模块的单元测试（.github/workflows/lint.yml）。
cd tests/e2e
test -z "$(gofmt -l .)"
go vet ./...
go test -short ./...
cd ../..

# 离线钩子测试（.github/workflows/test.yml）。
vfox plugin test .

# 许可证头（.github/workflows/license.yml）。仅需 Docker，使用 CI 所用的镜像。
docker run --rm -v "$PWD:/work" -w /work apache/skywalking-eyes:0.9.0 header check

# 工作流文件（lint 工作流中的 lint-workflows 任务）。
docker run --rm -v "$PWD:/repo" -w /repo rhysd/actionlint:1.7.12 -color
```

`stylua` 和 `lua-language-server` 也可以通过 Docker 运行，或使用它们的发布压缩包运行。许可证头部检查会读取 `.licenserc.yaml`，它要求每个 Lua、Go、YAML、TOML 和 JSONC 文件中都包含文本 `Copyright 2026 Han Li and contributors` 以及 Apache 2.0 声明。JSON、Markdown 和 `go.sum` 不在检查范围内。

## 持续集成

| 工作流          | 文件                            | 检查内容                                                                       |
| --------------- | ------------------------------- | ------------------------------------------------------------------------------ |
| Lint            | `lint.yml`                      | `tests/e2e` 的 gofmt、go vet 和单元测试；stylua；LuaLS；actionlint            |
| License         | `license.yml`                   | 使用 SkyWalking Eyes 检查许可证头部                                            |
| Test Plugin     | `test.yml`                      | 使用固定的 vfox 1.1.0 运行离线钩子测试                                         |
| E2E             | `e2e.yml`                       | 在 Ubuntu（amd64、arm64）和 Windows（amd64、arm64）上运行端到端测试套件       |
| Plugin          | `publish.yaml`                  | 拉取请求上的共享检查，以及推送标签或手动运行时进行的发布                       |

## 固定的工具版本

每个版本都写在使用它的工作流和开发容器中。修改某个版本时，请同时改掉所有这些位置，以及本表。

| 工具                | 版本    | 固定位置                                                                |
| ------------------- | ------- | ----------------------------------------------------------------------- |
| vfox                | 1.1.0   | `test.yml`（连同其 SHA-256）、`tests/e2e/vfox.go` 和 `.devcontainer/`   |
| Go                  | 1.27.3  | `lint.yml`、`e2e.yml` 和 `.devcontainer/Dockerfile`                     |
| stylua              | 2.5.2   | `lint.yml` 和 `.devcontainer/install-tools.sh`                          |
| lua-language-server | 3.19.1  | `lint.yml` 和 `.devcontainer/install-tools.sh`                          |
| skywalking-eyes     | 0.9.0   | `license.yml` 和 `.devcontainer/install-tools.sh`                       |
| actionlint          | 1.7.12  | `lint.yml` 和 `.devcontainer/install-tools.sh`                          |
| 被测试的 Deno       | 2.7.0   | `tests/e2e/e2e_test.go`                                                 |

## 发布

维护者可以在默认分支上通过 **Actions → Plugin → Run workflow** 进行发布，输入一个不带 `v` 前缀的稳定版插件版本号。共享工作流 [plugin-manifest-action](https://github.com/version-fox/plugin-manifest-action) 会更新 `metadata.lua`，创建版本提交和标签，并在本仓库中发布 ZIP 文件和清单。无需本地标签，也无需额外的发布令牌。拉取请求只运行检查。

推送版本标签同样会发布，前提是 `PLUGIN.version` 已与该标签匹配。如果发布失败，请重新运行失败的任务以恢复发布。

### 发布之后

文档会把比上一次发布更新的内容标记为“未发布”（英文版中为“Unreleased”）。发布完成后，请把 [changes.md](changes.md) 中的这些条目移到新版本之下，并写上发布日期，两种语言都要修改。

## 编写文档

英文页面位于 `docs/` 中，中文页面位于 `docs/zh-CN/` 中，文件名相同（中文 README 为 `README_CN.md`）。每个页面开头都有一个指向另一种语言版本的链接。新页面应加入两个 README 的“文档”列表中。

要从压缩包中试用插件的某个分支，请打包端到端测试套件所打包的相同文件，并使用 `vfox add` 注册它们：

```bash
zip -r /tmp/deno-plugin.zip metadata.lua hooks lib
vfox add deno --source /tmp/deno-plugin.zip
```
