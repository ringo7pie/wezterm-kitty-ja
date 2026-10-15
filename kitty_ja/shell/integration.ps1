# WezTerm が起動した pwsh だけで実行される (shell.lua の default_prog)。
# pwsh は Set-Location してもプロセスのカレントディレクトリを変えないので、
# 現在のフォルダとプロンプトの位置をエスケープシーケンスで WezTerm に通知する。
#
# 呼び出し側は「& 'integration.ps1'」で実行する (ドットソースしない)。
# 下の StrictMode と $ErrorActionPreference をこのスクリプトのスコープに閉じ込め、
# 対話セッションの設定を変えないため。
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($env:TERM_PROGRAM -ne 'WezTerm') { return }

# WezTerm が環境変数で渡す合言葉。フォルダの通知に添えて、このシェルが出した通知だと WezTerm 側が確かめる。
# 端末に文字を出すだけのもの (ssh 先や表示したファイル) が通知を偽装できないようにするため。
# 子プロセスへ渡らないよう、読んだら環境変数から消す
$global:KittyJaToken = [string] $env:KITTY_JA_TOKEN
Remove-Item -LiteralPath Env:KITTY_JA_TOKEN -ErrorAction Ignore

function global:Send-KittyJaLocation {
    param([System.Management.Automation.PathInfo] $PathInfo)

    if ($null -eq $PathInfo -or $PathInfo.Provider.Name -ne 'FileSystem') { return }
    $providerPath = $PathInfo.ProviderPath
    $escape = [char]27
    $bell = [char]7
    $sequence = ''

    # OSC 7: WezTerm 標準の cwd 通知
    try {
        $locationUri = ([System.Uri]::new($providerPath)).AbsoluteUri
        $sequence += '{0}]7;{1}{0}\' -f $escape, $locationUri
    } catch {
        $sequence = ''
    }

    # ユーザー変数 kitty_ja_cwd: 「合言葉|Windows のパス」を渡す (タブ記憶とタブの復元が使う)
    $notification = '{0}|{1}' -f $global:KittyJaToken, $providerPath
    $encodedPath = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($notification))
    $sequence += '{0}]1337;SetUserVar=kitty_ja_cwd={1}{2}' -f $escape, $encodedPath, $bell
    [Console]::Write($sequence)

    # タブの既定名を現在のフォルダにする (kitty のシェル統合と同じ見え方)
    $titlePath = $providerPath
    $homePath = [Environment]::GetFolderPath('UserProfile')
    if ($homePath -and $titlePath.StartsWith($homePath, [System.StringComparison]::OrdinalIgnoreCase)) {
        $titlePath = '~' + $titlePath.Substring($homePath.Length)
    }
    try {
        $Host.UI.RawUI.WindowTitle = $titlePath
    } catch {
        # タイトルを変えられないホストでは何もしない
        return
    }
}

# cd の瞬間に通知する。既にハンドラがあれば残したまま追加する
$locationHandler = [System.EventHandler[System.Management.Automation.LocationChangedEventArgs]] {
    param($eventSource, $eventArguments)
    Send-KittyJaLocation $eventArguments.NewPath
}
$currentHandler = $ExecutionContext.SessionState.InvokeCommand.LocationChangedAction
if ($currentHandler) {
    $ExecutionContext.SessionState.InvokeCommand.LocationChangedAction =
        [Delegate]::Combine($currentHandler, $locationHandler)
} else {
    $ExecutionContext.SessionState.InvokeCommand.LocationChangedAction = $locationHandler
}

# プロンプトの位置 (OSC 133)。Ctrl+Shift+Z / X のプロンプト間移動が使う。
# 既存の prompt 関数は置き換えずに包む。
if (-not (Get-Variable -Name KittyJaOriginalPrompt -Scope Global -ErrorAction Ignore)) {
    $global:KittyJaOriginalPrompt = $function:prompt
    function global:prompt {
        $savedExitCode = Get-Variable -Name LASTEXITCODE -Scope Global -ValueOnly -ErrorAction Ignore
        # プロンプトのたびにフォルダを通知し直す。実行したプログラムが偽の通知を出していても、ここで正しい値に戻る
        try {
            Send-KittyJaLocation (Get-Location)
        } catch {
            # 通知に失敗しても、プロンプトは表示する
            $null = $_
        }
        $escape = [char]27
        $promptText = @(& $global:KittyJaOriginalPrompt) -join ''
        $global:LASTEXITCODE = $savedExitCode
        ('{0}]133;A{0}\' -f $escape) + $promptText + ('{0}]133;B{0}\' -f $escape)
    }
}

# コマンド出力の開始位置 (OSC 133;C)。Ctrl+Shift+G の「直前コマンドの出力」が使う。
if (Get-Command -Name Set-PSReadLineKeyHandler -ErrorAction Ignore) {
    Set-PSReadLineKeyHandler -Key Enter -BriefDescription 'KittyJaAcceptLine' -Description 'コマンドを実行し、出力の開始位置を WezTerm に通知する' -ScriptBlock {
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
        [Console]::Write(('{0}]133;C{0}\' -f [char]27))
    }
}

# 履歴の予測候補 (PSReadLine)。表示形式 (ListView / InlineView) は shell.lua が環境変数で渡す。空なら何もしない。
# $PROFILE の後に実行されるので、表示形式は $PROFILE で決めた値よりこちらが優先される。
# 予測の元 (履歴・プラグイン) は、予測が切れている (None) ときだけ履歴にする。HistoryAndPlugin など、既にある設定は変えない。
# 子プロセスへ渡らないよう、環境変数は読んだら消す
$predictionViewStyle = [string] $env:KITTY_JA_PREDICTION
Remove-Item -LiteralPath Env:KITTY_JA_PREDICTION -ErrorAction Ignore
if ($predictionViewStyle -in @('ListView', 'InlineView')) {
    $setOptionCommand = Get-Command -Name Set-PSReadLineOption -ErrorAction Ignore
    # 予測に対応していない PSReadLine (2.0.0 など) では、引数が無いので何もしない
    if ($setOptionCommand -and $setOptionCommand.Parameters.ContainsKey('PredictionSource') -and $setOptionCommand.Parameters.ContainsKey('PredictionViewStyle')) {
        try {
            $optionArguments = @{ PredictionViewStyle = $predictionViewStyle }
            if ([string] (Get-PSReadLineOption).PredictionSource -eq 'None') {
                $optionArguments.PredictionSource = 'History'
            }
            Set-PSReadLineOption @optionArguments
        } catch {
            # 予測を使えない端末 (出力がリダイレクトされている、など) では、そのままにする
            $null = $_
        }
    }
}

Send-KittyJaLocation (Get-Location)
