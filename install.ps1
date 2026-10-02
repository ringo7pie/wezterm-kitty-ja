<#
.SYNOPSIS
WezTerm の kitty-ja 互換設定を、このユーザーにインストールする。

.DESCRIPTION
このスクリプトと同じフォルダにある設定一式を、WezTerm が読む場所へ置く。

  kitty_ja\           -> <ホーム>\.config\wezterm\kitty_ja\
  .wezterm.lua        -> <ホーム>\.wezterm.lua
  defaults\colors.txt -> <ホーム>\.config\wezterm-kitty-ja\tab-colors\colors.txt (無いときだけ)

既にあるファイルは消さず、名前に .bak-<日時> を付けて残す。
既にあるものがリンクのときは、リンクだけを消す (リンク先には触らない)。
ソフトウェアのダウンロードやインストール、レジストリや環境変数の変更はしない。
WezTerm と PowerShell 7 が無ければ、入れ方を表示して止まる。

Windows PowerShell 5.1 と PowerShell 7 のどちらでも実行できる。

.PARAMETER Link
ファイルをコピーせず、このフォルダへのリンクを張る (設定を編集しながら使う人向け)。
このフォルダを消したり動かしたりすると設定が読めなくなる。

.PARAMETER SkipRequirementCheck
WezTerm と PowerShell 7 が見つからなくても続ける。

.PARAMETER HomePath
インストール先のホームフォルダ。既定は現在のユーザーのホーム。

.EXAMPLE
.\install.ps1 -WhatIf
何をするかを表示するだけで、何も変更しない。
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch] $Link,
    [switch] $SkipRequirementCheck,
    [string] $HomePath = [Environment]::GetFolderPath('UserProfile')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$MinimumWezTermDate = 20240203
$LinkTypes = @('Junction', 'SymbolicLink')

# ファイルとして開けるか。Microsoft Store 版の実行エイリアスは開けないので $false になる
# (設定側の Lua も同じ方法で pwsh.exe を探すので、結果をそろえる)
function Test-FileReadable {
    param([string] $Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
    try {
        $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        $stream.Dispose()
        return $true
    } catch {
        return $false
    }
}

# PowerShell 7 を探す。戻り値は Path (実行に使えるパス) と AutoDetected (設定側が自動で見つけられるか)。無ければ $null
function Find-PowerShell7 {
    $candidates = @()
    foreach ($variableName in @('ProgramW6432', 'ProgramFiles', 'ProgramFiles(x86)')) {
        $basePath = [Environment]::GetEnvironmentVariable($variableName)
        if ($basePath) {
            $candidates += Join-Path (Join-Path (Join-Path $basePath 'PowerShell') '7') 'pwsh.exe'
        }
    }
    foreach ($directory in ($env:PATH -split ';')) {
        if (-not $directory.Trim()) { continue }
        # PATH には存在しないドライブや不正な文字が入りうる。Join-Path はそこで例外を出すので Path.Combine を使う
        try {
            $candidates += [System.IO.Path]::Combine($directory.Trim(), 'pwsh.exe')
        } catch {
            Write-Verbose "PATH の項目を読み飛ばしました: $directory"
        }
    }
    foreach ($candidate in $candidates) {
        if (Test-FileReadable -Path $candidate) {
            return [pscustomobject]@{ Path = $candidate; AutoDetected = $true }
        }
    }
    $command = Get-Command -Name 'pwsh.exe' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) {
        return [pscustomobject]@{ Path = $command.Source; AutoDetected = $false }
    }
    return $null
}

# WezTerm のインストール先フォルダを探す。無ければ $null
function Find-WezTerm {
    $command = Get-Command -Name 'wezterm.exe' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) { return Split-Path -Parent $command.Source }

    foreach ($variableName in @('ProgramW6432', 'ProgramFiles')) {
        $basePath = [Environment]::GetEnvironmentVariable($variableName)
        if ($basePath) {
            $candidate = Join-Path $basePath 'WezTerm'
            if (Test-Path -LiteralPath (Join-Path $candidate 'wezterm.exe') -PathType Leaf) { return $candidate }
        }
    }

    $uninstallKeys = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    foreach ($entry in (Get-ItemProperty -Path $uninstallKeys -ErrorAction SilentlyContinue)) {
        $displayName = $entry.PSObject.Properties['DisplayName']
        $installLocation = $entry.PSObject.Properties['InstallLocation']
        if ($displayName -and $installLocation -and $displayName.Value -like 'WezTerm*' -and $installLocation.Value) {
            if (Test-Path -LiteralPath (Join-Path $installLocation.Value 'wezterm.exe') -PathType Leaf) {
                return $installLocation.Value.TrimEnd('\')
            }
        }
    }
    return $null
}

