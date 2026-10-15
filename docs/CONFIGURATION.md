# 設定リファレンス (Configuration Reference)

この資料は `kitty_ja\settings.lua` を中心に、`kitty_ja` 配下のコードから確認できた設定項目・環境変数・データファイルをまとめたもの。コードを読んで確認したことだけを書き、確認できなかったことはその旨を明記する。

## settings.lua の設定項目

環境に合わせて変える場合は、このファイル (`kitty_ja\settings.lua`) だけを編集すればよい (ファイル先頭のコメントに明記)。

| 設定名 | 既定値 | 効果 |
|---|---|---|
| `home_dir` | `wezterm.home_dir` (WezTerm が返すホームディレクトリ) | 新しいタブ・新しい OS ウィンドウの起動フォルダ、パス解決 (`~` 展開) の基準になる |
| `colors_file` | `<ホーム>\.config\wezterm-kitty-ja\tab-colors\colors.txt` | タブ色定義ファイルの場所。設定の再読み込み監視対象に登録されている |
| `memory_file` | `<ホーム>\.config\wezterm-kitty-ja\tab-memory\memory.json` | フォルダごとのタブ名・タブ色の記憶ファイルの場所 |
| `session_enabled` | `true` | `false` にすると、タブ構成の保存・復元機能 (`session.lua`) 全体を止める |
| `session_file` | `<ホーム>\.config\wezterm-kitty-ja\session\session.json` | 保存するセッションファイルの場所 |
| `session_window_close_grace_seconds` | `3` | ウィンドウの数が減った状態がこの秒数続いてから保存する (複数ウィンドウを続けて閉じて終了したとき、途中の状態で上書きしないための猶予) |
| `session_probe_timeout_ms` | `2000` | 復元時にフォルダの到達性を並行して確認する待ち時間の上限 (ミリ秒)。届かないフォルダは本来の行き先を保持したままホームで開く |
| `session_tab_bar_rows` | `1` | タブが2枚以上のときに表示されるタブバーの行数分、復元時のウィンドウの高さに加算する (`hide_tab_bar_if_only_one_tab = true` / `use_fancy_tab_bar = false` との組み合わせに対応するための値) |
| `mux_server` | `true` | `true` なら、シェルを `wezterm-mux-server` に持たせ、GUI はそこへ接続するだけにする (`mux.lua`)。GUI を閉じる・強制終了する・起動し直しても、シェルとその中のプログラムが動き続ける。`false` で、従来のとおり GUI がシェルを持つ。起動中の GUI は設定の再読み込みでは切り替わらない。変えたら WezTerm を起動し直す (`true` から `false` に変えたあとも、動いているサーバーとその中のシェルは残る。止めるには `wezterm-mux-server.exe` を終了する) |
| `mux_domain_name` | `'unix'` | `unix_domains` に登録するドメイン名 (`wezterm connect <名前>` の名前)。`.wezterm.lua` で同じ名前のドメインを定義済みなら、そちらを使う |
| `shell_token_file` | `<ホーム>\.config\wezterm-kitty-ja\shell-token.txt` | mux 構成で、サーバーと GUI が共有するシェル連携の合言葉のファイル。サーバーが起動時に書き、GUI が読む (`state.lua`) |
| `shell_program` | `find_pwsh()` の戻り値 (自動検出。固定の既定値は無い) | 既定シェルとして起動する `pwsh.exe` のフルパス。見つからない場合は `nil` |
| `fallback_shell_program` | `%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe` | `shell_program` が見つからないときに使う Windows PowerShell |
| `integration_script` | `<ホーム>\.config\wezterm\kitty_ja\shell\integration.ps1` | pwsh 起動時に実行するシェル連携スクリプトのパス |
| `editor_command` | Notepad++ が見つかればそのパス、無ければ `%SystemRoot%\System32\notepad.exe` (自動検出) | `colors.txt` / `memory.json` / WezTerm 設定ファイルを開くエディタの起動コマンド (配列。先頭要素が実行ファイル) |
| `editor_line_option` | Notepad++ のときは `'-n'`、メモ帳のときは `nil` | 「ファイル:行番号」をエディタで開くときに、行番号の前へ付ける引数 |
| `font_size` | `11` | 既定のフォントサイズ |
| `render_mode` | `'webgpu-dx12'` | 画面の描画方式 (`appearance.lua`)。RDP で起動した窓が、コンソール (HDMI) への切り替えの間、画面が止まって見えるのを避けるための設定。`'opengl'` (WezTerm 既定)、`'angle'` (OpenGL を ANGLE 経由)、`'webgpu'` (GPU とバックエンドは WezTerm が選ぶ)、`'webgpu-dx12'` (DirectX 12 の GPU)、`'cpu'` (WebGpu の `webgpu_force_fallback_adapter`、実体は Windows 標準の Microsoft Basic Render Driver)。作者の PC (RTX 3070、Windows 11、WezTerm 20240203-110809-5046fc22) では、RDP で起動した窓を HDMI へ 3 分ほど切り替えると `'opengl'` だけが切り替えの瞬間から、`'angle'` は約 42 秒後に画面が止まり、`'webgpu'` / `'webgpu-dx12'` / `'cpu'` は止まらなかった。出力が流れ続けるときの 1 回の描画 (paint) の中央値は、`'opengl'` 0.9 ms、`'webgpu-dx12'` 1.7 ms、`'webgpu'` 14 ms、`'cpu'` 414 ms。別の PC・GPU では結果が変わりうるので、固まるときは値を変えて試す。開いている窓は設定の再読み込みでは切り替わらない (同じバージョンで確認)。変えたら WezTerm を起動し直す |
| `font_size_step_key` | `2.0` | キー操作 (Ctrl+Shift+=/-) でのフォントサイズの増減幅 |
| `font_size_step_palette` | `1.0` | コマンドパレットから実行したときのフォントサイズの増減幅 |
| `opacity_step` | `0.1` | 背景の不透明度を1段階変える幅 (Ctrl+Shift+A → M/L) |
| `new_tab_delay_seconds` | `0.5` | 新しいタブの初回処理 (タブ名・タブ色の確定) を待つ秒数。kitty 側の `tab_memory.py` の `NEW_TAB_DELAY` に相当するとコメントにある |
| `documentation_url` | `https://wezterm.org/` | `show_doc` (Ctrl+Shift+F1) で開く URL |

