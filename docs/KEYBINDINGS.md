# キー割り当て (Key Bindings) 一覧

この表は `kitty_ja\commands.lua` のコマンド表から作った。

- 項目数 (全体): **79 件** (`module.entries` の静的な項目 69 件 + ペイン番号ジャンプ用に実行時生成される 10 件)
- うち hidden (日本語コマンドパレットに出さない項目): **18 件** (静的 8 件 + ペイン番号ジャンプ 10 件)
- 日本語コマンドパレットに出る項目: **61 件**

件数は手で数えず、`Select-String` で次のように数えて確認した。

```powershell
# "id = '" の総数 71 から、実行時に複数件を生成するテンプレート行 2 件 (ペイン番号ジャンプ用・タブ色用) を除く
(Select-String -Path kitty_ja\commands.lua -Pattern "id = '").Count   # 71
(Select-String -Path kitty_ja\commands.lua -Pattern "hidden = true").Count  # 9 (= 静的 8 行 + ループ内 1 行)
```

表の「キー」列は、`commands.lua` の `label` フィールドをそのまま使っている。2 段キー (例: `Ctrl+Shift+A>M`) は本資料で `→` に表記を変えている (例: `Ctrl+Shift+A → M`。意味は「Ctrl+Shift+A を押して離してから M を押す」)。`label` が `-` の項目は「未割当」と表記する。`hidden` の項目には `label` が無いため、「hidden の項目」の節で別途注記する。

## ヘルプ・設定 (6件)

| 操作 (日本語名) | キー | id |
|---|---|---|
| WezTerm 公式ヘルプを表示 | Ctrl+Shift+F1 | `show_doc` |
| WezTerm 設定を編集 | Ctrl+Shift+F2 | `edit_config` |
| 標準 Command Palette を開く | Ctrl+Shift+F3 | `command_palette` |
| WezTerm 設定を再読み込み | Ctrl+Shift+F5 | `reload_config` |
| デバッグ画面を表示 | Ctrl+Shift+F6 | `debug_config` |
| デバッグ画面 (Lua REPL) を開く | 未割当 | `debug_shell` |

- Ctrl+Shift+Esc は Windows がタスクマネージャーに予約しているため、割り当てていない (コードのコメントに明記)。
- `debug_config` と `debug_shell` は、どちらも同じアクション (`act.ShowDebugOverlay`) を呼ぶ。名前は違うが実装上は同じ画面が開く。

## タブ (7件)

| 操作 (日本語名) | キー | id |
|---|---|---|
| 新しいタブを作成 | Ctrl+Shift+T | `new_tab` |
| 現在のタブを閉じる | Ctrl+Shift+Q | `close_tab` |
| 次のタブへ移動 | Ctrl+Shift+Right | `next_tab` |
| 前のタブへ移動 | Ctrl+Shift+Left | `previous_tab` |
| タブを右へ移動 | Ctrl+Shift+. | `move_tab_forward` |
| タブを左へ移動 | Ctrl+Shift+, | `move_tab_backward` |
| 現在のタブ名を変更 | Ctrl+Shift+Alt+T | `set_tab_title` |

- `set_tab_title` は入力欄 (`PromptInputLine`) が開き、名前を入力する。空のまま Enter すると既定の名前に戻る (コード中の `description` 文字列より)。

## ウィンドウ・ペイン (12件)

