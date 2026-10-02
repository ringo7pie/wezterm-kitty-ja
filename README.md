# wezterm-kitty-ja

Windows の WezTerm を、kitty + kitty-ja-shortcuts と同じ動作・同じショートカットキーにする設定。

- kitty と同じキー操作 (JIS 配列でも同じキー位置で動く)
- 日本語のコマンド一覧 (Ctrl+Shift+F12)
- タブ色の切り替えと、フォルダごとのタブ名・タブ色の記憶
- 閉じたときのタブとペイン分割を、次回の起動時に復元

## 必要なもの

| ソフト | 入れ方 |
|---|---|
| WezTerm (20240203 版で動作を確認) | `winget install --id wez.wezterm --source winget` |
| PowerShell 7 | `winget install --id Microsoft.PowerShell --source winget` |

Windows 標準の Windows PowerShell 5.1 だけでは動かない (シェルとして PowerShell 7 を使う)。
インストールスクリプトはこれらを自動では入れない。無ければ入れ方を表示して止まる。

## インストール

1. zip を展開する。
2. 展開したフォルダの `install.cmd` をダブルクリックする。
3. WezTerm を起動し直す。

コマンドで実行する場合は、PowerShell で次のようにする。`-WhatIf` を付けると、何をするかを表示するだけで何も変更しない。

```powershell
.\install.ps1 -WhatIf
.\install.ps1
```

「スクリプトの実行が無効」と表示されたら、`install.cmd` を使うか、次のように実行する。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

### インストールスクリプトがすること

| 配布物 | 置く場所 |
|---|---|
| `kitty_ja\` | `<ホーム>\.config\wezterm\kitty_ja\` |
| `.wezterm.lua` | `<ホーム>\.wezterm.lua` |
| `defaults\colors.txt` | `<ホーム>\.config\wezterm-kitty-ja\tab-colors\colors.txt` (無いときだけ) |

- 既にある `kitty_ja` や `.wezterm.lua` は消さず、名前に `.bak-<日時>` を付けて残す。
  それがリンク (ジャンクション・シンボリックリンク) のときは、リンクだけを消す。リンク先には触らない。
  リンク先のパスは、取得できた場合に表示する。
- 置いたファイルから「インターネットから入手したファイル」の印を外す (付いたままだと PowerShell がシェル連携スクリプトを実行しない)。
- ソフトのダウンロードやインストール、レジストリや環境変数の変更、管理者権限の要求はしない。ネットワークには接続しない。
- `<ホーム>\.config\wezterm\wezterm.lua` が既にあると、WezTerm はそちらを優先して `.wezterm.lua` を読まない。この場合は何も変更せずに止まる。
  環境変数 `XDG_CONFIG_HOME` が設定されている場合も、WezTerm が見る設定フォルダが変わるので止まる。
- `install.cmd` は、Windows 付属の PowerShell (`%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe`) で `install.ps1` を実行する。
  `-ExecutionPolicy Bypass` はその 1 回の実行だけに効き、PC の設定は変えない。

### 更新

新しい zip を展開して、もう一度 `install.cmd` を実行する。前の `kitty_ja` は `.bak-<日時>` として残る。

### アンインストール

`uninstall.cmd` をダブルクリックする。`kitty_ja` と `.wezterm.lua` は消さずに、名前へ `.removed-<日時>` を付けて残す。
データ (`<ホーム>\.config\wezterm-kitty-ja\`) はそのまま残るので、不要なら手で削除する。

## 使い方

- **コマンド一覧**: Ctrl+Shift+F12。キーの割り当てはここで確認できる。
- **一覧の検索**: 半角でそのまま打つ。読みのローマ字 (`tabu`、`pein`、`haritsuke`) か英語 (`new_tab`、`scroll`) で絞り込む。
  ヘボン式・訓令式 (`ti`、`hu`、`zi`)、`jya`、`nn` のどれで打ってもよい。
  WezTerm の選択画面は IME の入力を受け取れないので、日本語そのものでは検索できない。
- **タブ色**: Ctrl+Shift+Alt+数字。色の定義は `colors.txt` (Ctrl+Shift+Alt+E で開く)。
- **タブの復元**: WezTerm を閉じて開き直すと、タブ・ペイン分割・フォルダ・タブ名・タブ色が戻る。
  実行中だったプログラムと画面の文字は戻らない。

## 安全のための制限

端末の中で動くプログラム (ssh 先のホストや、表示したファイルの中身) は、画面に好きな文字列や制御用の文字列を出せる。
それを悪用されないよう、次の制限を入れている。

- **フォルダの通知**: シェルが WezTerm へ現在のフォルダを知らせるとき、WezTerm が起動時に渡した合言葉を添える。
  合言葉の無い通知は使わない。
- **タブの復元**: ドライブ文字で始まるフォルダ (`C:\...`) だけを復元する。ネットワークのパス (`\\server\share`) にいたペインは、
  その前にいたフォルダかホームで開く。起動のたびに外部へ自動で接続するのを避けるため。
- **画面のパスを開く** (Ctrl+Shift+P → Shift+F、Ctrl+Shift+O): 開くのは http(s) の URL と、この PC のドライブにある
  フォルダ・実行形式でない実在のファイルだけ。`.exe` `.bat` `.lnk` `.ps1` などの実行される種類と、ネットワークのパスは開かない。
- **ファイルの行を開く** (Ctrl+Shift+P → N): この PC のドライブにある実在のファイルだけをエディタに渡す。

## データ

`<ホーム>\.config\wezterm-kitty-ja\` に置かれる。PC ごとの内容なので、配布物には含まれない。

- `tab-colors\colors.txt`: タブ色の定義 (手で編集する)
- `tab-memory\memory.json`: フォルダごとのタブ名・タブ色の記憶
- `session\session.json`: 閉じたときのタブ構成。`session.json.bak` は直前の控え

## 設定を変える

`kitty_ja\settings.lua` に、フォントサイズ・エディタ・タブ復元の有効/無効 (`session_enabled`) などがある。

- **PowerShell 7 の場所**: 既定のインストール先と PATH から自動で探す。Microsoft Store 版は自動で見つけられないので、
  ユーザーの環境変数 `KITTY_JA_PWSH` に `pwsh.exe` のパスを設定する (インストールスクリプトがパスを表示する)。
- **エディタ**: Notepad++ があればそれを、無ければメモ帳を使う。

## 開発

リポジトリを clone して使う場合は、コピーではなくリンクを張ると、ファイルを保存するたびに WezTerm が設定を読み直す。

```powershell
.\install.ps1 -Link
```

- `kitty_ja` はジャンクション、`.wezterm.lua` はシンボリックリンクになる。
  シンボリックリンクには開発者モードか管理者権限が要り、作れないときは `.wezterm.lua` だけコピーになる。
- `<ホーム>\.config\wezterm\wezterm.lua` という名前のファイルは作らない (`.wezterm.lua` より優先されてしまう)。

配布用の zip は PowerShell 7 で次を実行して作る。`dist\` に zip と SHA-256 が出力される。

```powershell
.\tools\New-Package.ps1
```

zip に入るのは一覧にあるファイルだけで、git の履歴は入らない。
個人のパスやメールアドレスが紛れ込んでいると、zip を作らずに止まる。
