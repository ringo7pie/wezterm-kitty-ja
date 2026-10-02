-- 閉じたときのタブ構成を保存し、次回の起動時に復元する。
--
-- 動作:
--   - 全ウィンドウのタブ (フォルダ・名前・色・並び順・選択中のタブ) とペイン分割を、変わるたびに session.json へ書く
--     (WezTerm には閉じる直前のイベントが無いので、常に最新を保存しておく)
--   - 起動時 (gui-startup) に session.json を読み、ウィンドウ・タブ・ペインを作り直す
--   - 実行中だったプログラムと画面の文字は戻さない。各ペインはシェルが保存時のフォルダで開く
--
-- session.json:
--   { version, owner_pid, saved_at, windows = [ { active_tab, cols, rows, tabs = [ { title, colors, auto, layout } ] } ] }
--   layout は分割木。葉 { cwd, active } / 分割 { split = 'Right' か 'Bottom', cells, percent, first, second }
--   cells は second 側 (右・下) のセル数、percent はその割合
--   session.json.bak は、起動後に最初に書き換える直前の内容 (手で戻すための控え)
local wezterm = require 'wezterm'
local settings = require 'kitty_ja.settings'
local state = require 'kitty_ja.state'
local tab_memory = require 'kitty_ja.tab_memory'

local module = {}

local VERSION = 1
-- 最後に書いた内容 (windows の JSON 文字列) と、そのウィンドウ数
local WRITTEN_KEY = 'kitty_ja_session_written'
local WINDOW_COUNT_KEY = 'kitty_ja_session_window_count'
-- ウィンドウが減ったのを最初に見た時刻。0 は減っていない
local SHRINK_SINCE_KEY = 'kitty_ja_session_shrink_since'
-- 猶予を数え始めたときのウィンドウ数。さらに減ったら数え直す
local SHRINK_COUNT_KEY = 'kitty_ja_session_shrink_count'
local CHECKED_AT_KEY = 'kitty_ja_session_checked_at'
local BACKED_UP_KEY = 'kitty_ja_session_backed_up'
-- 'owner' は session.json を読み書きする。'secondary' は別の WezTerm が持ち主なので触らない
local ROLE_KEY = 'kitty_ja_session_role'
-- 'p<pane_id>' -> { last = 最後に分かったフォルダ, intended = 届かずホームで開いたペインの本来のフォルダ }
local PANE_CACHE_KEY = 'kitty_ja_session_panes'

-- 直前の WezTerm が終了し切るのを待つ上限
local OWNER_EXIT_WAIT_MS = 3000
local POLL_INTERVAL_MS = 50
-- 復元の後、選択中だったタブをもう一度選び直すまでの秒数
local ACTIVATE_RETRY_SECONDS = 0.5

local AXES = {
  { start = 'left', length = 'width', split = 'Right' },
  { start = 'top', length = 'height', split = 'Bottom' },
}

local function log(message)
  wezterm.log_error('kitty_ja session: ' .. tostring(message))
end

-- update-status は毎秒来るので、同じ内容のログは 1 回だけ出す
local logged = {}
local function log_once(key, message)
  if logged[key] then
    return
  end
  logged[key] = true
  log(message)
end

local function clamp(value, lowest, highest)
  return math.max(lowest, math.min(highest, value))
end

-- ---------------------------------------------------------------- ファイル

local function read_text(path)
  local file = io.open(path, 'rb')
  if not file then
    return nil
  end
  local content = file:read('a') or ''
  file:close()
  return content
end

-- os.rename は Windows では上書きできないので、消してから置き換える (tab_memory の write_folders と同じ手順)
local function write_text_atomic(path, content)
  local temporary_file = path .. '.tmp'
  local file = io.open(temporary_file, 'wb')
  if file then
    file:write(content)
    file:close()
    os.remove(path)
    if os.rename(temporary_file, path) then
      return true
    end
    os.remove(temporary_file)
  end
  file = io.open(path, 'wb')
  if not file then
    return false
  end
  file:write(content)
  file:close()
  return true
end

-- 読めなければ nil
local function read_session_file(path)
  local content = read_text(path)
  if not content or #content == 0 then
    return nil
  end
  local ok, data = pcall(wezterm.json_parse, content)
  if not ok or type(data) ~= 'table' or type(data.windows) ~= 'table' then
    log(path .. ' を読めません')
    return nil
  end
  return data
end

