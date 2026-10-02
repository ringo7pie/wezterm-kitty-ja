# wezterm-setting

Windows の WezTerm を、kitty + kitty-ja-shortcuts と同じ動作・同じショートカットキーにする設定。

## 構成

| リポジトリ内 | WezTerm が読む場所 (リンク) |
|---|---|
| `.wezterm.lua` | `C:\Users\mt\.wezterm.lua` (シンボリックリンク) |
| `kitty_ja\` | `C:\Users\mt\.config\wezterm\kitty_ja` (ジャンクション) |

実体はこのリポジトリにあり、WezTerm が読む場所にはリンクだけを置く。
リポジトリ内のファイルを保存すると、WezTerm が設定を自動で読み直す。

次のデータはリポジトリの外 (`C:\Users\mt\.config\wezterm-kitty-ja\`) にあり、git では管理しない。

- `tab-colors\colors.txt`: タブ色の定義 (手で編集する)
- `tab-memory\memory.json`: フォルダごとのタブ名・タブ色の記憶
- `session\session.json`: 閉じたときのタブ構成 (次回の起動時に復元する)

## リンクの作り直し

別の場所へ clone したときや、リンクを消してしまったときは、PowerShell 7 で次を実行する。
ファイルのシンボリックリンクは、開発者モードが有効か、管理者権限が必要。

```powershell
$repoDir = 'E:\nkdx\wezterm-setting'
New-Item -ItemType Directory -Force -Path (Join-Path $env:USERPROFILE '.config\wezterm')
New-Item -ItemType Junction -Path (Join-Path $env:USERPROFILE '.config\wezterm\kitty_ja') -Target (Join-Path $repoDir 'kitty_ja')
New-Item -ItemType SymbolicLink -Path (Join-Path $env:USERPROFILE '.wezterm.lua') -Target (Join-Path $repoDir '.wezterm.lua')
```

`C:\Users\mt\.config\wezterm\wezterm.lua` という名前のファイルは作らない (`.wezterm.lua` より優先されてしまう)。
