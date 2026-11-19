-- フォント・ベル・タブバーを kitty 側の設定に寄せる。描画方式 (CPU / GPU) も選ぶ。
local wezterm = require 'wezterm'
local settings = require 'kitty_ja.settings'

local module = {}

-- wezterm.gui.enumerate_gpus() の中から、backend が一致する単体 GPU を返す。無ければ nil。
-- wezterm.gui は GUI のプロセスにしか無いので、無いときは nil
local function find_discrete_gpu(backend)
  if not (wezterm.gui and wezterm.gui.enumerate_gpus) then
    return nil
  end
  for _, gpu in ipairs(wezterm.gui.enumerate_gpus()) do
    if gpu.backend == backend and gpu.device_type == 'DiscreteGpu' then
      return gpu
    end
  end
  return nil
end

-- 切り替えの操作 (toggle_render_mode) で選べる方式。render_mode_file にはこのどちらかだけを書く
local SWITCHABLE_RENDER_MODES = { ['webgpu-dx12'] = true, ['webgpu'] = true }

-- render_mode_file に保存した方式。無い・読めない・切り替え対象でない値なら nil
local function read_saved_render_mode()
  local file = io.open(settings.render_mode_file, 'rb')
  if not file then
    return nil
  end
  local content = file:read('a') or ''
  file:close()
  local mode = content:match('^%s*(%S+)%s*$')
  if mode and SWITCHABLE_RENDER_MODES[mode] then
    return mode
  end
  return nil
end

-- 使う描画方式。保存した方式 (render_mode_file) があればそれ、無ければ settings.lua の render_mode
function module.current_render_mode()
  return read_saved_render_mode() or settings.render_mode
end

-- os.rename は Windows では上書きできないので、消してから置き換える (session.lua の write_text_atomic と同じ手順)
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

-- 描画方式。RDP とコンソールを切り替えても窓が操作できるかは方式で変わる (settings.lua の render_mode)
local function apply_render_mode(config)
  local mode = module.current_render_mode()
  if mode == 'angle' then
    config.prefer_egl = true
  elseif mode == 'webgpu' then
    config.front_end = 'WebGpu'
  elseif mode == 'webgpu-dx12' then
    config.front_end = 'WebGpu'
    local gpu = find_discrete_gpu('Dx12')
    if gpu then
      config.webgpu_preferred_adapter = gpu
    elseif wezterm.gui then
      -- wezterm.gui が無いプロセス (mux-server・wezterm cli) では GPU を調べられないので、何も言わない
      wezterm.log_error('kitty_ja: DirectX 12 の GPU が見つからないので、WebGpu の既定の GPU を使います')
    end
  elseif mode == 'cpu' then
    config.front_end = 'WebGpu'
    config.webgpu_force_fallback_adapter = true
  elseif mode ~= 'opengl' then
    wezterm.log_error('kitty_ja: render_mode が不明です (' .. tostring(mode) .. ')。WezTerm の既定で描きます')
  end
end

local RENDER_MODE_LABELS = { ['webgpu-dx12'] = 'DirectX 12', ['webgpu'] = 'Vulkan' }

-- 描画方式を DirectX 12 ('webgpu-dx12') と Vulkan ('webgpu') で切り替えて render_mode_file に保存し、GUI を起動し直す。
-- 開いている窓は設定の再読み込みでは描画方式が変わらないので、起動し直さないと効かない。
-- mux-server 構成ならシェルは残るので、自動で起動し直す (shell\restart-gui.ps1)。そうでなければ、閉じるとシェルが終わるので通知だけ出す
function module.toggle_render_mode(window, _pane)
  local next_mode = module.current_render_mode() == 'webgpu-dx12' and 'webgpu' or 'webgpu-dx12'
  local label = RENDER_MODE_LABELS[next_mode]
  if not write_text_atomic(settings.render_mode_file, next_mode .. '\n') then
    window:toast_notification('WezTerm', '描画方式を保存できませんでした: ' .. settings.render_mode_file, nil, 6000)
    return
  end
  if not settings.mux_server then
    window:toast_notification('WezTerm', '次に WezTerm を起動したときから ' .. label .. ' で描きます。', nil, 6000)
    return
  end
  window:toast_notification('WezTerm', label .. ' で描くため、WezTerm の画面を起動し直します。', nil, 4000)
  -- 新しい GUI は 1 枚目のタブを開くので、今のタブを restart-gui.ps1 が開き直す。
  -- mux の窓では、GUI の tab_id は mux-server の tab_id と違うので、左から何枚目か (0 始まり) とタブの数を渡す
  local active_tab_index, tab_count = -1, 0
  pcall(function()
    local tabs = window:mux_window():tabs_with_info()
    tab_count = #tabs
    for _, info in ipairs(tabs) do
      if info.is_active then
        active_tab_index = info.index
      end
    end
  end)
  wezterm.background_child_process {
    settings.shell_program or settings.fallback_shell_program,
    '-NoLogo', '-NoProfile', '-NonInteractive', '-WindowStyle', 'Hidden',
    '-ExecutionPolicy', 'Bypass',
    '-File', settings.restart_gui_script,
    '-GuiPath', wezterm.executable_dir .. '\\wezterm-gui.exe',
    '-CliPath', wezterm.executable_dir .. '\\wezterm.exe',
    '-ActiveTabIndex', tostring(active_tab_index),
    '-TabCount', tostring(tab_count),
    '-Domain', settings.mux_domain_name,
    '-OldProcessId', tostring(wezterm.procinfo.pid()),
  }
end

function module.apply(config)
  -- kitty.conf: font_family JetBrains Mono / font_size 11。日本語は等幅フォントへ落とす
  config.font = wezterm.font_with_fallback { 'JetBrains Mono', 'BIZ UDGothic' }
  config.font_size = settings.font_size
  -- kitty.conf: enable_audio_bell no
  config.audible_bell = 'Disabled'
  apply_render_mode(config)

  -- kitty はフォントサイズを変えてもウィンドウの大きさを変えない
  config.adjust_window_size_when_changing_font_size = false

  -- kitty の既定: タブバーは下、タブが 2 枚以上のときだけ表示 (tab_bar_min_tabs 2)
  config.use_fancy_tab_bar = false
  config.tab_bar_at_bottom = true
  config.hide_tab_bar_if_only_one_tab = true
  config.show_new_tab_button_in_tab_bar = false
  config.tab_max_width = 40

  -- kitty の既定色: active #000 on #eee (bold-italic) / inactive #444 on #999
  config.colors = {
    tab_bar = {
      background = '#000000',
      active_tab = {
        bg_color = '#eeeeee',
        fg_color = '#000000',
        intensity = 'Bold',
        italic = true,
      },
      inactive_tab = {
        bg_color = '#999999',
        fg_color = '#444444',
      },
      inactive_tab_hover = {
        bg_color = '#aaaaaa',
        fg_color = '#222222',
      },
    },
  }
end

return module
