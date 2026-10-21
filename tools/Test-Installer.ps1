#requires -Version 7.0
<#
.SYNOPSIS
install.ps1 / uninstall.ps1 / New-Package.ps1 を、使い捨てのホームフォルダに対して実行して確かめる。

.DESCRIPTION
実際のホームフォルダと WezTerm の設定には触らない。次を確かめる。

  - -WhatIf は何も作らない
  - インストールで、設定本体・入口・タブ色の定義が置かれる
  - 2 回目の実行では、バックアップを作らない
  - 中身の違う .wezterm.lua があれば、消さずに .bak-<日時> として残す
  - 利用者が編集した colors.txt を上書きしない
  - uninstall は、設定を消さずに .removed-<日時> として残し、データは残す
  - 設定の置き場所が塞がれているとき (XDG_CONFIG_HOME、.config\wezterm\wezterm.lua) は、何も変更せずに止まる
  - 配布 zip が作れ、公開しないものが入っていない
  - シェル連携スクリプト (integration.ps1) が、履歴の予測候補を設定できない端末 (出力がリダイレクトされている) でも、
    エラーにならずに終わり、受け取った環境変数を消す。履歴を選んで消すキーが不正でも同じ
  - 履歴ファイルの書き換え (history.ps1) が、複数行のコマンド・重複・改行の違い・日本語で正しく働く

install.ps1 と uninstall.ps1 は、PowerShell 7 と Windows PowerShell 5.1 の両方で実行する。
ソフトのインストール (winget) は、どの検査でも行わない。

.OUTPUTS
検査の結果の要約。1 件でも失敗すれば、終了コード 1 で終わる。
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$scratchRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('wezterm-kitty-ja-test-' + [guid]::NewGuid().ToString('N'))
$failures = [System.Collections.Generic.List[string]]::new()
$passedCount = 0

function Assert-Condition {
    param(
        [bool] $Condition,
        [string] $Description
    )

    if ($Condition) {
        $script:passedCount++
        Write-Output "  ok   $Description"
    } else {
        $script:failures.Add($Description)
        Write-Output "  FAIL $Description"
    }
}

# スクリプトを別のプロセスで実行する。Windows PowerShell 5.1 は、標準エラーをリダイレクトすると
# 例外にするので、この関数の中だけ ErrorActionPreference を緩める
function Invoke-ScriptInChild {
    param(
        [string] $ShellPath,
        [string] $ScriptPath,
        [string[]] $Arguments = @()
    )

    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & $ShellPath -NoProfile -ExecutionPolicy Bypass -File $ScriptPath @Arguments 2>&1
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
    }
    return [pscustomobject]@{ ExitCode = $exitCode; Output = (@($output) -join "`n") }
}

function Get-ItemCount {
    param([string] $Path)

    return @(Get-ChildItem -LiteralPath $Path -Recurse -Force).Count
}

