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
| シェルの入力行で Ctrl+Home / Ctrl+End が「カーソルより前 / 後ろを削除」にならない | Ctrl+Home / Ctrl+End を、ログの先頭・末尾への移動に割り当てているためです (PowerShell の PSReadLine の既定では、この 2 つが入力行の削除です)。戻すには `kitty_ja\commands.lua` の `scroll_log_top` と `scroll_log_bottom` の 2 行を消します。修飾キーなしの Home / End は割り当てていないので、行頭・行末への移動はそのまま使えます |
| リモートデスクトップ (RDP) で起動した WezTerm が、コンソール (HDMI の直接操作) へ切り替えている間、画面が止まる。新しく起動した WezTerm は使える。RDP に戻すと動く | 描画方式 (`kitty_ja\settings.lua` の `render_mode`) によります。作者の PC では、既定の `'opengl'` だけが止まり、既定の `'webgpu-dx12'` は止まりませんでした (比較表は `docs\CONFIGURATION.md`)。止まるときは、`'webgpu'` や `'cpu'` (止まらないが重い) に変えて試します。開いている窓は、設定を再読み込みしても描画方式が切り替わらないので、WezTerm を起動し直します (mux-server 構成なら、窓を閉じて起動し直しても、シェルは残ります)。`'webgpu-dx12'` の窓を、先にコンソールで起動して RDP へ切り替える向きは、確かめていません |
| 窓を閉じたのに、PowerShell (や中で動かしていたプログラム) が残っている | mux-server 構成 (`mux_server = true`) の仕様です。窓 (GUI) を閉じても、シェルは `wezterm-mux-server.exe` に残り、次に WezTerm を起動すると同じ画面に戻ります。シェルを終わらせるときは、タブを閉じる (Ctrl+Shift+W) か `exit` します。サーバーごと止めるには、`wezterm-mux-server.exe` を終了します (中のシェルは全部終わります) |
| mux-server 構成で、codex の Ctrl+J (改行) が効かない。Shift+Enter や Ctrl+Enter が、ただの Enter になる | mux 経由では、WezTerm がキーの仮想キーコードと修飾キーを運べないためです (ローカルの窓では運べます)。Ctrl+J・Shift+Enter・Ctrl+Enter は、`kitty_ja\mux.lua` の `apply_keys` が補正します (`mux_server = true` のときだけ有効。設定の再読み込みのあと、新しく押したキーから効きます)。これ以外の修飾キー付きのキーが、アプリに届かないときは、`mux_server = false` にして同じ操作で確かめ、違いがあれば報告してください (確かめていません) |
| WezTerm を 2 つ起動したら、同じウィンドウが映る | mux-server 構成の仕様です。窓 (GUI) はどれも、同じサーバーのウィンドウを映します。別のウィンドウが要るときは Ctrl+Shift+N を使います |
| mux-server 構成で、PATH などの環境変数を変えたのに、新しいタブに反映されない | サーバーが作るシェルの環境変数は、サーバーを起動したときのものです。`wezterm-mux-server.exe` を終了して (中のシェルは全部終わります)、WezTerm を起動し直します |
| 起動時に `path must be shorter than SUN_LEN` と出て、サーバーが起動しない | Windows の `AF_UNIX` のソケットのパスは、108 文字までです。`.wezterm.lua` で `config.unix_domains` に `{ name = 'unix', socket_path = '<短いフォルダのパス>\\sock' }` のように短いパスを指定します (`<短いフォルダのパス>` は、書き込めるフォルダのうち、できるだけ短いパス)。急ぐときは `mux_server = false` にして、WezTerm を起動し直します |
| mux-server 構成で、GUI を起動し直したあと、タブ色が一部戻らない | 色は GUI のプロセスの中にしか無いので、GUI を作り直すと消えます。フォルダの記憶 (`memory.json`) と名前が同じタブは、色が戻ります。戻らないタブは、色を付け直します (付け直すと記憶されます) |
| ネットワークのフォルダにいたタブが、ホームで復元される | 起動のたびに外部へ自動で接続するのを避けるため、ドライブ文字で始まるフォルダだけを復元します。仕様です |
| 設定を変えたのに反映されない | `.wezterm.lua` と `kitty_ja\` を書き換えると自動で読み直されます。手動なら Ctrl+Shift+F5 です。リンクではなくコピーでインストールしたときは、リポジトリを直しただけでは WezTerm に反映されません (コピーし直すか、`-Link` で入れ直します) |

## 元に戻す

`uninstall.cmd` を実行します。設定は消さずに `.removed-<日時>` を付けて残し、データ (`<ホーム>\.config\wezterm-kitty-ja\`) もそのまま残します。
インストール前の `.wezterm.lua` は `.wezterm.lua.bak-<日時>` として残っているので、名前を `.wezterm.lua` に戻せば元に戻ります。
