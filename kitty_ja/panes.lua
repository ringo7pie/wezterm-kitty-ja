-- kitty のアクションのうち、WezTerm の標準アクション 1 個では表せないもの。
local wezterm = require 'wezterm'
local settings = require 'kitty_ja.settings'
local state = require 'kitty_ja.state'

local act = wezterm.action
local module = {}

local function log(message)
  wezterm.log_error('kitty_ja panes: ' .. tostring(message))
end

local function guarded(callback)
  return wezterm.action_callback(function(window, pane)
    local ok, err = pcall(callback, window, pane)
    if not ok then
      log(err)
    end
  end)
end

-- ---------------------------------------------------------------- ペイン

-- new_window: kitty の起動時レイアウト (fat) に寄せる。
-- 1 枚目は下に全幅で分割し、2 枚目以降は最下段の右端を右へ分割する。
module.new_window = guarded(function(window, pane)
  local tab = window:active_tab()
  local infos = tab:panes_with_info()
  local target_pane = pane
  local direction = 'Bottom'
  local top_level = true
  if #infos > 1 then
    local target_info = nil
    for _, info in ipairs(infos) do
      if not target_info
        or info.top > target_info.top
        or (info.top == target_info.top and info.left > target_info.left) then
        target_info = info
      end
    end
    target_pane = target_info.pane
    direction = 'Right'
    top_level = false
  end
  local new_pane = target_pane:split {
    direction = direction,
    top_level = top_level,
    cwd = settings.home_dir,
  }
  if new_pane then
    new_pane:activate()
  end
end)

-- リサイズモード (start_resizing_window) の 1 操作。
-- AdjustPaneSize は境界線を動かす向きを取るので、隣のペインがある側を調べて向きを決める。
local function resize_action(dimension, grow, amount)
  return guarded(function(window, pane)
    local tab = window:active_tab()
    local forward = dimension == 'width' and 'Right' or 'Down'
    local backward = dimension == 'width' and 'Left' or 'Up'
    local has_forward_neighbor = tab:get_pane_direction(forward) ~= nil
    local direction
    if has_forward_neighbor then
      direction = grow and forward or backward
    else
      direction = grow and backward or forward
    end
    window:perform_action(act.AdjustPaneSize { direction, amount }, pane)
  end)
end

module.resize_wider = resize_action('width', true, 1)
module.resize_narrower = resize_action('width', false, 1)
module.resize_taller = resize_action('height', true, 1)
module.resize_shorter = resize_action('height', false, 1)
module.resize_wider_fast = resize_action('width', true, 2)
module.resize_narrower_fast = resize_action('width', false, 2)
module.resize_taller_fast = resize_action('height', true, 2)
module.resize_shorter_fast = resize_action('height', false, 2)

-- ---------------------------------------------------------------- 表示

-- change_font_size all ±N: 倍率ではなくポイント数で増減する
function module.change_font_size(delta)
  return guarded(function(window, _pane)
    local overrides = window:get_config_overrides() or {}
    local current = overrides.font_size or window:effective_config().font_size
    overrides.font_size = math.max(1, current + delta)
    window:set_config_overrides(overrides)
  end)
end

module.reset_font_size = guarded(function(window, pane)
  local overrides = window:get_config_overrides() or {}
  overrides.font_size = nil
  window:set_config_overrides(overrides)
  window:perform_action(act.ResetFontSize, pane)
end)

-- set_background_opacity: 数値は増減、'full' は不透明、'default' は設定値へ戻す
function module.set_background_opacity(change)
  return guarded(function(window, _pane)
    local overrides = window:get_config_overrides() or {}
    if change == 'default' then
      overrides.window_background_opacity = nil
    elseif change == 'full' then
      overrides.window_background_opacity = 1.0
    else
      local current = overrides.window_background_opacity or window:effective_config().window_background_opacity
      overrides.window_background_opacity = math.min(1.0, math.max(0.1, current + change))
    end
    window:set_config_overrides(overrides)
  end)
end

-- toggle_maximized: 最大化の状態を取得する API が無いので、自分で覚えておく
module.toggle_maximized = guarded(function(window, _pane)
  local store = state.load()
  local window_key = 'w' .. tostring(window:window_id())
  if store.maximized[window_key] then
    store.maximized[window_key] = nil
    window:restore()
  else
    store.maximized[window_key] = true
    window:maximize()
  end
  state.save(store)
end)

-- ---------------------------------------------------------------- コピー&ペースト

