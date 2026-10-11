#Requires -Version 7
<#
.SYNOPSIS
    既存リポジトリにナレッジベースを追加する。既存ファイルは壊さない。
.DESCRIPTION
    CLAUDE.md が既にあるリポジトリ専用。骨格を作り、CLAUDE.md の末尾に @import を追記し、
    .gitignore に除外を足す。既存の記述は 1 行も消さない。

    追記前に CLAUDE.md.bak を作り、追記後に git diff の削除行数が 0 であることを検証する。
    何度実行しても結果は同じ（冪等）。

    CLAUDE.md が無いリポジトリでは停止する。その場合は New-KnowledgeBase.ps1 を使う。
.PARAMETER RepoRoot
    リポジトリのルート。省略するとカレントディレクトリ。
.PARAMETER AreaNames
    areas\ に作る雛形の名前（拡張子なし）。常時ロードされるため 2 つまでを推奨。
.PARAMETER Force
    CLAUDE.md が無くても中止せずに続行する（骨格と .gitignore だけ作る）。
.EXAMPLE
    & 'C:\Users\mt\.claude\scripts\Add-KnowledgeBase.ps1' -RepoRoot 'E:\nkdx\ExistingProject' -WhatIf
.EXAMPLE
    & 'C:\Users\mt\.claude\scripts\Add-KnowledgeBase.ps1' -AreaNames env, build
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
    if ($Entry.Action -eq 'created' -or $Entry.Action -eq 'appended') {
        Write-Host ('  ' + $Entry.Action.PadRight(6) + ' ' + $displayPath) -ForegroundColor Green
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

if (-not $state.HasClaudeMd -and -not $Force) {
    Write-Host ''
    Write-Host '中止: CLAUDE.md がありません。' -ForegroundColor Red
    Write-Host '  このリポジトリは「新規」です。次を使ってください:' -ForegroundColor Red
    Write-Host ("    & '" + (Join-Path $PSScriptRoot 'New-KnowledgeBase.ps1') + "' -RepoRoot '$resolvedRoot'")
    exit 1
}

Write-Host ('  CLAUDE.md          : ' + $(if ($state.HasClaudeMd) { 'あり' } else { 'なし' }))
Write-Host ('  knowledge/         : ' + $(if ($state.HasKnowledgeDir) { 'あり（既存を避けて追加する）' } else { 'なし' }))
Write-Host ('  @import            : ' + $(if ($state.HasImportBlock) { 'あり（追記しない）' } else { 'なし' }))
Write-Host ('  .claude/settings.json : ' + $(if ($state.HasProjectSettings) { 'あり（後述の確認あり）' } else { 'なし' }))

# git 管理下なら、追記前に作業ツリーが汚れていないかを見る。
# 汚れていると「このスクリプトが何を変えたか」を git diff で切り分けられない。
$gitCommand = Get-Command -Name 'git' -CommandType Application -ErrorAction SilentlyContinue |
    Select-Object -First 1
$wasClaudeMdDirty = $false
if ($repositoryInfo.IsGitRepository -and $null -ne $gitCommand -and $state.HasClaudeMd) {
    Push-Location -LiteralPath $resolvedRoot
    try {
        $pendingChanges = & $gitCommand.Source 'status' '--porcelain' '--' 'CLAUDE.md' 2>$null
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($pendingChanges)) {
            $wasClaudeMdDirty = $true
            Write-Host '  警告   CLAUDE.md に未コミットの変更があります。' -ForegroundColor Yellow
            Write-Host '         このスクリプトの追記と区別できません。先にコミットするか退避してください。' -ForegroundColor Yellow
        }
    }
    finally { Pop-Location }
}

# ---------------------------------------------------------------- 追加

# $WhatIfPreference はモジュールのスコープに流れ込まないため、明示的に渡す必要がある。
# 省くと -WhatIf を付けても実際に書き込まれる。
Write-Section '骨格'
$skeletonResults = New-KnowledgeSkeleton -RepoRoot $resolvedRoot -AreaNames $AreaNames -WhatIf:$WhatIfPreference
foreach ($entry in $skeletonResults) { Write-Result -Entry $entry -BasePath $resolvedRoot }

