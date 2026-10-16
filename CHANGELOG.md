# 変更履歴

書式は [Keep a Changelog](https://keepachangelog.com/ja/1.1.0/) に沿います。

## [Unreleased]

初めての公開に向けた内容です。

### 追加

- WezTerm を kitty + kitty-ja-shortcuts と同じ動作・同じショートカットキーにする設定 (`kitty_ja`)
- 日本語のコマンド一覧 (Ctrl+Shift+F12)。ローマ字・英語で検索できる
- タブ色の切り替えと、フォルダごとのタブ名・タブ色の記憶
- 閉じたときのタブとペイン分割の、次回起動時の復元
- スクロール履歴を Notepad++ で開く操作 (Ctrl+Shift+E)。保持するスクロール履歴を 10 万行以上にする設定
- 修飾キーなしの PageUp / PageDown でログを 1 ページずつスクロールする割り当て
- Ctrl+Home / Ctrl+End でログの先頭・末尾へ移動する割り当て (全画面のアプリには、キーをそのまま渡す)。
  修飾キーなしの Home / End は割り当てず、シェルの入力行で行頭・行末へ移動できる
- インストーラー (`install.cmd` / `install.ps1`) とアンインストーラー。既存のファイルは消さずに残す
- インストーラーの `-InstallMissing` (足りない WezTerm / PowerShell 7 を winget で入れる)、`-Launch` (インストール後に起動)、
  `-NoPrompt` (自動化用)。対話的な実行では、入れてよいか・起動してよいかを尋ねる
- インストール後に、WezTerm が設定を読み込めることを確かめる処理
- 配布用 zip の作成 (`tools\New-Package.ps1`)。個人のパス・メールアドレス・文字コード・改行を検査する
- インストーラーと配布物の自動テスト (`tools\Test-Installer.ps1`)
- MIT License、サードパーティの表示 (`THIRD_PARTY_NOTICES.md`)
- 設計・セキュリティ・キー一覧・設定・困ったときの資料 (`docs\`)、英語の README
- GitHub Actions による検査 (Lua の構文、インストーラーと配布物のテスト) と、タグからのリリース作成
- mux-server 構成 (`settings.lua` の `mux_server`、既定は有効)。シェルを `wezterm-mux-server` に持たせ、GUI は接続するだけにする。
  GUI を閉じても、強制終了しても、起動し直しても、シェルとその中のプログラムが動き続ける。
  タブの復元をサーバーの起動時 (`mux-startup`) に行い、シェル連携の合言葉をファイルで共有する。`false` で従来の構成に戻る
- mux-server 構成で、Ctrl+J・Shift+Enter・Ctrl+Enter が、Windows のコンソールの入力 (codex など) で別のキーとして届く問題の補正 (`mux.lua`)。
  codex の「Ctrl+J で改行」が効かなくなっていた
- 履歴の予測候補 (PSReadLine の予測) を、候補の一覧 (ListView) で出す設定 (`settings.lua` の `history_prediction`、既定は `'ListView'`)。
  `$PROFILE` は書き換えず、`integration.ps1` が pwsh の起動時に設定する。`'InlineView'` や、何も設定しない `false` にできる。
  予測が切れているときだけ履歴の予測にし、`HistoryAndPlugin` など既にある設定は変えない。
  PSReadLine が予測に対応していない環境 (Windows PowerShell 5.1 など) では何もしない

### 変更

- RDP で起動した窓が、コンソール (HDMI) への切り替えの間、画面が止まって見える問題を避けるため、描画方式を選べるようにし
  (`settings.lua` の `render_mode`)、既定を `'webgpu-dx12'` にした。作者の PC では、WezTerm 既定の OpenGL だけが止まり、
  WebGpu (DirectX 12) は止まらず、1 回の描画の中央値は OpenGL 0.9 ms に対して 1.7 ms だった (CPU 描画は止まらないが 414 ms)
- 配布物の検査が、どの PC にもある `C:\Program Files` を個人のパスと誤検出しないようにした
- 配布 zip に、`LICENSE`・`THIRD_PARTY_NOTICES.md`・英語の README・`docs\` を含めるようにした

### 修正

- mux-server 構成で、codex など代替画面 (alternate screen) を使うアプリの中で、PageUp / PageDown・Ctrl+Home / Ctrl+End が効かない問題。
  mux 経由のペインは `pane:is_alt_screen_active()` が常に false を返すので、キーをアプリへ渡さず、何も動かない WezTerm のスクロールになっていた。
  mux のペインは、サーバーから届く画面の大きさ (`scrollback_rows` が `viewport_rows` 以下) で代替画面を判定する (`commands.lua`)。
  スクロールバックが空の通常画面は代替画面と区別できず、そこでの Ctrl+Home / Ctrl+End はシェルへ渡る
- mux-server 構成で、GUI の起動のたびにログへ `tab_memory: tab id 0 not found in mux` が 1 行出る問題 (実害はなかった)。
  接続中だけある一時的なタブ (id 0) が、確認の前に消えるため。この WezTerm の `wezterm.mux.get_tab` は、タブが無いと nil ではなく
  エラーを投げるので、`tab_memory.lua` の `find_tab` で「タブが無い」だけを nil として扱う (理由が違うエラーはそのままログに出す)
