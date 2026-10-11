#Requires -Version 7
# PreToolUse (matcher: Edit|Write)
# knowledge\20-bronze\ は原本層。Edit / Write による書き込みを拒否する。
# 判定はパス断片のみで行うため、リポジトリを問わず 1 本で動く。

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-PropertyNames {
    param($Target)
    if ($null -eq $Target) { return @() }
    return @($Target.PSObject.Properties | Select-Object -ExpandProperty Name)
}

# 入力を解釈できない場合は素通しする。誤検知で編集を止めない。
try {
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

if ((Get-PropertyNames $hookInput) -notcontains 'tool_input') { exit 0 }
$toolInput = $hookInput.tool_input
if ((Get-PropertyNames $toolInput) -notcontains 'file_path') { exit 0 }

$targetPath = [string]$toolInput.file_path
if ([string]::IsNullOrWhiteSpace($targetPath)) { exit 0 }

$normalizedPath = $targetPath.Replace('/', '\')
if ($normalizedPath -notlike '*\knowledge\20-bronze\*') { exit 0 }

$denyReason = @(
    'knowledge\20-bronze\ は原本層（Bronze）です。Edit / Write では書き換えられません。'
    '整理済みの事実は knowledge\10-silver\ に、生成物は knowledge\30-gold\ に書いてください。'
    ('拒否した対象: ' + $targetPath)
) -join ' '

$response = [pscustomobject]@{
    hookSpecificOutput = [pscustomobject]@{
        hookEventName            = 'PreToolUse'
        permissionDecision       = 'deny'
        permissionDecisionReason = $denyReason
    }
}

$response | ConvertTo-Json -Depth 5 -Compress | Write-Output
[Console]::Error.WriteLine($denyReason)
exit 0
