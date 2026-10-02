-- フォルダごとにタブ名・タブ色を記憶し、復元する。kitty 側の tab_memory.py の移植。
--
-- 動作:
--   - タブ名・タブ色を変えると、その時点のフォルダへ自動で記憶する
--   - cd でフォルダが変わる・新しいタブを開くと、記憶を自動で復元する
--   - 記憶が無いフォルダでは、一番近い親フォルダの記憶を使う
--   - 記憶が無いフォルダへ移ったとき、自動復元した名前・色だけ既定へ戻す
local wezterm = require 'wezterm'
local settings = require 'kitty_ja.settings'
local state = require 'kitty_ja.state'

local module = {}

local COLOR_FIELDS = { 'active_fg', 'active_bg', 'inactive_fg', 'inactive_bg' }
-- フォルダのパスとして受け付ける長さの上限 (バイト数)。Windows の長いパスの上限 32767 文字より十分短くてよい
local MAX_PATH_LENGTH = 4096
-- 初回処理のタイマーが設定の再読み込みで失われたときに、定期処理で拾い直すまでの秒数
local PENDING_FALLBACK_SECONDS = 2

local function log(message)
  wezterm.log_error('kitty_ja tab_memory: ' .. tostring(message))
end

-- ---------------------------------------------------------------- パス

-- 区切りを \ に統一、ドライブ文字を大文字に、末尾の \ を除去 (ドライブルートは C:\ のまま)
function module.normalize_path(raw_path)
  if type(raw_path) ~= 'string' or #raw_path == 0 then
    return nil
  end
  local path = raw_path:gsub('/', '\\')
  -- Url.file_path 由来の「\C:\...」
  path = path:gsub('^\\(%a:)', '%1')
  local is_unc = path:sub(1, 2) == '\\\\'
  local body = is_unc and path:sub(3) or path
  body = body:gsub('\\+', '\\')
  path = is_unc and ('\\\\' .. body) or body
  path = path:gsub('^(%a):', function(drive)
    return drive:upper() .. ':'
  end)
  if path:match('^%a:$') then
    path = path .. '\\'
  end
  if not path:match('^%a:\\$') then
    path = path:gsub('\\$', '')
  end
  return path
end

-- 照合用のキー。ASCII の大文字小文字だけを無視する
local function path_key(path)
  local key = path:gsub('[A-Z]', string.lower)
  return key
end

-- 親フォルダ。ドライブルートと UNC の共有ルートは自分自身を返す
local function parent_path(path)
  if path:match('^%a:\\$') then
    return path
  end
  if path:sub(1, 2) == '\\\\' then
    local server, share, rest = path:match('^\\\\([^\\]+)\\([^\\]+)(.*)$')
    if not server or rest == '' then
      return path
    end
    local parent_rest = rest:match('^(.*)\\[^\\]+$')
    return '\\\\' .. server .. '\\' .. share .. (parent_rest or '')
  end
  local parent = path:match('^(.*)\\[^\\]+$')
  if not parent then
    return path
  end
  if parent:match('^%a:$') then
    return parent .. '\\'
  end
  return parent
end

-- ここで記憶した内容はサブフォルダへ継承しない (全フォルダに効いてしまうため)。
-- kitty の「/ とホーム」に当たるのは、ドライブルート・共有ルートとホーム。
local function is_no_inherit(path)
  if parent_path(path) == path then
    return true
  end
  local home = module.normalize_path(settings.home_dir)
  return home ~= nil and path_key(path) == path_key(home)
end

-- ---------------------------------------------------------------- 見た目 (look)

-- look = { title = 文字列, active_fg, active_bg, inactive_fg, inactive_bg = '#RRGGBB' か nil }
local function default_look()
  return { title = '' }
end

local function looks_equal(first, second)
  if (first.title or '') ~= (second.title or '') then
    return false
  end
  for _, field in ipairs(COLOR_FIELDS) do
    if (first[field] or false) ~= (second[field] or false) then
      return false
    end
  end
  return true
end

local function is_default_look(look)
  return looks_equal(look, default_look())
end

local function copy_look(look)
  local copied = { title = look.title or '' }
  for _, field in ipairs(COLOR_FIELDS) do
    copied[field] = look[field]
  end
  return copied
end

local function normalize_color(value)
  if type(value) ~= 'string' or value:upper() == 'NONE' then
    return nil
  end
  if not value:match('^#%x%x%x%x%x%x$') then
    return nil
  end
  return value:upper()