| 操作 (日本語名) | キー | id |
|---|---|---|
| ペインのズームを切り替え (レイアウト切替の代替) | Ctrl+Shift+L | `next_layout` |
| 新しいペインを作成 | Ctrl+Shift+Enter | `new_window` |
| 現在のペインを閉じる | Ctrl+Shift+W | `close_window` |
| 新しい OS ウィンドウを作成 | Ctrl+Shift+N | `new_os_window` |
| ペインサイズ変更モード | Ctrl+Shift+R | `start_resizing_window` |
| 次のペインへ移動 | Ctrl+Shift+] | `next_window` |
| 前のペインへ移動 | Ctrl+Shift+[ | `previous_window` |
| ペインを前方へ移動 | Ctrl+Shift+F | `move_window_forward` |
| ペインを後方へ移動 | Ctrl+Shift+B | `move_window_backward` |
| ペインを選んで入れ替え (先頭へ移動の代替) | Ctrl+Shift+\` | `move_window_to_top` |
| 画面を見ながらペインを選択 | Ctrl+Shift+F7 | `focus_visible_window` |
| 画面を見ながらペインを入れ替え | Ctrl+Shift+F8 | `swap_with_window` |

- `move_window_to_top` のキーは JIS 配列では `@` の位置 (Shift+`@` が `` ` ``) にあたる (コードのコメント)。
- `move_window_to_top` / `focus_visible_window` / `swap_with_window` は `act.PaneSelect` によるオーバーレイ選択で、選択用の文字は `1234567890` (`PANE_SELECT_ALPHABET`)。
- `start_resizing_window` (Ctrl+Shift+R) は、専用のキーテーブル `resize_window` に入るアクション。このテーブルは `one_shot = false` で、明示的に抜けるまで同じキーを繰り返し使える。内容は `commands.lua` ではなく `keys.lua` に直接書かれており、id は無い。

  | キー | 動作 |
  |---|---|
  | w | 幅を広くする (+1) |
  | n | 幅を狭くする (-1) |
  | t | 高さを高くする (+1) |
  | s | 高さを低くする (-1) |
  | Ctrl+w | 幅を広くする (+2) |
  | Ctrl+n | 幅を狭くする (-2) |
  | Ctrl+t | 高さを高くする (+2) |
  | Ctrl+s | 高さを低くする (-2) |
  | Escape / q / Enter | モードを抜ける |

  拡大・縮小する方向は、進行方向 (幅なら右、高さなら下) にペインが隣接しているかどうかで自動的に決まる (`tab:get_pane_direction` の結果による。コード上の実装)。

## スクロール・履歴 (14件)

| 操作 (日本語名) | キー | id |
|---|---|---|
| 1行上へスクロール | Ctrl+Shift+Up (または Ctrl+Shift+K) | `scroll_line_up` |
| 1行下へスクロール | Ctrl+Shift+Down (または Ctrl+Shift+J) | `scroll_line_down` |
| 1ページ上へスクロール | Ctrl+Shift+PageUp | `scroll_page_up` |
| 1ページ下へスクロール | Ctrl+Shift+PageDown | `scroll_page_down` |
| ログを1ページ上へスクロール (全画面アプリ以外) | PageUp | `scroll_log_page_up` |
| ログを1ページ下へスクロール (全画面アプリ以外) | PageDown | `scroll_log_page_down` |
| ログの先頭へ移動 (全画面アプリ以外) | Ctrl+Home | `scroll_log_top` |
| ログの末尾へ移動 (全画面アプリ以外) | Ctrl+End | `scroll_log_bottom` |
| 履歴の先頭へ移動 | Ctrl+Shift+Home | `scroll_home` |
| 履歴の末尾へ移動 | Ctrl+Shift+End | `scroll_end` |
| 前のシェルプロンプトへ | Ctrl+Shift+Z | `scroll_to_previous_prompt` |
| 次のシェルプロンプトへ | Ctrl+Shift+X | `scroll_to_next_prompt` |
| スクロールバックを表示 (コピーモード) | Ctrl+Shift+H | `show_scrollback` |
| 直前コマンドの出力をコピー | Ctrl+Shift+G | `show_last_command_output` |

- 修飾キーなしの PageUp / PageDown と Ctrl+Home / Ctrl+End の挙動は、専用の節 (下記) で解説する。
- `scroll_to_previous_prompt` / `scroll_to_next_prompt` / `show_last_command_output` は、シェル側が OSC 133 でプロンプト位置を通知していることに依存する (`kitty_ja\shell\integration.ps1` が送る)。通知が来ていない場合、`show_last_command_output` は何もしない (コード上、ゾーンが 0 件なら処理を終える)。

## コピー・貼り付け (4件)

| 操作 (日本語名) | キー | id |
|---|---|---|
| 選択範囲をクリップボードへコピー | Ctrl+Shift+C | `copy_to_clipboard` |
| クリップボードから貼り付け | Ctrl+Shift+V | `paste_from_clipboard` |
| 選択範囲 (無ければクリップボード) を貼り付け | Ctrl+Shift+S (または Shift+Insert) | `paste_from_selection` |
| 選択内容を外部プログラムへ渡す | Ctrl+Shift+O | `pass_selection_to_program` |