-- paste_from_selection: Windows には Primary Selection が無いので、
-- 選択中の文字列があればそれを、無ければクリップボードを貼る
module.paste_from_selection = guarded(function(window, pane)
  local text = window:get_selection_text_for_pane(pane)
  if text and #text > 0 then
    pane:send_paste(text)
  else
    window:perform_action(act.PasteFrom 'Clipboard', pane)
  end
end)

-- ---------------------------------------------------------------- 画面の文字列を開く

-- 画面の文字列は、ssh 先や表示したファイルが自由に出せる。それを Windows の「開く」に渡すと、
-- 実行ファイルなら実行され、ネットワークのパスなら相手へ接続して認証情報を送りうる。
-- 開いてよいのは http(s) の URL と、この PC のドライブにある実行形式でないファイル・フォルダだけにする

-- 「開く」と実行される種類の拡張子 (環境変数 PATHEXT の内容もこれに足す)
local EXECUTABLE_EXTENSIONS = {
  'appref-ms', 'application', 'bat', 'chm', 'cmd', 'com', 'cpl', 'exe', 'gadget', 'hta', 'inf', 'ins', 'isp',
  'jar', 'js', 'jse', 'lnk', 'msc', 'msi', 'msp', 'mst', 'pif', 'ps1', 'ps1xml', 'ps2', 'psc1', 'psd1', 'psm1',
  'py', 'pyw', 'reg', 'scf', 'scr', 'sct', 'settingcontent-ms', 'url', 'vb', 'vbe', 'vbs', 'ws', 'wsc', 'wsf',
  'wsh', 'xll',
}

local function executable_extension_set()
  local extensions = {}
  for _, extension in ipairs(EXECUTABLE_EXTENSIONS) do
    extensions[extension] = true
  end
  for extension in (os.getenv('PATHEXT') or ''):gmatch('%.([^;]+)') do
    extensions[extension:lower()] = true
  end
  return extensions
end

local function is_web_url(text)
  return text:match('^https?://[^%s%c]+$') ~= nil
end

local function is_absolute_path(path)
  return path:match('^%a:[\\/]') ~= nil or path:match('^[\\/][\\/]') ~= nil
end

-- 画面の文字列を、この PC のドライブにあるパスへ直す。直せなければ nil。
-- 相対パスは、ペインのフォルダが分かるときだけ直す
local function resolve_path(pane, path)
  local tab_memory = require 'kitty_ja.tab_memory'
  local resolved
  if path:sub(1, 1) == '~' then
    resolved = settings.home_dir .. path:sub(2)
  elseif is_absolute_path(path) then
    resolved = path
  else
    local cwd = tab_memory.pane_cwd(pane)
    if not cwd then
      return nil
    end
    resolved = cwd .. '\\' .. path
  end
  resolved = tab_memory.normalize_path(resolved)
  -- ドライブ文字より後ろの ':' (代替データストリーム) やワイルドカードなど、ファイル名に使えない文字は通さない
  if tab_memory.is_local_path(resolved) and not resolved:sub(3):find('[:*?"<>|]') then
    return resolved
  end
  return nil
end

local function is_directory(path)
  local ok = pcall(wezterm.read_dir, path)
  return ok
end

local function is_readable_file(path)
  local file = io.open(path, 'rb')
  if file then
    file:close()
    return true
  end
  return false
end

-- 既定のプログラムで開く。フォルダか、実行形式でない実在のファイルだけを開く
local function open_local_path(path)
  if is_directory(path) then
    wezterm.open_with(path)
    return
  end
  local extension = path:match('%.([^.\\]+)$')
  -- 拡張子の無い名前は、Windows が .exe などを補って実行することがあるので開かない
  if not extension or executable_extension_set()[extension:lower()] or not is_readable_file(path) then
    log('開きません (実行形式か、存在しないファイル): ' .. path)
    return
  end
  wezterm.open_with(path)
end

-- pass_selection_to_program: 選択内容を既定のプログラムで開く
module.pass_selection_to_program = guarded(function(window, pane)
  local text = window:get_selection_text_for_pane(pane)
  if not text or #text == 0 then
    return
  end
  text = text:gsub('^%s+', ''):gsub('%s+$', '')
  if is_web_url(text) then
    wezterm.open_with(text)
    return
  end
  local path = resolve_path(pane, text)
  if path then
    open_local_path(path)
  else
    log('開きません (URL でも、この PC のドライブのパスでもない)')
  end
end)

