-- wezterm --config-file tools/Test-Unwrap.lua show-keys
-- 選択した文字列から、折り返しの改行だけが消えることを確かめる。素材は 2026-11-20 に実機で採った表示。
local wezterm = require 'wezterm'
local root = wezterm.config_dir .. '/../kitty_ja/'
local environment = setmetatable({
  require = function(name)
    if name == 'wezterm' then return wezterm end
    error('Unexpected module: ' .. name)
  end,
}, { __index = _G })
local unwrap = assert(loadfile(root .. 'unwrap.lua', 't', environment))()

local failures = {}
local function check(label, actual, expected)
  if actual ~= expected then
    table.insert(failures, label .. '\n  expected: ' .. expected:gsub('\n', '\\n') .. '\n  actual:   ' .. tostring(actual):gsub('\n', '\\n'))
  end
end
local function lines(...)
  return table.concat({ ... }, '\n')
end

-- Claude Code (149 桁): 日本語の塊が入らず、空白の位置で改行した
check('Claude: 英語と日本語の境目',
  unwrap.join(lines(
    '● マウス割り当ては既定のままで、Claude Code / Codex が自前で改行を入れるため、WezTerm',
    '  の折り返し結合が効いていません。方針を決めるため、2点確認します。'), 149),
  '● マウス割り当ては既定のままで、Claude Code / Codex が自前で改行を入れるため、WezTerm の折り返し結合が効いていません。方針を決めるため、2点確認します。')

-- Claude Code: 幅を超える日本語の塊は、塊の中で強制改行される (空白を入れない)
check('Claude: 塊の中の強制改行',
  unwrap.join(lines(
    '  ⎿  · Claude Code / Codex',
    '     は単語の切れ目で自前の改行を入れるため、「次の行の先頭の語が前の行に入りきらなかったら結合する」という推定が要ります。通常',
    '     のシェル出力（ログなど）にも同じ推定をかけると、長めのログ行が誤って結合されることがあります。推定をどこで使いますか？ →',
    '     常に推定する',
    '     · Ctrl+Shift+C（選択範囲をクリップボードへコピー）にも同じ折り返し除去をかけますか？ → かける (Recommended)'), 128),
  lines(
    '  ⎿  · Claude Code / Codex は単語の切れ目で自前の改行を入れるため、「次の行の先頭の語が前の行に入りきらなかったら結合する」という推定が要ります。通常のシェル出力（ログなど）にも同じ推定をかけると、長めのログ行が誤って結合されることがあります。推定をどこで使いますか？ → 常に推定する',
    '     · Ctrl+Shift+C（選択範囲をクリップボードへコピー）にも同じ折り返し除去をかけますか？ → かける (Recommended)'))

-- Claude Code: 箇条書きの続き行と、次の項目
check('Claude: 箇条書き',
  unwrap.join(lines(
    '     - 境目の両側が CJK（全角）なら空白なしで結合。行 i が空白を含まない 1 語で幅いっぱい（長い URL やパスの強制改行）なら空白なし。それ以外は空白 1',
    '       個で結合。',
    '     - kitty_ja\\unwrap.lua（新規）: join と、copy_selection(window, pane)（選択文字列 → join → window:copy_to_clipboard(text, \'Clipboard\')）。cols は',
    '       pane:get_dimensions().cols、幅は wezterm.column_width。',
    '     - kitty_ja\\panes.lua: 既存の guarded で包んだ copy_selection_unwrapped を追加（unwrap.copy_selection を呼ぶ）。'), 149),
  lines(
    '     - 境目の両側が CJK（全角）なら空白なしで結合。行 i が空白を含まない 1 語で幅いっぱい（長い URL やパスの強制改行）なら空白なし。それ以外は空白 1 個で結合。',
    '     - kitty_ja\\unwrap.lua（新規）: join と、copy_selection(window, pane)（選択文字列 → join → window:copy_to_clipboard(text, \'Clipboard\')）。cols は pane:get_dimensions().cols、幅は wezterm.column_width。',
    '     - kitty_ja\\panes.lua: 既存の guarded で包んだ copy_selection_unwrapped を追加（unwrap.copy_selection を呼ぶ）。'))

-- Claude Code: 空行・見出し・ツールの出力・罫線は結合しない
local claude_blocks = lines(
  '● Updated plan',
  '  ⎿  /plan to preview',
  '',
  '     方式',
  '',
  '─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────',
  '❯',
  '│ ✨ Update available! 0.167.1 -> 0.169.0                                                                                                           │')
check('Claude: 区切りを残す', unwrap.join(claude_blocks, 149), claude_blocks)