## 環境変数

コードが読む環境変数は次の 8 個。「種別」の「外部」は OS やユーザーが用意するもの、「内部」は `kitty_ja` 自身が設定して自分で読み戻すものを指す。

| 変数名 | 種別 | 読む場所 | 役割 |
|---|---|---|---|
| `KITTY_JA_PWSH` | 外部 (ユーザーが設定) | `settings.lua` (`find_pwsh`) | `pwsh.exe` のパスを明示指定する。設定されていれば、ファイルの存在確認をせずそのまま使う (コード上、他の探索先と違い `file_exists` による検証をしていない)。Microsoft Store 版の `pwsh.exe` のように自動検出できない場合に使う |
| `ProgramW6432` / `ProgramFiles` / `ProgramFiles(x86)` | 外部 (OS 標準) | `settings.lua` (`find_in_program_files`) | `pwsh.exe` (`PowerShell\7\pwsh.exe`) と Notepad++ (`Notepad++\notepad++.exe`) を探す基準フォルダ。3 つを順に試し、最初に見つかったものを使う |
| `PATH` | 外部 (OS 標準) | `settings.lua` (`find_pwsh`) | Program Files 以下で見つからないとき、`;` 区切りの各フォルダで `pwsh.exe` を探す |
| `PATHEXT` | 外部 (OS 標準) | `panes.lua` (`executable_extension_set`) | 「開く」と実行されてしまう拡張子の一覧 (`EXECUTABLE_EXTENSIONS`) に、OS の `PATHEXT` の内容を追加する。画面の文字列を開く機能 (Ctrl+Shift+O など) の安全確認に使う |
| `SystemRoot` | 外部 (OS 標準。無ければ `C:\Windows`) | `settings.lua` | フォールバックの Windows PowerShell とメモ帳のパスを組み立てる基準 (`System32`) |
| `KITTY_JA_INTEGRATION` | 内部 (`shell.lua` が設定し、起動した pwsh 自身が `$env:KITTY_JA_INTEGRATION` として読む) | `shell.lua` (`config.default_prog` の `-Command '& $env:KITTY_JA_INTEGRATION'`) | `integration_script` のパスを子プロセス (pwsh) へ渡す。パスを `-Command` の文字列へ直接埋め込むと、引用符を含むパスでコマンドが壊れるための経由 (コードのコメント) |
| `KITTY_JA_TOKEN` | 内部 (`shell.lua` が設定し、`integration.ps1` が読んで即座に環境変数から削除する) | `shell.lua` / `kitty_ja\shell\integration.ps1` | シェル連携の合言葉。フォルダ通知 (OSC 1337 の `SetUserVar`) にこれを添えることで、端末に文字を出すだけのもの (ssh 先や `cat` したファイル) が通知を偽装できないようにする。`state.lua` の `shell_token()` が WezTerm プロセスごとに 1 回生成する |
| `TERM_PROGRAM` | 外部 (WezTerm 本体が設定) | `kitty_ja\shell\integration.ps1` | 値が `'WezTerm'` でなければ、連携スクリプトの処理を中断する (`return`)。WezTerm 以外の端末で誤って読み込まれたときの誤動作を避ける |

## データの置き場所

