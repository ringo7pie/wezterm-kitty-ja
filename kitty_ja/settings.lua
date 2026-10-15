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

local function file_exists(path)
  local file = io.open(path, 'rb')
  if file then
    file:close()
    return true
  end
  return false
end

-- Program Files 以下の relative_path にあるファイルを探す。無ければ nil
local function find_in_program_files(relative_path)
  for _, variable in ipairs({ 'ProgramW6432', 'ProgramFiles', 'ProgramFiles(x86)' }) do
    local base = os.getenv(variable)
    if base and #base > 0 and file_exists(base .. '\\' .. relative_path) then
      return base .. '\\' .. relative_path
    end
  end
  return nil
end

-- PowerShell 7 (pwsh.exe) の場所。見つからなければ nil。
-- 既定のインストール先、PATH の順に探す。Microsoft Store 版はファイルとして開けず見つけられないので、
-- その場合は環境変数 KITTY_JA_PWSH に pwsh.exe のパスを入れる
local function find_pwsh()
  local override = os.getenv('KITTY_JA_PWSH')
  if override and #override > 0 then
    return override
  end
  local installed = find_in_program_files('PowerShell\\7\\pwsh.exe')
  if installed then
    return installed
  end
  for directory in (os.getenv('PATH') or ''):gmatch('[^;]+') do
    local candidate = directory:gsub('[\\/]+$', '') .. '\\pwsh.exe'
    if file_exists(candidate) then
      return candidate
    end
  end
  return nil
end

-- Windows 付属のプログラムは、名前だけで起動せずフルパスで指定する
-- (名前だけだと、カレントフォルダや PATH にある同名の別のプログラムが起動しうる)
local system_directory = (os.getenv('SystemRoot') or 'C:\\Windows') .. '\\System32'

module.shell_program = find_pwsh()
-- PowerShell 7 が無いときに使う Windows PowerShell
module.fallback_shell_program = system_directory .. '\\WindowsPowerShell\\v1.0\\powershell.exe'
module.integration_script = wezterm.home_dir .. '\\.config\\wezterm\\kitty_ja\\shell\\integration.ps1'

-- 履歴の予測候補 (PSReadLine の予測。入力しかけの文字に合う過去のコマンドを出す)。integration.ps1 が pwsh の起動時に設定する。
--   'ListView'   候補の一覧を入力行の下に出す
--   'InlineView' 入力行の続きに、候補を 1 つだけ薄く出す
--   false        何も設定しない ($PROFILE の設定をそのまま使う)
-- integration.ps1 は $PROFILE の後に実行されるので、表示形式は、$PROFILE の設定よりこちらが優先される。
-- 予測の元 (履歴・プラグイン) は、予測が切れている (None) ときだけ履歴にする。HistoryAndPlugin など、既にある設定は変えない。
-- PSReadLine が予測に対応していない (Windows PowerShell 5.1 の PSReadLine 2.0.0 など) ときは、何も起きない
module.history_prediction = 'ListView'

-- colors.txt / memory.json / 設定ファイルを開くエディタ (kitty 側の nano に相当)。
-- Notepad++ があればそれを、無ければメモ帳を使う
local notepad_plus_plus = find_in_program_files('Notepad++\\notepad++.exe')
module.editor_command = { notepad_plus_plus or (system_directory .. '\\notepad.exe') }
-- 「ファイル:行番号」を開くときに行番号の前へ付ける引数。行を指定して開けないエディタでは nil
module.editor_line_option = notepad_plus_plus and '-n' or nil

module.font_size = 11
-- 画面の描画方式。RDP で起動した窓は、コンソール (HDMI) に切り替えている間、画面が止まって見えることがある
-- (窓は描き続けているつもりでも、画面に出ない。RDP に戻すと動く)。この PC (RTX 3070) で、RDP で起動した窓を HDMI に
-- 3 分ほど切り替えて、画面の絵が止まるかを撮って確かめた結果 (2026-10-15):
--   'opengl'      WezTerm の既定 (NVIDIA の OpenGL)。切り替えの瞬間から止まった。paint 0.9 ms
--   'angle'       OpenGL を ANGLE (Direct3D 11) 経由にする。約 42 秒後に止まった
--   'webgpu'      WebGpu。GPU とバックエンドは WezTerm が選ぶ (この PC では NVIDIA の Vulkan)。止まらなかった。paint 14 ms
--   'webgpu-dx12' WebGpu で DirectX 12 の GPU を選ぶ。止まらなかった。paint 1.7 ms。見つからなければ 'webgpu' と同じ
--   'cpu'         WebGpu の CPU アダプタ (Windows 標準の WARP) で描く。止まらなかったが、paint 414 ms と重い
-- paint は、出力が流れ続けるときの 1 回の描画の中央値。別の PC・GPU では結果が変わりうる。
-- 開いている窓は設定の再読み込みでは切り替わらない。変えたら WezTerm を起動し直す
module.render_mode = 'webgpu-dx12'

-- true: シェルを wezterm-mux-server に持たせ、GUI はそこへ接続するだけにする (mux.lua)。
-- GUI を閉じる・固まった GUI を強制終了する・GUI を起動し直しても、シェルとその中のプログラム (Claude Code など) は動き続ける。
-- 最初の GUI の起動でサーバーが自動で起動し、GUI を全部閉じても残る。サーバーを止める (PC を再起動する) とシェルも全部終わる。
-- GUI を複数起動すると、どれも同じウィンドウを映す。別のウィンドウが要るときは Ctrl+Shift+N。
-- 起動中の GUI は設定の再読み込みでは切り替わらない。変えたら WezTerm を起動し直す
module.mux_server = true
-- unix_domains に登録するドメイン名 (wezterm connect <名前> の名前)
module.mux_domain_name = 'unix'
-- シェルを起動する mux-server と、通知を確かめる GUI は別のプロセスなので、シェル連携の合言葉 (state.lua) はファイルで共有する。
-- mux-server が起動時に書き、GUI が読む
module.shell_token_file = data_dir .. '\\shell-token.txt'
-- kitty の既定キーは 2.0 刻み、commands.tsv (パレット) は 1.0 刻み
module.font_size_step_key = 2.0
module.font_size_step_palette = 1.0
module.opacity_step = 0.1

-- 新しいタブは名前が付け終わるまで待ってから扱う (tab_memory.py の NEW_TAB_DELAY)
module.new_tab_delay_seconds = 0.5

module.documentation_url = 'https://wezterm.org/'

return module
