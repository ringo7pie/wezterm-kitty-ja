#Requires -Version 7
# PreToolUse (matcher: Edit|Write|NotebookEdit|PowerShell|Bash)
# zzz-Temp はユーザーの作業フォルダ。Claude Code は読み取りだけ行い、書き込み・コミット・push をしない。
# 判定はパス断片とコマンド文字列だけで行うため、リポジトリを問わず 1 本で動く。
# コマンド文字列の判定は文字列照合であり、サンドボックスではない。取りこぼしは起こり得る。
# 入力を解釈できない場合は素通しする。誤検知で作業を止めない。

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$protectedFolderName = 'zzz-Temp'
$escapedFolderName = [regex]::Escape($protectedFolderName)
# ファイルパス・git のパス用: パスの 1 区間として一致する
$pathSegmentPattern = '(?i)(^|[\\/"''])' + $escapedFolderName + '([\\/"'']|$)'
# コマンド文字列用: 単語として一致する
$commandWordPattern = '(?i)(?<![\w-])' + $escapedFolderName + '(?![\w-])'

# 書き込み・削除・移動を行うコマンド。zzz-Temp と同じコマンドの中にあれば拒否する。
# 拡張子 (*.md の md)・パスの一部・変数 ($copy)・引用符の中の語は、コマンド名ではないので除く
$writeVerbPattern = '(?i)(?<![\w.\\/''"$-])(Set-Content|Add-Content|Clear-Content|Out-File|Tee-Object|New-Item|Remove-Item|Move-Item|Rename-Item|Copy-Item|Set-ItemProperty|Expand-Archive|Compress-Archive|Export-Csv|Export-Clixml|Invoke-WebRequest|Invoke-RestMethod|Start-BitsTransfer|rm|del|erase|rd|rmdir|mv|move|ren|rename|cp|copy|mkdir|md|touch|tee|robocopy|xcopy|attrib|icacls|takeown|truncate)(?![\w.\\/''"$-])|\[(System\.)?IO\.(File|Directory)\]::(Write|Append|Delete|Move|Copy|Create|Replace)|(?<![\w-])sed\s+-i'
# zzz-Temp を出力先にするリダイレクト
$redirectPattern = '(?<![<=\-])\d?>{1,2}\s*[^|;\r\n]*' + $commandWordPattern
# zzz-Temp のパスを渡されたら、作業ツリーかインデックスを変える git のサブコマンド
$gitPathSubcommands = @('add', 'stage', 'rm', 'mv', 'clean', 'checkout', 'restore', 'stash', 'apply')

function Get-PropertyNames {
    param($Target)
    if ($null -eq $Target) { return @() }
    return @($Target.PSObject.Properties | Select-Object -ExpandProperty Name)
}

function Get-PropertyValue {
    param($Target, [string] $Name)
    if ((Get-PropertyNames $Target) -contains $Name) { return $Target.$Name }
    return $null
}

function Write-Deny {
    param([string] $Reason)
    $response = [pscustomobject]@{
        hookSpecificOutput = [pscustomobject]@{
            hookEventName            = 'PreToolUse'
            permissionDecision       = 'deny'
            permissionDecisionReason = $Reason
        }
    }
    # 日本語を \uXXXX に直し、標準出力を ASCII だけにする (文字コードの食い違いで化けない)
    $response | ConvertTo-Json -Depth 5 -Compress -EscapeHandling EscapeNonAscii | Write-Output
    [Console]::Error.WriteLine($Reason)
    exit 0
}

function Get-GitOutput {
    param([string] $WorkingDirectory, [string[]] $Arguments)
    if ([string]::IsNullOrWhiteSpace($WorkingDirectory)) { return @() }
    if (-not (Test-Path -LiteralPath $WorkingDirectory -PathType Container)) { return @() }
    try {
        $output = & git -C $WorkingDirectory -c core.quotepath=false @Arguments 2>$null
        if ($LASTEXITCODE -ne 0) { return @() }
        return @($output)
    } catch {
        return @()
    }
}

# 1 つの文から git の呼び出しを取り出す。git でなければ $null
function ConvertTo-GitInvocation {
    param([string] $Statement)
    $tokens = @([regex]::Matches($Statement, '"[^"]*"|''[^'']*''|\S+') | ForEach-Object { $_.Value.Trim('"', "'") })
    $gitIndex = -1
    for ($index = 0; $index -lt $tokens.Count; $index++) {
        if ($tokens[$index] -match '(?i)(^|[\\/])git(\.exe)?$') { $gitIndex = $index; break }
    }
    if ($gitIndex -lt 0) { return $null }
    $cursor = $gitIndex + 1
    while ($cursor -lt $tokens.Count -and $tokens[$cursor].StartsWith('-')) {
        if ($tokens[$cursor] -in @('-C', '-c', '--git-dir', '--work-tree', '--namespace')) { $cursor += 2 } else { $cursor += 1 }
    }
    if ($cursor -ge $tokens.Count) { return $null }
    $arguments = @()
    if ($cursor + 1 -lt $tokens.Count) { $arguments = @($tokens[($cursor + 1)..($tokens.Count - 1)]) }
    return [pscustomobject]@{
        Subcommand = $tokens[$cursor].ToLowerInvariant()
        Arguments  = $arguments
    }
}

# git status のうち zzz-Temp 配下の行。Staged は add 済み (削除を除く) かどうか
function Get-ProtectedStatusEntries {
    param([string] $WorkingDirectory)
    $entries = @()
    foreach ($line in (Get-GitOutput $WorkingDirectory @('status', '--porcelain=v1', '--untracked-files=all'))) {
        if ($line.Length -lt 4) { continue }
        if ($line.Substring(3) -notmatch $pathSegmentPattern) { continue }
        # インデックスから外しただけの削除 (追跡をやめる操作) は中身を送らないので数えない
        if ($line.Substring(0, 2) -eq 'D ') { continue }
        $entries += [pscustomobject]@{
            Staged = ($line[0] -notin @(' ', '?', '!'))
            Line   = $line
        }
    }
    return $entries
}

