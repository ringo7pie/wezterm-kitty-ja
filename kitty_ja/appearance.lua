-- フォント・ベル・タブバーを kitty 側の設定に寄せる。
local wezterm = require 'wezterm'
local settings = require 'kitty_ja.settings'

local module = {}

function module.apply(config)
  -- kitty.conf: font_family JetBrains Mono / font_size 11。日本語は等幅フォントへ落とす
  config.font = wezterm.font_with_fallback { 'JetBrains Mono', 'BIZ UDGothic' }
  config.font_size = settings.font_size
  -- kitty.conf: enable_audio_bell no
  config.audible_bell = 'Disabled'
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
