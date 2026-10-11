#Requires -Version 7
<#
.SYNOPSIS
    ナレッジベースの骨格を作るための共通ロジック。
.DESCRIPTION
    New-KnowledgeBase.ps1（新規リポジトリ用）と Add-KnowledgeBase.ps1（既存リポジトリ用）が
    このモジュールを読み込む。両方から呼ばれるため、ここには分岐を置かない。

    構造の定義は C:\Users\mt\.claude\templates\knowledge-design.md にある。
    このモジュールはその §2-2 のツリーを作るだけで、事実は一切書かない。
#>

Set-StrictMode -Version Latest

$script:GitIgnoreEntries = @(
    'knowledge/20-bronze/'
    'knowledge/30-gold/'
)

$script:ImportHeading = '## 常時ロードされる知識'

function Write-Utf8File {
    <#
    .SYNOPSIS
        UTF-8（BOM なし）でファイルを書く。既存ファイルは上書きしない。
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Content
    )

    if (Test-Path -LiteralPath $Path) {
        return [pscustomobject]@{ Path = $Path; Action = 'skipped'; Reason = '既存' }
    }

    $parentDirectory = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($parentDirectory) -and -not (Test-Path -LiteralPath $parentDirectory)) {
        if ($PSCmdlet.ShouldProcess($parentDirectory, 'ディレクトリ作成')) {
            New-Item -ItemType Directory -Path $parentDirectory -Force | Out-Null
        }
    }

    if ($PSCmdlet.ShouldProcess($Path, 'ファイル作成')) {
        Set-Content -LiteralPath $Path -Value $Content -Encoding utf8NoBOM
    }
    return [pscustomobject]@{ Path = $Path; Action = 'created'; Reason = '' }
}

function Test-RepositoryRoot {
    <#
    .SYNOPSIS
        指定パスがリポジトリのルートとして妥当かを検査する。
    .DESCRIPTION
        git 管理下ならルートが一致するかも見る。git 管理外でも作業は続行できるが警告を返す。
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$RepoRoot)

    if (-not (Test-Path -LiteralPath $RepoRoot -PathType Container)) {
        throw "ディレクトリが存在しません: $RepoRoot"
    }

    $resolvedRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
    $warnings = [System.Collections.Generic.List[string]]::new()
    $isGitRepository = $false

    $gitCommand = Get-Command -Name 'git' -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if ($null -eq $gitCommand) {
        $warnings.Add('git が見つかりません。.gitignore の検証を省略します。')
    }
    else {
        Push-Location -LiteralPath $resolvedRoot
        try {
            $gitTopLevel = & $gitCommand.Source 'rev-parse' '--show-toplevel' 2>$null
            if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($gitTopLevel)) {
                $isGitRepository = $true
                $normalizedTop = (Resolve-Path -LiteralPath $gitTopLevel.Trim()).Path
                if ($normalizedTop -ne $resolvedRoot) {
                    $warnings.Add("指定パスは git リポジトリのルートではありません。ルートは $normalizedTop です。")
                }
            }
            else {
                $warnings.Add('git リポジトリではありません。knowledge\ は作れますが .gitignore は効きません。')
            }
        }
        finally {
            Pop-Location
        }
    }

    return [pscustomobject]@{
        RepoRoot        = $resolvedRoot
        IsGitRepository = $isGitRepository
        Warnings        = $warnings.ToArray()
    }
}

function Get-KnowledgeState {
    <#
    .SYNOPSIS
        リポジトリの現在の状態を調べる。新規か既存かの判定に使う。
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$RepoRoot)

    $claudeMdPath = Join-Path $RepoRoot 'CLAUDE.md'
    $knowledgePath = Join-Path $RepoRoot 'knowledge'

    $hasImportBlock = $false
    if (Test-Path -LiteralPath $claudeMdPath) {
        $claudeMdText = Get-Content -LiteralPath $claudeMdPath -Raw -Encoding utf8
        $hasImportBlock = $claudeMdText -match '(?m)^@knowledge/'
    }

    return [pscustomobject]@{
        ClaudeMdPath      = $claudeMdPath
        HasClaudeMd       = Test-Path -LiteralPath $claudeMdPath
        HasKnowledgeDir   = Test-Path -LiteralPath $knowledgePath
        HasImportBlock    = $hasImportBlock
        HasProjectSettings= Test-Path -LiteralPath (Join-Path $RepoRoot '.claude\settings.json')
        HasProjectRules   = Test-Path -LiteralPath (Join-Path $RepoRoot '.claude\rules')
    }
}

