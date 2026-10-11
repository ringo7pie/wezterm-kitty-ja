#Requires -Version 7
<#
.SYNOPSIS
    新規リポジトリにナレッジベースを適用する。
.DESCRIPTION
    CLAUDE.md がまだ無いリポジトリ専用。骨格・CLAUDE.md の雛形・.gitignore を作る。
    事実は一切書かない。areas\ と work\ の中身は実行後に /update-facts で埋める。

    既に CLAUDE.md があるリポジトリでは停止する。その場合は Add-KnowledgeBase.ps1 を使う。
.PARAMETER RepoRoot
    リポジトリのルート。省略するとカレントディレクトリ。
.PARAMETER AreaNames
    areas\ に作る雛形の名前（拡張子なし）。常時ロードされるため 2 つまでを推奨。
.PARAMETER Force
    CLAUDE.md や knowledge\ が既にあっても中止せず、既存ファイルを避けながら続行する。
.EXAMPLE
    & 'C:\Users\mt\.claude\scripts\New-KnowledgeBase.ps1' -RepoRoot 'E:\nkdx\MyNewProject'
.EXAMPLE
    & 'C:\Users\mt\.claude\scripts\New-KnowledgeBase.ps1' -AreaNames env, rendering -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$RepoRoot = (Get-Location).Path,
    [string[]]$AreaNames = @('env'),
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Import-Module (Join-Path $PSScriptRoot 'KnowledgeBase.psm1') -Force

# このスクリプトの出力は人間が読む報告。構造化された結果は最後に返す。
function Write-Section {
    param([string]$Title)
    Write-Host ''
    Write-Host $Title -ForegroundColor Cyan
    Write-Host ('-' * 62) -ForegroundColor DarkGray
}

function Write-Result {
    param([object]$Entry, [string]$BasePath)
    $displayPath = $Entry.Path
    if ($displayPath.StartsWith($BasePath)) {
        $displayPath = $displayPath.Substring($BasePath.Length).TrimStart('\')
    }
    if ($Entry.Action -eq 'created') {
        Write-Host ('  作成   ' + $displayPath) -ForegroundColor Green
    }
    else {
        Write-Host ('  skip   ' + $displayPath + '  (' + $Entry.Reason + ')') -ForegroundColor DarkGray
    }
}

# ---------------------------------------------------------------- 検査

$repositoryInfo = Test-RepositoryRoot -RepoRoot $RepoRoot
$resolvedRoot = $repositoryInfo.RepoRoot

Write-Section '対象'
Write-Host ('  ' + $resolvedRoot)
foreach ($warning in $repositoryInfo.Warnings) {
    Write-Host ('  警告   ' + $warning) -ForegroundColor Yellow
}

$state = Get-KnowledgeState -RepoRoot $resolvedRoot

if (-not $Force) {
    if ($state.HasClaudeMd) {
        Write-Host ''
        Write-Host '中止: CLAUDE.md が既にあります。' -ForegroundColor Red
        Write-Host '  このリポジトリは「既存」です。次を使ってください:' -ForegroundColor Red
        Write-Host ("    & '" + (Join-Path $PSScriptRoot 'Add-KnowledgeBase.ps1') + "' -RepoRoot '$resolvedRoot'")
        exit 1
    }
    if ($state.HasKnowledgeDir) {
        Write-Host ''
        Write-Host '中止: knowledge\ が既にあります。' -ForegroundColor Red
        Write-Host '  既存を壊さないため停止しました。続けるなら -Force を付けてください。' -ForegroundColor Red
        exit 1
    }
}

# ---------------------------------------------------------------- 作成

# $WhatIfPreference はモジュールのスコープに流れ込まないため、明示的に渡す必要がある。
# 省くと -WhatIf を付けても実際に書き込まれる。
Write-Section '骨格'
$skeletonResults = New-KnowledgeSkeleton -RepoRoot $resolvedRoot -AreaNames $AreaNames -WhatIf:$WhatIfPreference
foreach ($entry in $skeletonResults) { Write-Result -Entry $entry -BasePath $resolvedRoot }

Write-Section 'CLAUDE.md'
$claudeMdResult = New-ProjectClaudeMd -RepoRoot $resolvedRoot -AreaNames $AreaNames -WhatIf:$WhatIfPreference
Write-Result -Entry $claudeMdResult -BasePath $resolvedRoot
if ($claudeMdResult.Action -eq 'created') {
    Write-Host '  雛形です。概要とビルド手順は人間が書いてください。' -ForegroundColor Yellow
}

Write-Section '.gitignore'
$gitIgnoreResult = Add-KnowledgeGitIgnore -RepoRoot $resolvedRoot -WhatIf:$WhatIfPreference
if ($gitIgnoreResult.Action -eq 'appended') {
    foreach ($addedEntry in $gitIgnoreResult.Added) {
        Write-Host ('  追記   ' + $addedEntry) -ForegroundColor Green
    }
}
else {
    Write-Host ('  skip   ' + $gitIgnoreResult.Reason) -ForegroundColor DarkGray
}

# ---------------------------------------------------------------- 報告

Write-Section '常時ロード量'
$loadReport = Get-AlwaysLoadedReport -RepoRoot $resolvedRoot
foreach ($fileRow in $loadReport.Files) {
    Write-Host ('  {0,5} 行   {1}' -f $fileRow.Lines, $fileRow.Path)
}
$totalColor = if ($loadReport.OverBudget) { 'Red' } else { 'Green' }
Write-Host ('  {0,5} 行   合計（予算 {1} 行）' -f $loadReport.TotalLines, $loadReport.Budget) -ForegroundColor $totalColor

Write-Section '次にやること'
Write-Host '  1. claude を起動する（設定とスキルはセッション開始時にしか読まれない）'
Write-Host '  2. CLAUDE.md の概要とビルド手順を書く'
Write-Host '  3. /update-facts で areas/ と work/index.md を埋める'
Write-Host '  4. /context で Memory files に import 先が並ぶことを確認する'
Write-Host ''

return [pscustomobject]@{
    RepoRoot        = $resolvedRoot
    Mode            = 'new'
    IsGitRepository = $repositoryInfo.IsGitRepository
    Created         = @($skeletonResults | Where-Object { $_.Action -eq 'created' }).Count
    ClaudeMd        = $claudeMdResult.Action
    GitIgnore       = $gitIgnoreResult.Action
    AlwaysLoaded    = $loadReport.TotalLines
    OverBudget      = $loadReport.OverBudget
}
