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

-- 描画方式。RDP とコンソールを切り替えても窓が操作できるかは方式で変わる (settings.lua の render_mode)
local function apply_render_mode(config)
  local mode = settings.render_mode
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