-- 本体が無い・壊れているときは、書き込みの途中で残った .tmp を使う。
-- .bak は手で戻すための控えで、自動では読まない (session.json を消せば最初からやり直せる)
local function load_session()
  for _, suffix in ipairs({ '', '.tmp' }) do
    local data = read_session_file(settings.session_file .. suffix)
    if data then
      return data
    end
  end
  return nil
end

-- このプロセスが session.json を最初に書き換える前に、前回の内容を .bak へ控える
local function backup_once()
  if wezterm.GLOBAL[BACKED_UP_KEY] then
    return
  end
  wezterm.GLOBAL[BACKED_UP_KEY] = true
  local content = read_text(settings.session_file)
  if content and #content > 0 then
    write_text_atomic(settings.session_file .. '.bak', content)
  end
end

-- ---------------------------------------------------------------- 持ち主

local function own_pid()
  local ok, pid = pcall(wezterm.procinfo.pid)
  if ok and type(pid) == 'number' then
    return pid
  end
  return nil
end

-- session.json を書いた WezTerm が、自分とは別にまだ動いているか
local function is_other_gui_alive(pid)
  if type(pid) ~= 'number' then
    return false
  end
  pid = math.floor(pid)
  if pid == own_pid() then
    return false
  end
  local ok, executable = pcall(wezterm.procinfo.executable_path_for_pid, pid)
  if not ok or type(executable) ~= 'string' then
    return false
  end
  return executable:lower():find('wezterm-gui', 1, true) ~= nil
end

local function decide_role(session_data)
  local role = 'owner'
  if session_data and is_other_gui_alive(session_data.owner_pid) then
    role = 'secondary'
  end
  wezterm.GLOBAL[ROLE_KEY] = role
  return role
end

-- gui-startup を通っていないプロセス (設定の再読み込みでこの機能が入った場合) は、最初の保存時に決める
local function current_role()
  local role = wezterm.GLOBAL[ROLE_KEY]
  if role == 'owner' or role == 'secondary' then
    return role
  end
  return decide_role(read_session_file(settings.session_file))
end

-- ---------------------------------------------------------------- ペインのフォルダ

local function same_path(first, second)
  if first == nil or second == nil then
    return first == second
  end
  return first:gsub('[A-Z]', string.lower) == second:gsub('[A-Z]', string.lower)
end

local function home_path()
  return tab_memory.normalize_path(settings.home_dir)
end

local function load_pane_cache()
  local encoded = wezterm.GLOBAL[PANE_CACHE_KEY]
  if type(encoded) == 'string' and #encoded > 0 then
    local ok, decoded = pcall(wezterm.json_parse, encoded)
    if ok and type(decoded) == 'table' then
      return decoded
    end
  end
  return {}
end

local function save_pane_cache(pane_cache)
  wezterm.GLOBAL[PANE_CACHE_KEY] = wezterm.json_encode(pane_cache)
end

local function pane_key_of(pane)
  return 'p' .. tostring(pane:pane_id())
end

-- 保存するフォルダ。シェルがまだフォルダを通知していない間は、最後に分かっていたものを使う。
-- 届かずホームで開いたペインは、cd するまで本来のフォルダを保存し続ける (次回の起動で戻せるように)
local function pane_cwd_for_save(pane, pane_cache, alive_panes)
  local pane_key = pane_key_of(pane)
  alive_panes[pane_key] = true
  local entry = pane_cache[pane_key]
  if type(entry) ~= 'table' then
    entry = {}
  end
  local cwd = tab_memory.pane_cwd(pane)
  -- ネットワークのパス (\\server\share) は保存しない。次回の起動時に自動で接続しにいくことになるため
  if cwd and tab_memory.is_local_path(cwd) then
    entry.last = cwd
  else
    cwd = entry.last
  end
  if entry.intended then
    if cwd == nil or same_path(cwd, home_path()) then
      cwd = entry.intended
    else
      entry.intended = nil
    end
  end
  if entry.last or entry.intended then
    pane_cache[pane_key] = entry
  else
    pane_cache[pane_key] = nil
  end
  return cwd
end

-- ---------------------------------------------------------------- 保存

