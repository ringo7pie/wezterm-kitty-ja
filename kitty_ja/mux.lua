-- シェルを wezterm-mux-server に持たせ、GUI はそこへ接続するだけにする (settings.lua の mux_server)。
--
-- 動作:
--   - unix ドメインを 1 個登録し、GUI の起動を `wezterm connect <ドメイン名>` にする
--   - サーバーは最初の GUI の起動で自動で起動し (no_serve_automatically を指定しない)、GUI を全部閉じても残る
--   - サーバーも同じ設定ファイルを読む。サーバーのプロセスには wezterm.gui が無い (appearance.lua など参照)
--
-- 新しいタブ・ウィンドウ・ペインは、操作したペインと同じドメインへ作られる
-- (SpawnCommand の domain の既定値 CurrentPaneDomain。commands.lua / panes.lua は domain を指定していない)
local settings = require 'kitty_ja.settings'

local module = {}

function module.apply(config)
  if not settings.mux_server then
    return
  end

  local domains = {}
  local defined = false
  local ok, existing = pcall(function()
    return config.unix_domains
  end)
  if ok and type(existing) == 'table' then
    for _, domain in ipairs(existing) do
      table.insert(domains, domain)
      -- 同じ名前のドメインを定義済みなら、そちらを使う (追加しない)
      if domain.name == settings.mux_domain_name then
        defined = true
      end
    end
  end
  if not defined then
    table.insert(domains, { name = settings.mux_domain_name })
  end
  config.unix_domains = domains
  config.default_gui_startup_args = { 'connect', settings.mux_domain_name }
end

return module
