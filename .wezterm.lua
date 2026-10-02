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

return config