function New-KnowledgeSkeleton {
    <#
    .SYNOPSIS
        knowledge\ のディレクトリと雛形ファイルを作る。既存ファイルには触れない。
    .PARAMETER AreaNames
        areas\ に作る雛形の名前。拡張子なし。常時ロードされるため 2 つまでを推奨する。
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [string[]]$AreaNames = @('env')
    )

    $results = [System.Collections.Generic.List[object]]::new()

    $directories = @(
        'knowledge\00-system\scripts'
        'knowledge\10-silver\areas'
        'knowledge\10-silver\work'
        'knowledge\10-silver\resources'
        'knowledge\10-silver\archive'
        'knowledge\20-bronze'
        'knowledge\30-gold'
    )
    foreach ($relativeDirectory in $directories) {
        $fullPath = Join-Path $RepoRoot $relativeDirectory
        if (Test-Path -LiteralPath $fullPath) {
            $results.Add([pscustomobject]@{ Path = $fullPath; Action = 'skipped'; Reason = '既存' })
            continue
        }
        if ($PSCmdlet.ShouldProcess($fullPath, 'ディレクトリ作成')) {
            New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
        }
        $results.Add([pscustomobject]@{ Path = $fullPath; Action = 'created'; Reason = '' })
    }

    foreach ($areaName in $AreaNames) {
        $areaContent = @"
# $areaName

<!-- 常時ロードされる。50 行以内。areas/ は 2 ファイルまで。 -->
<!-- 終わりのない責任領域と、知らないと無駄に失敗する制約だけを書く。 -->
<!-- 終わりがある作業は work/ へ。外部資料の要約は resources/ へ。 -->
<!-- 断定文で書く。コードから導出できる情報（構成・依存一覧）は書かない。 -->

（まだ空。/update-facts で埋める）
"@
        $results.Add((Write-Utf8File -Path (Join-Path $RepoRoot "knowledge\10-silver\areas\$areaName.md") `
                                     -Content $areaContent -WhatIf:$WhatIfPreference))
    }

    $workIndexContent = @'
# 進行中の作業単位

書式: `- <id> — <一行の説明>（開始 yyyy-MM-dd）`
終了したら `/archive-work <id>` を使う。この行を手で消さない。
'@
    $results.Add((Write-Utf8File -Path (Join-Path $RepoRoot 'knowledge\10-silver\work\index.md') `
                                 -Content $workIndexContent -WhatIf:$WhatIfPreference))

    $designNotesContent = @'
# このリポジトリ固有の設計調整点

構造の定義は `C:\Users\mt\.claude\templates\knowledge-design.md`。
このファイルには、テンプレートからずらした点とその理由だけを書く。
ずらしていなければ「なし」と書く。

## テンプレートとの差分

なし

## 既知の限界

なし
'@
    $results.Add((Write-Utf8File -Path (Join-Path $RepoRoot 'knowledge\00-system\design-notes.md') `
                                 -Content $designNotesContent -WhatIf:$WhatIfPreference))

    # git は空ディレクトリを追跡しないため、コミット対象の空ディレクトリだけ .gitkeep を置く。
    # 20-bronze と 30-gold は .gitignore 対象なので置かない。
    foreach ($keepDirectory in @('knowledge\10-silver\resources', 'knowledge\10-silver\archive')) {
        $results.Add((Write-Utf8File -Path (Join-Path $RepoRoot (Join-Path $keepDirectory '.gitkeep')) `
                                     -Content '' -WhatIf:$WhatIfPreference))
    }

    return $results.ToArray()
}

