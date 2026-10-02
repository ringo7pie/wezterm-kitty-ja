-- 日本語コマンドパレット (Ctrl+Shift+F12)。kitty 側の jp_command_palette.py に相当。
-- WezTerm 内蔵の InputSelector を使うので、検索はあいまい一致になる。
--
-- InputSelector は IME で確定した文字を受け取れず、日本語では検索できない (WezTerm 20240203 の制限)。
-- そこで各行の画面外に、読みのローマ字とコマンド ID を検索語として足しておく。
-- 検索はラベル全体に対して行われ、表示は画面の幅で切られるので、検索語は見えない。
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

-- colors.txt の色名に対する検索語 (読みと英語)。ここに無い名前の色は tabuiro / color / キーの数字で探す
local COLOR_KEYWORDS = {
  ['デフォルト'] = 'deforuto default',
  ['赤'] = 'aka red',
  ['青'] = 'ao blue',
  ['緑'] = 'midori green',
  ['黄'] = 'ki yellow',
  ['黄色'] = 'kiiro yellow',
  ['紫'] = 'murasaki purple',
  ['オレンジ'] = 'orenji orange',
  ['ピンク'] = 'pinku pink',
  ['水色'] = 'mizuiro cyan',
  ['茶'] = 'cha brown',
  ['茶色'] = 'chairo brown',
  ['黒'] = 'kuro black',
  ['白'] = 'shiro white',
  ['灰'] = 'hai gray',
  ['灰色'] = 'haiiro gray',
  ['グレー'] = 'gure- gray',
}

-- ヘボン式の読みを訓令式に直す (chi → ti、fu → hu、ji → zi、sha → sya、she → sye など)
local function to_kunrei(reading)
  local converted = reading
  converted = converted:gsub('sh([aueo])', 'sy%1')
  converted = converted:gsub('shi', 'si')
  converted = converted:gsub('ch([aueo])', 'ty%1')
  converted = converted:gsub('chi', 'ti')
  converted = converted:gsub('tsu', 'tu')
  converted = converted:gsub('fu', 'hu')
  converted = converted:gsub('j([aueo])', 'zy%1')
  converted = converted:gsub('ji', 'zi')
  return converted
end

-- どの打ち方でも当たる綴りにする。検索は「打った文字がこの順に含まれるか」で決まるので、
-- 打ち方によって違う文字を全部並べておけば、混ぜて打っても当たる。
--   し shi (shi / si)       ち tchi (chi / ti)       ふ hfu (fu / hu)   じ zji (ji / zi)
--   しゃ shya (sha / sya)   ちゃ tchya (cha / tya)   じゃ zjya (ja / zya / jya)
--   ん nn (n / nn)。母音と y の前以外の n を「ん」とみなす
local function to_loose(reading)
  -- 語末の n も「ん」として扱えるよう、番兵の空白を足してから置き換える
  local converted = reading .. ' '
  converted = converted:gsub('sh([aueo])', 'shy%1')
  converted = converted:gsub('ch([aueo])', 'tchy%1')
  converted = converted:gsub('chi', 'tchi')
  converted = converted:gsub('fu', 'hfu')
  converted = converted:gsub('j([aueo])', 'zjy%1')
  converted = converted:gsub('ji', 'zji')
  converted = converted:gsub('n([^aiueoy])', 'nn%1')
  converted = converted:gsub(' $', '')
  return converted
end

-- 読みの検索語。ヘボン式・訓令式はそのままの綴りで (続けて一致するので上位に来る)、
-- それ以外の打ち方 (jya、語末の nn、混ぜ打ち) は to_loose の綴りで当てる
local function reading_words(reading)
  local words = { reading }
  for _, variant in ipairs({ to_kunrei(reading), to_loose(reading) }) do
    local is_new = true
    for _, word in ipairs(words) do
      if word == variant then
        is_new = false
      end
    end
    if is_new then
      table.insert(words, variant)
    end
  end
  return table.concat(words, ' ')
end

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
        keywords = reading_words(entry.yomi or '') .. ' ' .. entry.id,
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
      keywords = reading_words('tabuiro wo ' .. (COLOR_KEYWORDS[color.name] or '') .. ' ni henkou') .. ' color',
    })
  end
  return rows
end

-- 選択画面はタブ全体に重なるので、ペインではなくタブの桁数に合わせる
-- (ペインの桁数で作ると、分割したタブで行が短くなり、検索語が画面に出てしまう)
local function selector_columns(window, pane)
  local ok, size = pcall(function()
    return window:active_tab():get_size()
  end)
  if ok and type(size) == 'table' and type(size.cols) == 'number' then
    return size.cols
  end
  return pane:get_dimensions().cols
end

function module.show(window, pane)
  local columns = selector_columns(window, pane)
  local key_width, category_width
  if columns >= 90 then
    key_width, category_width = 26, 18
  elseif columns >= 70 then
    key_width, category_width = 22, 14
  else
    key_width, category_width = 16, 10
  end
  local name_width = math.max(10, columns - SELECTOR_MARGIN - key_width - category_width - 4)

  -- 見える部分をちょうど画面の幅にそろえ、その右 (画面の外) に検索語を置く
  local function make_label(key, name, category, keywords)
    return fit(key, key_width) .. '  ' .. fit(name, name_width) .. '  ' .. fit(category, category_width)
      .. '  ' .. keywords
  end

  local include_unmapped = show_unmapped()
  local choices = {
    {
      id = TOGGLE_UNMAPPED_ID,
      label = make_label(
        '',
        '未割当コマンドの表示: ' .. (include_unmapped and 'ON' or 'OFF') .. ' (選ぶと切り替え)',
        '表示',
        reading_words('miwariate komando no hyouji kirikae') .. ' unmapped toggle'
      ),
    },
  }
  for _, row in ipairs(build_rows()) do
    if include_unmapped or not row.unmapped then
      table.insert(choices, {
        id = row.id,
        label = make_label(row.key, row.name, row.category, row.keywords),
      })
    end
  end

  window:perform_action(
    act.InputSelector {
      title = '日本語 Command Palette',
      description = '日本語 Command Palette    Enter 実行  Esc 閉じる  / 検索',
      fuzzy = true,
      fuzzy_description = '検索 (ローマ字・英語): ',
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
