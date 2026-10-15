-- kitty-ja-shortcuts 入りの kitty と同じ動作・同じショートカットキーにするための WezTerm 設定。
-- 移植元: kitty-ja-shortcuts (kitty 0.49.1 用のアドオン)
--
-- 使い方 (.wezterm.lua):
--   local config = wezterm.config_builder()
--   require('kitty_ja').apply_to_config(config)
--   return config
local wezterm = require 'wezterm'
local settings = require 'kitty_ja.settings'
local appearance = require 'kitty_ja.appearance'
local shell = require 'kitty_ja.shell'
local state = require 'kitty_ja.state'
local mux = require 'kitty_ja.mux'
local keys = require 'kitty_ja.keys'
local palette = require 'kitty_ja.palette'
local tab_colors = require 'kitty_ja.tab_colors'
local tab_memory = require 'kitty_ja.tab_memory'

-- タブ構成の保存と復元。読み込めなくても、ほかの機能は今までどおり使えるようにする
local session_ok, session = pcall(require, 'kitty_ja.session')
if not session_ok then
  wezterm.log_error('kitty_ja: session を読み込めません: ' .. tostring(session))
end

local module = {}

function module.apply_to_config(config)
  appearance.apply(config)
  shell.apply(config)
  mux.apply(config)
  keys.apply(config)

  -- colors.txt を保存したら設定を読み直し、タブ色のキーを更新する
  wezterm.add_to_config_reload_watch_list(settings.colors_file)

  -- format-tab-title は最初に登録した 1 個しか実行されないので、ここ以外では登録しない
  wezterm.on('format-tab-title', function(...)
    local ok, result = pcall(tab_colors.format_tab_title, ...)
    if ok then
      return result
    end
    -- 失敗したら何も返さず、WezTerm 標準のタブ表示に任せる
    return nil
  end)
  -- タブ記憶が名前・色を確定させてから、その結果を保存する
  wezterm.on('update-status', function(window, pane)
    tab_memory.on_update_status(window, pane)
    if session_ok then
      session.on_update_status(window, pane)
    end
  end)
  wezterm.on('user-var-changed', tab_memory.on_user_var_changed)
  if session_ok then
    wezterm.on('gui-startup', session.on_gui_startup)
  end
  -- mux-startup は mux-server の起動時にだけ発火する。GUI が connect で接続する構成では gui-startup が発火しないので、
  -- タブの復元はここで行う。復元で作るシェルを GUI が確かめられるよう、合言葉を先に公開する
  if settings.mux_server then
    wezterm.on('mux-startup', function()
      local published, publish_error = pcall(state.publish_shell_token)
      if not published then
        wezterm.log_error('kitty_ja: 合言葉を公開できません: ' .. tostring(publish_error))
      end
      if session_ok then
        session.on_mux_startup()
      end
    end)
  end
  palette.register()
end

return module
