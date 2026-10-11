# env

<!-- 常時ロードされる。50 行以内。areas/ は 2 ファイルまで。 -->
<!-- 終わりのない責任領域と、知らないと無駄に失敗する制約だけを書く。 -->
<!-- 終わりがある作業は work/ へ。外部資料の要約は resources/ へ。 -->
<!-- 断定文で書く。コードから導出できる情報（構成・依存一覧）は書かない。 -->

## 入力
- ユーザーが「rollup / rolldown」と呼ぶキーは PageUp / PageDown である。修飾キーなしの PageUp / PageDown の割り当てで、通常画面のログが 1 ページずつスクロールすることを 2026-10-11 に実機で確認した。

## 設定の反映
- WezTerm が読む設定は `~\.wezterm.lua` と `~\.config\wezterm\kitty_ja\` のコピーで、リポジトリとはリンクされていない。リポジトリを直しただけでは WezTerm に反映されない。
- 反映するには変更したファイルをコピーする。`require` されるモジュールを書き換えると、WezTerm は自動で設定を読み直す（隔離環境で 6 秒以内に確認）。再起動は要らない。手動なら Ctrl+Shift+F5。
- `.\install.ps1` を丸ごと実行すると `~\.wezterm.lua` が差し替わり、個人設定の `notepadpp_override` がリポジトリ側の値（nil）に戻る。旧ファイルは `.bak-<日時>` で残る。リポジトリを直接読ませるなら `.\install.ps1 -Link`。
- GUI を起動せずに、実際の設定のキー割り当てを確かめるには `wezterm show-keys` を使う。

## 起動
- 起動時に出る、空で入力できない「WezTerm」窓は、コンソール版 `wezterm.exe` のコンソールを Windows Terminal が受け持った窓である。設定（Lua）では消せない。スタートメニューの「WezTerm」（`wezterm-gui.exe`）から起動する。`wezterm.exe` を起動した元は特定できていない。

## Git
- リモート（NAS の共有フォルダ）の HEAD は `main`、ローカルのブランチは `master`。送るときは `git push -u origin master:main` を使う。
- 共有フォルダの所有者が違うので、push は `dubious ownership` で拒否される。`git push --receive-pack="git -c safe.directory=<リモートのパス> receive-pack" origin master:main` で通す。clone は `git -c safe.directory=<URL> clone <URL>` で通る。恒久化は `git config --global --add safe.directory <URL>`。
- `user.name` / `user.email` は未設定で、未設定のまま `git commit` は失敗する。履歴と同じ作者を `-c user.name=... -c user.email=...` で渡す（`git log -1 --format='%an <%ae>'` で確認する）。
- `zzz-Temp/` はユーザーの作業フォルダ。Claude Code は読み取り専用で、書き込み・add・commit・push をしない。「全てコミット」と言われても含めない。`.gitignore` に入っている。

## Claude Code の環境
- hook・スキル・規則・グローバルの指示は `~\.claude\` にあり、リポジトリの `claude-config\` にコピーを持つ。他の PC への配置と、`~\.claude` を直したあとの取り込みは `claude-config\Sync-ClaudeConfig.ps1` を使う。
