#Requires -Version 7
<#
.SYNOPSIS
    New-KnowledgeBase.ps1 と Add-KnowledgeBase.ps1 の回帰テスト。
.DESCRIPTION
    一時ディレクトリに捨てリポジトリを作って検証する。既存のリポジトリには一切触れない。
    スクリプトを変更したら必ず実行すること。
.PARAMETER SandboxRoot
    捨てリポジトリを作る場所。既存の内容は削除される。
.EXAMPLE
    & 'C:\Users\mt\.claude\scripts\Test-KnowledgeBase.ps1'
#>
[CmdletBinding()]
param(
    [string]$SandboxRoot = (Join-Path $env:TEMP 'knowledgebase-tests')
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$scriptDirectory = $PSScriptRoot
$sandboxRoot = $SandboxRoot
if (Test-Path -LiteralPath $sandboxRoot) { Remove-Item -LiteralPath $sandboxRoot -Recurse -Force }
New-Item -ItemType Directory -Path $sandboxRoot -Force | Out-Null

$passCount = 0
$failCount = 0

function Assert-True {
    param([string]$Label, [bool]$Condition)
    if ($Condition) {
        Write-Host ('  PASS  ' + $Label) -ForegroundColor Green
        $script:passCount++
    }
    else {
        Write-Host ('  FAIL  ' + $Label) -ForegroundColor Red
        $script:failCount++
    }
}

function New-TestRepository {
    param([string]$Name)
    $repoPath = Join-Path $sandboxRoot $Name
    New-Item -ItemType Directory -Path $repoPath -Force | Out-Null
    Push-Location -LiteralPath $repoPath
    try {
        & git init -b main --quiet
        & git config user.email 'test@example.invalid'
        & git config user.name 'test'
    }
    finally { Pop-Location }
    return $repoPath
}

function Invoke-RepoCommit {
    param([string]$RepoPath, [string]$Message)
    Push-Location -LiteralPath $RepoPath
    try {
        & git add -A
        & git -c core.safecrlf=false commit -q -m $Message
    }
    finally { Pop-Location }
}

# =================================================================
Write-Host ''
Write-Host '[1] 新規リポジトリ — New-KnowledgeBase.ps1' -ForegroundColor Cyan
# =================================================================
$newRepo = New-TestRepository -Name 'fresh'
& (Join-Path $scriptDirectory 'New-KnowledgeBase.ps1') -RepoRoot $newRepo | Out-Null

Assert-True 'knowledge\10-silver\areas\env.md が作られる'  (Test-Path (Join-Path $newRepo 'knowledge\10-silver\areas\env.md'))
Assert-True 'knowledge\10-silver\work\index.md が作られる' (Test-Path (Join-Path $newRepo 'knowledge\10-silver\work\index.md'))
Assert-True 'knowledge\20-bronze\ が作られる'              (Test-Path (Join-Path $newRepo 'knowledge\20-bronze'))
Assert-True 'knowledge\30-gold\ が作られる'                (Test-Path (Join-Path $newRepo 'knowledge\30-gold'))
Assert-True '00-system\design-notes.md が作られる'         (Test-Path (Join-Path $newRepo 'knowledge\00-system\design-notes.md'))
Assert-True 'resources\.gitkeep が作られる'                (Test-Path (Join-Path $newRepo 'knowledge\10-silver\resources\.gitkeep'))
Assert-True 'CLAUDE.md が作られる'                         (Test-Path (Join-Path $newRepo 'CLAUDE.md'))

$newClaudeMd = Get-Content -LiteralPath (Join-Path $newRepo 'CLAUDE.md') -Raw -Encoding utf8
Assert-True 'CLAUDE.md に areas の import がある' ($newClaudeMd -match '@knowledge/10-silver/areas/env\.md')
Assert-True 'CLAUDE.md に work の import がある'  ($newClaudeMd -match '@knowledge/10-silver/work/index\.md')

Push-Location -LiteralPath $newRepo
try {
    $ignoredBronze = & git check-ignore 'knowledge/20-bronze' 2>$null
    Assert-True '20-bronze が .gitignore で除外される' ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($ignoredBronze))
    $ignoredGold = & git check-ignore 'knowledge/30-gold' 2>$null
    Assert-True '30-gold が .gitignore で除外される'   ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($ignoredGold))
}
finally { Pop-Location }

# =================================================================
Write-Host ''
Write-Host '[2] 新規スクリプトのガード — CLAUDE.md があると中止する' -ForegroundColor Cyan
# =================================================================
& (Join-Path $scriptDirectory 'New-KnowledgeBase.ps1') -RepoRoot $newRepo *>&1 | Out-Null
Assert-True 'CLAUDE.md がある repo では exit 1 で中止する' ($LASTEXITCODE -eq 1)

# =================================================================
Write-Host ''
Write-Host '[3] 既存リポジトリ — Add-KnowledgeBase.ps1' -ForegroundColor Cyan
# =================================================================
$existingRepo = New-TestRepository -Name 'legacy'
$originalClaudeMd = @'
# LegacyProject

既存のプロジェクト説明。この行は消えてはいけない。

## ビルド

cmake --build build --config Release

## 注意

