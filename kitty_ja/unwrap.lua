-- 選択した文字列から、ペインの幅で折り返した位置の改行を除く。
--
-- WezTerm は、端末が自動で折り返した行しか 1 行に戻さない。Claude Code と Codex は、自分で幅に合わせて
-- 改行を書くので、そのままコピーすると改行が残る。次のどちらかなら、行 i と行 i+1 は折り返しとみなして結合する。
--   1. 行 i が幅いっぱい (cols - 1 以上。全角が端に入らず 1 桁余る場合を含む)
--   2. 行 i+1 の先頭の語が、行 i の後ろ (空白 1 個ぶんを空けて) に入りきらない
-- 先頭の語は、字下げの後ろから最初の空白までとする。Claude Code は空白でだけ改行するので、
-- 空白を含まない日本語の塊は 1 語になる。Codex は日本語を 1 文字ずつ折り返すが、この語の長さで判定しても
-- 結合する範囲は広がる向きなので、Codex の折り返しも拾える。
-- 実測 (2026-11-20): Claude Code v2.1.329 (149 桁) と Codex 0.167.1 (100 桁) は、どちらも幅いっぱいまで使う。
--
-- 空行、箇条書きの記号で始まる行、罫線を含む行 (表・枠) は結合しない。
-- 判定は全ペインで常に行うので、通常のシェルの長い行が結合されることがある。
local wezterm = require 'wezterm'

local module = {}

local function is_wide(codepoint)
  return (codepoint >= 0x1100 and codepoint <= 0x115F)
    or (codepoint >= 0x2E80 and codepoint <= 0x303E)
    or (codepoint >= 0x3041 and codepoint <= 0xA4CF)
    or (codepoint >= 0xAC00 and codepoint <= 0xD7A3)
    or (codepoint >= 0xF900 and codepoint <= 0xFAFF)
    or (codepoint >= 0xFE30 and codepoint <= 0xFE4F)
    or (codepoint >= 0xFF00 and codepoint <= 0xFF60)
    or (codepoint >= 0xFFE0 and codepoint <= 0xFFE6)
end

-- 表示幅。WezTerm の中では wezterm.column_width を使う (不正な UTF-8 は 1 バイト 1 桁とみなす)
local function column_width(text)
  if wezterm.column_width then
    local ok, width = pcall(wezterm.column_width, text)
    if ok and width then
      return width
    end
  end
  local ok, length = pcall(utf8.len, text)
  if not ok or not length then
    return #text
  end
  local width = 0
  for _, codepoint in utf8.codes(text) do
    width = width + (is_wide(codepoint) and 2 or 1)
  end
  return width
end
module.column_width = column_width

local function first_codepoint(text)
  local ok, codepoint = pcall(utf8.codepoint, text, 1)
  if ok then
    return codepoint
  end
  return nil
end

local function last_codepoint(text)
  local ok, offset = pcall(utf8.offset, text, -1)
  if ok and offset then
    return first_codepoint(text:sub(offset))
  end
  return nil
end

local function trim_right(text)
  return (text:gsub('[ \t\r]+$', ''))
end

local function trim_left(text)
  return (text:gsub('^[ \t]+', ''))
end

-- 罫線 (U+2500〜U+257F) は UTF-8 で E2 94 80〜E2 95 BF
local function has_box_drawing(text)
  return text:find('\226\148[\128-\191]') ~= nil or text:find('\226\149[\128-\191]') ~= nil
end

