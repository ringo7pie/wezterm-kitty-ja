# wezterm-kitty-ja

![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)
![Platform: Windows](https://img.shields.io/badge/platform-Windows-0078D6.svg)
![WezTerm](https://img.shields.io/badge/WezTerm-20240203%2B-4E49EE.svg)
![PowerShell](https://img.shields.io/badge/PowerShell-7%20%2F%205.1-5391FE.svg)

A WezTerm configuration for Windows that makes [WezTerm](https://wezterm.org/) behave like
[kitty](https://sw.kovidgoyal.net/kitty/) with the kitty-ja-shortcuts add-on: the same key bindings,
a Japanese command palette, and per-folder tab memory.
It is a Lua configuration module (`kitty_ja`) plus an installer that is safe to run and safe to undo.

日本語: [README.md](README.md)

> The user interface strings (command names, installer messages) and most of the documentation under `docs/` are in Japanese.

## Features

- **kitty-compatible key bindings** — bound by physical key (`phys:`), so they land on the same key positions on JIS keyboards.
- **Command palette** (Ctrl+Shift+F12) — searchable by Japanese name, romaji (`tabu`, `pein`) or English (`new_tab`).
  WezTerm's selection UI cannot receive IME input, so romaji and English search terms are provided.
- **Tab colors and per-folder memory** — Ctrl+Shift+Alt+digit switches the tab color; tab name and color are remembered per folder.
- **Session restore** — tabs, pane splits, folders, names and colors come back on the next launch.
  Running programs and the screen contents are not restored.
- **Scrollback in Notepad++** (Ctrl+Shift+E, also Ctrl+Alt+Shift+F12) — writes the screen and scrollback to
  `%TEMP%\wezterm-history-<timestamp>-pane-<id>.txt` and opens it in Notepad++. This replaces kitty's Ctrl+Shift+E
  ("open URL with hints"), which stays available from the palette. The history file is **not** deleted automatically.
- **Safe defaults** — text printed in a terminal (from an ssh host or a displayed file) can only make the configuration open
  a restricted set of targets: http(s) URLs and existing non-executable files on local drives. Executable types and network paths are refused.

## Quick start

Requirements: Windows, [WezTerm](https://wezterm.org/), [PowerShell 7](https://github.com/PowerShell/PowerShell).
**If either is missing, the installer offers to install it with winget.**

1. Download the zip from [Releases](../../releases) and extract it
   (or use *Code → Download ZIP* if there is no release yet).
2. Double-click **`install.cmd`**. If Windows SmartScreen appears, choose *More info → Run anyway*.
3. Answer the prompts. At the end, answer `Y` to *start WezTerm* to open a window with the new configuration.

Press Ctrl+Shift+F12 to see every command.

To verify the zip, compare the `.zip.sha256` file with `Get-FileHash -Algorithm SHA256 <zip>`.

Tested with: Windows 11, WezTerm 20240203-110809-5046fc22, PowerShell 7.6.
The installer itself runs on both Windows PowerShell 5.1 and PowerShell 7; the terminal's shell is PowerShell 7.

## Installer

```powershell
.\install.ps1 -WhatIf                    # show what would happen, change nothing
.\install.ps1                            # install (asks questions when needed)
.\install.ps1 -InstallMissing -Launch    # install missing software, then start WezTerm, without asking
```

| Option | Effect |
|---|---|
| `-WhatIf` | Print the actions and change nothing |
| `-InstallMissing` | Install missing WezTerm / PowerShell 7 with winget, without asking |
| `-Launch` | Start WezTerm after installing |
| `-NoPrompt` | Never ask (for automation); does not install software or launch unless the flags above are given |
| `-Link` | Link to this folder instead of copying (for people editing the configuration) |
| `-SkipRequirementCheck` | Continue even if WezTerm or PowerShell 7 is not found |
| `-HomePath <folder>` | Target home folder; defaults to the current user's home |

What it does and does not do:

- Existing `kitty_ja` and `.wezterm.lua` are never deleted: they are renamed with a `.bak-<timestamp>` suffix.
  If they are links (junction / symlink), only the link is removed. Re-running with identical content changes nothing.
- Without PowerShell 7 the terminal still starts (with Windows PowerShell), but shell integration does not work,
  so per-folder tab memory and the restored working folders are unavailable.
- It does not change the registry or environment variables, does not request administrator rights and does not use the network.
  `winget` is called only with `-InstallMissing` or after you answer "yes" to the prompt.
- It stops without changing anything when `<home>\.config\wezterm\wezterm.lua` exists or `XDG_CONFIG_HOME` is set,
  because WezTerm would not read `.wezterm.lua` in those cases.
- After installing it checks that WezTerm can load the configuration.

Uninstall with `uninstall.cmd`: `kitty_ja` and `.wezterm.lua` are renamed to `.removed-<timestamp>` (links are removed, their targets
are left alone), a `.wezterm.lua` that does not load `kitty_ja` is not touched, and your data stays in `<home>\.config\wezterm-kitty-ja\`.

## Design highlights

| Topic | Where |
|---|---|
| One command table drives both the key bindings and the command palette | `kitty_ja/commands.lua` → `keys.lua`, `palette.lua` |
| Physical-key bindings that work on JIS and US layouts | `kitty_ja/keys.lua` |
| Session restore and per-folder tab memory | `kitty_ja/session.lua`, `kitty_ja/tab_memory.lua` |
| Shell integration with a per-launch shared secret | `kitty_ja/shell.lua`, `kitty_ja/state.lua`, `kitty_ja/shell/integration.ps1` |
| Idempotent, `-WhatIf`-aware installer for PowerShell 5.1 and 7 | `install.ps1`, `uninstall.ps1` |
| Release packaging with content checks (personal paths, e-mail addresses, encodings) | `tools/New-Package.ps1` |
| Installer tests against a throw-away home folder | `tools/Test-Installer.ps1` |

Details (Japanese): [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), [docs/SECURITY-MODEL.md](docs/SECURITY-MODEL.md),
[docs/KEYBINDINGS.md](docs/KEYBINDINGS.md), [docs/CONFIGURATION.md](docs/CONFIGURATION.md).

## Development

```powershell
.\install.ps1 -Link              # link instead of copy; WezTerm reloads on every save
.\tools\Test-Installer.ps1       # PowerShell 7; never touches your real home folder
.\tools\New-Package.ps1          # writes a zip and its SHA-256 to dist\
wezterm show-keys                # check the resulting key bindings without opening a window
```

See [CONTRIBUTING.md](CONTRIBUTING.md) and [SECURITY.md](SECURITY.md).

## About the development

This project was built by [Claude Code](https://claude.com/claude-code) (Anthropic), an AI coding agent, at the direction of the author (ringo2pie).

- Decided by the author: the goal (make WezTerm behave like kitty), the specification and scope, the license, and the decision to publish.
- Done by Claude Code: the Lua configuration module, the installer, the package checks, the tests and the documentation.
- The documentation states only what was verified by reading the code; what could not be verified from the code is marked as such
  (see chapter 6 of [docs/SECURITY-MODEL.md](docs/SECURITY-MODEL.md), in Japanese).

## License

[MIT License](LICENSE).

This project contains no code from WezTerm, kitty, PowerShell or Notepad++; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
WezTerm, kitty and the other names belong to their respective owners, and this project is not affiliated with them.
