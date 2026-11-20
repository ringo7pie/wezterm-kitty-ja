-- マウスで選択し終えたとき (左ボタンを離したとき) に、折り返しの改行を除いてからクリップボードへ入れる。
-- 割り当てを足すのは、WezTerm 既定の Left Up のうち、通常の選択 (修飾なし・Shift) の 3 種だけ。
-- ほかの既定 (押したとき・ドラッグ・Alt の矩形選択・Ctrl でリンクを開く) は、そのまま残る。
local wezterm = require 'wezterm'
local unwrap = require 'kitty_ja.unwrap'

local act = wezterm.action
local module = {}

-- 選択が無いときは既定と同じアクション (単クリックならリンクを開く) に任せる
local function complete(fallback)
  return wezterm.action_callback(function(window, pane)
    local ok, copied = pcall(unwrap.copy_selection, window, pane, 'ClipboardAndPrimarySelection')
    if not ok then
      wezterm.log_error('kitty_ja mouse: ' .. tostring(copied))
    end
    if not ok or not copied then
      window:perform_action(fallback, pane)
    end
  end)
end

function module.apply(config)
  local bindings = config.mouse_bindings or {}
  local single = complete(act.CompleteSelectionOrOpenLinkAtMouseCursor 'ClipboardAndPrimarySelection')
  local multiple = complete(act.CompleteSelection 'ClipboardAndPrimarySelection')
  table.insert(bindings, { event = { Up = { streak = 1, button = 'Left' } }, mods = 'NONE', action = single })
  table.insert(bindings, { event = { Up = { streak = 1, button = 'Left' } }, mods = 'SHIFT', action = single })
  table.insert(bindings, { event = { Up = { streak = 2, button = 'Left' } }, mods = 'NONE', action = multiple })
  table.insert(bindings, { event = { Up = { streak = 3, button = 'Left' } }, mods = 'NONE', action = multiple })
  config.mouse_bindings = bindings
end

return module
