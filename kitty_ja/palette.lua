-- 日本語コマンドパレット (Ctrl+Shift+F12)。kitty 側の jp_command_palette.py に相当。
-- WezTerm 内蔵の InputSelector を使うので、検索はあいまい一致になる。
local wezterm = require 'wezterm'
local tab_colors = require 'kitty_ja.tab_colors'

local act = wezterm.action
local module = {}

local SELECTED_EVENT = 'kitty-ja-palette-selected'
local TOGGLE_UNMAPPED_ID = '__toggle_unmapped'
local SHOW_UNMAPPED_KEY = 'kitty_ja_palette_show_unmapped'
local UNMAPPED_LABEL = '(未割当)'
-- InputSelector は各行の先頭に 4 桁を使い、ラベルを「画面の桁数 - 6」で切る
local SELECTOR_MARGIN = 6

-- 全角を 2 桁として数え、width 桁に切り詰めたうえで空白で埋める (jp_command_palette.py の fit)
local function fit(text, width)
  if width <= 0 then
    return ''
  end
  local pieces = {}
  local used = 0
  for _, codepoint in utf8.codes(text) do
    local character = utf8.char(codepoint)
    local character_width = wezterm.column_width(character)
    if used + character_width > width then
      break
    end
    table.insert(pieces, character)
    used = used + character_width
  end
  return table.concat(pieces) .. string.rep(' ', math.max(0, width - used))
end

local function show_unmapped()
  return wezterm.GLOBAL[SHOW_UNMAPPED_KEY] ~= false
end

local function build_rows()
  local commands = require 'kitty_ja.commands'
  local rows = {}
  for _, entry in ipairs(commands.entries) do
    if not entry.hidden then
      local unmapped = entry.label == nil or entry.label == '-'
      table.insert(rows, {
        id = entry.id,
        key = unmapped and UNMAPPED_LABEL or entry.label,
        name = entry.name,
        category = entry.category,
        unmapped = unmapped,
      })
    end
  end
  -- タブ色は開くたびに colors.txt を読み直す
  for _, color in ipairs(tab_colors.load_colors()) do
    table.insert(rows, {
      id = 'color:' .. color.key,
      key = color.display_key,
      name = 'タブ色を「' .. color.name .. '」に変更',
      category = 'タブ色',
      unmapped = false,
    })
  end
  return rows
end

function module.show(window, pane)
  local columns = pane:get_dimensions().cols
  local key_width, category_width
  if columns >= 90 then
    key_width, category_width = 26, 18
  elseif columns >= 70 then
    key_width, category_width = 22, 14
  else
    key_width, category_width = 16, 10
  end
  local name_width = math.max(10, columns - SELECTOR_MARGIN - key_width - category_width - 4)

  local include_unmapped = show_unmapped()
  local choices = {
    {
      id = TOGGLE_UNMAPPED_ID,
      label = fit('', key_width) .. '  ' .. fit(
        '未割当コマンドの表示: ' .. (include_unmapped and 'ON' or 'OFF') .. ' (選ぶと切り替え)',
        name_width
      ) .. '  ' .. fit('表示', category_width),
    },
  }
  for _, row in ipairs(build_rows()) do
    if include_unmapped or not row.unmapped then
      table.insert(choices, {
        id = row.id,
        label = fit(row.key, key_width) .. '  ' .. fit(row.name, name_width) .. '  ' .. fit(row.category, category_width),
      })
    end
  end

  window:perform_action(
    act.InputSelector {
      title = '日本語 Command Palette',
      description = '日本語 Command Palette    Enter 実行  Esc 閉じる  / 検索',
      fuzzy = true,
      fuzzy_description = '検索: ',
      choices = choices,
      action = act.EmitEvent(SELECTED_EVENT),
    },
    pane
  )
end

local function on_selected(window, pane, selected_id, _label)
  if not selected_id then
    return
  end
  if selected_id == TOGGLE_UNMAPPED_ID then
    wezterm.GLOBAL[SHOW_UNMAPPED_KEY] = not show_unmapped()
    module.show(window, pane)
    return
  end
  local color_key = selected_id:match('^color:(.+)$')
  if color_key then
    local color = tab_colors.find_color(color_key)
    if color then
      tab_colors.set_active_tab_colors(window, color.colors)
    end
    return
  end
  local entry = require('kitty_ja.commands').find(selected_id)
  if entry and entry.action then
    window:perform_action(entry.action, pane)
  end
end

-- 選択時の処理は設定の読み込みごとに 1 回だけ登録する
function module.register()
  wezterm.on(SELECTED_EVENT, function(window, pane, selected_id, label)
    local ok, err = pcall(on_selected, window, pane, selected_id, label)
    if not ok then
      wezterm.log_error('kitty_ja palette: ' .. tostring(err))
    end
  end)
end

return module
