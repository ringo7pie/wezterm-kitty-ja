-- コマンド表。キー定義 (keys.lua) と日本語コマンドパレット (palette.lua) の唯一の定義元。
--
-- 各項目:
--   id        パレットで選ばれたときの識別子
--   keys      キー指定の配列。'ctrl+shift+a>m' は「Ctrl+Shift+A を押して離してから M」
--   label     パレットに出すキー表記。'-' は未割当
--   name      日本語名 (kitty 側の jp-palette/commands.tsv と同じ。動作が違うものだけ言い換え)
--   category  カテゴリ
--   action    パレットから実行するアクション
--   key_action キーから実行するアクション (省略時は action と同じ)
--   hidden    true ならパレットに出さない (kitty の既定キーのうち commands.tsv に無いもの)
local wezterm = require 'wezterm'
local settings = require 'kitty_ja.settings'
local panes = require 'kitty_ja.panes'
local tab_colors = require 'kitty_ja.tab_colors'
local tab_memory = require 'kitty_ja.tab_memory'

local act = wezterm.action
local module = {}

local PANE_SELECT_ALPHABET = '1234567890'

local function callback(handler)
  return wezterm.action_callback(function(window, pane)
    local ok, err = pcall(handler, window, pane)
    if not ok then
      wezterm.log_error('kitty_ja commands: ' .. tostring(err))
    end
  end)
end

local function memory_command(command)
  return callback(function(window, _pane)
    tab_memory.run_command(window, command)
  end)
end

local open_palette = callback(function(window, pane)
  require('kitty_ja.palette').show(window, pane)
end)

local open_documentation = callback(function(_window, _pane)
  wezterm.open_with(settings.documentation_url)
end)

local edit_config_file = callback(function(_window, _pane)
  tab_memory.open_in_editor(wezterm.config_file)
end)

local edit_colors_file = callback(function(_window, _pane)
  tab_memory.open_in_editor(settings.colors_file)
end)

-- set_tab_title: 入力した名前を付ける。空文字で既定の名前に戻す
local rename_tab = act.PromptInputLine {
  description = 'タブ名を入力 (空のまま Enter で既定の名前に戻す)',
  action = wezterm.action_callback(function(window, _pane, line)
    if line == nil then
      return
    end
    tab_memory.set_active_tab_title(window, line)
  end),
}

