-- 設定の再読み込みをまたいで残す状態。
-- wezterm.GLOBAL に JSON 文字列 1 個として置く (入れ子テーブルの代入や nil の扱いに依存しないため)。
local wezterm = require 'wezterm'
local settings = require 'kitty_ja.settings'

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
local TOKEN_LENGTH = 32
-- mux 構成の GUI が、合言葉のファイルを読み直す最短の間隔 (秒)
local TOKEN_REFRESH_SECONDS = 2
local TOKEN_REFRESHED_AT_KEY = 'kitty_ja_shell_token_refreshed_at'
-- ファイルから読んだ、mux-server の合言葉
local SHARED_TOKEN_KEY = 'kitty_ja_shell_token_shared'

local function generate_token()
  local parts = {}
  for _ = 1, 4 do
    table.insert(parts, string.format('%08x', math.random(0, 0xFFFFFFFF)))
  end
  return table.concat(parts)
end

local function read_token_file()
  local file = io.open(settings.shell_token_file, 'rb')
  if not file then
    return nil
  end
  local content = file:read('a') or ''
  file:close()
  local token = content:match('^%s*(%x+)%s*$')
  -- 書き込みの途中で読んだ場合は、長さが足りないので捨てる
  if token and #token == TOKEN_LENGTH then
    return token
  end
  return nil
end

local function write_token_file(token)
  local file = io.open(settings.shell_token_file, 'wb')
  if not file then
    return false
  end
  file:write(token .. '\n')
  file:close()
  return true
end

-- シェル連携の合言葉。WezTerm のプロセスごとに 1 個作り、環境変数で pwsh へ渡す (shell.lua)。
-- integration.ps1 はフォルダの通知にこれを添える。端末に文字を出すだけのもの (ssh 先や cat したファイル) は
-- 合言葉を知らないので、通知を偽装できない。
--
-- mux 構成 (settings.mux_server) では、シェルを起動する mux-server と、通知を確かめる GUI が別のプロセスになり、
-- それぞれが別の合言葉を作る。mux-server は起動時 (mux-startup) に自分の合言葉をファイルへ公開し (publish_shell_token)、
-- GUI は is_shell_token で、自分のものとそのファイルの両方を受け付ける
function module.shell_token()
  local token = wezterm.GLOBAL[TOKEN_KEY]
  if type(token) ~= 'string' or #token == 0 then
    token = generate_token()
    wezterm.GLOBAL[TOKEN_KEY] = token
  end
  return token
end

-- mux-server の起動時に、このプロセスの合言葉をファイルへ書く (init.lua の mux-startup)。
-- 呼ぶのは mux-startup だけにする (wezterm cli など、設定を評価するだけのプロセスが書き換えないように)
function module.publish_shell_token()
  if not settings.mux_server then
    return
  end
  if not write_token_file(module.shell_token()) then
    wezterm.log_error('kitty_ja: シェル連携の合言葉を ' .. tostring(settings.shell_token_file) .. ' に書けません。GUI が通知を確かめられず、OSC 7 のフォルダだけを使います')
  end
end

-- candidate が、このシェル連携の合言葉か。
-- mux 構成では、GUI が mux-server より先に起動する (自動起動) ので、ファイルに公開される前に確かめることがある。
-- 合わないときはファイルを読み直して確かめる (2 秒に 1 回まで)
function module.is_shell_token(candidate)
  if type(candidate) ~= 'string' or #candidate == 0 then
    return false
  end
  if candidate == module.shell_token() then
    return true
  end
  if not settings.mux_server then
    return false
  end
  if candidate == wezterm.GLOBAL[SHARED_TOKEN_KEY] then
    return true
  end
  local now = os.time()
  if now - (wezterm.GLOBAL[TOKEN_REFRESHED_AT_KEY] or 0) < TOKEN_REFRESH_SECONDS then
    return false
  end
  wezterm.GLOBAL[TOKEN_REFRESHED_AT_KEY] = now
  local file_token = read_token_file()
  if file_token then
    wezterm.GLOBAL[SHARED_TOKEN_KEY] = file_token
  end
  return file_token ~= nil and candidate == file_token
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