function Add-KnowledgeGitIgnore {
    <#
    .SYNOPSIS
        .gitignore に原本層と生成物層の除外を追記する。既にあれば何もしない。
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory)][string]$RepoRoot)

    $gitIgnorePath = Join-Path $RepoRoot '.gitignore'
    $existingLines = @()
    if (Test-Path -LiteralPath $gitIgnorePath) {
        $existingLines = @(Get-Content -LiteralPath $gitIgnorePath -Encoding utf8)
    }

    $trimmedExisting = @($existingLines | ForEach-Object { $_.Trim() })
    $missingEntries = @($script:GitIgnoreEntries | Where-Object { $trimmedExisting -notcontains $_ })

    if ($missingEntries.Count -eq 0) {
        return [pscustomobject]@{ Path = $gitIgnorePath; Action = 'skipped'; Added = @(); Reason = '既に除外済み' }
    }

    $appendedLines = [System.Collections.Generic.List[string]]::new()
    if ($existingLines.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($existingLines[-1])) {
        $appendedLines.Add('')
    }
    $appendedLines.Add('# ナレッジベースの原本層と生成物層。毎日の差分がコミットに載るのを防ぐ。')
    $appendedLines.Add('# 10-silver/ と 00-system/ はコミット対象。')
    foreach ($entry in $missingEntries) { $appendedLines.Add($entry) }

    if ($PSCmdlet.ShouldProcess($gitIgnorePath, '.gitignore へ追記')) {
        Add-Content -LiteralPath $gitIgnorePath -Value $appendedLines -Encoding utf8NoBOM
    }

    return [pscustomobject]@{
        Path   = $gitIgnorePath
        Action = 'appended'
        Added  = $missingEntries
        Reason = ''
    }
}

function Get-ImportBlock {
    <#
    .SYNOPSIS
        CLAUDE.md の末尾に足す @import ブロックを組み立てる。
    #>
    [CmdletBinding()]
    param([string[]]$AreaNames = @('env'))

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add($script:ImportHeading)
    $lines.Add('')
    foreach ($areaName in $AreaNames) {
        $lines.Add("@knowledge/10-silver/areas/$areaName.md")
    }
    $lines.Add('@knowledge/10-silver/work/index.md')
    return $lines.ToArray()
}

function Add-KnowledgeImport {
    <#
    .SYNOPSIS
        既存の CLAUDE.md の末尾に @import ブロックを追記する。既存の行は 1 行も消さない。
    .DESCRIPTION
        追記前に .bak を作る。既に @knowledge/ の import があれば何もしない。
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$ClaudeMdPath,
        [string[]]$AreaNames = @('env')
    )

    if (-not (Test-Path -LiteralPath $ClaudeMdPath)) {
        throw "CLAUDE.md が存在しません: $ClaudeMdPath"
    }

    $originalText = Get-Content -LiteralPath $ClaudeMdPath -Raw -Encoding utf8
    if ($originalText -match '(?m)^@knowledge/') {
        return [pscustomobject]@{
            Path = $ClaudeMdPath; Action = 'skipped'; BackupPath = $null
            Added = @(); Reason = '既に @import がある'
        }
    }

    $backupPath = $ClaudeMdPath + '.bak'
    if (-not (Test-Path -LiteralPath $backupPath)) {
        if ($PSCmdlet.ShouldProcess($backupPath, 'バックアップ作成')) {
            Copy-Item -LiteralPath $ClaudeMdPath -Destination $backupPath
        }
    }

    $importLines = Get-ImportBlock -AreaNames $AreaNames
    $appendedLines = [System.Collections.Generic.List[string]]::new()
    if (-not [string]::IsNullOrWhiteSpace($originalText) -and -not $originalText.EndsWith("`n")) {
        $appendedLines.Add('')
    }
    $appendedLines.Add('')
    foreach ($importLine in $importLines) { $appendedLines.Add($importLine) }

    if ($PSCmdlet.ShouldProcess($ClaudeMdPath, '@import ブロックを末尾に追記')) {
        Add-Content -LiteralPath $ClaudeMdPath -Value $appendedLines -Encoding utf8NoBOM
    }

    return [pscustomobject]@{
        Path       = $ClaudeMdPath
        Action     = 'appended'
        BackupPath = $backupPath
        Added      = $importLines
        Reason     = ''
    }
}