function Format-Entries {
    param($Entries)
    return (@($Entries | Select-Object -First 5 | ForEach-Object { $_.Line }) -join ' / ')
}

try {
    # 入出力とも UTF-8 にそろえる (既定のコードページだと、標準エラーの日本語が化ける)
    [Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false)
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    $rawInput = [Console]::In.ReadToEnd()
} catch {
    exit 0
}
if ([string]::IsNullOrWhiteSpace($rawInput)) { exit 0 }

try {
    $hookInput = $rawInput | ConvertFrom-Json
} catch {
    exit 0
}

$toolInput = Get-PropertyValue $hookInput 'tool_input'
if ($null -eq $toolInput) { exit 0 }

$readOnlyAdvice = '読み取りだけなら Read / Get-Content / Get-ChildItem を使ってください。Claude 自身の一時ファイルは scratchpad に置いてください。'

# --- Edit / Write / NotebookEdit: パスで判定する ---
foreach ($propertyName in 'file_path', 'notebook_path') {
    $targetPath = [string](Get-PropertyValue $toolInput $propertyName)
    if ([string]::IsNullOrWhiteSpace($targetPath)) { continue }
    if ($targetPath -match $pathSegmentPattern) {
        Write-Deny ("$protectedFolderName はユーザーの作業フォルダです。Claude Code は読み取り専用で、書き込めません。$readOnlyAdvice 拒否した対象: $targetPath")
    }
}

# --- PowerShell / Bash: コマンド文字列で判定する ---
$command = [string](Get-PropertyValue $toolInput 'command')
if ([string]::IsNullOrWhiteSpace($command)) { exit 0 }

$workingDirectory = [string](Get-PropertyValue $hookInput 'cwd')
if ([string]::IsNullOrWhiteSpace($workingDirectory)) { $workingDirectory = (Get-Location).Path }

$statements = @($command -split '(?:;|&&|\|\||\||\r?\n)')
$nonGitStatements = @()

foreach ($statement in $statements) {
    $invocation = ConvertTo-GitInvocation $statement
    if ($null -eq $invocation) {
        $nonGitStatements += $statement
        continue
    }

    $subcommand = $invocation.Subcommand
    $arguments = $invocation.Arguments
    $mentionsFolder = @($arguments | Where-Object { $_ -match $commandWordPattern }).Count -gt 0
    $unstageOnly = ($arguments -contains '--staged') -and -not ($arguments -contains '--worktree') -and -not ($arguments -contains '-W')

    if ($subcommand -in $gitPathSubcommands -and $mentionsFolder -and -not ($subcommand -eq 'restore' -and $unstageOnly)) {
        Write-Deny "$protectedFolderName はユーザーの作業フォルダです。git $subcommand の対象にできません。コミットも push もしない決まりです。"
    }

    $isBroadAdd = $subcommand -in @('add', 'stage') -and (@($arguments | Where-Object { $_ -in @('-A', '--all', '-u', '--update', '.', '*', ':/') }).Count -gt 0)
    $isCommitAll = $subcommand -eq 'commit' -and (@($arguments | Where-Object { $_ -match '^-[A-Za-z]*a[A-Za-z]*$' -or $_ -eq '--all' }).Count -gt 0)

    if ($isBroadAdd -or $isCommitAll) {
        $entries = @(Get-ProtectedStatusEntries $workingDirectory)
        if ($entries.Count -gt 0) {
            Write-Deny "$protectedFolderName に未コミットの変更があるので、まとめて add / commit -a できません。パスを指定して add してください。該当: $(Format-Entries $entries)"
        }
    }

    if ($subcommand -eq 'commit') {
        $stagedEntries = @(Get-ProtectedStatusEntries $workingDirectory | Where-Object { $_.Staged })
        if ($stagedEntries.Count -gt 0) {
            Write-Deny "$protectedFolderName の変更が add 済みなのでコミットできません。git restore --staged でインデックスから外してください。該当: $(Format-Entries $stagedEntries)"
        }
    }

    if ($subcommand -eq 'push') {
        # どのリモート追跡ブランチにも無いコミットが zzz-Temp の中身を追加・変更していれば、push しない。
        # 削除 (--diff-filter=d で除外) は中身を送らないので通す。追跡を外すコミットを push できるようにするため
        $unpushedPaths = Get-GitOutput $workingDirectory @('log', '--name-only', '--diff-filter=d', '--pretty=format:', 'HEAD', '--not', '--remotes')
        $pendingPaths = @($unpushedPaths | Where-Object { $_ -match $pathSegmentPattern })
        if ($pendingPaths.Count -gt 0) {
            Write-Deny "未 push のコミットが $protectedFolderName を変更しているので push できません。該当: $(@($pendingPaths | Select-Object -First 5) -join ' / ')"
        }
    }
}

# git 以外の文: zzz-Temp を含み、書き込み系のコマンドかリダイレクトがあれば拒否する。
# パイプで区切られた文をつなぎ直して見る (Get-ChildItem zzz-Temp | Remove-Item を拾うため)
$nonGitText = $nonGitStatements -join "`n"
if ($nonGitText -match $commandWordPattern) {
    if (($nonGitText -match $writeVerbPattern) -or ($nonGitText -match $redirectPattern)) {
        Write-Deny "$protectedFolderName はユーザーの作業フォルダです。書き込み・削除・移動・コピーを含むコマンドは実行できません。$readOnlyAdvice"
    }
}

exit 0
