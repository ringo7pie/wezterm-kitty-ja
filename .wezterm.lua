local wezterm = require 'wezterm'

local config = wezterm.config_builder()

-- kitty_ja の読み込みに失敗しても端末が使えるように、既定のシェルは先に決めておく
config.default_prog = {
  'C:\\Program Files\\PowerShell\\7\\pwsh.exe',
  '-NoLogo'
}

-- kitty-ja-shortcuts 入りの kitty と同じ動作・同じショートカットキーにする。
-- 本体は C:\Users\mt\.config\wezterm\kitty_ja\ にある
local ok, kitty_ja = pcall(require, 'kitty_ja')
if ok then
  kitty_ja.apply_to_config(config)
else
  wezterm.log_error('kitty_ja を読み込めません: ' .. tostring(kitty_ja))
end

return config
