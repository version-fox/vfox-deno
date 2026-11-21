# Already installed Deno

[中文](zh-CN/link.md) | [English](link.md)

If Deno is already on the machine — from the Deno install script, Cargo, Homebrew, asdf, mise, Scoop, winget, or somewhere on `PATH` — `vfox link --detect deno` adopts it instead of downloading another copy. It needs vfox 1.1.0 or later (`vfox --version`).

```bash
vfox link --detect deno
```

vfox lists what the plugin found and links the ones you pick. `vfox link --detect -y deno` links everything without asking. Afterwards `vfox use deno@<version>` works as usual, and `vfox list deno` marks linked versions with their folder:

```text
-> 2.7.0 (linked → /home/you/.deno/bin)
```

## What it finds

The plugin looks in these places, in this order:

- The Deno install script's folder: `$DENO_INSTALL/bin`, then `~/.deno/bin` (`%USERPROFILE%\.deno\bin` on Windows)
- Cargo: `~/.cargo/bin`
- Homebrew kegs: `opt/deno/bin` under `/opt/homebrew`, `/usr/local` and Linuxbrew
- asdf: each folder under `~/.asdf/installs/deno`
- mise: each folder under `~/.local/share/mise/installs/deno`, or under `$MISE_DATA_DIR`
- Windows only: Scoop's `current` folder (`%SCOOP%\apps\deno\current`, or `~\scoop\apps\deno\current`), the winget package folder that starts with `DenoLand.Deno`, and `%ProgramFiles%\Deno`
- Every absolute folder on `PATH`, which also covers the system directories such as `/usr/local/bin` and `/usr/bin`

Each folder counts only when it holds the `deno` executable (`deno.exe` on Windows) and that executable runs `deno --version`. A file that is not a working Deno is skipped.

vfox's own installs are never offered back: anything under a `.vfox` folder, and anything under the folder `VFOX_HOME` names.

## Names

Each install is named by its release number the way `vfox install` names it: `2.7.0`, or `2.2.0-rc.1` for a pre-release. The build metadata that `deno --version` prints after a plus sign is left out.

A version is listed once. When two places hold the same version, the first place in the list above wins, so the install script's copy is preferred over a copy on `PATH`.

## Removing a link

`vfox uninstall deno@<version>` on a linked version removes only the link. The Deno it points to stays where it was, so a Deno you installed by another tool is never deleted by vfox.

## Linking by hand

When the Deno you want is somewhere the plugin does not look, point vfox at its folder yourself. The folder is the one that holds the `deno` executable directly:

```bash
vfox link deno@2.7.0 /opt/deno/bin
vfox use --global deno@2.7.0
```

To point a version that is already linked at a different folder, add `--force`: `vfox link --force deno@2.7.0 <folder>`.
