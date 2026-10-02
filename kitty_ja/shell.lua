-- 既定のシェル。pwsh の起動時に integration.ps1 を実行させる ($PROFILE は触らない)。
-- ドットソースではなく & で実行し、スクリプト内の StrictMode を対話セッションへ漏らさない。
local settings = require 'kitty_ja.settings'

local module = {}

function module.apply(config)
  config.default_prog = {
    settings.shell_program,
    '-NoLogo',
    '-NoExit',
    '-Command',
    "& '" .. settings.integration_script .. "'",
  }
end

return module