Write-Section 'CLAUDE.md への追記'
if ($state.HasClaudeMd) {
    $importResult = Add-KnowledgeImport -ClaudeMdPath $state.ClaudeMdPath -AreaNames $AreaNames -WhatIf:$WhatIfPreference
    Write-Result -Entry $importResult -BasePath $resolvedRoot
    if ($importResult.Action -eq 'appended') {
        Write-Host ('  退避   ' + (Split-Path -Leaf $importResult.BackupPath)) -ForegroundColor Green
        foreach ($addedLine in $importResult.Added) {
            if (-not [string]::IsNullOrWhiteSpace($addedLine)) {
                Write-Host ('         + ' + $addedLine) -ForegroundColor Green
            }
        }
    }
}
else {
    $importResult = [pscustomobject]@{ Action = 'skipped'; Reason = 'CLAUDE.md なし'; BackupPath = $null }
    Write-Host '  skip   CLAUDE.md が無いため追記しません' -ForegroundColor DarkGray
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

# ---------------------------------------------------------------- 検証

$deletedLineCount = $null
Write-Section '既存を壊していないことの検証'
if (-not $repositoryInfo.IsGitRepository -or $null -eq $gitCommand) {
    Write-Host '  git 管理外のため差分検証を省略しました。' -ForegroundColor Yellow
    if ($null -ne $importResult.BackupPath) {
        Write-Host ('  退避済み: ' + $importResult.BackupPath) -ForegroundColor Yellow
    }
}
elseif ($wasClaudeMdDirty) {
    Write-Host '  実行前から未コミットの変更があったため、差分の切り分けができません。' -ForegroundColor Yellow
    Write-Host '  手で git diff CLAUDE.md を確認してください。' -ForegroundColor Yellow
}
elseif ($WhatIfPreference) {
    Write-Host '  -WhatIf のため実際の差分はありません。' -ForegroundColor DarkGray
}
else {
    Push-Location -LiteralPath $resolvedRoot
    try {
        $numstat = & $gitCommand.Source 'diff' '--numstat' '--' 'CLAUDE.md' 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Host '  git diff が失敗しました。手で確認してください。' -ForegroundColor Yellow
        }
        elseif ([string]::IsNullOrWhiteSpace($numstat)) {
            Write-Host '  CLAUDE.md に差分なし（追記済みか、追記対象が無い）。' -ForegroundColor DarkGray
        }
        else {
            $columns = ($numstat -split "`t")
            $addedLineCount = [int]$columns[0]
            $deletedLineCount = [int]$columns[1]
            Write-Host ('  追加行: ' + $addedLineCount)
            if ($deletedLineCount -eq 0) {
                Write-Host '  削除行: 0   既存の記述は 1 行も消えていません。' -ForegroundColor Green
            }
            else {
                Write-Host ('  削除行: ' + $deletedLineCount + '   *** 既存の記述が消えています ***') -ForegroundColor Red
                Write-Host '  次で元に戻してください:' -ForegroundColor Red
                Write-Host '    git checkout -- CLAUDE.md'
            }
        }
    }
    finally { Pop-Location }
}

# ---------------------------------------------------------------- 手作業の指示

Write-Section '常時ロード量'
$loadReport = Get-AlwaysLoadedReport -RepoRoot $resolvedRoot
foreach ($fileRow in $loadReport.Files) {
    Write-Host ('  {0,5} 行   {1}' -f $fileRow.Lines, $fileRow.Path)
}
$totalColor = if ($loadReport.OverBudget) { 'Red' } else { 'Green' }
Write-Host ('  {0,5} 行   合計（予算 {1} 行）' -f $loadReport.TotalLines, $loadReport.Budget) -ForegroundColor $totalColor
if ($loadReport.OverBudget) {
    Write-Host '  予算超過です。areas/ の記述を resources/ へ降格させてください。' -ForegroundColor Red
}

# 既存 CLAUDE.md の見出しを並べて、どれを knowledge\ へ移すか人間が判断できるようにする。
# 機械的に判定はしない（内容の意味づけは人間にしか分からない）。
if ($state.HasClaudeMd) {
    $headings = @(
        Select-String -LiteralPath $state.ClaudeMdPath -Pattern '^#{1,3}\s+(.+)$' |
            ForEach-Object { $_.Matches[0].Groups[1].Value.Trim() } |
            Where-Object { $_ -ne '常時ロードされる知識' }
    )
    if ($headings.Count -gt 0) {
        Write-Section '重複の解消（手作業）'
        Write-Host '  既存 CLAUDE.md の見出しです。同じ事実が areas/ と両方にあると、'
        Write-Host '  食い違ったとき Claude はどちらかを恣意的に選びます。'
        Write-Host ''
        foreach ($heading in $headings) {
            Write-Host ('    - ' + $heading) -ForegroundColor White
        }
        Write-Host ''
        Write-Host '  移す先の目安:' -ForegroundColor DarkGray
        Write-Host '    ビルドコマンド / 環境の前提 / バージョン  ->  areas/env.md' -ForegroundColor DarkGray
        Write-Host '    継続的な方針 / 守るべき制約              ->  areas/' -ForegroundColor DarkGray
        Write-Host '    進行中の案件 / TODO                      ->  work/index.md' -ForegroundColor DarkGray
        Write-Host '    言語が限定できるコーディング規則          ->  .claude/rules/（paths: 付き）' -ForegroundColor DarkGray
        Write-Host '    リポジトリの概要 / 構成                  ->  CLAUDE.md に残す' -ForegroundColor DarkGray
    }
}

if ($state.HasProjectSettings) {
    Write-Section 'プロジェクト側 settings.json の確認（手作業）'
    Write-Host '  ユーザー側の hooks は置き換えではなく併存します。二重実行に注意してください。'
    Write-Host '    Get-Content .claude\settings.json | ConvertFrom-Json | Select-Object -ExpandProperty hooks'
    Write-Host '  PostToolUse に構文チェックが既にあるなら、どちらか片方に寄せてください。'
}

Write-Section '次にやること'
Write-Host '  1. claude を起動し直す（設定とスキルはセッション開始時にしか読まれない）'
Write-Host '  2. 上の「重複の解消」に従って既存 CLAUDE.md を整理する'
Write-Host '  3. /update-facts で areas/ と work/index.md を埋める'
Write-Host '  4. /context で Memory files に既存 CLAUDE.md と import 先が両方並ぶことを確認する'
Write-Host ''

return [pscustomobject]@{
    RepoRoot        = $resolvedRoot
    Mode            = 'existing'
    IsGitRepository = $repositoryInfo.IsGitRepository
    Created         = @($skeletonResults | Where-Object { $_.Action -eq 'created' }).Count
    ClaudeMd        = $importResult.Action
    BackupPath      = $importResult.BackupPath
    GitIgnore       = $gitIgnoreResult.Action
    DeletedLines    = $deletedLineCount
    AlwaysLoaded    = $loadReport.TotalLines
    OverBudget      = $loadReport.OverBudget
}