end

-- ---------------------------------------------------------------- 記憶ファイル

local function json_string(text)
  local escaped = text:gsub('[%c"\\]', function(character)
    if character == '"' then
      return '\\"'
    elseif character == '\\' then
      return '\\\\'
    elseif character == '\n' then
      return '\\n'
    elseif character == '\r' then
      return '\\r'
    elseif character == '\t' then
      return '\\t'
    end
    return string.format('\\u%04x', character:byte())
  end)
  return '"' .. escaped .. '"'
end

-- memory.json を読む。戻り値は { フォルダ(正規化済み) -> look } と、ファイルが壊れているかどうか。
-- 壊れているとき (手で編集して JSON の書式を崩したとき) は、呼び出し側は上書きしないこと
local function load_folders()
  local folders = {}
  local file = io.open(settings.memory_file, 'rb')
  if not file then
    return folders, false
  end
  local content = file:read('a') or ''
  file:close()
  if not content:find('%S') then
    return folders, false
  end
  local ok, data = pcall(wezterm.json_parse, content)
  if not ok or type(data) ~= 'table' or type(data.folders) ~= 'table' then
    log(settings.memory_file .. ' を読めません。直すまで、タブ名・色の記憶は保存しません')
    return folders, true
  end
  for raw_path, entry in pairs(data.folders) do
    local path = module.normalize_path(raw_path)
    if path and type(entry) == 'table' then
      local look = { title = type(entry.title) == 'string' and entry.title or '' }
      for _, field in ipairs(COLOR_FIELDS) do
        look[field] = normalize_color(entry[field])
      end
      folders[path] = look
    end
  end
  return folders, false
end

