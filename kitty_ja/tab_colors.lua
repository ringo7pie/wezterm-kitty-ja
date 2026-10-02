-- タブ色: colors.txt の読み込みと、タブごとの色の描画。
-- kitty 側の tab-colors/generate_colors.py と同じ書式・同じ文字色計算。
local wezterm = require 'wezterm'
local settings = require 'kitty_ja.settings'
local state = require 'kitty_ja.state'

local module = {}

module.COLOR_FIELDS = { 'active_fg', 'active_bg', 'inactive_fg', 'inactive_bg' }

local MODIFIER_DISPLAY_NAMES = { ctrl = 'Ctrl', shift = 'Shift', alt = 'Alt', super = 'Super', cmd = 'Cmd' }

local function trim(text)
  local trimmed = text:gsub('^%s+', '')
  trimmed = trimmed:gsub('%s+$', '')
  return trimmed
end

local function split_fields(line)
  local fields = {}
  for field in (line .. '|'):gmatch('([^|]*)|') do
    table.insert(fields, trim(field))
  end
  return fields
end

-- '#RRGGBB' (大文字) か 'NONE' を返す。書式が違えば error
local function normalize_color(value)
  if value:upper() == 'NONE' then
    return 'NONE'
  end
  if not value:match('^#%x%x%x%x%x%x$') then
    error('bad color: ' .. value)
  end
  return value:upper()
end

-- 背景の輝度から文字色を黒か白に決める (generate_colors.py の auto_foreground)
local function auto_foreground(background)
  if background == 'NONE' then
    return 'NONE'
  end
  local function linear(component)
    local ratio = component / 255.0
    if ratio <= 0.04045 then
      return ratio / 12.92
    end
    return ((ratio + 0.055) / 1.055) ^ 2.4
  end
  local red = tonumber(background:sub(2, 3), 16)
  local green = tonumber(background:sub(4, 5), 16)
  local blue = tonumber(background:sub(6, 7), 16)
  local luminance = 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
  if luminance > 0.45 then
    return '#000000'
  end
  return '#FFFFFF'
end

-- KEY 列: 1 桁の数字は ctrl+shift+alt+数字、それ以外は完全なキー指定
local function normalize_key(value)
  if value:match('^%d$') then
    return 'ctrl+shift+alt+' .. value
  end
  if not value:match('^[%w_+%-.,<>/]+$') then
    error('bad key: ' .. value)
  end
  return value:lower()
end

local function display_key(key_spec)
  local parts = {}
  for part in key_spec:gmatch('[^+]+') do
    local display_name = MODIFIER_DISPLAY_NAMES[part]
    if not display_name then
      display_name = #part == 1 and part:upper() or (part:sub(1, 1):upper() .. part:sub(2))
    end
    table.insert(parts, display_name)
  end
  return table.concat(parts, '+')
end

local function none_to_nil(color)
  if color == 'NONE' then
    return nil
  end
  return color
end

-- colors.txt を読む。戻り値は { key, display_key, name, colors = { active_fg, ... } } の配列。
-- colors の各色は '#RRGGBB' か nil (NONE = 既定色へ戻す)。
function module.load_colors()
  local entries = {}
  local file = io.open(settings.colors_file, 'rb')
  if not file then
    return entries
  end
  local content = file:read('a') or ''
  file:close()
  content = content:gsub('^\239\187\191', '')

  local line_number = 0
  for raw_line in (content .. '\n'):gmatch('([^\n]*)\n') do
    line_number = line_number + 1
    local line = trim((raw_line:gsub('\r', '')))
    if #line > 0 and line:sub(1, 1) ~= '#' then
      local ok, err = pcall(function()
        local fields = split_fields(line)
        if #fields < 4 or #fields > 6 then
          error('expected 4..6 fields')
        end
        local key_spec = normalize_key(fields[1])
        local active_bg = normalize_color(fields[3])
        local inactive_bg = normalize_color(fields[4])
        local active_fg = (fields[5] and #fields[5] > 0) and normalize_color(fields[5]) or auto_foreground(active_bg)
        local inactive_fg = (fields[6] and #fields[6] > 0) and normalize_color(fields[6]) or auto_foreground(inactive_bg)
        table.insert(entries, {
          key = key_spec,
          display_key = display_key(key_spec),
          name = fields[2],
          colors = {
            active_fg = none_to_nil(active_fg),
            active_bg = none_to_nil(active_bg),
            inactive_fg = none_to_nil(inactive_fg),
            inactive_bg = none_to_nil(inactive_bg),
          },
        })
      end)
      if not ok then
        wezterm.log_warn(string.format('kitty_ja: colors.txt:%d: %s', line_number, tostring(err)))
      end
    end
  end
  return entries
end

function module.find_color(key_spec)
  for _, entry in ipairs(module.load_colors()) do
    if entry.key == key_spec then
      return entry
    end
  end
  return nil
end

-- 現在のタブの色を変える。変更はタブ記憶にも反映される (kitty の watcher と同じ)。
function module.set_active_tab_colors(window, colors)
  local tab_memory = require 'kitty_ja.tab_memory'
  tab_memory.change_look(window, function(_tab, tab_state)
    local new_colors = {}
    for _, field in ipairs(module.COLOR_FIELDS) do
      new_colors[field] = colors[field]
    end
    tab_state.colors = new_colors
  end)
end

-- colors.txt のキーごとに、そのキーが押された時点の定義を読み直して適用するアクションを作る
function module.color_action(key_spec)
  return wezterm.action_callback(function(window, _pane)
    local entry = module.find_color(key_spec)
    if entry then
      module.set_active_tab_colors(window, entry.colors)
    end
  end)
end

local function fit_title(title, max_width)
  local available = math.max(1, max_width - 2)
  if wezterm.column_width(title) > available then
    title = wezterm.truncate_right(title, math.max(1, available - 1)) .. '…'
  end
  return ' ' .. title .. ' '
end

-- format-tab-title: タブ名と、付けてある色を返す。色が無い成分は既定色に任せる。
function module.format_tab_title(tab, _tabs, _panes, _config, _hover, max_width)
  local title = tab.tab_title
  if not title or #title == 0 then
    title = tab.active_pane.title
  end
  local elements = {}

  local store = state.load()
  local tab_state = store.tabs['t' .. tostring(tab.tab_id)]
  local colors = tab_state and tab_state.colors or nil
  if colors then
    local background = colors.inactive_bg
    local foreground = colors.inactive_fg
    if tab.is_active then
      background = colors.active_bg
      foreground = colors.active_fg
    end
    if background then
      table.insert(elements, { Background = { Color = background } })
    end
    if foreground then
      table.insert(elements, { Foreground = { Color = foreground } })
    end
  end

  table.insert(elements, { Text = fit_title(title or '', max_width) })
  return elements
end

return module