-- 記号 + 空白で始まる行は、箇条書き・ツールの出力・プロンプトの始まりとみなす
local MARKERS = {
  '-', '*', '+', '>', '•', '◦', '·', '●', '⏺', '⎿', '❯', '›', '✻', '✳', '▶', '■', '□', '☐', '☒', '✔', '✓', '✗', '✘', '※',
}
local function starts_with_marker(text)
  local body = trim_left(text)
  for _, marker in ipairs(MARKERS) do
    if body:sub(1, #marker) == marker then
      local rest = body:sub(#marker + 1)
      if rest == '' or rest:find('^[ \t]') then
        return true
      end
    end
  end
  return body:find('^%d+[.)][ \t]') ~= nil or body:find('^%a[.)][ \t]') ~= nil
end

local function first_word(text)
  local body = trim_left(text)
  -- 全角の空白 (U+3000) も区切りにする
  local stop = body:find('[ \t]') or (#body + 1)
  local ideographic = body:find('\227\128\128', 1, true)
  if ideographic and ideographic < stop then
    stop = ideographic
  end
  return body:sub(1, stop - 1)
end

-- 端末上で最後の行が何桁を使っているか。WezTerm が自動の折り返しを既に結合した長い行は、最後の 1 段の幅を見る
local function last_row_width(width, cols)
  if width <= cols then
    return width
  end
  return ((width - 1) % cols) + 1
end

local function should_join(previous, previous_width, following, cols)
  if trim_right(previous) == '' or trim_right(following) == '' then
    return false
  end
  if has_box_drawing(previous) or has_box_drawing(following) then
    return false
  end
  if starts_with_marker(following) then
    return false
  end
  local used = last_row_width(previous_width, cols)
  if used >= cols - 1 then
    return true
  end
  return used + 1 + column_width(first_word(following)) > cols
end

local function separator(previous, previous_width, following, cols)
  previous = trim_right(previous)
  local last = last_codepoint(previous)
  local first = first_codepoint(following)
  if last and first and is_wide(last) and is_wide(first) then
    return ''
  end
  -- 空白を含まない 1 語が幅いっぱいなら、長い URL やパスを途中で切ったものとみなす
  local body = trim_left(previous)
  if last_row_width(previous_width, cols) >= cols - 1 and not body:find('[ \t]') then
    return ''
  end
  return ' '
end

-- text: 選択した文字列。cols: ペインの桁数。first_prefix_width: 1 行目より左にある、選択していない部分の桁数
function module.join(text, cols, first_prefix_width)
  if type(text) ~= 'string' or text == '' or not cols or cols < 2 then
    return text
  end
  local newline = text:find('\r\n', 1, true) and '\r\n' or '\n'
  local lines = {}
  for line in (text .. '\n'):gmatch('(.-)\r?\n') do
    table.insert(lines, line)
  end
  if #lines < 2 then
    return text
  end
  -- 末尾の改行は 1 行ぶんの空行として残す
  local parts = { lines[1] }
  local previous = lines[1]
  local previous_width = (first_prefix_width or 0) + column_width(trim_right(previous))
  for index = 2, #lines do
    local following = lines[index]
    if should_join(previous, previous_width, following, cols) then
      local body = trim_left(following)
      parts[#parts] = trim_right(parts[#parts]) .. separator(previous, previous_width, body, cols) .. body
    else
      table.insert(parts, following)
    end
    previous = following
    previous_width = column_width(trim_right(following))
  end
  return table.concat(parts, newline)
end

-- 1 行目が画面のどこから始まるかを、画面の各行の末尾との一致で探す。1 行だけ見つかったときにだけ使う
function module.first_prefix_width(pane, text)
  local first = trim_right((text:match('^[^\r\n]*')) or '')
  if first == '' then
    return 0
  end
  local ok, screen = pcall(function()
    return pane:get_lines_as_text()
  end)
  if not ok or type(screen) ~= 'string' then
    return 0
  end
  local found = nil
  for line in (screen .. '\n'):gmatch('(.-)\r?\n') do
    local row = trim_right(line)
    if #row >= #first and row:sub(#row - #first + 1) == first then
      if found then
        return 0
      end
      found = row:sub(1, #row - #first)
    end
  end
  if not found then
    return 0
  end
  return column_width(found)
end

function module.selection_text(window, pane)
  local text = window:get_selection_text_for_pane(pane) or ''
  if text == '' then
    return ''
  end
  local cols = pane:get_dimensions().cols
  return module.join(text, cols, module.first_prefix_width(pane, text))
end

-- 選択を結合してクリップボードへ入れる。選択が無ければ false を返す
function module.copy_selection(window, pane, destination)
  local text = module.selection_text(window, pane)
  if text == '' then
    return false
  end
  window:copy_to_clipboard(text, destination or 'Clipboard')
  return true
end

return module
