-- commands.lua のコマンド表から config.keys と config.key_tables を作る。
--
-- キーは物理キー (phys:) で定義する。WezTerm は物理キーの割り当てを最初に照合するので、
-- 標準の割り当てより優先され、JIS 配列で記号の文字が US 配列と違っても同じキー位置で動く。
-- 英字・数字・名前付きキーには、通常の (mapped) 指定も予備として併せて登録する。
local wezterm = require 'wezterm'
local commands = require 'kitty_ja.commands'
local panes = require 'kitty_ja.panes'

local act = wezterm.action
local module = {}

local MODIFIER_NAMES = { ctrl = 'CTRL', shift = 'SHIFT', alt = 'ALT', super = 'SUPER', cmd = 'SUPER' }
local MODIFIER_ORDER = { 'CTRL', 'SHIFT', 'ALT', 'SUPER' }

-- キー名 -> { phys = 物理キー名, mapped = 通常のキー名 (あれば) }
local NAMED_KEYS = {
  enter = { phys = 'Return', mapped = 'Enter' },
  backspace = { phys = 'Backspace', mapped = 'Backspace' },
  delete = { phys = 'Delete', mapped = 'Delete' },
  escape = { phys = 'Escape', mapped = 'Escape' },
  tab = { phys = 'Tab', mapped = 'Tab' },
  insert = { phys = 'Insert', mapped = 'Insert' },
  home = { phys = 'Home', mapped = 'Home' },
  ['end'] = { phys = 'End', mapped = 'End' },
  pageup = { phys = 'PageUp', mapped = 'PageUp' },
  pagedown = { phys = 'PageDown', mapped = 'PageDown' },
  up = { phys = 'UpArrow', mapped = 'UpArrow' },
  down = { phys = 'DownArrow', mapped = 'DownArrow' },
  left = { phys = 'LeftArrow', mapped = 'LeftArrow' },
  right = { phys = 'RightArrow', mapped = 'RightArrow' },
  space = { phys = 'Space' },
  kp_add = { phys = 'KeypadAdd' },
  kp_subtract = { phys = 'KeypadSubtract' },
  ['['] = { phys = 'LeftBracket' },
  [']'] = { phys = 'RightBracket' },
  [','] = { phys = 'Comma' },
  ['.'] = { phys = 'Period' },
  ['/'] = { phys = 'Slash' },
  ['`'] = { phys = 'Grave' },
  ['='] = { phys = 'Equal' },
  ['-'] = { phys = 'Minus' },
  [';'] = { phys = 'Semicolon' },
  ["'"] = { phys = 'Quote' },
  ['\\'] = { phys = 'Backslash' },
}

-- 2 段キーの 1 段目 -> キーテーブル名
local CHORD_TABLE_NAMES = {
  ['ctrl+shift+a'] = 'opacity',
  ['ctrl+shift+p'] = 'hints',
}

local function modifier_string(modifier_set, without_shift)
  local parts = {}
  for _, name in ipairs(MODIFIER_ORDER) do
    if modifier_set[name] and not (without_shift and name == 'SHIFT') then
      table.insert(parts, name)
    end
  end
  if #parts == 0 then
    return 'NONE'
  end
  return table.concat(parts, '|')
end

