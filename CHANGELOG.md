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

### 変更

- RDP で起動した窓が、コンソール (HDMI) への切り替えの間、画面が止まって見える問題を避けるため、描画方式を選べるようにし
  (`settings.lua` の `render_mode`)、既定を `'webgpu-dx12'` にした。作者の PC では、WezTerm 既定の OpenGL だけが止まり、
  WebGpu (DirectX 12) は止まらず、1 回の描画の中央値は OpenGL 0.9 ms に対して 1.7 ms だった (CPU 描画は止まらないが 414 ms)
- 配布物の検査が、どの PC にもある `C:\Program Files` を個人のパスと誤検出しないようにした
- 配布 zip に、`LICENSE`・`THIRD_PARTY_NOTICES.md`・英語の README・`docs\` を含めるようにした
