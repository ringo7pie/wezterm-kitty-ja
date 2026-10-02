-- kitty-ja-shortcuts 互換設定の設定値。環境に合わせて変えるのはこのファイルだけでよい。
local wezterm = require 'wezterm'

local module = {}

local data_dir = wezterm.home_dir .. '\\.config\\wezterm-kitty-ja'

module.home_dir = wezterm.home_dir

-- データファイルは Lua モジュールと別フォルダに置く
-- (同じフォルダだと memory.json の保存で設定の再読み込みが走る恐れがある)
module.colors_file = data_dir .. '\\tab-colors\\colors.txt'
module.memory_file = data_dir .. '\\tab-memory\\memory.json'

-- 閉じたときのタブ構成の保存と、次回起動時の復元 (session.lua)。false で機能ごと止まる
module.session_enabled = true
module.session_file = data_dir .. '\\session\\session.json'
-- ウィンドウが減った状態は、この秒数続いてから保存する
-- (複数のウィンドウを続けて閉じて終了したとき、全部を復元するため)
module.session_window_close_grace_seconds = 3
-- 復元時にフォルダの存在を確かめる時間の上限。届かないフォルダのタブはホームで開く
module.session_probe_timeout_ms = 2000
-- タブが 2 枚以上のときだけ出るタブバーの行数。その分だけ高いウィンドウを作って、行数が減るのを防ぐ
-- (appearance.lua の hide_tab_bar_if_only_one_tab = true / use_fancy_tab_bar = false に対応)
module.session_tab_bar_rows = 1

module.shell_program = 'C:\\Program Files\\PowerShell\\7\\pwsh.exe'
module.integration_script = wezterm.home_dir .. '\\.config\\wezterm\\kitty_ja\\shell\\integration.ps1'

-- colors.txt / memory.json / 設定ファイルを開くエディタ (kitty 側の nano に相当)
module.editor_command = { 'C:\\Program Files\\Notepad++\\notepad++.exe' }

module.font_size = 11
-- kitty の既定キーは 2.0 刻み、commands.tsv (パレット) は 1.0 刻み
module.font_size_step_key = 2.0
module.font_size_step_palette = 1.0
module.opacity_step = 0.1

-- 新しいタブは名前が付け終わるまで待ってから扱う (tab_memory.py の NEW_TAB_DELAY)
module.new_tab_delay_seconds = 0.5

module.documentation_url = 'https://wezterm.org/'

return module