- `paste_from_selection` は、Windows には Primary Selection が無いための代替実装。選択中の文字列があればそれを、無ければクリップボードを貼る (コードのコメント)。
- `pass_selection_to_program` には安全のための制限がある。開くのは http(s) の URL と、この PC のドライブにあるフォルダ・実行形式でない実在のファイルだけ (詳細は README.md の「安全のための制限」節)。

## 表示・フォント (9件)

| 操作 (日本語名) | キー | id |
|---|---|---|
| フォントを大きくする | Ctrl+Shift+= (または Ctrl+Shift+Keypad+) | `increase_font_size` |
| フォントを小さくする | Ctrl+Shift+- (または Ctrl+Shift+Keypad-) | `decrease_font_size` |
| フォントサイズを初期値へ戻す | Ctrl+Shift+Backspace | `reset_font_size` |
| フルスクリーン ON/OFF | Ctrl+Shift+F11 | `toggle_fullscreen` |
| 最大化 ON/OFF | Ctrl+Shift+F10 | `toggle_maximized` |
| 背景をより不透明にする | Ctrl+Shift+A → M | `opacity_more` |
| 背景をより透明にする | Ctrl+Shift+A → L | `opacity_less` |
| 背景を完全に不透明にする | Ctrl+Shift+A → 1 | `opacity_full` |
| 背景透明度を既定値へ戻す | Ctrl+Shift+A → D | `opacity_default` |

- JIS 配列では `=` の位置に `;` (+) があるため、Ctrl+Shift+; がこの機能に対応する (コードのコメント)。
- `increase_font_size` / `decrease_font_size` は、コマンドパレットから実行したとき (`action`) と、キーから実行したとき (`key_action`) で増減量が違う。パレットからは 1.0 ポイント刻み (`font_size_step_palette`)、キーからは 2.0 ポイント刻み (`font_size_step_key`)。
- `opacity_*` の 4 項目は Ctrl+Shift+A で始まる 2 段キー。詳細は下記「2段キー (chord)」の節。
- `toggle_maximized` は、WezTerm にウィンドウが最大化状態かどうかを取得する API が無いため、このアドオンが状態を自前で記憶している (コードのコメント)。

## URL・Hints (1件)

| 操作 (日本語名) | キー | id |
|---|---|---|
| 画面上の URL を選んで開く | Ctrl+Shift+E | `open_url_with_hints` |

- `act.QuickSelectArgs` によるオーバーレイ選択 (kitty の `kitten hints --type url` に相当)。開けるのは http(s) の URL のみ。
- **Ctrl+Shift+E は、キーからは動かない。** `.wezterm.lua` が Ctrl+Shift+E の割り当てを差し替えて、
  画面とスクロール履歴を `%TEMP%` の `wezterm-history-<日時>-pane-<ペイン番号>.txt` に書いて Notepad++ で開く操作 (イベント `open-scrollback-in-notepadpp`) にしている。
  同じ操作は Ctrl+Alt+Shift+F12 でも呼べる。この項目は、コマンド一覧 (Ctrl+Shift+F12) からだけ実行できる。
  このファイルは自動では消えない。

## 入力 (1件)

| 操作 (日本語名) | キー | id |
|---|---|---|
| Unicode 文字入力 | Ctrl+Shift+U | `unicode_input` |

## 端末 (1件)

| 操作 (日本語名) | キー | id |
|---|---|---|
| 端末をリセット | Ctrl+Shift+Delete | `reset_terminal` |

- `act.ClearScrollback 'ScrollbackAndViewport'` と `act.ResetTerminal` を `act.Multiple` で続けて実行する。

## タブ色 (固定の2件。色の切替キーは別節)

| 操作 (日本語名) | キー | id |
|---|---|---|
| タブ色設定 colors.txt を編集 | Ctrl+Shift+Alt+E | `edit_colors` |
| タブ色設定を再読み込み | Ctrl+Shift+Alt+R | `reload_colors` |

- `reload_colors` も `act.ReloadConfiguration` を呼ぶ。設定全体の再読み込みと同じアクションで、タブ色専用の再読み込み処理ではない。
- 実際に色を切り替えるキー (既定では Ctrl+Shift+Alt+0〜5) は `colors.txt` から実行時に生成される。件数は環境ごとの `colors.txt` の内容に依存するため、この表の 79 件には含めていない。詳細は「タブ色のキーと colors.txt」の節を見る。

## タブ記憶 (4件)