# 「wezterm 20240203-110809-5046fc22」の日付部分を数値で返す。読めなければ $null
function Get-WezTermDate {
    param([string] $InstallDirectory)

    # 標準エラーはリダイレクトしない (Windows PowerShell 5.1 では、リダイレクトした標準エラーが例外になる)
    $output = & (Join-Path $InstallDirectory 'wezterm.exe') --version
    if ($LASTEXITCODE -ne 0) { return $null }
    if (("$output") -match '(\d{8})-\d{6}') { return [int] $Matches[1] }
    return $null
}

# pwsh の実行ポリシー。このスクリプトを -ExecutionPolicy Bypass で起動していても影響されないよう、
# プロセス単位の設定を除いて判定する
function Get-PersistentExecutionPolicy {
    param([string] $PowerShellPath)

    $query = '(Get-ExecutionPolicy -List | Where-Object { $_.Scope -ne ''Process'' -and $_.ExecutionPolicy -ne ''Undefined'' } | Select-Object -First 1).ExecutionPolicy'
    $output = & $PowerShellPath -NoProfile -NoLogo -NonInteractive -Command $query
    if ($LASTEXITCODE -ne 0) { return $null }
    $policy = ("$output").Trim()
    if (-not $policy) { return 'Restricted' }
    return $policy
}

# Get-FileHash は Windows PowerShell 5.1 の -WhatIf で何も返さないので、.NET で計算する
function Get-FileSha256 {
    param([string] $Path)

    $algorithm = [System.Security.Cryptography.SHA256]::Create()
    try {
        return [System.BitConverter]::ToString($algorithm.ComputeHash([System.IO.File]::ReadAllBytes($Path)))
    } finally {
        $algorithm.Dispose()
    }
}