-- ペインの矩形の集まりを分割木にする。
-- 全ペインがどちらか片側に収まる縦線か横線を探して 2 つに分け、それぞれを同じ手順で分ける。
-- 分けられない配置なら nil
local function rects_to_layout(rects)
  if #rects == 1 then
    return { cwd = rects[1].cwd, active = rects[1].active or nil }
  end
  for _, axis in ipairs(AXES) do
    local sorted = {}
    for _, rect in ipairs(rects) do
      table.insert(sorted, rect)
    end
    table.sort(sorted, function(first, second)
      return first[axis.start] < second[axis.start]
    end)
    local region_start = sorted[1][axis.start]
    local region_end = region_start
    for _, rect in ipairs(sorted) do
      region_end = math.max(region_end, rect[axis.start] + rect[axis.length])
    end

    local first_end = region_start
    for index = 1, #sorted - 1 do
      first_end = math.max(first_end, sorted[index][axis.start] + sorted[index][axis.length])
      local second_start = sorted[index + 1][axis.start]
      -- 隣り合うペインの間には区切り線が 1 セルある
      if first_end < second_start then
        local first_rects = {}
        local second_rects = {}
        for sorted_index, rect in ipairs(sorted) do
          table.insert(sorted_index <= index and first_rects or second_rects, rect)
        end
        local first_layout = rects_to_layout(first_rects)
        local second_layout = rects_to_layout(second_rects)
        if not first_layout or not second_layout then
          return nil
        end
        -- 復元は cells (second 側のセル数) で分ける。percent はウィンドウが小さくて入らないときの代わり。
        -- WezTerm は「新しい側 = 全体 * percent / 100 の切り捨て」で分けるので、切り上げておく
        local cells = region_end - second_start
        local percent = math.ceil(cells * 100 / (region_end - region_start))
        return {
          split = axis.split,
          cells = cells,
          percent = clamp(percent, 1, 99),
          first = first_layout,
          second = second_layout,
        }
      end
    end
  end
  return nil
end

-- ウィンドウ 1 枚分。分割木にできないタブがあれば nil (その回は保存しない)
local function build_window(mux_window, store, pane_cache, alive_panes)
  local window_data = { active_tab = 1, tabs = {} }
  for _, tab_info in ipairs(mux_window:tabs_with_info()) do
    local tab = tab_info.tab
    local rects = {}
    for _, pane_info in ipairs(tab:panes_with_info()) do
      table.insert(rects, {
        left = pane_info.left,
        top = pane_info.top,
        width = pane_info.width,
        height = pane_info.height,
        cwd = pane_cwd_for_save(pane_info.pane, pane_cache, alive_panes),
        active = pane_info.is_active,
      })
      window_data.cols = math.max(window_data.cols or 0, pane_info.left + pane_info.width)
      window_data.rows = math.max(window_data.rows or 0, pane_info.top + pane_info.height)
    end
    if #rects > 0 then
      local layout = rects_to_layout(rects)
      if not layout then
        return nil
      end
      local tab_data = { layout = layout }
      local look = tab_memory.export_look(store, tab)
      if look then
        tab_data.title = look.title
        tab_data.colors = look.colors
        tab_data.auto = look.auto
      end
      table.insert(window_data.tabs, tab_data)
      if tab_info.is_active then
        window_data.active_tab = #window_data.tabs
      end
    end
  end
  return window_data
end

local function build_windows()
  local mux_windows = {}
  for _, mux_window in ipairs(wezterm.mux.all_windows()) do
    table.insert(mux_windows, mux_window)
  end
  table.sort(mux_windows, function(first, second)
    return first:window_id() < second:window_id()
  end)

  local store = state.load()
  local pane_cache = load_pane_cache()
  local alive_panes = {}
  local windows = {}
  local complete = true
  for _, mux_window in ipairs(mux_windows) do
    local window_data = build_window(mux_window, store, pane_cache, alive_panes)
    if not window_data then
      complete = false
    elseif #window_data.tabs > 0 then
      table.insert(windows, window_data)
    end
  end
  for pane_key in pairs(pane_cache) do
    if not alive_panes[pane_key] then
      pane_cache[pane_key] = nil
    end
  end
  save_pane_cache(pane_cache)
  if not complete then
    return nil
  end
  return windows
end

