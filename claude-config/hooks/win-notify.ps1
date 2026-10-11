#Requires -Version 7
# Stop / Notification / PreToolUse(AskUserQuestion) 共通。WinNotify.exe で通知を出す。
# 使い方: win-notify.ps1 -Kind Stop|Notification|Question
#   Stop         : main エージェントの終了。直前の応答の冒頭を添える。
#   Notification : 許可確認などのユーザー確認待ち。通知の本文を添える。
#   Question     : AskUserQuestion の質問文を添える。
# 通知の失敗でエージェントを止めないよう、常に終了コード 0 で終わる。標準出力には何も書かない。
param(
    [Parameter(Mandatory)]
    [ValidateSet('Stop', 'Notification', 'Question')]
    [string]$Kind
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$notifyExe = 'C:\WinNotify\publish\WinNotify.exe'
$maxSummaryLength = 100
$duplicateWindowSeconds = 5
$questionStampPath = Join-Path ([System.IO.Path]::GetTempPath()) 'claude-win-notify-question.stamp'

function Get-OptionalProperty {
    param($Target, [string]$Name)
    if ($null -eq $Target) { return $null }
    $property = $Target.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function ConvertTo-Summary {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return '' }
    $collapsed = ($Text -replace '\s+', ' ').Trim()
    if ($collapsed.Length -le $maxSummaryLength) { return $collapsed }
    return $collapsed.Substring(0, $maxSummaryLength) + '…'
}

function Get-LastAssistantText {
    param([string]$TranscriptPath)
    if ([string]::IsNullOrWhiteSpace($TranscriptPath)) { return '' }
    if (-not (Test-Path -LiteralPath $TranscriptPath -PathType Leaf)) { return '' }

    $tailLines = @(Get-Content -LiteralPath $TranscriptPath -Tail 200 -Encoding UTF8)
    for ($index = $tailLines.Count - 1; $index -ge 0; $index--) {
        try {
            $entry = $tailLines[$index] | ConvertFrom-Json
        } catch {
            continue
        }
        if ((Get-OptionalProperty $entry 'type') -ne 'assistant') { continue }
        $content = Get-OptionalProperty (Get-OptionalProperty $entry 'message') 'content'
        if ($content -is [string]) {
            if (-not [string]::IsNullOrWhiteSpace($content)) { return $content }
            continue
        }
        foreach ($block in @($content)) {
            if ((Get-OptionalProperty $block 'type') -eq 'text') {
                $blockText = [string](Get-OptionalProperty $block 'text')
                if (-not [string]::IsNullOrWhiteSpace($blockText)) { return $blockText }
            }
        }
    }
    return ''
}

function Send-Notification {
    param([string]$Text)
    if (-not (Test-Path -LiteralPath $notifyExe -PathType Leaf)) { return }

    # Windows のコマンドライン引用規則に合わせる（" の前の \ を倍にし、末尾の \ も倍にする）。
    $escaped = $Text -replace '(\\*)"', '$1$1\"' -replace '(\\+)$', '$1$1'

    # UseShellExecute = $true にして、フックの標準入出力のハンドルを子プロセスへ継がせない。
    # 継がせると、通知ウィンドウが開いている間フックが終わらない恐れがある。
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new($notifyExe)
    $startInfo.UseShellExecute = $true
    $startInfo.WorkingDirectory = Split-Path -Parent $notifyExe
    $startInfo.Arguments = '"' + $escaped + '"'
    [void][System.Diagnostics.Process]::Start($startInfo)
}

try {
    try {
        $rawInput = [Console]::In.ReadToEnd()
    } catch {
        $rawInput = ''
    }

    $hookInput = $null
    if (-not [string]::IsNullOrWhiteSpace($rawInput)) {
        try {
            $hookInput = $rawInput | ConvertFrom-Json
        } catch {
            $hookInput = $null
        }
    }

    switch ($Kind) {
        'Stop' {
            $prefix = 'mainエージェント終了'
            $detail = ConvertTo-Summary ([string](Get-OptionalProperty $hookInput 'last_assistant_message'))
            if ($detail -eq '') {
                $transcriptPath = [string](Get-OptionalProperty $hookInput 'transcript_path')
                $detail = ConvertTo-Summary (Get-LastAssistantText $transcriptPath)
            }
        }
        'Notification' {
            $prefix = 'ユーザー確認待ち'
            # AskUserQuestion は直前の Question 通知で知らせ済みなので、続けて出る同種の通知は省く。
            if (Test-Path -LiteralPath $questionStampPath -PathType Leaf) {
                $stampAge = (Get-Date) - (Get-Item -LiteralPath $questionStampPath).LastWriteTime
                if ($stampAge.TotalSeconds -lt $duplicateWindowSeconds) { exit 0 }
            }
            $detail = ConvertTo-Summary ([string](Get-OptionalProperty $hookInput 'message'))
        }
        'Question' {
            $prefix = 'ユーザー確認待ち'
            $toolInput = Get-OptionalProperty $hookInput 'tool_input'
            $questionTexts = foreach ($question in @(Get-OptionalProperty $toolInput 'questions')) {
                $questionText = [string](Get-OptionalProperty $question 'question')
                if (-not [string]::IsNullOrWhiteSpace($questionText)) { $questionText }
            }
            $detail = ConvertTo-Summary (@($questionTexts) -join ' / ')
            Set-Content -LiteralPath $questionStampPath -Value (Get-Date -Format 'o') -Encoding UTF8
        }
    }

    $notificationText = if ($detail -eq '') { $prefix } else { "$prefix $detail" }
    Send-Notification $notificationText
} catch {
    # 通知の失敗は握りつぶす。エージェントの進行を妨げない。
}

exit 0
