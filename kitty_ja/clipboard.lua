-- 画像はローカルの PNG に保存してパスを貼り付け、文字は標準の貼り付けに任せる。
local wezterm = require 'wezterm'
local settings = require 'kitty_ja.settings'

local module = {}

function module.paste(window, pane)
  local success, stdout, stderr = wezterm.run_child_process {
    settings.shell_program or settings.fallback_shell_program,
    '-NoLogo', '-NoProfile', '-NonInteractive', '-STA',
    '-ExecutionPolicy', 'Bypass',
    '-File', settings.clipboard_image_script,
  }
  if not success then
    wezterm.log_error('kitty_ja clipboard: ' .. tostring(stderr))
    window:toast_notification('WezTerm', 'クリップボードの画像を取得できませんでした。', nil, 5000)
    return
  end

  local result = wezterm.json_parse(stdout)
  if result.kind == 'image' then
    -- Windows のパスを / 表記にして、空白を含む場合も 1 つのパスとして渡す。
    pane:send_paste('"' .. result.path:gsub('\\', '/') .. '" ')
  elseif result.kind == 'text' then
    window:perform_action(wezterm.action.PasteFrom 'Clipboard', pane)
  else
    error('Unexpected clipboard result: ' .. tostring(result.kind))
  end
end

return module