-- Codex (100 桁): 日本語を 1 文字単位で折り返す
check('Codex: 段落',
  unwrap.join(lines(
    '• WezTerm と Windows Terminal は、どちらも shell を表示・操作する terminal emulator で、タブや pane',
    '  分割で作業を並べられます。WezTerm は Windows・macOS・Linux などに対応し、Lua で設定や動作を組み立',
    '  てられる点が特徴です。内蔵 SSH client や multiplexer もあり、複数環境で操作感をそろえたい人に向き',
    '  ます。一方、Windows Terminal は Windows 向けで、PowerShell、コマンドプロンプト、WSL をまとめて扱え',
    '  ます。設定は GUI を中心に変更でき、JSON での編集も可能です。選ぶ目安は、OS をまたいだ共通化やプロ',
    '  グラムによるカスタマイズを重視するなら WezTerm、Windows 上での設定の手軽さを重視するなら Windows',
    '  Terminal です。',
    '',
    '  • 対応 OS：WezTerm は cross-platform、Windows Terminal は Windows 向け。',
    '  • 設定方法：WezTerm は Lua、Windows Terminal は GUI と JSON。'), 100),
  lines(
    '• WezTerm と Windows Terminal は、どちらも shell を表示・操作する terminal emulator で、タブや pane 分割で作業を並べられます。WezTerm は Windows・macOS・Linux などに対応し、Lua で設定や動作を組み立てられる点が特徴です。内蔵 SSH client や multiplexer もあり、複数環境で操作感をそろえたい人に向きます。一方、Windows Terminal は Windows 向けで、PowerShell、コマンドプロンプト、WSL をまとめて扱えます。設定は GUI を中心に変更でき、JSON での編集も可能です。選ぶ目安は、OS をまたいだ共通化やプログラムによるカスタマイズを重視するなら WezTerm、Windows 上での設定の手軽さを重視するなら Windows Terminal です。',
    '',
    '  • 対応 OS：WezTerm は cross-platform、Windows Terminal は Windows 向け。',
    '  • 設定方法：WezTerm は Lua、Windows Terminal は GUI と JSON。'))

check('Codex: 入力欄',
  unwrap.join(lines(
    '› ファイルは読まずに答えて。WezTerm と Windows Terminal の違いを、日本語と英単語を混ぜて 400 字の段 ',
    '  落 1 つと、3 項目の箇条書きで説明して。'), 100),
  '› ファイルは読まずに答えて。WezTerm と Windows Terminal の違いを、日本語と英単語を混ぜて 400 字の段落 1 つと、3 項目の箇条書きで説明して。')

-- 長い URL の強制改行は空白を入れずにつなぐ
local url = 'https://example.com/' .. string.rep('a', 60)
check('URL', unwrap.join(lines(url:sub(1, 40), url:sub(41)), 40), url)

-- 短い行が並ぶ通常の出力はそのまま
local short = lines('PS E:\\> ls', '', 'Mode  LastWriteTime  Name', '----  -------------  ----', 'd---- 2026/11/20     kitty_ja')
check('短い行', unwrap.join(short, 80), short)

-- 選択が行の途中から始まるときは、左の選択していない部分を足して判定する
check('1 行目の途中から',
  unwrap.join(lines('word word word', 'longword'), 30, 10), 'word word word longword')
check('1 行目の途中から (足さないと結合しない)',
  unwrap.join(lines('word word word', 'longword'), 30, 0), lines('word word word', 'longword'))

-- WezTerm が自動の折り返しを結合済みの長い行は、最後の段の幅で判定する
check('結合済みの長い行', unwrap.join(lines(string.rep('x', 150), 'next line'), 100), lines(string.rep('x', 150), 'next line'))

-- 改行コード CRLF を保つ。末尾の改行も残す
check('CRLF', unwrap.join('one two three four\r\nfive\r\nsix', 20), 'one two three four five\r\nsix')
check('末尾の改行', unwrap.join('abc\n', 80), 'abc\n')
check('空', unwrap.join('', 80), '')

-- 画面の行の末尾との一致で、1 行目より左の桁数を求める
local pane = { get_lines_as_text = function() return '❯ 日本語 abc def\nother\n' end }
assert(unwrap.first_prefix_width(pane, 'abc def\nxyz') == 9, 'prefix width')
assert(unwrap.first_prefix_width(pane, 'zzz\nxyz') == 0, 'prefix not found')
local ambiguous = { get_lines_as_text = function() return 'a x\nb x\n' end }
assert(unwrap.first_prefix_width(ambiguous, 'x') == 0, 'ambiguous prefix')

-- クリップボードへは結合後の文字列を入れる
local copied, destination
local window = {
  get_selection_text_for_pane = function() return 'aaaa bbbb\ncccccc' end,
  copy_to_clipboard = function(_, text, target) copied, destination = text, target end,
}
local fake_pane = { get_dimensions = function() return { cols = 12 } end, get_lines_as_text = function() return '' end }
assert(unwrap.copy_selection(window, fake_pane, 'ClipboardAndPrimarySelection') == true, 'copy result')
assert(copied == 'aaaa bbbb cccccc' and destination == 'ClipboardAndPrimarySelection', 'copied text: ' .. tostring(copied))
window.get_selection_text_for_pane = function() return '' end
copied = nil
assert(unwrap.copy_selection(window, fake_pane) == false and copied == nil, 'empty selection copied')

if #failures > 0 then
  -- show-keys は設定のエラーを表示しないことがあるので、ログにも出す
  wezterm.log_error('FAIL:\n' .. table.concat(failures, '\n'))
  error('FAIL:\n' .. table.concat(failures, '\n'))
end
print('PASS: Claude Code / Codex の折り返し、区切りの保持、URL、CRLF、選択の途中開始')
return {}
