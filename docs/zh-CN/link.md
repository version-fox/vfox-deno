# 已安装的 Deno

[中文](link.md) | [English](../link.md)

如果机器上已经有 Deno（来自 Deno 安装脚本、Cargo、Homebrew、asdf、mise、Scoop、winget，或 `PATH` 中的某个位置），`vfox link --detect deno` 会采用它，而不是再下载一份。它需要 vfox 1.1.0 或更高版本（可用 `vfox --version` 查看）。

```bash
vfox link --detect deno
```

vfox 会列出插件找到的 Deno，并链接你选择的那些。`vfox link --detect -y deno` 会不经询问地链接所有找到的 Deno。之后，`vfox use deno@<version>` 照常工作，`vfox list deno` 会用所在目录标记已链接的版本：

```text
-> 2.7.0 (linked → /home/you/.deno/bin)
```

## 查找范围

插件会按以下顺序在这些位置查找：

- Deno 安装脚本的目录：先是 `$DENO_INSTALL/bin`，然后是 `~/.deno/bin`（Windows 上为 `%USERPROFILE%\.deno\bin`）
- Cargo：`~/.cargo/bin`
- Homebrew 的 keg：位于 `/opt/homebrew`、`/usr/local` 和 Linuxbrew 之下的 `opt/deno/bin`
- asdf：`~/.asdf/installs/deno` 下的每个目录
- mise：`~/.local/share/mise/installs/deno` 下的每个目录；设置了 `MISE_DATA_DIR` 时，还包括 `$MISE_DATA_DIR/installs/deno` 下的每个目录
- 仅限 Windows：Scoop 的 `current` 目录（`%SCOOP%\apps\deno\current`，或 `~\scoop\apps\deno\current`）、以 `DenoLand.Deno` 开头的 winget 包目录，以及 `%ProgramFiles%\Deno`
- `PATH` 中每个绝对路径的目录，其中也包括 `/usr/local/bin` 和 `/usr/bin` 等系统目录

只有当某个目录中包含 `deno` 可执行文件（Windows 上为 `deno.exe`），并且该可执行文件能够运行 `deno --version` 时，这个目录才会被计入。不是可用 Deno 的文件会被跳过。

vfox 自身的安装永远不会被当作可链接的 Deno 提供出来：位于 `.vfox` 目录下的任何内容，以及位于 `VFOX_HOME` 所指定目录下的任何内容，都不会被提供。

## 名称

每个安装的版本都按照 `vfox install` 的命名方式，以其发布版本号命名，即 `2.7.0`，预发布版本则为 `2.2.0-rc.1`。`deno --version` 在加号之后打印的构建元数据会被省略。

每个版本只会列出一次。当两个位置包含同一版本时，以上面列表中靠前的位置为准，因此 Deno 安装脚本中的副本会优先于 `PATH` 中的副本。

## 删除链接

对已链接的版本执行 `vfox uninstall deno@<version>`，只会删除该链接。链接所指向的 Deno 会保留在原处，因此你用其他工具安装的 Deno 永远不会被 vfox 删除。

## 手动链接

如果你想使用的 Deno 位于插件不会查找的位置，请自行让 vfox 指向它所在的目录。该目录是直接包含 `deno` 可执行文件的那个目录：

```bash
vfox link deno@2.7.0 /opt/deno/bin
vfox use --global deno@2.7.0
```

要让已经链接的版本指向另一个目录，请添加 `--force`：`vfox link --force deno@2.7.0 <folder>`。