local function save_if_changed()
  if not settings.session_enabled or state.is_restoring() then
    return
  end
  -- update-status はウィンドウごとに来るので、全体で 1 秒に 1 回だけ調べる
  local now = os.time()
  if wezterm.GLOBAL[CHECKED_AT_KEY] == now then
    return
  end
  wezterm.GLOBAL[CHECKED_AT_KEY] = now
  if current_role() ~= 'owner' then
    return
  end

  local windows = build_windows()
  if not windows or #windows == 0 then
    return
  end
  local encoded = wezterm.json_encode(windows)
  local written_count = wezterm.GLOBAL[WINDOW_COUNT_KEY] or 0
  if #windows >= written_count then
    wezterm.GLOBAL[SHRINK_SINCE_KEY] = 0
  end
  if encoded == wezterm.GLOBAL[WRITTEN_KEY] then
    return
  end
  if #windows < written_count then
    local shrink_since = wezterm.GLOBAL[SHRINK_SINCE_KEY] or 0
    if shrink_since == 0 or wezterm.GLOBAL[SHRINK_COUNT_KEY] ~= #windows then
      -- 続けて閉じている間は、閉じるたびに数え直す
      wezterm.GLOBAL[SHRINK_SINCE_KEY] = now
      wezterm.GLOBAL[SHRINK_COUNT_KEY] = #windows
      return
    end
    if now - shrink_since < settings.session_window_close_grace_seconds then
      return
    end
    wezterm.GLOBAL[SHRINK_SINCE_KEY] = 0
  end

  backup_once()
  local content = wezterm.json_encode({
    version = VERSION,
    owner_pid = own_pid(),
    saved_at = os.date('%Y-%m-%dT%H:%M:%S'),
    windows = windows,
  })
  if write_text_atomic(settings.session_file, content .. '\n') then
    wezterm.GLOBAL[WRITTEN_KEY] = encoded
    wezterm.GLOBAL[WINDOW_COUNT_KEY] = #windows
  else
    log_once('write', settings.session_file .. ' に書けません')
  end
end

-- update-status: タブ構成が変わっていたら保存する
function module.on_update_status(_window, _pane)
  local ok, err = pcall(save_if_changed)
  if not ok then
    log_once('save', err)
  end
end

-- ---------------------------------------------------------------- 復元

local function first_leaf(node)
  while type(node) == 'table' and node.split do
    node = node.first
  end
  return node
end

-- 葉に保存されたフォルダ。ドライブ文字で始まるパスだけを使う。
-- それ以外 (ネットワークのパスなど) は、存在の確認もせずホームで開く
local function leaf_cwd(leaf)
  if type(leaf) ~= 'table' then
    return nil
  end
  local path = tab_memory.normalize_path(leaf.cwd)
  if tab_memory.is_local_path(path) then
    return path
  end
  return nil
end

local function collect_dirs(node, dirs)
  if type(node) ~= 'table' then
    return
  end
  if node.split then
    collect_dirs(node.first, dirs)
    collect_dirs(node.second, dirs)
    return
  end
  local cwd = leaf_cwd(node)
  if cwd then
    dirs[cwd] = true
  end
end

local function dir_exists(path)
  local ok = pcall(wezterm.read_dir, path)
  return ok
end

-- フォルダの存在を並行して確かめる。戻り値は { フォルダ -> true (開ける) }。
-- 存在しないフォルダや、時間内に応答が無いフォルダ (切断中のネットワークドライブ) は入らない
local function probe_dirs(dirs, timeout_ms)
  local home = home_path()
  local reachable = {}
  local answered = {}
  local targets = { [home] = true }
  for path in pairs(dirs) do
    targets[path] = true
  end
  local pending = 0
  for path in pairs(targets) do
    pending = pending + 1
    wezterm.time.call_after(0, function()
      local exists = dir_exists(path)
      answered[path] = true
      if exists then
        reachable[path] = true
      end
      pending = pending - 1
    end)
  end
  local waited_ms = 0
  while pending > 0 and waited_ms < timeout_ms do
    wezterm.sleep_ms(POLL_INTERVAL_MS)
    waited_ms = waited_ms + POLL_INTERVAL_MS
  end
  if not answered[home] then
    -- 必ずあるホームの結果すら来ないなら、並行して調べる仕組みが動いていない。1 個ずつ調べ直す
    log('フォルダの確認を並行して実行できません。順番に確認します')
    local checked = {}
    for path in pairs(targets) do
      if dir_exists(path) then
        checked[path] = true
      end
    end
    return checked
  end
  -- 時間切れの後で届いた結果が混ざらないよう、この時点の結果を写して返す
  local snapshot = {}
  for path in pairs(reachable) do
    snapshot[path] = true
  end
  return snapshot
end

-- 葉のペインを開くフォルダ。届かないときはホームで開き、本来のフォルダを intended に残す
local function resolve_cwd(leaf, context)
  local wanted = leaf_cwd(leaf)
  if not wanted then
    return { path = home_path() }
  end
  if context.reachable[wanted] then
    return { path = wanted }
  end
  return { path = home_path(), intended = wanted }
end

