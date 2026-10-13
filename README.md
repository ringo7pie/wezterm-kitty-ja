# wezterm-kitty-ja

![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)
![Platform: Windows](https://img.shields.io/badge/platform-Windows-0078D6.svg)
![WezTerm](https://img.shields.io/badge/WezTerm-20240203%2B-4E49EE.svg)
![PowerShell](https://img.shields.io/badge/PowerShell-7%20%2F%205.1-5391FE.svg)

Windows の [WezTerm](https://wezterm.org/) を、[kitty](https://sw.kovidgoyal.net/kitty/) + kitty-ja-shortcuts と同じ動作・同じショートカットキーにする設定です。
Lua で書いた設定モジュール (`kitty_ja`) と、安全に入れて外せるインストーラーでできています。

English: [README.en.md](README.en.md)

- **kitty と同じキー操作**: JIS 配列でも、同じキー位置で動きます (物理キーで割り当てています)。
- **日本語のコマンド一覧**: Ctrl+Shift+F12 で開きます。ローマ字 (`tabu`、`pein`) や英語 (`new_tab`) で絞り込めます。
- **タブ色と、フォルダごとのタブ名・タブ色の記憶**: Ctrl+Shift+Alt+数字で色を切り替えます。
- **タブとペイン分割の復元**: 閉じたときの構成を、次の起動で戻します。
- **安全側の既定**: 端末に表示された文字列から、意図しないファイルが開かれたり実行されたりしないよう、開く対象を制限しています。

## クイックスタート

必要なもの: Windows、[WezTerm](https://wezterm.org/)、[PowerShell 7](https://github.com/PowerShell/PowerShell)。
**無ければ、インストーラーが winget で入れるかを尋ねます。**

1. このリポジトリの [Releases](../../releases) から zip をダウンロードして展開します
   (Releases が無いときは、緑の「Code」ボタン → 「Download ZIP」でも同じように使えます)。
2. 展開したフォルダの **`install.cmd` をダブルクリック**します。
   Windows の確認画面 (SmartScreen) が出たら、「詳細情報」→「実行」を選びます。
3. 画面の質問に答えます。最後に「WezTerm を起動しますか」と尋ねるので、`Y` を入力して Enter を押すと WezTerm の窓が開きます。

Ctrl+Shift+F12 を押すと、使えるコマンドの一覧が開きます。

> zip を検証したいときは、同じ場所にある `.zip.sha256` と、PowerShell の `Get-FileHash -Algorithm SHA256 <zip>` の結果を比べます。

### 動作確認の環境

| ソフト | 版 |
|---|---|
| OS | Windows 11 |
| WezTerm | 20240203-110809-5046fc22 |
| PowerShell 7 | 7.6 |

端末のシェルには PowerShell 7 を使います。PowerShell 7 が無くても端末は Windows PowerShell で起動しますが、
シェル連携 (フォルダの通知) が働かないので、フォルダごとのタブ名・色の記憶とタブの復元先のフォルダは使えません。
インストーラー自体は、Windows PowerShell 5.1 と PowerShell 7 のどちらでも実行できます。

## インストール

### 足りないソフトの入れ方

`install.cmd` を実行したときに WezTerm か PowerShell 7 が無ければ、winget で入れてよいかを尋ねます (既定は「いいえ」)。
winget のインストーラーが、管理者権限の確認画面を出すことがあります。

自分で入れる場合は、次のコマンドを使います。

```powershell
winget install --id wez.wezterm --source winget
winget install --id Microsoft.PowerShell --source winget
```

### コマンドで実行する

PowerShell で、展開したフォルダへ移動して実行します。`-WhatIf` を付けると、何をするかを表示するだけで何も変更しません。

```powershell
.\install.ps1 -WhatIf     # 何をするかを表示するだけ
.\install.ps1             # インストール (必要なら質問します)
.\install.ps1 -InstallMissing -Launch   # 足りないソフトを入れ、WezTerm を起動する (質問しない)
```

| オプション | 効果 |
|---|---|
| `-WhatIf` | 何をするかを表示して、何も変更しない |
| `-InstallMissing` | 足りない WezTerm / PowerShell 7 を、確認なしで winget から入れる |
| `-Launch` | インストールの後に WezTerm を起動する |
| `-NoPrompt` | 何も尋ねない (自動化用)。`-InstallMissing` / `-Launch` を付けなければ、入れも起動もしない |
| `-Link` | コピーではなく、このフォルダへのリンクを張る (設定を編集しながら使う人向け) |
| `-SkipRequirementCheck` | WezTerm と PowerShell 7 が見つからなくても続ける |
| `-HomePath <フォルダ>` | インストール先のホーム。既定は現在のユーザーのホーム |

「スクリプトの実行が無効」と表示されたら、`install.cmd` を使うか、次のように実行します。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

### インストーラーがすること

| 配布物 | 置く場所 |
|---|---|
| `kitty_ja\` | `<ホーム>\.config\wezterm\kitty_ja\` |
| `.wezterm.lua` | `<ホーム>\.wezterm.lua` |
| `defaults\colors.txt` | `<ホーム>\.config\wezterm-kitty-ja\tab-colors\colors.txt` (無いときだけ) |

- 既にある `kitty_ja` や `.wezterm.lua` は消さず、名前に `.bak-<日時>` を付けて残します。
  それがリンク (ジャンクション・シンボリックリンク) のときは、リンクだけを消します。リンク先には触りません。
  同じ中身が既に入っていれば、何もしません (何度実行しても同じ結果です)。
- 置いたファイルから「インターネットから入手したファイル」の印を外します (付いたままだと PowerShell がシェル連携スクリプトを実行しません)。
- 既定では、ソフトのダウンロードやインストール、レジストリや環境変数の変更、管理者権限の要求、ネットワークへの接続をしません。
  winget を呼ぶのは、`-InstallMissing` を付けたときと、確認に「はい」と答えたときだけです。
- 現在のユーザーのホームへ入れ、WezTerm が見つかったときは、入れたあとに WezTerm がこの設定を読み込めることを確かめます。
- `<ホーム>\.config\wezterm\wezterm.lua` が既にあると、WezTerm はそちらを優先して `.wezterm.lua` を読みません。この場合は何も変更せずに止まります。
  環境変数 `XDG_CONFIG_HOME` が設定されている場合も、WezTerm が見る設定フォルダが変わるので止まります。
- `install.cmd` は、Windows 付属の PowerShell (`%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe`) で `install.ps1` を実行します。
  `-ExecutionPolicy Bypass` はその 1 回の実行だけに効き、PC の設定は変えません。

### 更新

新しい zip を展開して、もう一度 `install.cmd` を実行します。前の `kitty_ja` は `.bak-<日時>` として残ります。

### アンインストール

`uninstall.cmd` をダブルクリックします。`kitty_ja` と `.wezterm.lua` は消さずに、名前へ `.removed-<日時>` を付けて残します。
リンクのときは、リンクだけを消します (リンク先には触りません)。`kitty_ja` を読み込んでいない `.wezterm.lua` には触りません。
データ (`<ホーム>\.config\wezterm-kitty-ja\`) はそのまま残るので、不要なら手で削除してください。

## 使い方

- **コマンド一覧**: Ctrl+Shift+F12。キーの割り当てはここで確認できます。全キーの表は [docs/KEYBINDINGS.md](docs/KEYBINDINGS.md) にあります。
- **一覧の検索**: 半角でそのまま打ちます。読みのローマ字 (`tabu`、`pein`、`haritsuke`) か英語 (`new_tab`、`scroll`) で絞り込みます。
  ヘボン式・訓令式 (`ti`、`hu`、`zi`)、`jya`、`nn` のどれで打ってもかまいません。
  WezTerm の選択画面は IME の入力を受け取れないので、日本語そのものでは検索できません。
- **タブ色**: Ctrl+Shift+Alt+数字。色の定義は `colors.txt` (Ctrl+Shift+Alt+E で開く)。
- **タブの復元**: WezTerm を閉じて開き直すと、タブ・ペイン分割・フォルダ・タブ名・タブ色が戻ります。
  実行中だったプログラムと画面の文字は戻りません。
- **スクロール履歴を Notepad++ で開く**: Ctrl+Shift+E (Ctrl+Alt+Shift+F12 でも)。画面とスクロール履歴を、
  `%TEMP%` の `wezterm-history-<日時>-pane-<ペイン番号>.txt` (BOM 付き UTF-8) に書いて開きます。
  Notepad++ が無いときは、ファイルの場所を通知します。**このファイルは自動では消えません**。
  パスワードなどを表示したあとは、手で削除してください。
  なお、kitty の Ctrl+Shift+E (画面上の URL を選んで開く) は、この操作に差し替えています。URL を選んで開くには、コマンド一覧から実行します。
- **ログのスクロール**: PageUp / PageDown で 1 ページずつスクロールし、Ctrl+Home でログの先頭、Ctrl+End でログの末尾へ移動します。
  vim や less のような全画面のアプリの中では、そのアプリへキーをそのまま渡します。
  Ctrl+Shift+PageUp / PageDown / Home / End は従来どおりです。
  修飾キーなしの Home / End は割り当てていないので、シェルの入力行で行頭・行末へ移動できます。
  PowerShell (PSReadLine) の既定では、Ctrl+Home / Ctrl+End は入力行の「カーソルより前 / 後ろを削除」です。
  この割り当てがあるので、入力行ではその操作が使えません。
  戻したいときは `kitty_ja\commands.lua` の `scroll_log_top` と `scroll_log_bottom` の 2 行を消します。
- **起動のしかた**: スタートメニューの「WezTerm」(`wezterm-gui.exe`) から起動します。
  コンソール版の `wezterm.exe` を Explorer (「ファイル名を指定して実行」やアイコンのダブルクリック) から起動すると、
  WezTerm の窓とは別に、中身が空で入力できない「WezTerm」という名前のコンソールの窓 (Windows Terminal) が一緒に開きます。
  この窓は `wezterm.exe` の起動時に Windows が作るので、WezTerm の設定では出ないようにできません。

## 設定を変える

`kitty_ja\settings.lua` に、フォントサイズ・エディタ・タブ復元の有効/無効 (`session_enabled`) などがあります。
全項目は [docs/CONFIGURATION.md](docs/CONFIGURATION.md) を見てください。

- **PowerShell 7 の場所**: 既定のインストール先と PATH から自動で探します。Microsoft Store 版は自動で見つけられないので、
  ユーザーの環境変数 `KITTY_JA_PWSH` に `pwsh.exe` のパスを設定します (インストーラーがパスを表示します)。
- **エディタ**: Notepad++ があればそれを、無ければメモ帳を使います。
- 設定ファイルを書き換えると、WezTerm が自動で読み直します。手動なら Ctrl+Shift+F5 です。

### データ

`<ホーム>\.config\wezterm-kitty-ja\` に置かれます。PC ごとの内容なので、配布物には含まれません。

- `tab-colors\colors.txt`: タブ色の定義 (手で編集する)
- `tab-memory\memory.json`: フォルダごとのタブ名・タブ色の記憶
- `session\session.json`: 閉じたときのタブ構成。`session.json.bak` は直前の控え

## 安全のための制限

端末の中で動くプログラム (ssh 先のホストや、表示したファイルの中身) は、画面に好きな文字列や制御用の文字列を出せます。
それを悪用されないよう、次の制限を入れています。詳しい考え方は [docs/SECURITY-MODEL.md](docs/SECURITY-MODEL.md) にあります。

- **フォルダの通知**: シェルが WezTerm へ現在のフォルダを知らせるとき、WezTerm が起動時に渡した合言葉を添えます。
  合言葉の合わない通知は無視します。合言葉の無い OSC 7 (WezTerm 標準のフォルダ通知) は、ドライブ文字で始まるパスに限って、
  フォルダの推定に使います。
- **タブの復元**: ドライブ文字で始まるフォルダ (`C:\...`) だけを復元します。ネットワークのパス (`\\server\share`) にいたペインは、
  その前にいたフォルダかホームで開きます。起動のたびに外部へ自動で接続するのを避けるためです。
- **画面のパスを開く** (選択範囲を開く Ctrl+Shift+O、パスを選んで開く Ctrl+Shift+P → Shift+F): 開くのは、この PC のドライブにある
  フォルダと、実行形式でない実在のファイルだけです (URL を開くのは Ctrl+Shift+O と、コマンド一覧の「画面上の URL を選んで開く」で、http(s) だけ)。
  `.exe` `.bat` `.lnk` `.ps1` などの実行される種類、拡張子の無い名前、ネットワークのパスは開きません。
- **ファイルの行を開く** (Ctrl+Shift+P → N): この PC のドライブにある実在のファイルだけをエディタに渡します。

脆弱性を見つけたときは、[SECURITY.md](SECURITY.md) の手順で報告してください。

## 設計と実装

| 資料 | 内容 |
|---|---|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | 全体の構成、モジュールの責務、設計上の工夫 |
| [docs/SECURITY-MODEL.md](docs/SECURITY-MODEL.md) | 想定する脅威と、制限ごとの実装 |
| [docs/KEYBINDINGS.md](docs/KEYBINDINGS.md) | 全コマンドとキー割り当ての一覧 |
| [docs/CONFIGURATION.md](docs/CONFIGURATION.md) | 設定項目・環境変数・データの置き場所 |
| [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | うまく動かないときの確認 |

要点:

- **コマンド表が唯一の定義元**: `kitty_ja\commands.lua` の 1 つの表から、キー割り当て (`keys.lua`) と日本語のコマンド一覧 (`palette.lua`) を作ります。
  キーと一覧の食い違いが起きない作りです。
- **物理キーで割り当て**: `phys:` 指定で、JIS 配列のように記号の文字が US 配列と違っても、同じキー位置で動かします。
- **PowerShell 5.1 でも 7 でも動くインストーラー**: 冪等 (何度実行しても同じ結果)、`-WhatIf` に対応、既存のファイルは消さずに残します。
- **配布物の検査**: zip を作る前に、個人のパスやメールアドレス、想定外の種類のファイル、文字コードや改行の誤りを検査し、1 件でもあれば zip を作りません。
- **インストーラーの自動テスト**: 使い捨てのホームフォルダに対して、インストール・再実行・バックアップ・アンインストール・中止の条件を確かめます。

## 開発

リポジトリを clone して使う場合は、コピーではなくリンクを張ると、ファイルを保存するたびに WezTerm が設定を読み直します。

```powershell
.\install.ps1 -Link
```

- `kitty_ja` はジャンクション、`.wezterm.lua` はシンボリックリンクになります。
  シンボリックリンクには開発者モードか管理者権限が要り、作れないときは `.wezterm.lua` だけコピーになります。
- `<ホーム>\.config\wezterm\wezterm.lua` という名前のファイルは作らないでください (`.wezterm.lua` より優先されてしまいます)。
- GUI を起動せずに、設定したキー割り当てを確かめるには `wezterm show-keys` を使います。

テストと配布用 zip の作成は、PowerShell 7 で実行します。

```powershell
.\tools\Test-Installer.ps1   # インストーラーと配布物の検査 (実際のホームには触らない)
.\tools\New-Package.ps1      # dist\ に zip と SHA-256 を出力する
```

zip に入るのは一覧にあるファイルだけで、git の履歴は入りません。
個人のパスやメールアドレスが紛れ込んでいると、zip を作らずに止まります。
貢献の手順は [CONTRIBUTING.md](CONTRIBUTING.md) を見てください。

## 開発について

このプロジェクトは、作者 (ringo2pie) の指示で、AI コーディングエージェントの [Claude Code](https://claude.com/claude-code) (Anthropic) が
実装・資料・テストを作成しました。

- 作者が決めたこと: 目的 (WezTerm を kitty と同じ操作にする)、仕様と範囲、ライセンス、公開の判断。
- Claude Code が行ったこと: Lua の設定モジュール、インストーラー、配布物の検査、テスト、資料の作成。
- 資料の記述は、コードを読んで確かめた内容に限っています。コードから確かめられないことは、その旨を書いています
  ([docs/SECURITY-MODEL.md](docs/SECURITY-MODEL.md) の 6 章など)。

## ライセンス

[MIT License](LICENSE)。

このプロジェクトは WezTerm・kitty・PowerShell・Notepad++ のコードを含みません。
利用しているソフトウェアとフォントの扱いは [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) に書いています。
WezTerm、kitty などの名称は、それぞれの権利者のものです。このプロジェクトは、それらの権利者とは無関係です。