この節も残らなければならない。
'@
Set-Content -LiteralPath (Join-Path $existingRepo 'CLAUDE.md') -Value $originalClaudeMd -Encoding utf8NoBOM
Set-Content -LiteralPath (Join-Path $existingRepo '.gitignore') -Value "build/`nbin/" -Encoding utf8NoBOM
Set-Content -LiteralPath (Join-Path $existingRepo 'main.cpp') -Value 'int main() { return 0; }' -Encoding utf8NoBOM
Invoke-RepoCommit -RepoPath $existingRepo -Message 'initial'

$addResult = & (Join-Path $scriptDirectory 'Add-KnowledgeBase.ps1') -RepoRoot $existingRepo

Assert-True 'knowledge\ が作られる' (Test-Path (Join-Path $existingRepo 'knowledge\10-silver\areas\env.md'))
Assert-True 'CLAUDE.md.bak が作られる' (Test-Path (Join-Path $existingRepo 'CLAUDE.md.bak'))

$updatedClaudeMd = Get-Content -LiteralPath (Join-Path $existingRepo 'CLAUDE.md') -Raw -Encoding utf8
Assert-True '既存の 1 行目が残っている'     ($updatedClaudeMd -match '# LegacyProject')
Assert-True '既存のビルド節が残っている'     ($updatedClaudeMd -match 'cmake --build build --config Release')
Assert-True '既存の注意節が残っている'       ($updatedClaudeMd -match 'この節も残らなければならない')
Assert-True '@import が追記されている'       ($updatedClaudeMd -match '@knowledge/10-silver/work/index\.md')
Assert-True '削除行が 0 と報告される'        ($addResult.DeletedLines -eq 0)

# 改行コードに依存しないよう、行に分割して比較する
$updatedGitIgnoreLines = @(Get-Content -LiteralPath (Join-Path $existingRepo '.gitignore') -Encoding utf8 |
    ForEach-Object { $_.Trim() })
Assert-True '既存の .gitignore の行が残る'   ($updatedGitIgnoreLines -contains 'build/')
Assert-True '20-bronze が追記される'         ($updatedGitIgnoreLines -contains 'knowledge/20-bronze/')
Assert-True '30-gold が追記される'           ($updatedGitIgnoreLines -contains 'knowledge/30-gold/')

# =================================================================
Write-Host ''
Write-Host '[4] 冪等性 — 2 回目の実行で何も増えない' -ForegroundColor Cyan
# =================================================================
$claudeMdBefore = Get-Content -LiteralPath (Join-Path $existingRepo 'CLAUDE.md') -Raw -Encoding utf8
$gitIgnoreBefore = Get-Content -LiteralPath (Join-Path $existingRepo '.gitignore') -Raw -Encoding utf8
$secondResult = & (Join-Path $scriptDirectory 'Add-KnowledgeBase.ps1') -RepoRoot $existingRepo
$claudeMdAfter = Get-Content -LiteralPath (Join-Path $existingRepo 'CLAUDE.md') -Raw -Encoding utf8
$gitIgnoreAfter = Get-Content -LiteralPath (Join-Path $existingRepo '.gitignore') -Raw -Encoding utf8

Assert-True '2 回目で CLAUDE.md が変わらない'  ($claudeMdBefore -eq $claudeMdAfter)
Assert-True '2 回目で .gitignore が変わらない' ($gitIgnoreBefore -eq $gitIgnoreAfter)
Assert-True '2 回目は skipped と報告される'    ($secondResult.ClaudeMd -eq 'skipped')

# =================================================================
Write-Host ''
Write-Host '[5] -WhatIf — 何も書き込まない' -ForegroundColor Cyan
# =================================================================
$whatIfRepo = New-TestRepository -Name 'whatif'
Set-Content -LiteralPath (Join-Path $whatIfRepo 'CLAUDE.md') -Value '# WhatIf' -Encoding utf8NoBOM
Invoke-RepoCommit -RepoPath $whatIfRepo -Message 'initial'
& (Join-Path $scriptDirectory 'Add-KnowledgeBase.ps1') -RepoRoot $whatIfRepo -WhatIf *>&1 | Out-Null

Assert-True '-WhatIf では knowledge\ を作らない'    (-not (Test-Path (Join-Path $whatIfRepo 'knowledge')))
Assert-True '-WhatIf では CLAUDE.md.bak を作らない' (-not (Test-Path (Join-Path $whatIfRepo 'CLAUDE.md.bak')))
$whatIfClaudeMd = Get-Content -LiteralPath (Join-Path $whatIfRepo 'CLAUDE.md') -Raw -Encoding utf8
Assert-True '-WhatIf では CLAUDE.md を変えない'     ($whatIfClaudeMd.Trim() -eq '# WhatIf')

# =================================================================
Write-Host ''
Write-Host '[6] 既存スクリプトのガード — CLAUDE.md が無いと中止する' -ForegroundColor Cyan
# =================================================================
$bareRepo = New-TestRepository -Name 'bare'
& (Join-Path $scriptDirectory 'Add-KnowledgeBase.ps1') -RepoRoot $bareRepo *>&1 | Out-Null
Assert-True 'CLAUDE.md が無い repo では exit 1 で中止する' ($LASTEXITCODE -eq 1)
Assert-True '中止時は knowledge\ を作らない'               (-not (Test-Path (Join-Path $bareRepo 'knowledge')))

# =================================================================
Write-Host ''
Write-Host ('結果: PASS ' + $passCount + ' / FAIL ' + $failCount) -ForegroundColor $(if ($failCount -eq 0) { 'Green' } else { 'Red' })
Write-Host ''
if ($failCount -gt 0) { exit 1 }
exit 0