local function note_spawned_pane(pane, resolved, context)
  context.pane_cache[pane_key_of(pane)] = { last = resolved.path, intended = resolved.intended }
  context.pane_count = context.pane_count + 1
end

-- pane:split に渡す、新しいペイン側の大きさ。1 以上はセル数、1 未満は割合として扱われる。
-- 保存時と同じセル数が入るならセル数で、ウィンドウが小さくて入らないなら割合で分ける
-- (入らないセル数を渡すと分割に失敗し、起動済みのシェルがどのタブにも属さずに残る)
local function split_size(pane, node)
  local percent = clamp(tonumber(node.percent) or 50, 1, 99)
  -- WezTerm は size * 100 を切り捨てるので、0.5 足して誤差で 1 減るのを防ぐ
  local by_percent = (percent + 0.5) / 100
  local cells = tonumber(node.cells)
  if not cells or cells < 1 then
    return by_percent
  end
  local ok, dimensions = pcall(function()
    return pane:get_dimensions()
  end)
  if not ok or type(dimensions) ~= 'table' then
    return by_percent
  end
  local available = node.split == 'Right' and dimensions.cols or dimensions.viewport_rows
  -- 元のペインに 1 セル、区切り線に 1 セル要る
  if type(available) ~= 'number' or cells + 2 > available then
    return by_percent
  end
  return math.floor(cells)
end

-- pane が受け持つ領域を、分割木のとおりに分ける。先に 2 つへ分けてから、それぞれの中を分ける。
-- pane は最後に first 側をたどった先の葉になる
local function restore_layout(pane, node, context)
  if type(node) ~= 'table' then
    return
  end
  if node.split == 'Right' or node.split == 'Bottom' then
    local resolved = resolve_cwd(first_leaf(node.second), context)
    local size = split_size(pane, node)
    local ok, new_pane = pcall(function()
      return pane:split {
        direction = node.split,
        size = size,
        cwd = resolved.path,
      }
    end)
    if ok and new_pane then
      note_spawned_pane(new_pane, resolved, context)
      restore_layout(pane, node.first, context)
      restore_layout(new_pane, node.second, context)
    else
      log('ペインを分割できません: ' .. tostring(new_pane))
      restore_layout(pane, node.first, context)
    end
    return
  end
  if node.active then
    context.active_pane = pane
    context.active_cwd = resolve_cwd(node, context).path
  end
end

-- タブ 1 枚を作る。mux_window が nil なら新しいウィンドウに作る。戻り値は ウィンドウ, タブ
local function restore_tab(mux_window, window_data, tab_data, context)
  local resolved = resolve_cwd(first_leaf(tab_data.layout), context)
  local tab, pane
  if mux_window then
    tab, pane = mux_window:spawn_tab { cwd = resolved.path }
  else
    local spawn = { cwd = resolved.path }
    local cols = tonumber(window_data.cols)
    local rows = tonumber(window_data.rows)
    if cols and rows and cols >= 1 and rows >= 1 then
      spawn.width = math.floor(cols)
      spawn.height = math.floor(rows)
      -- ウィンドウはタブ 1 枚 (タブバーなし) の前提で作られ、2 枚目ができるとタブバーの分だけ行が減る
      if context.window_tab_count >= 2 then
        spawn.height = spawn.height + settings.session_tab_bar_rows
      end
    end
    tab, pane, mux_window = wezterm.mux.spawn_window(spawn)
  end
  note_spawned_pane(pane, resolved, context)

  -- ここから先で失敗しても、作ったタブは復元済みとして返す (ウィンドウを見失うと、次のタブが別のウィンドウになる)
  local ok, err = pcall(function()
    context.active_pane = pane
    context.active_cwd = resolved.path
    restore_layout(pane, tab_data.layout, context)

    -- 名前・色を保存していないタブ (初回処理の前に閉じたタブ) は、tab_memory の初回処理に任せる
    if type(tab_data.title) == 'string' or type(tab_data.colors) == 'table' then
      -- store は spawn や split をまたいで持ち回らない (その間に他の処理が書き換えうる)
      local store = state.load()
      tab_memory.adopt_look(store, tab, tab_data, context.active_cwd)
      state.save(store)
    end
    -- split のたびに新しいペインが選択されるので、最後に選び直す
    context.active_pane:activate()
  end)
  if not ok then
    log(err)
  end
  return mux_window, tab
end