`<ホーム>\.config\wezterm-kitty-ja\` 以下に、PC ごとのデータを置く (`settings.lua` の `data_dir`)。Lua モジュール本体 (`<ホーム>\.config\wezterm\kitty_ja\`) とは別フォルダで、理由はコードのコメントに「同じフォルダだと `memory.json` の保存で設定の再読み込みが走る恐れがある」とある。README.md にも明記されているとおり、配布物にはこのフォルダの内容は含まれない。

| パス | 役割 |
|---|---|
| `tab-colors\colors.txt` | タブ色の定義。手で編集する (エディタは上記 `editor_command`)。`tab_colors.lua` の `load_colors` はファイルが無ければ空配列を返すだけで、エラーにはしない |
| `tab-memory\memory.json` | フォルダごとのタブ名・タブ色の記憶 (`tab_memory.lua`)。`version` と `folders` を持つ JSON。手で編集して JSON として壊れた場合、直るまでそのフォルダの記憶を上書き保存しない (`load_folders` が `broken = true` を返し、呼び出し側が書き込みを避ける実装) |
| `session\session.json` | 閉じたときのタブ構成・ペイン分割 (`session.lua`)。`windows = [ { active_tab, cols, rows, tabs = [...] } ]` の形。`version`、`owner_pid`、`saved_at` も持つ |
| `shell-token.txt` | mux 構成で、サーバーとシェルを共有する合言葉 (`state.lua` の `publish_shell_token`)。サーバーの起動のたびに書き換わる。手で編集しない |
| `session\session.json.bak` | このプロセスが `session.json` を最初に上書きする直前の内容の控え。手で戻すためのもので、自動では読まない |
| `session\session.json.tmp` | 書き込み中に使う一時ファイル。本体 (`session.json`) が無い・壊れているときだけ、フォールバックとして読む |

## PowerShell 7 とエディタの探索順序

コードに書かれている順序どおりに記載する。

### PowerShell 7 (`pwsh.exe`) — `settings.lua` の `find_pwsh`

1. 環境変数 `KITTY_JA_PWSH` が設定されていれば、その値を無条件に使う (ファイルの存在確認はコード上行っていない)。
2. `ProgramW6432` → `ProgramFiles` → `ProgramFiles(x86)` の順に、各フォルダ配下の `PowerShell\7\pwsh.exe` の実在を確認し、最初に見つかったものを使う。
3. 環境変数 `PATH` を `;` で区切った各フォルダ配下の `pwsh.exe` を順に確認し、最初に見つかったものを使う。
4. どれにも無ければ `shell_program` は `nil` になり、`fallback_shell_program` (Windows PowerShell) で起動する。この場合、シェル連携スクリプト (`integration.ps1`) が実行されないため、フォルダ通知に依存するタブ記憶・セッションの復元先・プロンプト間の移動が働かない (`shell.lua` のコードコメントに明記)。

### エディタ — `settings.lua` の `find_in_program_files` と `editor_command` の組み立て

1. `ProgramW6432` → `ProgramFiles` → `ProgramFiles(x86)` の順に `Notepad++\notepad++.exe` の実在を確認する。
2. 見つからなければ `%SystemRoot%\System32\notepad.exe` (メモ帳) を使う。

行番号を指定して開く機能 (「ファイルの行を開く」など) は、Notepad++ が見つかったときだけ `editor_line_option` が `'-n'` になり、「ファイル:行番号」を開く際に `-n<行番号>` という引数が追加される。メモ帳のときは `editor_line_option` が `nil` で、行番号は渡されない。

## 設定を変えたあとの反映

- `colors.txt` は `wezterm.add_to_config_reload_watch_list` に登録されている (`kitty_ja\init.lua`)。保存すると WezTerm が設定を再読み込みし、タブ色の直接キー (Ctrl+Shift+Alt+数字) も更新される。手動でも Ctrl+Shift+F5 (`reload_config`) や Ctrl+Shift+Alt+R (`reload_colors`。実装は `reload_config` と同じ `act.ReloadConfiguration`) で再読み込みできる。
- `settings.lua` / `appearance.lua` / `shell.lua` / `keys.lua` などの Lua モジュールについて、`add_to_config_reload_watch_list` への追加はコード上 `colors_file` 以外には見当たらない。これらは WezTerm 本体が、`require` で読み込まれたモジュールの変更として検知する。隔離した環境で、`kitty_ja` のモジュールを書き換えると 6 秒以内に設定が読み直されることを確かめた (WezTerm 20240203-110809-5046fc22)。再起動は要らない。
- `memory.json` は手で編集しても、WezTerm の再読み込みを待つ必要がない。`tab_memory.lua` の `load_folders` はキャッシュを持たず、cd やタブ操作のたびにファイルを読み直す実装になっている。
- `session.json` は起動時 (`gui-startup` イベント) に一度だけ読み込まれて復元に使われ、以後は `update-status` イベントのたびに最新のタブ構成で上書き保存される (`session.lua`)。手で編集した内容を復元に使うには、WezTerm を再起動する必要がある (起動中のプロセスが再読み込みする経路はコード上見当たらない)。