# 2 つのフォルダの中身 (ファイルの相対パスと内容) が同じか
function Test-SameDirectoryContent {
    param(
        [string] $ReferencePath,
        [string] $DifferencePath
    )

    $referenceFiles = @(Get-ChildItem -LiteralPath $ReferencePath -Recurse -File -Force)
    $differenceFiles = @(Get-ChildItem -LiteralPath $DifferencePath -Recurse -File -Force)
    if ($referenceFiles.Count -ne $differenceFiles.Count) { return $false }
    foreach ($referenceFile in $referenceFiles) {
        $relativePath = $referenceFile.FullName.Substring($ReferencePath.Length).TrimStart('\')
        $otherPath = Join-Path $DifferencePath $relativePath
        if (-not (Test-Path -LiteralPath $otherPath -PathType Leaf)) { return $false }
        if ((Get-FileSha256 -Path $referenceFile.FullName) -ne (Get-FileSha256 -Path $otherPath)) { return $false }
    }
    return $true
}

function Test-Link {
    param([string] $Path)

    $item = Get-Item -LiteralPath $Path -Force
    return ($LinkTypes -contains $item.LinkType)
}

# 既にあるものをどける。リンクならリンクだけを消し (リンク先には触らない)、実体なら名前を変えて残す
function Backup-ExistingItem {
    param(
        [string] $Path,
        [string] $Suffix
    )

    if (-not (Test-Path -LiteralPath $Path)) { return }
    $item = Get-Item -LiteralPath $Path -Force
    if (Test-Link -Path $Path) {
        # リンク先は、消す前に取得しておく。取得できないときは表示しない
        $linkTarget = @($item.Target | Where-Object { $_ }) -join ', '
        if ($PSCmdlet.ShouldProcess($Path, 'リンクを削除 (リンク先は残す)')) {
            if ($item.PSIsContainer) {
                [System.IO.Directory]::Delete($Path)
            } else {
                [System.IO.File]::Delete($Path)
            }
            if ($linkTarget) {
                Write-Output "リンクを削除しました: $Path (リンク先: $linkTarget)"
            } else {
                Write-Output "リンクを削除しました: $Path"
            }
        }
        return
    }
    $backupName = $item.Name + $Suffix
    Rename-Item -LiteralPath $Path -NewName $backupName
    if (-not $WhatIfPreference) {
        Write-Output "既存のものを残しました: $(Join-Path (Split-Path -Parent $Path) $backupName)"
    }
}

# ---------------------------------------------------------------- 配布物と置き場所

$sourceRoot = $PSScriptRoot
$sourceModuleDirectory = Join-Path $sourceRoot 'kitty_ja'
$sourceEntryFile = Join-Path $sourceRoot '.wezterm.lua'
$sourceColorsFile = Join-Path (Join-Path $sourceRoot 'defaults') 'colors.txt'

$requiredFiles = @(
    $sourceEntryFile,
    $sourceColorsFile,
    (Join-Path $sourceModuleDirectory 'init.lua'),
    (Join-Path (Join-Path $sourceModuleDirectory 'shell') 'integration.ps1')
)
foreach ($requiredFile in $requiredFiles) {
    if (-not (Test-Path -LiteralPath $requiredFile -PathType Leaf)) {
        throw "配布物が足りません: $requiredFile"
    }
}
if (-not (Test-Path -LiteralPath $HomePath -PathType Container)) {
    throw "ホームフォルダがありません: $HomePath"
}
# 絶対パスにそろえる。相対パスのままだと、PowerShell のコマンドと .NET の呼び出しが別の場所を指しうる
$HomePath = (Resolve-Path -LiteralPath $HomePath).ProviderPath

$configDirectory = Join-Path (Join-Path $HomePath '.config') 'wezterm'
$targetModuleDirectory = Join-Path $configDirectory 'kitty_ja'
$targetEntryFile = Join-Path $HomePath '.wezterm.lua'
$dataDirectory = Join-Path (Join-Path $HomePath '.config') 'wezterm-kitty-ja'
$targetColorsFile = Join-Path (Join-Path $dataDirectory 'tab-colors') 'colors.txt'
$backupSuffix = '.bak-' + (Get-Date -Format 'yyyyMMdd-HHmmss')

# ---------------------------------------------------------------- 前提の確認

$problems = @()

# WezTerm は .wezterm.lua より <ホーム>\.config\wezterm\wezterm.lua を優先して読む
$shadowingConfig = Join-Path $configDirectory 'wezterm.lua'
if (Test-Path -LiteralPath $shadowingConfig) {
    $problems += @(
        "既に $shadowingConfig があります。WezTerm はこのファイルを優先するので、.wezterm.lua は読まれません。",
        "  このファイルを別の名前に変えるか、中で require('kitty_ja').apply_to_config(config) を呼ぶようにしてから、もう一度実行してください。"
    )
}

# XDG_CONFIG_HOME があると、WezTerm は <その値>\wezterm だけを設定フォルダとして見る
if ($env:XDG_CONFIG_HOME) {
    $problems += @(
        "環境変数 XDG_CONFIG_HOME ($($env:XDG_CONFIG_HOME)) が設定されています。WezTerm は <ホーム>\.config\wezterm を見ないので、この設定は読まれません。",
        '  この環境変数を外してから、もう一度実行してください。'
    )
}

$powerShell7 = Find-PowerShell7
$wezTermDirectory = Find-WezTerm
if (-not $SkipRequirementCheck) {
    if (-not $powerShell7) {
        $problems += @(
            'PowerShell 7 が見つかりません。次のコマンドでインストールしてから、もう一度実行してください。',
            '  winget install --id Microsoft.PowerShell --source winget'
        )
    }
    if (-not $wezTermDirectory) {
        $problems += @(
            'WezTerm が見つかりません。次のコマンドでインストールしてから、もう一度実行してください。',
            '  winget install --id wez.wezterm --source winget',
            '  (インストール済みなのに見つからない場合は -SkipRequirementCheck を付けて実行してください)'
        )
    }
}
if ($problems.Count -gt 0) {
    foreach ($problem in $problems) { Write-Warning $problem }
    throw 'インストールを中止しました。何も変更していません。'
}

if ($powerShell7) { Write-Output "PowerShell 7: $($powerShell7.Path)" }
if ($wezTermDirectory) {
    Write-Output "WezTerm: $wezTermDirectory"
    $wezTermDate = Get-WezTermDate -InstallDirectory $wezTermDirectory
    if ($wezTermDate -and $wezTermDate -lt $MinimumWezTermDate) {
        Write-Warning "WezTerm が古い可能性があります ($wezTermDate)。動作を確認しているのは $MinimumWezTermDate 版です。"
    }
}

# ---------------------------------------------------------------- インストール

foreach ($directory in @(
        $configDirectory,
        (Join-Path $dataDirectory 'tab-colors'),
        (Join-Path $dataDirectory 'tab-memory'),
        (Join-Path $dataDirectory 'session')
    )) {
    if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
        $null = New-Item -ItemType Directory -Path $directory -Force
    }
}