| 操作 (日本語名) | キー | id |
|---|---|---|
| タブ名・色をこのフォルダに記憶 | Ctrl+Shift+Alt+S | `memory_save` |
| このフォルダのタブ名・色を復元 | Ctrl+Shift+Alt+L | `memory_restore` |
| このフォルダの記憶を削除 | Ctrl+Shift+Alt+D | `memory_forget` |
| タブ記憶ファイル memory.json を編集 | 未割当 | `memory_edit` |

---

## hidden の項目 (日本語コマンドパレットに出ない。18件)

`commands.lua` には `hidden = true` の項目があり、`palette.lua` の `build_rows` がパレットの一覧作成時にこれらを明示的に除外する。キーは有効だが、パレットの検索には出ない。

### kitty 互換のための項目 (静的・8件)

commands.lua のコメントに「kitty の既定キーのうち commands.tsv に載っていないもの」とある項目。`name` / `yomi` フィールドが無いため、下表の「操作」列は `panes.lua` の `QuickSelectArgs` のラベル文字列や、アクション名から本資料が補った説明。

| 操作 | キー | id |
|---|---|---|
| 日本語コマンドパレットを開く | Ctrl+Shift+F12 | `palette` |
| 選択中の文字列 (無ければ空文字) でスクロールバックを検索する (`act.Search 'CurrentSelectionOrEmptyString'`) | Ctrl+Shift+/ | `search_scrollback` |
| パスを挿入 | Ctrl+Shift+P → F | `hint_insert_path` |
| パスを開く | Ctrl+Shift+P → Shift+F | `hint_open_path` |
| 行を挿入 | Ctrl+Shift+P → L | `hint_insert_line` |
| 単語を挿入 | Ctrl+Shift+P → W | `hint_insert_word` |
| ハッシュを挿入 | Ctrl+Shift+P → H | `hint_insert_hash` |
| ファイルの行を開く (「ファイル:行番号」をエディタで開く) | Ctrl+Shift+P → N | `hint_open_line_number` |

- `search_scrollback` の検索ダイアログ自体の詳しい動作 (`act.Search`) は WezTerm 本体の機能で、このリポジトリのコードからは確認できない。
- `hint_open_path` / `hint_open_line_number` にも、README.md に書かれている安全のための制限 (この PC のドライブにある実在のファイル・フォルダのみを開く) が適用される。

### ペインへの番号ジャンプ (実行時生成・10件)

`commands.lua` の末尾にある `for pane_number = 1, 10 do` のループで生成される。

```lua
for pane_number = 1, 10 do
  table.insert(module.entries, {
    id = 'pane_' .. pane_number,
    keys = { 'ctrl+shift+' .. tostring(pane_number % 10) },
    hidden = true,
    action = act.ActivatePaneByIndex(pane_number - 1),
  })
end
```

| キー | id | アクション |
|---|---|---|
| Ctrl+Shift+1 | `pane_1` | `ActivatePaneByIndex(0)` |
| Ctrl+Shift+2 | `pane_2` | `ActivatePaneByIndex(1)` |
| Ctrl+Shift+3 | `pane_3` | `ActivatePaneByIndex(2)` |
| Ctrl+Shift+4 | `pane_4` | `ActivatePaneByIndex(3)` |
| Ctrl+Shift+5 | `pane_5` | `ActivatePaneByIndex(4)` |
| Ctrl+Shift+6 | `pane_6` | `ActivatePaneByIndex(5)` |
| Ctrl+Shift+7 | `pane_7` | `ActivatePaneByIndex(6)` |
| Ctrl+Shift+8 | `pane_8` | `ActivatePaneByIndex(7)` |
| Ctrl+Shift+9 | `pane_9` | `ActivatePaneByIndex(8)` |
| Ctrl+Shift+0 | `pane_10` | `ActivatePaneByIndex(9)` |

- ペインの「番号 (インデックス)」が画面上のどの位置に対応するかは WezTerm 本体の `ActivatePaneByIndex` の仕様によるもので、このリポジトリのコードからは確認できない。

---

## 2段キー (chord)

`keys.lua` の `CHORD_TABLE_NAMES` に、1段目のキーとキーテーブル名の対応がある。