function New-ProjectClaudeMd {
    <#
    .SYNOPSIS
        新規リポジトリ用の CLAUDE.md を雛形から作る。既存があれば何もしない。
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [string[]]$AreaNames = @('env')
    )

    $claudeMdPath = Join-Path $RepoRoot 'CLAUDE.md'
    $repositoryName = Split-Path -Leaf $RepoRoot
    $importText = (Get-ImportBlock -AreaNames $AreaNames) -join "`n"

    $content = @"
# $repositoryName

<!-- このリポジトリが何をするものかを 2〜3 行で書く。承認前に人間が確認すること。 -->

## 構成

| パス | 内容 |
|---|---|
| ``knowledge/`` | ナレッジベース本体 |

## ビルドとテスト

<!-- ビルドコマンドとテストコマンドを書く。無ければ「無い」と明記する。 -->
<!-- 具体的な手順は knowledge/10-silver/areas/ 側に置き、ここには置き場所だけ書く。 -->

$importText
"@

    return Write-Utf8File -Path $claudeMdPath -Content $content -WhatIf:$WhatIfPreference
}

function Get-AlwaysLoadedReport {
    <#
    .SYNOPSIS
        常時ロードされるファイルと合計行数を数える。予算は 250 行。
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$RepoRoot)

    $candidatePaths = [System.Collections.Generic.List[string]]::new()
    # 設定ディレクトリは CLAUDE_CONFIG_DIR で移動できる。未設定ならインストール先を使う。
    $claudeHome = if (-not [string]::IsNullOrWhiteSpace($env:CLAUDE_CONFIG_DIR)) {
        $env:CLAUDE_CONFIG_DIR
    } else {
        'C:\Users\mt\.claude'
    }
    $candidatePaths.Add((Join-Path $claudeHome 'CLAUDE.md'))
    $candidatePaths.Add((Join-Path $claudeHome 'RTK.md'))

    $claudeMdPath = Join-Path $RepoRoot 'CLAUDE.md'
    if (Test-Path -LiteralPath $claudeMdPath) {
        $candidatePaths.Add($claudeMdPath)
        foreach ($line in (Get-Content -LiteralPath $claudeMdPath -Encoding utf8)) {
            if ($line -match '^@(.+)$') {
                $importTarget = Join-Path $RepoRoot ($Matches[1].Trim() -replace '/', '\')
                if (Test-Path -LiteralPath $importTarget) { $candidatePaths.Add($importTarget) }
            }
        }
    }

    $rows = [System.Collections.Generic.List[object]]::new()
    $totalLines = 0
    foreach ($candidatePath in $candidatePaths) {
        if (-not (Test-Path -LiteralPath $candidatePath)) { continue }
        $lineCount = @(Get-Content -LiteralPath $candidatePath -Encoding utf8).Count
        $totalLines += $lineCount
        $rows.Add([pscustomobject]@{ Lines = $lineCount; Path = $candidatePath })
    }

    return [pscustomobject]@{
        Files      = $rows.ToArray()
        TotalLines = $totalLines
        Budget     = 250
        OverBudget = ($totalLines -gt 250)
    }
}

Export-ModuleMember -Function @(
    'Test-RepositoryRoot'
    'Get-KnowledgeState'
    'New-KnowledgeSkeleton'
    'Add-KnowledgeGitIgnore'
    'Add-KnowledgeImport'
    'New-ProjectClaudeMd'
    'Get-ImportBlock'
    'Get-AlwaysLoadedReport'
)