# 設定本体 (kitty_ja)。同じ中身のコピーが既に入っていれば、そのまま使う
$moduleIsCurrent = $false
if ((Test-Path -LiteralPath $targetModuleDirectory -PathType Container) -and -not $Link -and -not (Test-Link -Path $targetModuleDirectory)) {
    $moduleIsCurrent = Test-SameDirectoryContent -ReferencePath $sourceModuleDirectory -DifferencePath $targetModuleDirectory
}
if (-not $moduleIsCurrent) {
    Backup-ExistingItem -Path $targetModuleDirectory -Suffix $backupSuffix
    if ($Link) {
        $null = New-Item -ItemType Junction -Path $targetModuleDirectory -Target $sourceModuleDirectory
    } else {
        # 親フォルダへ kitty_ja ごとコピーする
        Copy-Item -LiteralPath $sourceModuleDirectory -Destination $configDirectory -Recurse
    }
}

# 入口 (.wezterm.lua)。中身が同じ実ファイルが既にあれば、そのまま使う
$entryIsCurrent = $false
if ((Test-Path -LiteralPath $targetEntryFile -PathType Leaf) -and -not $Link -and -not (Test-Link -Path $targetEntryFile)) {
    $entryIsCurrent = (Get-FileSha256 -Path $targetEntryFile) -eq (Get-FileSha256 -Path $sourceEntryFile)
}
if (-not $entryIsCurrent) {
    Backup-ExistingItem -Path $targetEntryFile -Suffix $backupSuffix
    $entryLinked = $false
    if ($Link) {
        try {
            $null = New-Item -ItemType SymbolicLink -Path $targetEntryFile -Target $sourceEntryFile
            $entryLinked = $true
        } catch {
            Write-Warning "シンボリックリンクを作れないので、.wezterm.lua はコピーします (開発者モードか管理者権限が必要です): $($_.Exception.Message)"
        }
    }
    if (-not $entryLinked) {
        Copy-Item -LiteralPath $sourceEntryFile -Destination $targetEntryFile
    }
}

# タブ色の定義。利用者が編集するファイルなので、既にあれば触らない
if (-not (Test-Path -LiteralPath $targetColorsFile)) {
    Copy-Item -LiteralPath $sourceColorsFile -Destination $targetColorsFile
}

# ダウンロードした zip から展開したファイルには「インターネットから入手」の印が付き、
# PowerShell の既定の設定 (RemoteSigned) では integration.ps1 を実行できない。置いたファイルの印を外す
$installedRoots = @($targetModuleDirectory, $targetEntryFile)
if ($Link) { $installedRoots = @($sourceModuleDirectory, $sourceEntryFile) }
foreach ($installedRoot in $installedRoots) {
    if (Test-Path -LiteralPath $installedRoot) {
        Get-ChildItem -LiteralPath $installedRoot -Recurse -File -Force | Unblock-File
    }
}

# ---------------------------------------------------------------- 結果

if ($WhatIfPreference) {
    Write-Output '-WhatIf のため、何も変更していません。'
    return
}

Write-Output ''
Write-Output 'インストールしました。'
Write-Output "  設定本体: $targetModuleDirectory"
Write-Output "  入口    : $targetEntryFile"
Write-Output "  データ  : $dataDirectory"
Write-Output 'WezTerm を起動し直すと反映されます。Ctrl+Shift+F12 でコマンド一覧が開きます。'

if ($powerShell7 -and -not $powerShell7.AutoDetected) {
    Write-Warning 'PowerShell 7 が Microsoft Store 版のため、設定側で自動検出できません。'
    Write-Warning "  ユーザーの環境変数 KITTY_JA_PWSH に次のパスを設定してください: $($powerShell7.Path)"
}
if ($powerShell7) {
    $executionPolicy = Get-PersistentExecutionPolicy -PowerShellPath $powerShell7.Path
    if (@('Restricted', 'AllSigned') -contains $executionPolicy) {
        Write-Warning "PowerShell 7 の実行ポリシーが $executionPolicy のため、シェル連携スクリプト (integration.ps1) を実行できません。"
        Write-Warning '  フォルダごとのタブ名・色の記憶と、タブの復元先のフォルダが働きません。'
        Write-Warning '  許可する場合は PowerShell 7 で次を実行してください: Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned'
    }
}