function Test-InstallerWithShell {
    param(
        [string] $ShellLabel,
        [string] $ShellPath
    )

    Write-Output ''
    Write-Output "== $ShellLabel =="
    $installScript = Join-Path $repositoryRoot 'install.ps1'
    $uninstallScript = Join-Path $repositoryRoot 'uninstall.ps1'
    $homePath = Join-Path $scratchRoot $ShellLabel
    $null = New-Item -ItemType Directory -Path $homePath -Force
    $entryFile = Join-Path $homePath '.wezterm.lua'
    $moduleDirectory = Join-Path (Join-Path (Join-Path $homePath '.config') 'wezterm') 'kitty_ja'
    $dataDirectory = Join-Path (Join-Path $homePath '.config') 'wezterm-kitty-ja'
    $colorsFile = Join-Path (Join-Path $dataDirectory 'tab-colors') 'colors.txt'
    $commonArguments = @('-HomePath', $homePath, '-SkipRequirementCheck', '-NoPrompt')

    $result = Invoke-ScriptInChild -ShellPath $ShellPath -ScriptPath $installScript -Arguments ($commonArguments + '-WhatIf')
    Assert-Condition ($result.ExitCode -eq 0) '-WhatIf が正常に終わる'
    Assert-Condition ((Get-ItemCount -Path $homePath) -eq 0) '-WhatIf は何も作らない'

    $result = Invoke-ScriptInChild -ShellPath $ShellPath -ScriptPath $installScript -Arguments $commonArguments
    Assert-Condition ($result.ExitCode -eq 0) 'インストールが正常に終わる'
    Assert-Condition (Test-Path -LiteralPath $entryFile -PathType Leaf) '入口 (.wezterm.lua) が置かれる'
    Assert-Condition (Test-Path -LiteralPath (Join-Path $moduleDirectory 'init.lua') -PathType Leaf) '設定本体 (kitty_ja\init.lua) が置かれる'
    Assert-Condition (Test-Path -LiteralPath (Join-Path (Join-Path $moduleDirectory 'shell') 'integration.ps1') -PathType Leaf) 'シェル連携スクリプトが置かれる'
    Assert-Condition (Test-Path -LiteralPath $colorsFile -PathType Leaf) 'タブ色の定義 (colors.txt) が置かれる'
    Assert-Condition (@(Get-ChildItem -LiteralPath $homePath -Recurse -Force -Filter '*.bak-*').Count -eq 0) '初回はバックアップを作らない'

    $result = Invoke-ScriptInChild -ShellPath $ShellPath -ScriptPath $installScript -Arguments $commonArguments
    Assert-Condition ($result.ExitCode -eq 0) '2 回目のインストールが正常に終わる'
    Assert-Condition (@(Get-ChildItem -LiteralPath $homePath -Recurse -Force -Filter '*.bak-*').Count -eq 0) '2 回目はバックアップを作らない (同じ中身なので)'

    Set-Content -LiteralPath $colorsFile -Value '# edited by the user' -Encoding utf8
    Set-Content -LiteralPath $entryFile -Value 'return {} -- someone else''s config' -Encoding utf8
    $result = Invoke-ScriptInChild -ShellPath $ShellPath -ScriptPath $installScript -Arguments $commonArguments
    Assert-Condition ($result.ExitCode -eq 0) '別の .wezterm.lua があるときも、インストールが正常に終わる'
    $entryBackups = @(Get-ChildItem -LiteralPath $homePath -Force -Filter '.wezterm.lua.bak-*')
    Assert-Condition ($entryBackups.Count -eq 1) '中身の違う .wezterm.lua を .bak-<日時> として残す'
    if ($entryBackups.Count -eq 1) {
        Assert-Condition ((Get-Content -LiteralPath $entryBackups[0].FullName -Raw) -match "someone else's config") 'バックアップに元の中身が残っている'
    }
    Assert-Condition ((Get-Content -LiteralPath $entryFile -Raw) -match "require\s+'kitty_ja'|pcall\(require,\s*'kitty_ja'\)") '入口が kitty_ja を読み込む内容になる'
    Assert-Condition ((Get-Content -LiteralPath $colorsFile -Raw) -match 'edited by the user') '利用者が編集した colors.txt を上書きしない'

    $result = Invoke-ScriptInChild -ShellPath $ShellPath -ScriptPath $uninstallScript -Arguments @('-HomePath', $homePath)
    Assert-Condition ($result.ExitCode -eq 0) 'アンインストールが正常に終わる'
    Assert-Condition (-not (Test-Path -LiteralPath $moduleDirectory)) 'アンインストールで設定本体が外れる'
    Assert-Condition (@(Get-ChildItem -LiteralPath (Split-Path -Parent $moduleDirectory) -Force -Filter 'kitty_ja.removed-*').Count -eq 1) '設定本体を消さずに .removed-<日時> として残す'
    Assert-Condition (-not (Test-Path -LiteralPath $entryFile)) 'アンインストールで入口が外れる'
    Assert-Condition (Test-Path -LiteralPath $colorsFile -PathType Leaf) 'データ (colors.txt) は残す'
}