-- ゾーンの文字列を取り出す。
-- WezTerm 20240203 の get_text_from_semantic_zone はゾーンの最終行を含めないので、
-- 範囲を 1 行広げて取り出し、前後の空行を落とす。
function module.zone_text(pane, zone)
  local text = pane:get_text_from_region(zone.start_x, zone.start_y, 0, zone.end_y + 1) or ''
  text = text:gsub('^[ \t\r]*\n', '')
  text = text:gsub('%s+$', '')
  return text
end

-- show_last_command_output の代替: 直前コマンドの出力をクリップボードへコピーする。
-- シェルがプロンプト位置 (OSC 133) を通知していないときは何もしない。
module.copy_last_command_output = guarded(function(window, pane)
  local prompt_zones = pane:get_semantic_zones('Prompt')
  local output_zones = pane:get_semantic_zones('Output')
  if not prompt_zones or #prompt_zones == 0 or not output_zones or #output_zones == 0 then
    return
  end
  local text = module.zone_text(pane, output_zones[#output_zones])
  if #text > 0 then
    window:copy_to_clipboard(text, 'Clipboard')
  end
end)

-- ---------------------------------------------------------------- hints

local function quick_select(label, patterns, handler)
  return act.QuickSelectArgs {
    label = label,
    patterns = patterns,
    action = guarded(function(window, pane)
      local text = window:get_selection_text_for_pane(pane)
      if text and #text > 0 then
        handler(window, pane, text)
      end
    end),
  }
end

local function paste_into_pane(_window, pane, text)
  pane:send_paste(text)
end

local URL_PATTERNS = { [[https?://[^\s"'<>]+]] }
local PATH_PATTERNS = {
  [[(?:[A-Za-z]:[\\/]|~[\\/]|\.{1,2}[\\/]|[\\/])?(?:[\w.@%+\-]+[\\/])+[\w.@%+\-]*]],
  [[[\w@%+\-][\w.@%+\-]*\.[A-Za-z0-9]{1,7}]],
}
local LINE_PATTERNS = { [[(?m)^.+$]] }
local WORD_PATTERNS = { [[\S+]] }
local HASH_PATTERNS = { [[\b[0-9a-f]{7,128}\b]] }
local LINE_NUMBER_PATTERNS = { [[(?:[A-Za-z]:)?[\w.@%+\-\\/]+\.\w+:\d+]] }

-- open_url_with_hints
module.hint_open_url = quick_select('URL を開く', URL_PATTERNS, function(_window, _pane, text)
  if is_web_url(text) then
    wezterm.open_with(text)
  end
end)
-- kitten hints --type path --program -
module.hint_insert_path = quick_select('パスを挿入', PATH_PATTERNS, paste_into_pane)
-- kitten hints --type path
module.hint_open_path = quick_select('パスを開く', PATH_PATTERNS, function(_window, pane, text)
  local path = resolve_path(pane, text)
  if path then
    open_local_path(path)
  else
    log('開きません (この PC のドライブのパスに直せない): ' .. text)
  end
end)
-- kitten hints --type line --program -
module.hint_insert_line = quick_select('行を挿入', LINE_PATTERNS, paste_into_pane)
-- kitten hints --type word --program -
module.hint_insert_word = quick_select('単語を挿入', WORD_PATTERNS, paste_into_pane)
-- kitten hints --type hash --program -
module.hint_insert_hash = quick_select('ハッシュを挿入', HASH_PATTERNS, paste_into_pane)
-- kitten hints --type linenum: ファイル:行番号 をエディタで開く
module.hint_open_line_number = quick_select('ファイルの行を開く', LINE_NUMBER_PATTERNS, function(_window, pane, text)
  local raw_path, line_number = text:match('^(.*):(%d+)$')
  if not raw_path then
    return
  end
  -- エディタに渡すのは、この PC のドライブにある実在のファイルだけ
  -- (ネットワークのパスや、オプションに見える文字列をエディタの引数にしない)
  local path = resolve_path(pane, raw_path)
  if not path or not is_readable_file(path) then
    log('開きません (この PC のドライブに無いファイル): ' .. raw_path)
    return
  end
  local command = {}
  for _, argument in ipairs(settings.editor_command) do
    table.insert(command, argument)
  end
  table.insert(command, path)
  if settings.editor_line_option then
    table.insert(command, settings.editor_line_option .. line_number)
  end
  wezterm.background_child_process(command)
end)

return module
