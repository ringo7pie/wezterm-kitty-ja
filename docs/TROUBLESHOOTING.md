# うまく動かないとき

## インストールが止まる

| 表示 | 原因と対処 |
|---|---|
| `PowerShell 7 が見つかりません` / `WezTerm が見つかりません` | 入れてよいかの質問に「はい」と答えるか、`winget install --id Microsoft.PowerShell --source winget` / `winget install --id wez.wezterm --source winget` を実行します。入れたのに見つからないときは `-SkipRequirementCheck` を付けます |
| `既に <ホーム>\.config\wezterm\wezterm.lua があります` | WezTerm は、このファイルを `.wezterm.lua` より優先します。別の名前に変えるか、中で `require('kitty_ja').apply_to_config(config)` を呼ぶようにしてから、もう一度実行します |
| `環境変数 XDG_CONFIG_HOME が設定されています` | WezTerm は `<ホーム>\.config\wezterm` を見なくなります。この環境変数を外してから、もう一度実行します |
| 「スクリプトの実行が無効」 | `install.cmd` を使います。コマンドで実行するなら `powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1` です |
| Windows の確認画面 (SmartScreen) が出る | ダウンロードした `install.cmd` に出ます。「詳細情報」→「実行」を選びます。気になるときは、先に zip の SHA-256 を確かめます |

## 入れたあとの症状

| 症状 | 原因と対処 |
|---|---|
| キーがすべて既定のまま、日本語のコマンド一覧が開かない | 設定が読み込めていません。`wezterm show-keys` を実行して、`(Physical)` の付いた割り当てが出るかを確かめます。出ないときは WezTerm を起動して、設定のエラー表示を見ます。`<ホーム>\.config\wezterm\kitty_ja` が置かれているかも確かめます |
| タブ名・タブ色の記憶と、タブの復元先のフォルダが働かない | PowerShell 7 の実行ポリシーが `Restricted` か `AllSigned` だと、シェル連携スクリプトを実行できません。`Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned` を PowerShell 7 で実行します |
| PowerShell 7 が Microsoft Store 版で、設定側が見つけられない | ユーザーの環境変数 `KITTY_JA_PWSH` に `pwsh.exe` のパスを設定します (インストーラーがパスを表示します) |
| 起動すると、中身が空で入力できない「WezTerm」という窓が一緒に開く | コンソール版の `wezterm.exe` を Explorer から起動したときに、Windows が作る窓です。設定では消せません。スタートメニューの「WezTerm」(`wezterm-gui.exe`) から起動します |
| シェルの入力行で Home / End が行頭・行末に動かない | 修飾キーなしの Home / End を、ログの先頭・末尾への移動に割り当てているためです。戻すには `kitty_ja\commands.lua` の `scroll_log_top` と `scroll_log_bottom` の 2 行を消します |
| ネットワークのフォルダにいたタブが、ホームで復元される | 起動のたびに外部へ自動で接続するのを避けるため、ドライブ文字で始まるフォルダだけを復元します。仕様です |
| 設定を変えたのに反映されない | `.wezterm.lua` と `kitty_ja\` を書き換えると自動で読み直されます。手動なら Ctrl+Shift+F5 です。リンクではなくコピーでインストールしたときは、リポジトリを直しただけでは WezTerm に反映されません (コピーし直すか、`-Link` で入れ直します) |

## 元に戻す

`uninstall.cmd` を実行します。設定は消さずに `.removed-<日時>` を付けて残し、データ (`<ホーム>\.config\wezterm-kitty-ja\`) もそのまま残します。
インストール前の `.wezterm.lua` は `.wezterm.lua.bak-<日時>` として残っているので、名前を `.wezterm.lua` に戻せば元に戻ります。