| 1段目 | キーテーブル名 | 2段目で選べるもの |
|---|---|---|
| Ctrl+Shift+A | `opacity` | M (不透明に) / L (透明に) / 1 (完全不透明) / D (既定へ) |
| Ctrl+Shift+P | `hints` | F (パス挿入) / Shift+F (パスを開く) / L (行挿入) / W (単語挿入) / H (ハッシュ挿入) / N (ファイルの行を開く) |

`keys.lua` のコメントに「1段目でキーテーブルに入り、次の1打鍵で抜ける」とあるとおり、これらのキーテーブルは `one_shot = true` かつ `until_unknown = true` で登録され、さらに明示的に Escape → `PopKeyTable` (テーブルを抜ける) が追加されている。

上記の「ペインサイズ変更モード」(`resize_window` キーテーブル) は、`one_shot = false` で登録されており、1打鍵では抜けない常駐モードである点が異なる。

---

## タブ色のキーと colors.txt

### colors.txt の書式 (`kitty_ja\tab_colors.lua` の `load_colors` が読む)

```
KEY | 名前 | 選択中背景色 | 非選択背景色 | 選択中文字色(省略可) | 非選択文字色(省略可)
```

- `#` で始まる行と、空行は読み飛ばす。
- フィールドは `|` 区切りで前後の空白を取り除く (`trim`)。4〜6 個のフィールドが必須で、それ以外の行数はエラーとしてログに警告を出し、その行はスキップする。
- **KEY**: 1 桁の数字 (`0`〜`9`) なら `ctrl+shift+alt+<数字>` に自動変換される。それ以外は完全なキー指定 (例: `ctrl+shift+alt+f8`) として、英数字・`_+-.,<>/` のみを許可し小文字化してそのまま使う。
- **色**: `#RRGGBB` (16進6桁) か、大小文字を問わない `NONE`。`NONE` は WezTerm の既定色へ戻す指定として扱われる (内部的には `nil` にマップされ、その要素だけ既定色に委ねる)。
- **選択中文字色・非選択文字色は省略可**。省略すると、対応する背景色の相対輝度 (sRGB をリニアライズし `0.2126R + 0.7152G + 0.0722B` で計算) が 0.45 より大きければ黒 (`#000000`)、そうでなければ白 (`#FFFFFF`) を自動で選ぶ (`auto_foreground`、kitty 側の `generate_colors.py` の `auto_foreground` と同じ計算、とコードのコメントにある)。
- 表示用のキー表記 (`display_key`) は、修飾キー名を `Ctrl` / `Shift` / `Alt` / `Super` / `Cmd` に変換し、それ以外の部分は 1 文字なら大文字化、複数文字なら先頭だけ大文字化して組み立てる。

### 配布時点の既定ファイル (`defaults\colors.txt`) — 6件

| KEY | 名前 | 選択中背景色 | 非選択背景色 | 文字色 |
|---|---|---|---|---|
| 0 | デフォルト | NONE | NONE | NONE / NONE (既定色へ戻す) |
| 1 | 赤 | #B71C1C | #4B2020 | 省略 (自動計算) |
| 2 | 青 | #1565C0 | #203A58 | 省略 (自動計算) |
| 3 | 緑 | #2E7D32 | #254629 | 省略 (自動計算) |
| 4 | 紫 | #6A1B9A | #442450 | 省略 (自動計算) |
| 5 | オレンジ | #EF6C00 | #5D381D | 省略 (自動計算) |

対応するキーは既定で Ctrl+Shift+Alt+0〜5。6〜9 は `colors.txt` に追記すれば使える (KEY 列に数字を書くだけで `ctrl+shift+alt+<数字>` になる)。

### 反映

- `colors.txt` は `wezterm.add_to_config_reload_watch_list` に登録されている (`kitty_ja\init.lua`)。保存すると WezTerm が設定を再読み込みし、タブ色の直接キーも更新される。Ctrl+Shift+Alt+R (`reload_colors`) でも同じ再読み込みができる。
- 日本語コマンドパレットは、開くたびに `colors.txt` を読み直す (`palette.lua` の `build_rows` が毎回 `tab_colors.load_colors()` を呼ぶ)。そのため、パレット経由のタブ色変更は保存するだけで反映され、再読み込みを待たなくてよい。

---

## 修飾キーなしの PageUp / PageDown と Ctrl+Home / Ctrl+End

`commands.lua` のコメントに「kitty には無い、この設定だけの割り当て」とある (kitty では、修飾キーなしの PageUp / PageDown と Ctrl+Home / Ctrl+End はそのままアプリへ渡る)。