function Test-BlockedInstall {
    param(
        [string] $ShellPath,
        [string] $Label,
        [scriptblock] $Prepare,
        [scriptblock] $Cleanup
    )

    $homePath = Join-Path $scratchRoot $Label
    $null = New-Item -ItemType Directory -Path $homePath -Force
    & $Prepare $homePath
    try {
        $result = Invoke-ScriptInChild -ShellPath $ShellPath -ScriptPath (Join-Path $repositoryRoot 'install.ps1') `
            -Arguments @('-HomePath', $homePath, '-SkipRequirementCheck', '-NoPrompt')
    } finally {
        & $Cleanup
    }
    Assert-Condition ($result.ExitCode -ne 0) "${Label}: 止まる (終了コードが 0 ではない)"
    Assert-Condition (-not (Test-Path -LiteralPath (Join-Path $homePath '.wezterm.lua'))) "${Label}: .wezterm.lua を作らない"
    Assert-Condition (-not (Test-Path -LiteralPath (Join-Path (Join-Path (Join-Path $homePath '.config') 'wezterm') 'kitty_ja'))) "${Label}: kitty_ja を置かない"
}

function Test-PackageBuild {
    param([string] $ShellPath)

    Write-Output ''
    Write-Output '== 配布 zip =='
    $outputDirectory = Join-Path $scratchRoot 'dist'
    $result = Invoke-ScriptInChild -ShellPath $ShellPath -ScriptPath (Join-Path (Join-Path $repositoryRoot 'tools') 'New-Package.ps1') `
        -Arguments @('-OutputDirectory', $outputDirectory, '-Version', '0.0.0-test')
    Assert-Condition ($result.ExitCode -eq 0) 'New-Package.ps1 が正常に終わる'
    if ($result.ExitCode -ne 0) {
        Write-Output $result.Output
        return
    }
    $zipPath = Join-Path $outputDirectory 'wezterm-kitty-ja-0.0.0-test.zip'
    Assert-Condition (Test-Path -LiteralPath $zipPath -PathType Leaf) 'zip ができる'
    Assert-Condition (Test-Path -LiteralPath "$zipPath.sha256" -PathType Leaf) 'SHA-256 のファイルができる'

    $extractDirectory = Join-Path $scratchRoot 'extracted'
    Expand-Archive -LiteralPath $zipPath -DestinationPath $extractDirectory
    $packageDirectory = Join-Path $extractDirectory 'wezterm-kitty-ja-0.0.0-test'
    foreach ($requiredName in @('LICENSE', 'THIRD_PARTY_NOTICES.md', 'README.md', 'install.cmd', 'install.ps1', 'uninstall.cmd', '.wezterm.lua')) {
        Assert-Condition (Test-Path -LiteralPath (Join-Path $packageDirectory $requiredName) -PathType Leaf) "zip に $requiredName が入っている"
    }
    foreach ($forbiddenName in @('claude-config', 'knowledge', 'zzz-Temp', '.git', 'CLAUDE.md', '.wezterm.lua-back')) {
        Assert-Condition (-not (Test-Path -LiteralPath (Join-Path $packageDirectory $forbiddenName))) "zip に $forbiddenName が入っていない"
    }
}

function Test-ShellIntegration {
    param([string] $ShellPath)

    Write-Output ''
    Write-Output '== シェル連携スクリプト (履歴の予測候補・履歴を選んで消すキー) =='
    $integrationScript = Join-Path (Join-Path (Join-Path $repositoryRoot 'kitty_ja') 'shell') 'integration.ps1'
    $quotedScript = $integrationScript.Replace("'", "''")
    # スクリプトを実行したあと、環境変数が残っていれば終了コード 3、履歴を消す関数が無ければ 4 にする
    $command = "& '$quotedScript'; if (`$env:KITTY_JA_PREDICTION -or `$env:KITTY_JA_HISTORY_DELETE_KEY) { exit 3 }; if (-not (Get-Command -Name Remove-KittyJaHistory -ErrorAction Ignore)) { exit 4 }"
    $savedTermProgram = $env:TERM_PROGRAM
    $savedPrediction = $env:KITTY_JA_PREDICTION
    $savedHistoryDeleteKey = $env:KITTY_JA_HISTORY_DELETE_KEY
    try {
        $env:TERM_PROGRAM = 'WezTerm'
        foreach ($style in @('ListView', 'InlineView', '', 'bogus')) {
            $env:KITTY_JA_PREDICTION = $style
            $null = & $ShellPath -NoProfile -NoLogo -Command $command 2>&1
            $label = if ($style) { $style } else { '(空)' }
            Assert-Condition ($LASTEXITCODE -eq 0) "KITTY_JA_PREDICTION=$label でも、エラーにならずに終わり、環境変数を消す"
        }
        $env:KITTY_JA_PREDICTION = ''
        foreach ($key in @('Shift+F7', '', 'bogus-key')) {
            $env:KITTY_JA_HISTORY_DELETE_KEY = $key
            $null = & $ShellPath -NoProfile -NoLogo -Command $command 2>&1
            $label = if ($key) { $key } else { '(空)' }
            Assert-Condition ($LASTEXITCODE -eq 0) "KITTY_JA_HISTORY_DELETE_KEY=$label でも、エラーにならずに終わり、環境変数を消し、履歴を消す関数が使える"
        }
    } finally {
        $env:TERM_PROGRAM = $savedTermProgram
        $env:KITTY_JA_PREDICTION = $savedPrediction
        $env:KITTY_JA_HISTORY_DELETE_KEY = $savedHistoryDeleteKey
    }
}

# 履歴ファイルの書き換え (history.ps1 の Remove-KittyJaHistoryText) を、文字列だけで確かめる。
# 履歴を消す本体 (Remove-KittyJaHistory) は、対話の PSReadLine が要るので、ここでは動かさない
function Test-HistoryRewrite {
    param([string] $ShellPath)

    Write-Output ''
    Write-Output '== 履歴ファイルの書き換え (Remove-KittyJaHistoryText) =='
    $historyScript = Join-Path (Join-Path (Join-Path $repositoryRoot 'kitty_ja') 'shell') 'history.ps1'
    $checkScript = Join-Path $scratchRoot 'check-history-rewrite.ps1'
    Set-Content -LiteralPath $checkScript -Encoding utf8 -Value @'
param([string] $HistoryScript)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
& $HistoryScript

$crlf = "`r`n"
$lf = "`n"
$multiLineRaw = 'Format-Volume ``' + $lf + '  -DriveLetter F ``' + $lf + '  -FileSystem ReFS' + $crlf
$multiLineLogical = 'Format-Volume `' + $lf + '  -DriveLetter F `' + $lf + '  -FileSystem ReFS'
$failures = [System.Collections.Generic.List[string]]::new()
function Assert-Rewrite {
    param([string] $Label, [string] $Text, [string[]] $CommandLine, [string] $ExpectedText, [int] $ExpectedCount)
    $result = Remove-KittyJaHistoryText -Text $Text -CommandLine $CommandLine
    if ($result.Text -cne $ExpectedText -or $result.RemovedCount -ne $ExpectedCount) { $failures.Add($Label) }
}

Assert-Rewrite '単純な 1 行を消す' "a${crlf}b${crlf}c${crlf}" @('b') "a${crlf}c${crlf}" 1
Assert-Rewrite '同じコマンドが複数あれば全部消す' "a${crlf}b${crlf}a${crlf}" @('a') "b${crlf}" 2
Assert-Rewrite '複数行のコマンドを、続きの行ごと消す' "x${crlf}${multiLineRaw}y${crlf}" @($multiLineLogical) "x${crlf}y${crlf}" 1
Assert-Rewrite '複数行のコマンドの 1 行目だけでは消えない' "x${crlf}${multiLineRaw}y${crlf}" @('Format-Volume `') "x${crlf}${multiLineRaw}y${crlf}" 0
Assert-Rewrite '消さない複数行のコマンドは 1 バイトも変わらない' "x${crlf}${multiLineRaw}y${crlf}" @('x') "${multiLineRaw}y${crlf}" 1
Assert-Rewrite '一致しなければ何も変わらない' "a${crlf}b${crlf}" @('zzz') "a${crlf}b${crlf}" 0
Assert-Rewrite '行末が LF だけの行も消える' "a${crlf}b${lf}" @('b') "a${crlf}" 1
Assert-Rewrite '末尾に改行が無い行も消える' "a${crlf}b" @('b') "a${crlf}" 1
Assert-Rewrite '続きの無い途中のコマンドには触らない' ('a' + $crlf + 'b`' + $lf) @('b') ('a' + $crlf + 'b`' + $lf) 0
Assert-Rewrite '空のファイル' '' @('a') '' 0
Assert-Rewrite '日本語のコマンドも消える' "日本語のコマンド${crlf}b${crlf}" @('日本語のコマンド') "b${crlf}" 1

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { "FAIL: $_" }
    exit 1
}
'OK'
'@
    $result = Invoke-ScriptInChild -ShellPath $ShellPath -ScriptPath $checkScript -Arguments @($historyScript)
    Assert-Condition ($result.ExitCode -eq 0) '履歴ファイルの書き換えが、複数行・重複・改行の違い・日本語で正しく働く'
    if ($result.ExitCode -ne 0) { Write-Output $result.Output }
}