local function restore_window(window_data, context)
  if type(window_data) ~= 'table' or type(window_data.tabs) ~= 'table' then
    return
  end
  context.window_tab_count = 0
  for _, tab_data in ipairs(window_data.tabs) do
    if type(tab_data) == 'table' and type(tab_data.layout) == 'table' then
      context.window_tab_count = context.window_tab_count + 1
    end
  end

  local mux_window = nil
  local active_tab = nil
  local last_tab = nil
  for tab_index, tab_data in ipairs(window_data.tabs) do
    if type(tab_data) == 'table' and type(tab_data.layout) == 'table' then
      local ok, restored_window, tab = pcall(restore_tab, mux_window, window_data, tab_data, context)
      if ok and tab then
        mux_window = restored_window
        last_tab = tab
        if tab_index == window_data.active_tab then
          active_tab = tab
        end
      else
        log('タブを復元できません: ' .. tostring(restored_window))
      end
    end
  end
  -- 選択中だったタブは、全部のウィンドウを作り終えてから選び直す (activate_tabs)
  active_tab = active_tab or last_tab
  if active_tab then
    table.insert(context.active_tab_ids, active_tab:tab_id())
  end
end

local function activate_tabs(tab_ids)
  for _, tab_id in ipairs(tab_ids) do
    local ok, err = pcall(function()
      local tab = wezterm.mux.get_tab(tab_id)
      if tab then
        tab:activate()
      end
    end)
    if not ok then
      log(err)
    end
  end
end

local function restore_session(cmd)
  if not settings.session_enabled then
    return
  end
  local session_data = load_session()
  if session_data and is_other_gui_alive(session_data.owner_pid) then
    -- 閉じてすぐ開き直すと、直前の WezTerm がまだ終了し切っていないことがある
    local waited_ms = 0
    while waited_ms < OWNER_EXIT_WAIT_MS and is_other_gui_alive(session_data.owner_pid) do
      wezterm.sleep_ms(POLL_INTERVAL_MS)
      waited_ms = waited_ms + POLL_INTERVAL_MS
    end
  end
  if decide_role(session_data) ~= 'owner' then
    log('別の WezTerm が動いているので、タブの復元と保存をしません')
    return
  end
  if not session_data then
    return
  end
  -- 復元がうまくいかず少ないタブで上書きされたときに、手で戻せるように控える
  backup_once()

  local dirs = {}
  local saved_tab_count = 0
  for _, window_data in ipairs(session_data.windows) do
    if type(window_data) == 'table' and type(window_data.tabs) == 'table' then
      for _, tab_data in ipairs(window_data.tabs) do
        if type(tab_data) == 'table' and type(tab_data.layout) == 'table' then
          saved_tab_count = saved_tab_count + 1
          collect_dirs(tab_data.layout, dirs)
        end
      end
    end
  end
  if saved_tab_count == 0 then
    return
  end

  state.set_restoring(true)
  local context = {
    reachable = probe_dirs(dirs, settings.session_probe_timeout_ms),
    pane_cache = {},
    pane_count = 0,
    window_tab_count = 0,
    active_tab_ids = {},
  }
  for _, window_data in ipairs(session_data.windows) do
    restore_window(window_data, context)
  end
  save_pane_cache(context.pane_cache)

  if context.pane_count == 0 then
    -- 1 個も作れなかった: WezTerm 既定の起動に任せる (cmd もそちらで実行される)。
    -- 既定のタブ 1 枚で session.json を上書きしないよう、このプロセスでは保存しない
    wezterm.GLOBAL[ROLE_KEY] = 'secondary'
    log('タブを 1 枚も復元できませんでした。session.json は書き換えません')
    return
  end
  if cmd then
    -- 「ここで開く」や wezterm start -- prog で起動された: 復元に加えて、その内容のウィンドウを開く
    local ok, err = pcall(wezterm.mux.spawn_window, cmd)
    if not ok then
      log(err)
    end
  end

  -- ペインを選び直すと、その通知が後から処理されて、ペインのあるタブが選択中になる。
  -- 通知を処理させてから、選択中だったタブを選び直す。処理が遅れた場合に備えて少し後にもう一度行う
  local active_tab_ids = context.active_tab_ids
  wezterm.sleep_ms(POLL_INTERVAL_MS)
  activate_tabs(active_tab_ids)
  wezterm.time.call_after(ACTIVATE_RETRY_SECONDS, function()
    activate_tabs(active_tab_ids)
  end)
end

-- gui-startup: 前回のタブ構成を作り直す
function module.on_gui_startup(cmd)
  local ok, err = pcall(restore_session, cmd)
  state.set_restoring(false)
  if not ok then
    log(err)
  end
end

return module
