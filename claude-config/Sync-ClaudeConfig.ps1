#Requires -Version 7
<#
.SYNOPSIS
Claude Code の自作環境 (この claude-config\ の中身) と、<ホーム>\.claude を突き合わせる。

.DESCRIPTION
-Mode Status  (既定) 差分を表示するだけで、何も書かない。
-Mode Install claude-config\ から <ホーム>\.claude へ配置する。内容が違う既存ファイルは、
              名前に .bak-<日時> を付けて退避してから置き換える。
-Mode Export  <ホーム>\.claude から claude-config\ へ取り込む。<ホーム>\.claude を直したあと、
              リポジトリへ反映するときに使う。

対象は、CLAUDE.md、hooks、scripts、agents、rules、templates と、下の $managedSkillNames に挙げた skills。
settings.json は上書きしない。無ければ settings.template.json から作り、有れば未登録の hook を知らせるだけ。
資格情報・メモリ・セッション・プラグイン・skills\synced は対象外。

.EXAMPLE
.\claude-config\Sync-ClaudeConfig.ps1
.\claude-config\Sync-ClaudeConfig.ps1 -Mode Install -WhatIf
.\claude-config\Sync-ClaudeConfig.ps1 -Mode Install
.\claude-config\Sync-ClaudeConfig.ps1 -Mode Export
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('Status', 'Install', 'Export')]
    [string] $Mode = 'Status',

    # 配置先・取り込み元。既定は <ホーム>\.claude。試験のために変えられる
    [string] $ClaudeHome = (Join-Path $HOME '.claude')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# リポジトリに置いてあるファイルの中の、基準のパス。
# 配置するときは $ClaudeHome に置き換え、取り込むときは逆にこの形へ戻す
$canonicalClaudeHome = 'C:\Users\mt\.claude'
$repositoryConfigRoot = $PSScriptRoot
$utf8WithoutBom = [System.Text.UTF8Encoding]::new($false)

# 自作の skills。名前を足せば対象になる (skills\synced などの自作でないものは入れない)
$managedSkillNames = @('archive-work', 'init-knowledge', 'update-facts')
$managedPatterns = @(
    @{ Directory = 'hooks'; Filter = '*.ps1' }
    @{ Directory = 'scripts'; Filter = '*.ps1' }
    @{ Directory = 'scripts'; Filter = '*.psm1' }
    @{ Directory = 'agents'; Filter = '*.md' }
    @{ Directory = 'rules'; Filter = '*.md' }
    @{ Directory = 'templates'; Filter = '*.md' }
)

# claude-config\ の直下に CLAUDE.md を置くと、このリポジトリの指示として読み込まれてしまう。
# リポジトリの中では別名で持ち、<ホーム>\.claude へは CLAUDE.md として配置する
$repositoryInstructionsName = 'CLAUDE.global.md'

function Get-RepositoryRelativePath {
    param([string] $RelativePath)
    if ($RelativePath -eq 'CLAUDE.md') { return $repositoryInstructionsName }
    return $RelativePath
}

# 戻り値は <ホーム>\.claude 側の相対パス (CLAUDE.md は常に 'CLAUDE.md')
function Get-ManagedRelativePaths {
    param([string] $Root, [string] $InstructionsName)
    $relativePaths = [System.Collections.Generic.List[string]]::new()
    if (Test-Path -LiteralPath (Join-Path $Root $InstructionsName) -PathType Leaf) { $relativePaths.Add('CLAUDE.md') }
    foreach ($pattern in $managedPatterns) {
        $directoryPath = Join-Path $Root $pattern.Directory
        if (-not (Test-Path -LiteralPath $directoryPath -PathType Container)) { continue }
        # -Filter は短い名前との照合で .bak 付きを拾うことがあるので、-like で絞り直す
        foreach ($file in (Get-ChildItem -LiteralPath $directoryPath -File | Where-Object { $_.Name -like $pattern.Filter })) {
            $relativePaths.Add((Join-Path $pattern.Directory $file.Name))
        }
    }
    foreach ($skillName in $managedSkillNames) {
        $skillRelativePath = Join-Path (Join-Path 'skills' $skillName) 'SKILL.md'
        if (Test-Path -LiteralPath (Join-Path $Root $skillRelativePath) -PathType Leaf) { $relativePaths.Add($skillRelativePath) }
    }
    return $relativePaths
}

# 比較用に、UTF-8 として読み、改行を LF にそろえる
function Read-NormalizedText {
    param([string] $Path)
    return [System.IO.File]::ReadAllText($Path, $utf8WithoutBom).Replace("`r`n", "`n")
}

function ConvertTo-HomeSpecific {
    param([string] $Text)
    return $Text.Replace($canonicalClaudeHome, $ClaudeHome)
}

function ConvertTo-Canonical {
    param([string] $Text)
    return $Text.Replace($ClaudeHome, $canonicalClaudeHome)
}