実装は `scroll_or_pass_through(scroll_action, key_name, mods)` という関数で、`pane:is_alt_screen_active()` (代替画面 = alternate screen を使っているか) によって動作を分ける。

| 画面の状態 | PageUp | PageDown | Ctrl+Home | Ctrl+End |
|---|---|---|---|---|
| 通常画面 (alt screen でない) | 1ページ上へスクロール (`ScrollByPage(-1)`) | 1ページ下へスクロール (`ScrollByPage(1)`) | ログの先頭へ移動 (`ScrollToTop`) | ログの末尾へ移動 (`ScrollToBottom`) |
| 代替画面 (vim / less など全画面アプリ) | そのアプリへ `PageUp` キーをそのまま渡す | そのアプリへ `PageDown` キーをそのまま渡す | そのアプリへ `Ctrl+Home` キーをそのまま渡す | そのアプリへ `Ctrl+End` キーをそのまま渡す |

- Ctrl+Shift+PageUp / PageDown / Home / End (上の「スクロール・履歴」節の `scroll_page_up` 等) は、この分岐を持たず、常に通常のスクロール動作になる。
- 修飾キーなしの Home / End は割り当てていない。シェルの入力行 (コマンドラインの編集中) で、行頭・行末への移動にそのまま使える。
- Ctrl+Home / Ctrl+End を WezTerm が受け取るので、PowerShell (PSReadLine) の既定の割り当て (Ctrl+Home = `BackwardDeleteInput`、Ctrl+End = `ForwardDeleteInput`。`Get-PSReadLineKeyHandler` で確認した) は、シェルの入力行では使えない。元に戻すには `commands.lua` の `scroll_log_top` と `scroll_log_bottom` の 2 行を消す。

---

## コマンド一覧 (Ctrl+Shift+F12) の使い方

Ctrl+Shift+F12 (id: `palette`) で、WezTerm 内蔵の `InputSelector` (`fuzzy = true`) を使った日本語コマンドパレットが開く (`kitty_ja\palette.lua`)。

- 各行は「キー表記 / 操作名 / カテゴリ」を画面幅に応じた桁数で整形して表示する (画面の桁数が 90 以上 / 70 以上 / それ未満で列幅が 3 段階に変わる)。
- 先頭の行は「未割当コマンドの表示: ON/OFF (選ぶと切り替え)」のトグル。選ぶと表示・非表示を切り替えて一覧を開き直す。既定は ON (未割当のコマンドも表示する)。この状態は `wezterm.GLOBAL` に保持されるが、WezTerm の再起動後も保持されるかどうかは、このリポジトリのコードからは確認できない。
- `hidden = true` の項目は、常に一覧に出ない (上記「hidden の項目」節を参照)。

### ローマ字・英語での検索

WezTerm の `InputSelector` は IME で確定した文字を受け取れず、日本語そのものでは検索できない (`palette.lua` のコメントに明記)。そのため各行の画面外に、読みのローマ字と `id` を検索語として埋め込んでいる。検索欄には半角でそのまま入力する。

- **ヘボン式ローマ字**: `commands.lua` の `yomi` フィールドをそのまま使う (例: `tabu wo migi he idou`)。
- **訓令式ローマ字**: `to_kunrei` 関数がヘボン式から変換する (`shi→si`、`chi→ti`、`tsu→tu`、`fu→hu`、`ji→zi`、`sha→sya` など)。
- **打ち方を混ぜても当たる綴り**: `to_loose` 関数が、どちらの打ち方でも検索語にマッチするよう両方の文字を綴りに含める (例: し → `shi` のまま一致、ち → `tchi`、ふ → `hfu`、じ → `zji`、しゃ → `shya`、ちゃ → `tchya`、じゃ → `zjya`。また母音・`y` の前以外の `n` は `nn` としても一致する)。
- **英語 / id**: 各項目の `id` (例: `new_tab`、`scroll_line_up`) もそのまま検索語に含まれる。
- **タブ色の項目**: 色名の読み・英語 (`palette.lua` の `COLOR_KEYWORDS` に無い色名は読みと `color` のみ) で検索できる。

検索はラベル全体 (画面に見える部分 + 画面外の検索語) に対するあいまい一致 (fuzzy match) で行われる。