-- 手で編集するファイルなので、フォルダ順に並べて整形して書く (kitty 側と同じ書式)
local function write_folders(folders)
  local paths = {}
  for path in pairs(folders) do
    table.insert(paths, path)
  end
  table.sort(paths)

  local lines = { '{', '  "version": 1,' }
  if #paths == 0 then
    table.insert(lines, '  "folders": {}')
  else
    table.insert(lines, '  "folders": {')
    for index, path in ipairs(paths) do
      local look = folders[path]
      table.insert(lines, '    ' .. json_string(path) .. ': {')
      table.insert(lines, '      "title": ' .. json_string(look.title or '') .. ',')
      for field_index, field in ipairs(COLOR_FIELDS) do
        local value = look[field] and json_string(look[field]) or 'null'
        local separator = field_index < #COLOR_FIELDS and ',' or ''
        table.insert(lines, '      ' .. json_string(field) .. ': ' .. value .. separator)
      end
      table.insert(lines, '    }' .. (index < #paths and ',' or ''))
    end
    table.insert(lines, '  }')
  end
  table.insert(lines, '}')
  local content = table.concat(lines, '\n') .. '\n'

  -- os.rename は Windows では上書きできないので、消してから置き換える
  local temporary_file = settings.memory_file .. '.tmp'
  local file = io.open(temporary_file, 'wb')
  if file then
    file:write(content)
    file:close()
    os.remove(settings.memory_file)
    if os.rename(temporary_file, settings.memory_file) then
      return true
    end
    os.remove(temporary_file)
  end
  file = io.open(settings.memory_file, 'wb')
  if not file then
    log(settings.memory_file .. ' に書けません')
    return false
  end
  file:write(content)
  file:close()
  return true
end

-- cwd 自身か一番近い親フォルダの記憶を返す。無ければ nil, nil
local function lookup(folders, cwd)
  local keyed = {}
  for path in pairs(folders) do
    keyed[path_key(path)] = path
  end
  local cwd_key = path_key(cwd)
  local path = cwd
  while true do
    local stored_path = keyed[path_key(path)]
    if stored_path and (path_key(path) == cwd_key or not is_no_inherit(path)) then
      return stored_path, folders[stored_path]
    end
    local parent = parent_path(path)
    if parent == path then
      return nil, nil
    end
    path = parent
  end
end

local function find_stored_path(folders, cwd)
  local cwd_key = path_key(cwd)
  for path in pairs(folders) do
    if path_key(path) == cwd_key then
      return path
    end
  end
  return nil
end

local function remember(cwd, look)
  local folders, broken = load_folders()
  if broken then
    -- 読めなかった内容を、この 1 件だけのファイルで上書きしない
    return
  end
  local stored_path = find_stored_path(folders, cwd)
  if is_default_look(look) then
    -- 既定の見た目 = 記憶なし
    if not stored_path then
      return
    end
    folders[stored_path] = nil
  else
    folders[stored_path or cwd] = copy_look(look)
  end
  write_folders(folders)
end

-- ---------------------------------------------------------------- タブ操作

local function percent_decode(text)
  local decoded = text:gsub('%%(%x%x)', function(hex)
    return string.char(tonumber(hex, 16))
  end)
  return decoded
end

-- 「C:\...」の形の、ドライブ文字で始まるパスか。
-- ネットワークのパス (\\server\share) やデバイスのパスは、開こうとするだけで相手へ接続して認証情報を送りうる。
-- 自動で開く処理 (セッションの復元、hints) は、この検査を通ったパスだけを使う
function module.is_local_path(path)
  return type(path) == 'string'
    and #path <= MAX_PATH_LENGTH
    and path:match('^%a:\\') ~= nil
    and path:find('%c') == nil
end

-- integration.ps1 が通知したフォルダ。値は「合言葉|パス」。合言葉が合わない値は偽装とみなして無視する
local function notified_cwd(pane)
  local ok, user_vars = pcall(function()
    return pane:get_user_vars()
  end)
  if not ok or type(user_vars) ~= 'table' then
    return nil
  end
  local value = user_vars.kitty_ja_cwd
  if type(value) ~= 'string' or #value == 0 or #value > MAX_PATH_LENGTH + 64 then
    return nil
  end
  local token, raw_path = value:match('^([^|]*)|(.*)$')
  if token ~= state.shell_token() then
    return nil
  end
  local path = module.normalize_path(raw_path)
  if not path or #path > MAX_PATH_LENGTH or path:find('%c') then
    return nil
  end
  return path
end

-- OSC 7 か、シェルのプロセスから WezTerm が調べたフォルダ。
-- OSC 7 は端末に文字を出すだけで誰でも送れるので、ドライブ文字で始まるパスだけを受け付ける
local function reported_cwd(pane)
  local cwd_ok, cwd = pcall(function()
    return pane:get_current_working_dir()
  end)
  if not cwd_ok or not cwd then
    return nil
  end
  local raw_path = nil
  if type(cwd) == 'string' then
    local encoded_path = cwd:match('^file://[^/]*(/.*)$')
    raw_path = encoded_path and percent_decode(encoded_path) or nil
  else
    local path_ok, file_path = pcall(function()
      return cwd.file_path
    end)
    if path_ok and type(file_path) == 'string' then
      raw_path = file_path
    end
  end
  local path = module.normalize_path(raw_path)
  if module.is_local_path(path) then
    return path
  end
  return nil
end

-- ペインで動くシェルの現在のフォルダ。integration.ps1 が通知したユーザー変数を優先する
function module.pane_cwd(pane)
  if not pane then
    return nil
  end
  return notified_cwd(pane) or reported_cwd(pane)
end

local function tab_cwd(tab)
  local ok, pane = pcall(function()
    return tab:active_pane()
  end)
  if not ok then
    return nil
  end
  return module.pane_cwd(pane)
end

local function tab_look(tab, tab_state)
  local look = { title = tab:get_title() or '' }
  local colors = tab_state.colors or {}
  for _, field in ipairs(COLOR_FIELDS) do
    look[field] = colors[field]
  end
  return look
end

local function apply_look(tab, tab_state, look)
  if looks_equal(tab_look(tab, tab_state), look) then
    return
  end
  local colors = {}
  for _, field in ipairs(COLOR_FIELDS) do
    colors[field] = look[field]
  end
  tab_state.colors = colors
  if (tab:get_title() or '') ~= (look.title or '') then
    tab:set_title(look.title or '')
  end
end

local function restore(tab, tab_state, cwd)
  local stored_path, look = nil, nil
  if cwd then
    stored_path, look = lookup(load_folders(), cwd)
  end
  if look then
    -- 手で付けた見た目と同じ記憶なら、手動設定のまま扱う
    if not (tab_state.auto == nil and looks_equal(tab_look(tab, tab_state), look)) then
      apply_look(tab, tab_state, look)
      tab_state.auto = stored_path
    end
  elseif tab_state.auto ~= nil then
    -- 自動復元した見た目だけ戻す。手で付けた名前・色は残す
    apply_look(tab, tab_state, default_look())
    tab_state.auto = nil
  end
  tab_state.look = tab_look(tab, tab_state)
end

local function tab_key_of(tab)
  return 't' .. tostring(tab:tab_id())
end

local function first_sight(store, tab)
  local tab_key = tab_key_of(tab)
  store.pending[tab_key] = nil
  if store.tabs[tab_key] then
    return
  end
  local cwd = tab_cwd(tab)
  local tab_state = { cwd = cwd, colors = {} }
  tab_state.look = tab_look(tab, tab_state)
  store.tabs[tab_key] = tab_state
  -- 最初から名前が付いているタブはそのまま使う
  if is_default_look(tab_state.look) then
    restore(tab, tab_state, cwd)
  end
end

local function gui_window_of(tab)
  local ok, gui_window = pcall(function()
    return tab:window():gui_window()
  end)
  if ok then
    return gui_window
  end
  return nil
end

local function first_sight_by_id(tab_id)
  local ok, err = pcall(function()
    local tab = wezterm.mux.get_tab(tab_id)
    local store = state.load()
    if not tab then
      store.pending['t' .. tostring(tab_id)] = nil
      state.save(store)
      return
    end
    first_sight(store, tab)
    state.save(store)
    state.request_redraw(gui_window_of(tab))
  end)
  if not ok then
    log(err)
  end
end

local function same_path(first, second)
  if first == nil or second == nil then
    return first == second
  end
  return path_key(first) == path_key(second)
end

local function sync_tab(store, tab)
  local tab_key = tab_key_of(tab)
  local tab_state = store.tabs[tab_key]
  if not tab_state then
    local pending_since = store.pending[tab_key]
    if not pending_since then
      store.pending[tab_key] = os.time()
      local tab_id = tab:tab_id()
      wezterm.time.call_after(settings.new_tab_delay_seconds, function()
        first_sight_by_id(tab_id)
      end)
    elseif os.time() - pending_since >= PENDING_FALLBACK_SECONDS then
      first_sight(store, tab)
    end
    return
  end

  tab_state.colors = tab_state.colors or {}
  tab_state.look = tab_state.look or default_look()
  local cwd = tab_cwd(tab)
  local look = tab_look(tab, tab_state)
  if not looks_equal(look, tab_state.look) then
    -- 名前・色がユーザー操作で変わった → 今のフォルダへ記憶
    tab_state.cwd = cwd
    tab_state.look = look
    tab_state.auto = nil
    if cwd then
      remember(cwd, look)
    end
    return
  end
  if cwd and not same_path(cwd, tab_state.cwd) then
    tab_state.cwd = cwd
    restore(tab, tab_state, cwd)
  end
end

local function ensure_state(store, tab)
  local tab_key = tab_key_of(tab)
  store.pending[tab_key] = nil
  local tab_state = store.tabs[tab_key]
  if not tab_state then
    tab_state = { cwd = tab_cwd(tab), colors = {} }
    tab_state.look = tab_look(tab, tab_state)
    store.tabs[tab_key] = tab_state
  end
  tab_state.colors = tab_state.colors or {}
  return tab_state
end

local function prune(store)
  local alive = {}
  for _, mux_window in ipairs(wezterm.mux.all_windows()) do
    for _, tab in ipairs(mux_window:tabs()) do
      alive[tab_key_of(tab)] = true
    end
  end
  for tab_key in pairs(store.tabs) do
    if not alive[tab_key] then
      store.tabs[tab_key] = nil
    end
  end
  for tab_key in pairs(store.pending) do
    if not alive[tab_key] then
      store.pending[tab_key] = nil
    end
  end
end

-- ---------------------------------------------------------------- イベント

local function sync_tabs(gui_window, tabs)
  local ok, err = pcall(function()
    local store = state.load()
    local before = wezterm.json_encode(store.tabs)
    for _, tab in ipairs(tabs) do
      sync_tab(store, tab)
    end
    prune(store)
    state.save(store)
    if wezterm.json_encode(store.tabs) ~= before then
      state.request_redraw(gui_window)
    end
  end)
  if not ok then
    log(err)
  end
end

-- update-status: 新しいタブと、外から変えられたタブ名を拾う
function module.on_update_status(window, _pane)
  if state.is_restoring() then
    return
  end
  local ok, tabs = pcall(function()
    return window:mux_window():tabs()
  end)
  if ok then
    sync_tabs(window, tabs)
  end
end

-- user-var-changed: cd の直後に integration.ps1 から届く
function module.on_user_var_changed(window, pane, name, _value)
  if name ~= 'kitty_ja_cwd' or state.is_restoring() then
    return
  end
  local ok, tab = pcall(function()
    return pane:tab()
  end)
  if ok and tab then
    sync_tabs(window, { tab })
  end
end

-- ---------------------------------------------------------------- セッション (session.lua)

-- 保存用: タブの名前・色。まだ初回処理を終えていないタブは nil
function module.export_look(store, tab)
  local tab_state = store.tabs[tab_key_of(tab)]
  if not tab_state then
    return nil
  end
  local colors = {}
  local has_color = false
  for _, field in ipairs(COLOR_FIELDS) do
    local color = (tab_state.colors or {})[field]
    if color then
      colors[field] = color
      has_color = true
    end
  end
  return {
    title = tab:get_title() or '',
    colors = has_color and colors or nil,
    auto = tab_state.auto,
  }
end

-- 復元用: export_look の内容を、作り直したタブへ付ける。cwd はタブの選択中ペインのフォルダ。
-- look は実際のタブから作り直す (保存値のまま入れて食い違うと、sync_tab がユーザー操作とみなして記憶を書き換える)
function module.adopt_look(store, tab, saved, cwd)
  local tab_key = tab_key_of(tab)
  local colors = {}
  if type(saved.colors) == 'table' then
    for _, field in ipairs(COLOR_FIELDS) do
      colors[field] = normalize_color(saved.colors[field])
    end
  end
  local title = type(saved.title) == 'string' and saved.title or ''
  if (tab:get_title() or '') ~= title then
    tab:set_title(title)
  end
  local tab_state = {
    cwd = cwd,
    colors = colors,
    auto = type(saved.auto) == 'string' and saved.auto or nil,
  }
  tab_state.look = tab_look(tab, tab_state)
  store.tabs[tab_key] = tab_state
  store.pending[tab_key] = nil
end

-- ---------------------------------------------------------------- 手動操作

-- 現在のタブの名前・色をユーザー操作として変える。変更はその時点のフォルダへ記憶される
function module.change_look(window, mutate)
  local ok, err = pcall(function()
    local tab = window:active_tab()
    local store = state.load()
    local tab_state = ensure_state(store, tab)
    mutate(tab, tab_state)
    sync_tab(store, tab)
    state.save(store)
    state.request_redraw(window)
  end)
  if not ok then
    log(err)
  end
end

function module.set_active_tab_title(window, title)
  module.change_look(window, function(tab, _tab_state)
    tab:set_title(title)
  end)
end

local function open_in_editor(path)
  local command = {}
  for _, argument in ipairs(settings.editor_command) do
    table.insert(command, argument)
  end
  table.insert(command, path)
  wezterm.background_child_process(command)
end
module.open_in_editor = open_in_editor

-- save / restore / forget / edit (tab_memory.py の run_command)
function module.run_command(window, command)
  local ok, err = pcall(function()
    if command == 'edit' then
      local file = io.open(settings.memory_file, 'rb')
      if file then
        file:close()
      else
        write_folders(load_folders())
      end
      open_in_editor(settings.memory_file)
      return
    end

    local tab = window:active_tab()
    local store = state.load()
    local tab_state = ensure_state(store, tab)
    local cwd = tab_cwd(tab)
    if not cwd then
      log('現在のフォルダを取得できません')
      state.save(store)
      return
    end
    tab_state.cwd = cwd
    if command == 'save' then
      local look = tab_look(tab, tab_state)
      remember(cwd, look)
      tab_state.look = look
      tab_state.auto = nil
    elseif command == 'restore' then
      restore(tab, tab_state, cwd)
    elseif command == 'forget' then
      local folders = load_folders()
      local stored_path = lookup(folders, cwd)
      if stored_path then
        folders[stored_path] = nil
        write_folders(folders)
      end
      apply_look(tab, tab_state, default_look())
      tab_state.auto = nil
      -- さらに上の親フォルダに記憶があればそれを使う
      restore(tab, tab_state, cwd)
    else
      log('不明なサブコマンド: ' .. tostring(command))
    end
    state.save(store)
    state.request_redraw(window)
  end)
  if not ok then
    log(err)
  end
end

return module
