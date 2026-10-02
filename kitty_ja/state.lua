-- 設定の再読み込みをまたいで残す状態。
-- wezterm.GLOBAL に JSON 文字列 1 個として置く (入れ子テーブルの代入や nil の扱いに依存しないため)。
local wezterm = require 'wezterm'

local module = {}

local GLOBAL_KEY = 'kitty_ja_state'

-- store.tabs    : 't<tab_id>' -> { cwd, look, auto, colors }
-- store.pending : 't<tab_id>' -> 初回処理を待ち始めた時刻 (os.time)
-- store.maximized : 'w<window_id>' -> true
function module.load()
  local store = nil
  local encoded = wezterm.GLOBAL[GLOBAL_KEY]
  if type(encoded) == 'string' and #encoded > 0 then
    local ok, decoded = pcall(wezterm.json_parse, encoded)
    if ok and type(decoded) == 'table' then
      store = decoded
    end
  end
  store = store or {}
  store.tabs = store.tabs or {}
  store.pending = store.pending or {}
  store.maximized = store.maximized or {}
  return store
end

function module.save(store)
  wezterm.GLOBAL[GLOBAL_KEY] = wezterm.json_encode(store)
end

local TOKEN_KEY = 'kitty_ja_shell_token'

-- シェル連携の合言葉。WezTerm のプロセスごとに 1 個作り、環境変数で pwsh へ渡す (shell.lua)。
-- integration.ps1 はフォルダの通知にこれを添える。端末に文字を出すだけのもの (ssh 先や cat したファイル) は
-- 合言葉を知らないので、通知を偽装できない
function module.shell_token()
  local token = wezterm.GLOBAL[TOKEN_KEY]
  if type(token) ~= 'string' or #token == 0 then
    local parts = {}
    for _ = 1, 4 do
      table.insert(parts, string.format('%08x', math.random(0, 0xFFFFFFFF)))
    end
    token = table.concat(parts)
    wezterm.GLOBAL[TOKEN_KEY] = token
  end
  return token
end

local RESTORING_KEY = 'kitty_ja_restoring_since'
-- 復元が途中で止まっても、この秒数で復元中の扱いを終える
local RESTORING_TIMEOUT_SECONDS = 60

-- セッションの復元中は、タブ記憶の自動処理と保存を止める
function module.set_restoring(flag)
  wezterm.GLOBAL[RESTORING_KEY] = flag and os.time() or 0
end

function module.is_restoring()
  local since = wezterm.GLOBAL[RESTORING_KEY] or 0
  return since ~= 0 and os.time() - since < RESTORING_TIMEOUT_SECONDS
end

-- タブバーは left status の文字列が変わると再計算される。
-- 見えない差分 (空文字と SGR リセット) を交互に渡して、色だけ変えたときも描き直させる。
function module.request_redraw(gui_window)
  if not gui_window then
    return
  end
  local ok, err = pcall(function()
    local tick_key = 'kitty_ja_redraw_w' .. tostring(gui_window:window_id())
    local tick = (wezterm.GLOBAL[tick_key] or 0) + 1
    wezterm.GLOBAL[tick_key] = tick
    gui_window:set_left_status(tick % 2 == 0 and '' or '\x1b[0m')
  end)
  if not ok then
    wezterm.log_error('kitty_ja: redraw: ' .. tostring(err))
  end
end

return module