module.entries = {
  -- ヘルプ・設定
  { id = 'show_doc', keys = { 'ctrl+shift+f1' }, label = 'Ctrl+Shift+F1', name = 'WezTerm 公式ヘルプを表示', category = 'ヘルプ・設定', action = open_documentation },
  { id = 'edit_config', keys = { 'ctrl+shift+f2' }, label = 'Ctrl+Shift+F2', name = 'WezTerm 設定を編集', category = 'ヘルプ・設定', action = edit_config_file },
  { id = 'command_palette', keys = { 'ctrl+shift+f3' }, label = 'Ctrl+Shift+F3', name = '標準 Command Palette を開く', category = 'ヘルプ・設定', action = act.ActivateCommandPalette },
  { id = 'reload_config', keys = { 'ctrl+shift+f5' }, label = 'Ctrl+Shift+F5', name = 'WezTerm 設定を再読み込み', category = 'ヘルプ・設定', action = act.ReloadConfiguration },
  { id = 'debug_config', keys = { 'ctrl+shift+f6' }, label = 'Ctrl+Shift+F6', name = 'デバッグ画面を表示', category = 'ヘルプ・設定', action = act.ShowDebugOverlay },
  -- Ctrl+Shift+Esc は Windows がタスクマネージャーに予約しているので割り当てない
  { id = 'debug_shell', keys = {}, label = '-', name = 'デバッグ画面 (Lua REPL) を開く', category = 'ヘルプ・設定', action = act.ShowDebugOverlay },

  -- タブ
  { id = 'new_tab', keys = { 'ctrl+shift+t' }, label = 'Ctrl+Shift+T', name = '新しいタブを作成', category = 'タブ', action = act.SpawnCommandInNewTab { cwd = settings.home_dir } },
  { id = 'close_tab', keys = { 'ctrl+shift+q' }, label = 'Ctrl+Shift+Q', name = '現在のタブを閉じる', category = 'タブ', action = act.CloseCurrentTab { confirm = false } },
  { id = 'next_tab', keys = { 'ctrl+shift+right' }, label = 'Ctrl+Shift+Right', name = '次のタブへ移動', category = 'タブ', action = act.ActivateTabRelative(1) },
  { id = 'previous_tab', keys = { 'ctrl+shift+left' }, label = 'Ctrl+Shift+Left', name = '前のタブへ移動', category = 'タブ', action = act.ActivateTabRelative(-1) },
  { id = 'move_tab_forward', keys = { 'ctrl+shift+.' }, label = 'Ctrl+Shift+.', name = 'タブを右へ移動', category = 'タブ', action = act.MoveTabRelative(1) },
  { id = 'move_tab_backward', keys = { 'ctrl+shift+,' }, label = 'Ctrl+Shift+,', name = 'タブを左へ移動', category = 'タブ', action = act.MoveTabRelative(-1) },
  { id = 'set_tab_title', keys = { 'ctrl+shift+alt+t' }, label = 'Ctrl+Shift+Alt+T', name = '現在のタブ名を変更', category = 'タブ', action = rename_tab },

  -- ウィンドウ・ペイン
  { id = 'next_layout', keys = { 'ctrl+shift+l' }, label = 'Ctrl+Shift+L', name = 'ペインのズームを切り替え (レイアウト切替の代替)', category = 'ウィンドウ・ペイン', action = act.TogglePaneZoomState },
  { id = 'new_window', keys = { 'ctrl+shift+enter' }, label = 'Ctrl+Shift+Enter', name = '新しいペインを作成', category = 'ウィンドウ・ペイン', action = panes.new_window },
  { id = 'close_window', keys = { 'ctrl+shift+w' }, label = 'Ctrl+Shift+W', name = '現在のペインを閉じる', category = 'ウィンドウ・ペイン', action = act.CloseCurrentPane { confirm = false } },
  { id = 'new_os_window', keys = { 'ctrl+shift+n' }, label = 'Ctrl+Shift+N', name = '新しい OS ウィンドウを作成', category = 'ウィンドウ・ペイン', action = act.SpawnCommandInNewWindow { cwd = settings.home_dir } },
  { id = 'start_resizing_window', keys = { 'ctrl+shift+r' }, label = 'Ctrl+Shift+R', name = 'ペインサイズ変更モード', category = 'ウィンドウ・ペイン', action = act.ActivateKeyTable { name = 'resize_window', one_shot = false } },
  { id = 'next_window', keys = { 'ctrl+shift+]' }, label = 'Ctrl+Shift+]', name = '次のペインへ移動', category = 'ウィンドウ・ペイン', action = act.ActivatePaneDirection 'Next' },
  { id = 'previous_window', keys = { 'ctrl+shift+[' }, label = 'Ctrl+Shift+[', name = '前のペインへ移動', category = 'ウィンドウ・ペイン', action = act.ActivatePaneDirection 'Prev' },
  { id = 'move_window_forward', keys = { 'ctrl+shift+f' }, label = 'Ctrl+Shift+F', name = 'ペインを前方へ移動', category = 'ウィンドウ・ペイン', action = act.RotatePanes 'Clockwise' },
  { id = 'move_window_backward', keys = { 'ctrl+shift+b' }, label = 'Ctrl+Shift+B', name = 'ペインを後方へ移動', category = 'ウィンドウ・ペイン', action = act.RotatePanes 'CounterClockwise' },
  -- JIS 配列では @ のキー (Shift+@ が `)
  { id = 'move_window_to_top', keys = { 'ctrl+shift+`' }, label = 'Ctrl+Shift+`', name = 'ペインを選んで入れ替え (先頭へ移動の代替)', category = 'ウィンドウ・ペイン', action = act.PaneSelect { mode = 'SwapWithActive', alphabet = PANE_SELECT_ALPHABET } },
  { id = 'focus_visible_window', keys = { 'ctrl+shift+f7' }, label = 'Ctrl+Shift+F7', name = '画面を見ながらペインを選択', category = 'ウィンドウ・ペイン', action = act.PaneSelect { alphabet = PANE_SELECT_ALPHABET } },
  { id = 'swap_with_window', keys = { 'ctrl+shift+f8' }, label = 'Ctrl+Shift+F8', name = '画面を見ながらペインを入れ替え', category = 'ウィンドウ・ペイン', action = act.PaneSelect { mode = 'SwapWithActiveKeepFocus', alphabet = PANE_SELECT_ALPHABET } },

  -- スクロール・履歴
  { id = 'scroll_line_up', keys = { 'ctrl+shift+up', 'ctrl+shift+k' }, label = 'Ctrl+Shift+Up', name = '1行上へスクロール', category = 'スクロール・履歴', action = act.ScrollByLine(-1) },
  { id = 'scroll_line_down', keys = { 'ctrl+shift+down', 'ctrl+shift+j' }, label = 'Ctrl+Shift+Down', name = '1行下へスクロール', category = 'スクロール・履歴', action = act.ScrollByLine(1) },
  { id = 'scroll_page_up', keys = { 'ctrl+shift+pageup' }, label = 'Ctrl+Shift+PageUp', name = '1ページ上へスクロール', category = 'スクロール・履歴', action = act.ScrollByPage(-1) },
  { id = 'scroll_page_down', keys = { 'ctrl+shift+pagedown' }, label = 'Ctrl+Shift+PageDown', name = '1ページ下へスクロール', category = 'スクロール・履歴', action = act.ScrollByPage(1) },
  { id = 'scroll_home', keys = { 'ctrl+shift+home' }, label = 'Ctrl+Shift+Home', name = '履歴の先頭へ移動', category = 'スクロール・履歴', action = act.ScrollToTop },
  { id = 'scroll_end', keys = { 'ctrl+shift+end' }, label = 'Ctrl+Shift+End', name = '履歴の末尾へ移動', category = 'スクロール・履歴', action = act.ScrollToBottom },
  { id = 'scroll_to_previous_prompt', keys = { 'ctrl+shift+z' }, label = 'Ctrl+Shift+Z', name = '前のシェルプロンプトへ', category = 'スクロール・履歴', action = act.ScrollToPrompt(-1) },
  { id = 'scroll_to_next_prompt', keys = { 'ctrl+shift+x' }, label = 'Ctrl+Shift+X', name = '次のシェルプロンプトへ', category = 'スクロール・履歴', action = act.ScrollToPrompt(1) },
  { id = 'show_scrollback', keys = { 'ctrl+shift+h' }, label = 'Ctrl+Shift+H', name = 'スクロールバックを表示 (コピーモード)', category = 'スクロール・履歴', action = act.ActivateCopyMode },
  { id = 'show_last_command_output', keys = { 'ctrl+shift+g' }, label = 'Ctrl+Shift+G', name = '直前コマンドの出力をコピー', category = 'スクロール・履歴', action = panes.copy_last_command_output },

  -- コピー・貼り付け
  { id = 'copy_to_clipboard', keys = { 'ctrl+shift+c' }, label = 'Ctrl+Shift+C', name = '選択範囲をクリップボードへコピー', category = 'コピー・貼り付け', action = act.CopyTo 'Clipboard' },
  { id = 'paste_from_clipboard', keys = { 'ctrl+shift+v' }, label = 'Ctrl+Shift+V', name = 'クリップボードから貼り付け', category = 'コピー・貼り付け', action = act.PasteFrom 'Clipboard' },
  { id = 'paste_from_selection', keys = { 'ctrl+shift+s', 'shift+insert' }, label = 'Ctrl+Shift+S', name = '選択範囲 (無ければクリップボード) を貼り付け', category = 'コピー・貼り付け', action = panes.paste_from_selection },
  { id = 'pass_selection_to_program', keys = { 'ctrl+shift+o' }, label = 'Ctrl+Shift+O', name = '選択内容を外部プログラムへ渡す', category = 'コピー・貼り付け', action = panes.pass_selection_to_program },

  -- 表示・フォント
  -- JIS 配列では = のキー位置に ;(+) があるので、Ctrl+Shift+; が拡大になる
  { id = 'increase_font_size', keys = { 'ctrl+shift+=', 'ctrl+shift+kp_add' }, label = 'Ctrl+Shift+=', name = 'フォントを大きくする', category = '表示・フォント', action = panes.change_font_size(settings.font_size_step_palette), key_action = panes.change_font_size(settings.font_size_step_key) },
  { id = 'decrease_font_size', keys = { 'ctrl+shift+-', 'ctrl+shift+kp_subtract' }, label = 'Ctrl+Shift+-', name = 'フォントを小さくする', category = '表示・フォント', action = panes.change_font_size(-settings.font_size_step_palette), key_action = panes.change_font_size(-settings.font_size_step_key) },
  { id = 'reset_font_size', keys = { 'ctrl+shift+backspace' }, label = 'Ctrl+Shift+Backspace', name = 'フォントサイズを初期値へ戻す', category = '表示・フォント', action = panes.reset_font_size },
  { id = 'toggle_fullscreen', keys = { 'ctrl+shift+f11' }, label = 'Ctrl+Shift+F11', name = 'フルスクリーン ON/OFF', category = '表示・フォント', action = act.ToggleFullScreen },
  { id = 'toggle_maximized', keys = { 'ctrl+shift+f10' }, label = 'Ctrl+Shift+F10', name = '最大化 ON/OFF', category = '表示・フォント', action = panes.toggle_maximized },
  { id = 'opacity_more', keys = { 'ctrl+shift+a>m' }, label = 'Ctrl+Shift+A>M', name = '背景をより不透明にする', category = '表示・フォント', action = panes.set_background_opacity(settings.opacity_step) },
  { id = 'opacity_less', keys = { 'ctrl+shift+a>l' }, label = 'Ctrl+Shift+A>L', name = '背景をより透明にする', category = '表示・フォント', action = panes.set_background_opacity(-settings.opacity_step) },
  { id = 'opacity_full', keys = { 'ctrl+shift+a>1' }, label = 'Ctrl+Shift+A>1', name = '背景を完全に不透明にする', category = '表示・フォント', action = panes.set_background_opacity('full') },
  { id = 'opacity_default', keys = { 'ctrl+shift+a>d' }, label = 'Ctrl+Shift+A>D', name = '背景透明度を既定値へ戻す', category = '表示・フォント', action = panes.set_background_opacity('default') },

  -- URL・Hints
  { id = 'open_url_with_hints', keys = { 'ctrl+shift+e' }, label = 'Ctrl+Shift+E', name = '画面上の URL を選んで開く', category = 'URL・Hints', action = panes.hint_open_url },

  -- 入力
  { id = 'unicode_input', keys = { 'ctrl+shift+u' }, label = 'Ctrl+Shift+U', name = 'Unicode 文字入力', category = '入力', action = act.CharSelect { copy_on_select = false } },

  -- 端末
  { id = 'reset_terminal', keys = { 'ctrl+shift+delete' }, label = 'Ctrl+Shift+Delete', name = '端末をリセット', category = '端末', action = act.Multiple { act.ClearScrollback 'ScrollbackAndViewport', act.ResetTerminal } },

  -- タブ色
  { id = 'edit_colors', keys = { 'ctrl+shift+alt+e' }, label = 'Ctrl+Shift+Alt+E', name = 'タブ色設定 colors.txt を編集', category = 'タブ色', action = edit_colors_file },
  { id = 'reload_colors', keys = { 'ctrl+shift+alt+r' }, label = 'Ctrl+Shift+Alt+R', name = 'タブ色設定を再読み込み', category = 'タブ色', action = act.ReloadConfiguration },

  -- タブ記憶
  { id = 'memory_save', keys = { 'ctrl+shift+alt+s' }, label = 'Ctrl+Shift+Alt+S', name = 'タブ名・色をこのフォルダに記憶', category = 'タブ記憶', action = memory_command('save') },
  { id = 'memory_restore', keys = { 'ctrl+shift+alt+l' }, label = 'Ctrl+Shift+Alt+L', name = 'このフォルダのタブ名・色を復元', category = 'タブ記憶', action = memory_command('restore') },
  { id = 'memory_forget', keys = { 'ctrl+shift+alt+d' }, label = 'Ctrl+Shift+Alt+D', name = 'このフォルダの記憶を削除', category = 'タブ記憶', action = memory_command('forget') },
  { id = 'memory_edit', keys = {}, label = '-', name = 'タブ記憶ファイル memory.json を編集', category = 'タブ記憶', action = memory_command('edit') },

  -- ここから下は kitty の既定キーのうち commands.tsv に載っていないもの (パレットには出さない)
  { id = 'palette', keys = { 'ctrl+shift+f12' }, hidden = true, action = open_palette },
  { id = 'search_scrollback', keys = { 'ctrl+shift+/' }, hidden = true, action = act.Search 'CurrentSelectionOrEmptyString' },
  { id = 'hint_insert_path', keys = { 'ctrl+shift+p>f' }, hidden = true, action = panes.hint_insert_path },
  { id = 'hint_open_path', keys = { 'ctrl+shift+p>shift+f' }, hidden = true, action = panes.hint_open_path },
  { id = 'hint_insert_line', keys = { 'ctrl+shift+p>l' }, hidden = true, action = panes.hint_insert_line },
  { id = 'hint_insert_word', keys = { 'ctrl+shift+p>w' }, hidden = true, action = panes.hint_insert_word },
  { id = 'hint_insert_hash', keys = { 'ctrl+shift+p>h' }, hidden = true, action = panes.hint_insert_hash },
  { id = 'hint_open_line_number', keys = { 'ctrl+shift+p>n' }, hidden = true, action = panes.hint_open_line_number },
}

-- Ctrl+Shift+1〜0: 番号でペインへ移動 (first_window 〜 tenth_window)
for pane_number = 1, 10 do
  table.insert(module.entries, {
    id = 'pane_' .. pane_number,
    keys = { 'ctrl+shift+' .. tostring(pane_number % 10) },
    hidden = true,
    action = act.ActivatePaneByIndex(pane_number - 1),
  })
end

-- colors.txt のタブ色。キーは設定の読み込み時に、色は押された時点の定義で決まる
function module.color_entries()
  local entries = {}
  for _, color in ipairs(tab_colors.load_colors()) do
    table.insert(entries, {
      id = 'color:' .. color.key,
      keys = { color.key },
      label = color.display_key,
      name = 'タブ色を「' .. color.name .. '」に変更',
      category = 'タブ色',
      action = tab_colors.color_action(color.key),
    })
  end
  return entries
end

function module.find(entry_id)
  for _, entry in ipairs(module.entries) do
    if entry.id == entry_id then
      return entry
    end
  end
  return nil
end

return module