$shells = [System.Collections.Generic.List[object]]::new()
$shells.Add([pscustomobject]@{ Label = 'pwsh7'; Path = (Get-Command -Name 'pwsh' -CommandType Application | Select-Object -First 1).Source })
$windowsPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
if (Test-Path -LiteralPath $windowsPowerShell -PathType Leaf) {
    $shells.Add([pscustomobject]@{ Label = 'winps51'; Path = $windowsPowerShell })
}

$savedXdgConfigHome = $env:XDG_CONFIG_HOME
try {
    $null = New-Item -ItemType Directory -Path $scratchRoot -Force
    # XDG_CONFIG_HOME が設定されていると、インストーラーは (設計どおり) 止まる。通常の検査では外す
    $env:XDG_CONFIG_HOME = $null

    foreach ($shell in $shells) {
        Test-InstallerWithShell -ShellLabel $shell.Label -ShellPath $shell.Path
    }

    Write-Output ''
    Write-Output '== 設定の置き場所が塞がれているとき =='
    $primaryShell = $shells[0].Path
    Test-BlockedInstall -ShellPath $primaryShell -Label 'blocked-shadowing-config' `
        -Prepare {
            param($HomePath)
            $configDirectory = Join-Path (Join-Path $HomePath '.config') 'wezterm'
            $null = New-Item -ItemType Directory -Path $configDirectory -Force
            Set-Content -LiteralPath (Join-Path $configDirectory 'wezterm.lua') -Value 'return {}' -Encoding utf8
        } `
        -Cleanup { }
    Test-BlockedInstall -ShellPath $primaryShell -Label 'blocked-xdg-config-home' `
        -Prepare { param($HomePath) $env:XDG_CONFIG_HOME = (Join-Path $HomePath 'xdg') } `
        -Cleanup { $env:XDG_CONFIG_HOME = $null }

    Test-ShellIntegration -ShellPath $primaryShell

    Test-HistoryRewrite -ShellPath $primaryShell

    Test-PackageBuild -ShellPath $primaryShell
} finally {
    $env:XDG_CONFIG_HOME = $savedXdgConfigHome
    if (Test-Path -LiteralPath $scratchRoot) {
        Remove-Item -LiteralPath $scratchRoot -Recurse -Force
    }
}

Write-Output ''
Write-Output "成功 $passedCount 件、失敗 $($failures.Count) 件"
if ($failures.Count -gt 0) {
    foreach ($failure in $failures) { Write-Output "  失敗: $failure" }
    exit 1
}
