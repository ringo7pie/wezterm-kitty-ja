-- 既定のシェル。pwsh の起動時に integration.ps1 を実行させる ($PROFILE は触らない)。
-- ドットソースではなく & で実行し、スクリプト内の StrictMode を対話セッションへ漏らさない。
local wezterm = require 'wezterm'
local settings = require 'kitty_ja.settings'
local state = require 'kitty_ja.state'

local module = {}

function module.apply(config)
  if not settings.shell_program then
    -- PowerShell 7 が無い: 端末は使えるようにしておく。
    -- フォルダの通知が来ないので、タブ記憶・タブの復元先・プロンプト間の移動は働かない
    wezterm.log_error('kitty_ja: PowerShell 7 (pwsh.exe) が見つかりません。Windows PowerShell で起動します')
    config.default_prog = { settings.fallback_shell_program, '-NoLogo' }
    return
  end

  -- スクリプトのパスと合言葉は環境変数で渡す。
  -- パスを -Command の文字列へ埋め込むと、引用符を含むパスでコマンドが壊れる
  local environment = {}
  local ok, existing = pcall(function()
    return config.set_environment_variables
  end)
  if ok and type(existing) == 'table' then
    for name, value in pairs(existing) do
      environment[name] = value
    end
  end
  environment.KITTY_JA_INTEGRATION = settings.integration_script
  environment.KITTY_JA_TOKEN = state.shell_token()
  -- 履歴の予測候補の表示形式。決まった値以外 (false など) は空にして、integration.ps1 に何もさせない
  local prediction = settings.history_prediction
  if prediction ~= 'ListView' and prediction ~= 'InlineView' then
    prediction = ''
  end
  environment.KITTY_JA_PREDICTION = prediction
  config.set_environment_variables = environment

  config.default_prog = {
    settings.shell_program,
    '-NoLogo',
    '-NoExit',
    '-Command',
    '& $env:KITTY_JA_INTEGRATION',
  }end

return module