-- 'ctrl+shift+t' のような 1 打鍵の指定を、WezTerm の { key, mods } の配列にする
local function key_variants(key_spec)
  local modifier_set = {}
  local key_name = nil
  -- 末尾が '+' の指定は無いので、単純に '+' で区切る
  for part in key_spec:gmatch('[^+]+') do
    local modifier = MODIFIER_NAMES[part]
    if modifier then
      modifier_set[modifier] = true
    else
      key_name = part
    end
  end
  if not key_name then
    error('bad key spec: ' .. key_spec)
  end

  local mods = modifier_string(modifier_set, false)
  local variants = {}
  if key_name:match('^%a$') then
    table.insert(variants, { key = 'phys:' .. key_name:upper(), mods = mods })
    if modifier_set.SHIFT then
      table.insert(variants, { key = key_name:lower(), mods = mods })
      table.insert(variants, { key = key_name:upper(), mods = mods })
      table.insert(variants, { key = key_name:upper(), mods = modifier_string(modifier_set, true) })
    else
      table.insert(variants, { key = key_name:lower(), mods = mods })
    end
  elseif key_name:match('^%d$') then
    table.insert(variants, { key = 'phys:' .. key_name, mods = mods })
    -- Shift を含む数字は配列によって届く文字が違うので、予備は Shift なしのときだけ
    if not modifier_set.SHIFT then
      table.insert(variants, { key = key_name, mods = mods })
    end
  elseif key_name:match('^f%d+$') then
    local function_key = key_name:upper()
    table.insert(variants, { key = 'phys:' .. function_key, mods = mods })
    table.insert(variants, { key = function_key, mods = mods })
  else
    local named = NAMED_KEYS[key_name]
    if not named then
      error('unknown key: ' .. key_spec)
    end
    table.insert(variants, { key = 'phys:' .. named.phys, mods = mods })
    if named.mapped then
      table.insert(variants, { key = named.mapped, mods = mods })
    end
  end
  return variants
end

local function add_bindings(target, key_spec, action)
  for _, variant in ipairs(key_variants(key_spec)) do
    table.insert(target, { key = variant.key, mods = variant.mods, action = action })
  end
end

local function chord_table_name(prefix_spec)
  local name = CHORD_TABLE_NAMES[prefix_spec]
  if not name then
    name = 'chord_' .. prefix_spec:gsub('[^%w]', '_')
  end
  return name
end

function module.apply(config)
  local keys = {}
  local key_tables = {}
  local chord_prefixes = {}

  local function bind(entry)
    local action = entry.key_action or entry.action
    for _, key_spec in ipairs(entry.keys or {}) do
      local ok, err = pcall(function()
        local prefix_spec, second_spec = key_spec:match('^(.-)>(.+)$')
        if prefix_spec then
          local table_name = chord_table_name(prefix_spec)
          key_tables[table_name] = key_tables[table_name] or {}
          add_bindings(key_tables[table_name], second_spec, action)
          chord_prefixes[prefix_spec] = table_name
        else
          add_bindings(keys, key_spec, action)
        end
      end)
      if not ok then
        wezterm.log_warn('kitty_ja keys: ' .. tostring(err))
      end
    end
  end

  for _, entry in ipairs(commands.entries) do
    bind(entry)
  end
  for _, entry in ipairs(commands.color_entries()) do
    bind(entry)
  end

  -- 2 段キー: 1 段目でキーテーブルに入り、次の 1 打鍵で抜ける
  for prefix_spec, table_name in pairs(chord_prefixes) do
    add_bindings(keys, prefix_spec, act.ActivateKeyTable {
      name = table_name,
      one_shot = true,
      until_unknown = true,
    })
    add_bindings(key_tables[table_name], 'escape', act.PopKeyTable)
  end

  -- リサイズモード (kitty: w 広く / n 狭く / t 高く / s 低く、Ctrl 併用で倍、Esc か q で終了)
  local resize_table = {}
  add_bindings(resize_table, 'w', panes.resize_wider)
  add_bindings(resize_table, 'n', panes.resize_narrower)
  add_bindings(resize_table, 't', panes.resize_taller)
  add_bindings(resize_table, 's', panes.resize_shorter)
  add_bindings(resize_table, 'ctrl+w', panes.resize_wider_fast)
  add_bindings(resize_table, 'ctrl+n', panes.resize_narrower_fast)
  add_bindings(resize_table, 'ctrl+t', panes.resize_taller_fast)
  add_bindings(resize_table, 'ctrl+s', panes.resize_shorter_fast)
  add_bindings(resize_table, 'escape', act.PopKeyTable)
  add_bindings(resize_table, 'q', act.PopKeyTable)
  add_bindings(resize_table, 'enter', act.PopKeyTable)
  key_tables.resize_window = resize_table

  config.keys = keys
  config.key_tables = key_tables
end

return module