function Write-Utf8Text {
    param([string] $Path, [string] $Text)
    $directoryPath = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $directoryPath -PathType Container)) {
        New-Item -ItemType Directory -Force -Path $directoryPath | Out-Null
    }
    [System.IO.File]::WriteAllText($Path, $Text, $utf8WithoutBom)
}

$repositoryPaths = @(Get-ManagedRelativePaths $repositoryConfigRoot $repositoryInstructionsName)
$homePaths = @(Get-ManagedRelativePaths $ClaudeHome 'CLAUDE.md')
$allPaths = @($repositoryPaths + $homePaths | Sort-Object -Unique)

$rows = foreach ($relativePath in $allPaths) {
    $repositoryFile = Join-Path $repositoryConfigRoot (Get-RepositoryRelativePath $relativePath)
    $homeFile = Join-Path $ClaudeHome $relativePath
    $inRepository = Test-Path -LiteralPath $repositoryFile -PathType Leaf
    $inHome = Test-Path -LiteralPath $homeFile -PathType Leaf
    $state = if ($inRepository -and $inHome) {
        if ((ConvertTo-HomeSpecific (Read-NormalizedText $repositoryFile)) -ceq (Read-NormalizedText $homeFile)) { 'same' } else { 'differs' }
    } elseif ($inRepository) {
        'repo-only'
    } else {
        'home-only'
    }
    [pscustomobject]@{ State = $state; Path = $relativePath }
}

"対象: claude-config\ = $repositoryConfigRoot"
"      <ホーム>\.claude = $ClaudeHome"
$rows | Format-Table -AutoSize
$stateCounts = $rows | Group-Object -Property State | ForEach-Object { '{0}: {1}' -f $_.Name, $_.Count }
"集計: $($stateCounts -join ' / ')"

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$changedCount = 0

if ($Mode -eq 'Install') {
    foreach ($row in ($rows | Where-Object { $_.State -in 'repo-only', 'differs' })) {
        $repositoryFile = Join-Path $repositoryConfigRoot (Get-RepositoryRelativePath $row.Path)
        $homeFile = Join-Path $ClaudeHome $row.Path
        if ($PSCmdlet.ShouldProcess($homeFile, "配置 ($($row.State))")) {
            if ($row.State -eq 'differs') {
                Copy-Item -LiteralPath $homeFile -Destination "$homeFile.bak-$stamp"
            }
            Write-Utf8Text $homeFile (ConvertTo-HomeSpecific (Read-NormalizedText $repositoryFile))
            if ($homeFile -match '\.(ps1|psm1)$') { Unblock-File -LiteralPath $homeFile -ErrorAction SilentlyContinue }
            $changedCount++
        }
    }
}

if ($Mode -eq 'Export') {
    foreach ($row in ($rows | Where-Object { $_.State -in 'home-only', 'differs' })) {
        $repositoryFile = Join-Path $repositoryConfigRoot (Get-RepositoryRelativePath $row.Path)
        $homeFile = Join-Path $ClaudeHome $row.Path
        if ($PSCmdlet.ShouldProcess($repositoryFile, "取り込み ($($row.State))")) {
            Write-Utf8Text $repositoryFile (ConvertTo-Canonical (Read-NormalizedText $homeFile))
            $changedCount++
        }
    }
}

# settings.json: 上書きしない。無ければ雛形から作り、有れば未登録の hook を知らせる
$templatePath = Join-Path $repositoryConfigRoot 'settings.template.json'
$settingsPath = Join-Path $ClaudeHome 'settings.json'
if (Test-Path -LiteralPath $templatePath -PathType Leaf) {
    $templateText = [System.IO.File]::ReadAllText($templatePath, $utf8WithoutBom)
    if (-not (Test-Path -LiteralPath $settingsPath -PathType Leaf)) {
        if ($Mode -eq 'Install') {
            if ($PSCmdlet.ShouldProcess($settingsPath, '雛形から作成')) {
                Write-Utf8Text $settingsPath $templateText
                $changedCount++
                "settings.json: 無かったので settings.template.json から作成した"
            }
        } else {
            'settings.json: 無い (-Mode Install で settings.template.json から作る)'
        }
    } else {
        $settingsText = [System.IO.File]::ReadAllText($settingsPath, $utf8WithoutBom)
        $hookScriptNames = @([regex]::Matches($templateText, 'hooks\\\\([\w-]+\.ps1)') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
        $missingHooks = @($hookScriptNames | Where-Object { $settingsText -notmatch [regex]::Escape($_) })
        if ($missingHooks.Count -eq 0) {
            'settings.json: 雛形の hook は全て登録済み (中身は変更しない)'
        } else {
            "settings.json: 次の hook が未登録。settings.template.json を見て手で追記してください: $($missingHooks -join ', ')"
        }
    }
}

"変更したファイル: $changedCount 件 (Mode = $Mode)"
