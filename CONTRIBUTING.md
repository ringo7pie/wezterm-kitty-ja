# 貢献のしかた

Issue と Pull Request を歓迎します。

## 開発の準備

1. WezTerm と PowerShell 7 を入れます ([README](README.md) を見てください)。
2. リポジトリを clone します。
3. リンクでインストールします。ファイルを保存するたびに WezTerm が設定を読み直します。

   ```powershell
   .\install.ps1 -Link
   ```

   既に `.wezterm.lua` を使っているときは、`-WhatIf` を付けて何が起きるかを先に確かめてください。
   既存のファイルは `.bak-<日時>` として残ります。

## 変更の確かめ方

```powershell
.\tools\Test-Installer.ps1    # インストーラーと配布物の検査。実際のホームには触らない
wezterm show-keys             # 設定したキー割り当てを、窓を開かずに確かめる
```

- `kitty_ja\` を変えたときは、WezTerm を起動して動作を確かめてください。
  設定の読み込みに失敗すると、WezTerm は既定の割り当てに戻りますが、エラーは表示されます。
- `commands.lua` のコマンドを増やしたときは、[docs/KEYBINDINGS.md](docs/KEYBINDINGS.md) も更新してください。
- 配布物に入るファイルを増やすときは、`tools\New-Package.ps1` の一覧も更新してください。

## 書き方

- Lua: 2 スペースのインデント。モジュールは `local module = {}` を返す形にそろえています。
  設定の値は `settings.lua` にまとめ、他のファイルへ直接書かないでください。
- PowerShell: 先頭で `Set-StrictMode -Version Latest` と `$ErrorActionPreference = 'Stop'` を宣言します。
  関数名は承認済みの動詞 (`Get-Verb` の一覧) を使います。
  `install.ps1` と `uninstall.ps1` は Windows PowerShell 5.1 でも動く書き方にし、BOM 付き UTF-8 で保存します。
  `install.cmd` と `uninstall.cmd` の改行は CRLF です (`.gitattributes` が管理します)。
- 利用者のファイルを消す・上書きする変更は、バックアップを残すか、確認を挟んでください。
- 個人のパスやメールアドレスを書かないでください。`tools\New-Package.ps1` が検出して止まります。

## コミットと Pull Request

- コミットメッセージは、何を変えたかではなく、何ができるようになったか (なぜ変えたか) を 1 行目に書きます。
- Pull Request には、確かめた内容 (実行したコマンドと結果、動かした WezTerm の版) を書いてください。

## ライセンス

貢献された内容は、このプロジェクトと同じ [MIT License](LICENSE) で公開されます。
