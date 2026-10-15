-- シェルを wezterm-mux-server に持たせ、GUI はそこへ接続するだけにする (settings.lua の mux_server)。
--
-- 動作:
--   - unix ドメインを 1 個登録し、GUI の起動を `wezterm connect <ドメイン名>` にする
--   - サーバーは最初の GUI の起動で自動で起動し (no_serve_automatically を指定しない)、GUI を全部閉じても残る
--   - サーバーも同じ設定ファイルを読む。サーバーのプロセスには wezterm.gui が無い (appearance.lua など参照)
--
-- 新しいタブ・ウィンドウ・ペインは、操作したペインと同じドメインへ作られる
-- (SpawnCommand の domain の既定値 CurrentPaneDomain。commands.lua / panes.lua は domain を指定していない)
--
-- キー入力の補正 (apply_keys):
--   GUI から mux-server へ送るキー入力は、キーの文字と修飾キーだけを運ぶ (WezTerm 20240203 で確認)。
--   ローカルの窓は、仮想キーコードまで含むキーの情報 (win32-input-mode) を ConPTY へ渡せるが、mux 経由では渡せない。
--   そのため、Windows のコンソールの入力 (ReadConsoleInput を使う codex など) で、次のキーが別のキーとして届く:
--     Ctrl+J       -> Enter の Ctrl (本来は J の Ctrl。codex の「Ctrl+J で改行」が効かない)
--     Shift+Enter  -> 修飾キーなしの Enter
--     Ctrl+Enter   -> 修飾キーなしの Enter
--   この 3 つは、win32-input-mode の列 (ESC [ Vk ; Sc ; Uc ; Kd ; Cs ; Rc _) を直接送る割り当てで、ローカルの窓と同じ入力になる
--   (2026-10-15、WezTerm 20240203-110809-5046fc22 で確認)。Claude Code のように文字コードで読むアプリは、この割り当てがなくても同じに動く。
--   前提は、ペインが ConPTY で動くこと (この設定のドメインは、どれも該当する)
local wezterm = require 'wezterm'
local settings = require 'kitty_ja.settings'

local act = wezterm.action

local module = {}

-- virtual_key: 仮想キーコード / scan_code: スキャンコード / character: 文字コード / control_state: 修飾キーの状態
-- (Windows の dwControlKeyState: LEFT_CTRL_PRESSED = 8、SHIFT_PRESSED = 16)
local WIN32_INPUT_KEYS = {
  { key = 'phys:J', mods = 'CTRL', virtual_key = 74, scan_code = 36, character = 10, control_state = 8 },
  { key = 'phys:Return', mods = 'SHIFT', virtual_key = 13, scan_code = 28, character = 13, control_state = 16 },
  { key = 'phys:Return', mods = 'CTRL', virtual_key = 13, scan_code = 28, character = 10, control_state = 8 },
}

-- キーを押した列と離した列を続けて返す
local function win32_input_sequence(entry)
  local function record(key_down)
    return string.format('\x1b[%d;%d;%d;%d;%d;1_', entry.virtual_key, entry.scan_code, entry.character, key_down, entry.control_state)
  end
  return record(1) .. record(0)
end

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

-- keys.apply が config.keys を作り直すので、その後に呼ぶ
function module.apply_keys(config)
  if not settings.mux_server then
    return
  end

  config.keys = config.keys or {}
  for _, entry in ipairs(WIN32_INPUT_KEYS) do
    table.insert(config.keys, { key = entry.key, mods = entry.mods, action = act.SendString(win32_input_sequence(entry)) })
  end
end

return module
