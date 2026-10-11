local wezterm = require 'wezterm'

local config = wezterm.config_builder()

-- kitty-ja-shortcuts 入りの kitty と同じ動作・同じショートカットキーにする。
-- 本体は ホーム\.config\wezterm\kitty_ja\ にある
local ok, kitty_ja = pcall(require, 'kitty_ja')
if ok then
  kitty_ja.apply_to_config(config)
else
  wezterm.log_error('kitty_ja を読み込めません: ' .. tostring(kitty_ja))
  -- 読み込みに失敗しても PowerShell 7 で端末を使えるようにする (見つからなければ WezTerm の既定のシェル)
  local settings_ok, settings = pcall(require, 'kitty_ja.settings')
  if settings_ok and settings.shell_program then
    config.default_prog = { settings.shell_program, '-NoLogo' }
  end
end

-- WezTerm に保持するスクロール履歴の最大行数。
-- kitty_ja 側でさらに大きい値を設定している場合は、その値を維持する。
config.scrollback_lines = math.max(config.scrollback_lines or 0, 100000)

-- Notepad++ を標準以外の場所にインストールした場合のみ、実際のパスを指定する。
-- 例: local notepadpp_override = 'E:\\Program Files\\Notepad++\\notepad++.exe'
local notepadpp_override = nil

local function file_exists(path)
  if not path then
    return false
  end
  local file = io.open(path, 'rb')
  if not file then
    return false
  end
  file:close()
  return true
end

local function find_notepadpp()
  local candidates = {}
  if notepadpp_override then
    table.insert(candidates, notepadpp_override)
  end

  local program_files = os.getenv('ProgramFiles') or 'C:\\Program Files'
  local program_files_x86 = os.getenv('ProgramFiles(x86)') or 'C:\\Program Files (x86)'
  local local_appdata = os.getenv('LOCALAPPDATA')
  table.insert(candidates, program_files .. '\\Notepad++\\notepad++.exe')
  table.insert(candidates, program_files_x86 .. '\\Notepad++\\notepad++.exe')
  if local_appdata then
    table.insert(candidates, local_appdata .. '\\Programs\\Notepad++\\notepad++.exe')
  end

  for _, candidate in ipairs(candidates) do
    if file_exists(candidate) then
      return candidate
    end
  end
  return nil
end

-- Ctrl+Shift+E: フォーカス中のペインの表示内容とスクロール履歴を
-- UTF-8 テキストで保存し、Windows 側の Notepad++ で開く。
wezterm.on('open-scrollback-in-notepadpp', function(window, pane)
  local dimensions = pane:get_dimensions()
  local history = pane:get_lines_as_text(dimensions.scrollback_rows)
  local temp_directory = os.getenv('TEMP') or os.getenv('TMP') or wezterm.home_dir
  local history_path = string.format(
    '%s\\wezterm-history-%s-pane-%s.txt',
    temp_directory,
    os.date('%Y%m%d-%H%M%S'),
    tostring(pane:pane_id())
  )

  local file, open_error = io.open(history_path, 'wb')
  if not file then
    wezterm.log_error('履歴を保存できません: ' .. tostring(open_error))
    window:toast_notification('WezTerm', '履歴保存に失敗しました: ' .. tostring(open_error), nil, 5000)
    return
  end

  -- BOM を付けて、日本語を含む履歴も Notepad++ で UTF-8 として認識させる。
  local written, write_error = file:write('\239\187\191', history)
  local closed, close_error = file:close()
  if not written or not closed then
    local error_text = tostring(write_error or close_error)
    wezterm.log_error('履歴の書き込みに失敗しました: ' .. error_text)
    window:toast_notification('WezTerm', '履歴の書き込みに失敗しました: ' .. error_text, nil, 5000)
    return
  end

  local notepad_executable = find_notepadpp()
  if not notepad_executable then
    wezterm.log_error('Notepad++ が見つかりません。履歴は保存済み: ' .. history_path)
    window:toast_notification('WezTerm', 'Notepad++ が見つかりません。履歴: ' .. history_path, nil, 6000)
    return
  end

  local launched, launch_error = pcall(wezterm.open_with, history_path, notepad_executable)
  if not launched then
    wezterm.log_error('Notepad++ の起動に失敗しました: ' .. tostring(launch_error))
    window:toast_notification('WezTerm', 'Notepad++ を起動できませんでした。履歴: ' .. history_path, nil, 6000)
  end
end)

-- kitty_ja が同じ操作を「E + CTRL」など別表記で登録する場合がある。
-- WezTerm は mapped:E + CTRL を Ctrl+Shift+E として扱う場合があるため、
-- 物理キー／配列依存キーの両方から衝突する登録を除去する。
local function parse_modifiers(mods)
  local parsed = {}
  if type(mods) ~= 'string' then
    return parsed
  end
  for modifier in mods:gmatch('[^|]+') do
    local normalized = modifier:match('^%s*(.-)%s*$'):upper()
    parsed[normalized] = true
  end
  return parsed
end

local function is_ctrl_shift_e(binding)
  if type(binding) ~= 'table' or type(binding.key) ~= 'string' then
    return false
  end

  local key_kind, key_character = binding.key:match('^(%a+):(.+)$')
  if not key_kind then
    key_kind = config.key_map_preference == 'Physical' and 'phys' or 'mapped'
    key_character = binding.key
  end
  key_kind = key_kind:lower()
  if key_character:upper() ~= 'E' then
    return false
  end

  local modifiers = parse_modifiers(binding.mods)
  if not modifiers.CTRL then
    return false
  end
  -- CTRL と SHIFT 以外も使っているキーバインドは変更しない。
  for modifier_name in pairs(modifiers) do
    if modifier_name ~= 'CTRL' and modifier_name ~= 'SHIFT' then
      return false
    end
  end

  if key_kind == 'phys' then
    return modifiers.SHIFT == true
  end
  if key_kind == 'mapped' then
    -- mapped:E + CTRL は大文字 E に SHIFT が含まれている場合がある。
    return modifiers.SHIFT == true or key_character == 'E'
  end
  return false
end

config.keys = config.keys or {}
for key_index = #config.keys, 1, -1 do
  if is_ctrl_shift_e(config.keys[key_index]) then
    table.remove(config.keys, key_index)
  end
end

local open_history_action = wezterm.action.EmitEvent 'open-scrollback-in-notepadpp'

-- 物理キーで Ctrl+Shift+E を拾う。
table.insert(config.keys, {
  key = 'phys:E',
  mods = 'CTRL|SHIFT',
  action = open_history_action,
})
-- 日本語配列／キーの mapped 解釈も拾う。
table.insert(config.keys, {
  key = 'mapped:E',
  mods = 'CTRL',
  action = open_history_action,
})
table.insert(config.keys, {
  key = 'mapped:e',
  mods = 'CTRL|SHIFT',
  action = open_history_action,
})

-- 切り分け用: Ctrl+Alt+Shift+F12 でも同じ機能を呼び出せる。
-- Ctrl+Shift+E が動かない場合、このキーで読み込み状況を確認する。
table.insert(config.keys, {
  key = 'F12',
  mods = 'CTRL|ALT|SHIFT',
  action = open_history_action,
})

return config
