# 履歴 (PSReadLine) のコマンドを選んで消す。integration.ps1 が「& 'history.ps1'」で実行する (ドットソースしない)。
# 下の StrictMode と $ErrorActionPreference をこのスクリプトのスコープに閉じ込め、対話セッションの設定を変えないため。
#
# 消す先は 2 つ: 履歴ファイル (HistorySavePath) と、このシェルのメモリ内の履歴 (ListView の予測が読む)。
# 消した内容をどこにも残さないため、バックアップは作らない (パスワードなどを打ち込んだコマンドを消す使い方を想定している)。
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# 履歴ファイルの書式 (PSReadLine 2.4.5 の実際のファイルで確認):
#   1 コマンドの終わりは CRLF。コマンドの中の改行は、LF の前に「`」を足して書く。
#   行末が「`」の行は、次の行へ続く。読むときは、続く行の「`」を 1 個外して LF でつなぐ。
# 消さないコマンドは、1 バイトも変えずにそのまま残したいので、行の区切りを保ったまま分けて扱う。
function global:Remove-KittyJaHistoryText {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Text,

        [Parameter(Mandatory)]
        [string[]] $CommandLine
    )

    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    $targets = [System.Collections.Generic.HashSet[string]]::new([string[]] $CommandLine, [System.StringComparer]::Ordinal)
    $keptText = [System.Text.StringBuilder]::new()
    $pendingRawText = [System.Text.StringBuilder]::new()
    $pendingLines = [System.Collections.Generic.List[string]]::new()
    $removedCount = 0

    foreach ($lineMatch in [regex]::Matches($Text, "[^\n]*\n|[^\n]+")) {
        $rawLine = $lineMatch.Value
        $content = $rawLine
        if ($content.EndsWith("`n")) { $content = $content.Substring(0, $content.Length - 1) }
        if ($content.EndsWith("`r")) { $content = $content.Substring(0, $content.Length - 1) }
        $null = $pendingRawText.Append($rawLine)

        if ($content.EndsWith('`')) {
            # 続きの行がある。行末の「`」は、コマンドの文字ではなく継続の印
            $pendingLines.Add($content.Substring(0, $content.Length - 1))
            continue
        }

        $pendingLines.Add($content)
        if ($targets.Contains($pendingLines -join "`n")) {
            $removedCount++
        } else {
            $null = $keptText.Append($pendingRawText.ToString())
        }
        $null = $pendingRawText.Clear()
        $pendingLines.Clear()
    }
    # ファイルの終わりが「`」の行 (続きが無い途中のコマンド) は、触らずに残す
    $null = $keptText.Append($pendingRawText.ToString())

    [pscustomobject]@{
        Text         = $keptText.ToString()
        RemovedCount = $removedCount
    }
}

function global:Remove-KittyJaHistory {
    <#
    .SYNOPSIS
    履歴 (PSReadLine) のコマンドを選んで消す。

    .DESCRIPTION
    引数なしで実行すると、履歴の一覧を Out-GridView で出す。消すコマンドを選んで OK を押すと、
    履歴ファイルと、このシェルのメモリ内の履歴の両方から消す (同じコマンドが履歴ファイルに何度もあれば、全部消す)。
    -CommandLine を渡すと、一覧を出さずに、そのコマンドを消す。

    このシェルのメモリだけが対象なので、ほかのペインで動いている pwsh は、開き直すまで消したコマンドを予測に出す。
    履歴ファイルを書き換える間に、ほかの pwsh が履歴を追記すると、その追記は失われうる (書き換え前に、ファイルの大きさが
    変わっていないことだけ確かめる)。

    .PARAMETER CommandLine
    消すコマンドの全文 (複数行のコマンドは、行を LF でつないだもの)。

    .OUTPUTS
    選んだ数、履歴ファイルとメモリから消した数、メモリの履歴を作り直せたかどうか。
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [string[]] $CommandLine
    )

    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    if (-not ('Microsoft.PowerShell.PSConsoleReadLine' -as [type])) {
        throw 'PSReadLine が読み込まれていないので、履歴を扱えません。'
    }
    $readLineType = [Microsoft.PowerShell.PSConsoleReadLine]
    $historyPath = (Get-PSReadLineOption).HistorySavePath
    $currentItems = @($readLineType::GetHistoryItems())

    # --- 消すコマンドを決める。引数が無ければ、一覧から選ぶ
    if (-not $PSBoundParameters.ContainsKey('CommandLine')) {
        if (-not (Get-Command -Name Out-GridView -ErrorAction Ignore)) {
            throw 'Out-GridView が使えません。消すコマンドを -CommandLine で渡してください。'
        }
        $commandByNumber = @{}
        $rows = [System.Collections.Generic.List[object]]::new()
        $seenCommands = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
        # 新しい順。同じコマンドは 1 行にまとめる (メモリ内の履歴は、PSReadLine の設定で重複を除くことがある)
        for ($index = $currentItems.Count - 1; $index -ge 0; $index--) {
            $commandText = $currentItems[$index].CommandLine
            if (-not $seenCommands.Add($commandText)) { continue }
            $number = $rows.Count + 1
            $commandByNumber[$number] = $commandText
            $rows.Add([pscustomobject]@{
                    '番号'   = $number
                    'コマンド' = $commandText.Replace("`n", ' ↵ ')
                })
        }
        $selectedRows = @($rows | Out-GridView -Title '履歴を選んで削除 (Ctrl / Shift で複数選択し、OK を押すと履歴から消します)' -OutputMode Multiple)
        $CommandLine = @($selectedRows | ForEach-Object { $commandByNumber[[int] $_.'番号'] })
    }

    $targets = [System.Collections.Generic.HashSet[string]]::new([string[]] $CommandLine, [System.StringComparer]::Ordinal)
    if ($targets.Count -eq 0) {
        return [pscustomobject]@{ SelectedCount = 0; RemovedFromFile = 0; RemovedFromMemory = 0; MemoryRebuilt = $false }
    }

    # --- 履歴ファイルから消す。同じ場所に一時ファイルを作って、置き換える (途中で失敗しても、元のファイルを壊さない)
    $removedFromFile = 0
    if (Test-Path -LiteralPath $historyPath -PathType Leaf) {
        $originalBytes = [System.IO.File]::ReadAllBytes($historyPath)
        $hasByteOrderMark = ($originalBytes.Length -ge 3) -and ($originalBytes[0] -eq 0xEF) -and ($originalBytes[1] -eq 0xBB) -and ($originalBytes[2] -eq 0xBF)
        $skippedByteCount = 0
        if ($hasByteOrderMark) { $skippedByteCount = 3 }
        # 不正なバイトがあれば例外にする。置き換えの文字に変えたまま書き戻すと、履歴を壊すため
        $strictDecoder = [System.Text.UTF8Encoding]::new($false, $true)
        $originalText = $strictDecoder.GetString($originalBytes, $skippedByteCount, $originalBytes.Length - $skippedByteCount)

        $rewritten = Remove-KittyJaHistoryText -Text $originalText -CommandLine $CommandLine
        if ($rewritten.RemovedCount -gt 0) {
            $temporaryPath = $historyPath + '.kitty-ja-tmp'
            [System.IO.File]::WriteAllText($temporaryPath, $rewritten.Text, [System.Text.UTF8Encoding]::new($hasByteOrderMark))
            try {
                if ([System.IO.FileInfo]::new($historyPath).Length -ne $originalBytes.Length) {
                    throw '履歴ファイルが、読んだあとに書き換えられました (ほかの pwsh の追記です)。もう一度実行してください。'
                }
                # バックアップのファイル名は渡さない (消した内容を残さないため)。$null は PowerShell が空文字列にしてしまうので NullString を使う
                [System.IO.File]::Replace($temporaryPath, $historyPath, [System.Management.Automation.Language.NullString]::Value)
            } catch {
                Remove-Item -LiteralPath $temporaryPath -ErrorAction Ignore
                throw
            }
            $removedFromFile = $rewritten.RemovedCount
        }
    }

    # --- このシェルのメモリ内の履歴から消す。PSReadLine には、1 件だけ消す API が無い。
    # 全部消して、残すものを足し直す。足し直した項目は「未保存」の印が付き、次のコマンドのときに、履歴ファイルへ全部書かれてしまう
    # (SaveIncrementally のとき。実測した)。それを避けるため、足し直す間は保存を止め、足し直したあとに印を元の値へ戻す
    $savedFlagByCommand = @{}
    $remainingCommands = [System.Collections.Generic.List[string]]::new()
    $savedField = $null
    if ($currentItems.Count -gt 0) {
        $savedField = $currentItems[0].GetType().GetField('_saved', [System.Reflection.BindingFlags]'Instance,NonPublic')
    }
    $memoryRebuilt = $false
    $removedFromMemory = 0
    if ($null -ne $savedField) {
        foreach ($item in $currentItems) {
            if ($targets.Contains($item.CommandLine)) { continue }
            $remainingCommands.Add($item.CommandLine)
            $savedFlagByCommand[$item.CommandLine] = [bool] $savedField.GetValue($item)
        }
        $originalSaveStyle = (Get-PSReadLineOption).HistorySaveStyle
        try {
            Set-PSReadLineOption -HistorySaveStyle SaveNothing
            $readLineType::ClearHistory($null, $null)
            foreach ($commandText in $remainingCommands) {
                $readLineType::AddToHistory($commandText)
            }
        } finally {
            Set-PSReadLineOption -HistorySaveStyle $originalSaveStyle
        }
        foreach ($item in $readLineType::GetHistoryItems()) {
            $savedFlag = $true
            if ($savedFlagByCommand.ContainsKey($item.CommandLine)) { $savedFlag = $savedFlagByCommand[$item.CommandLine] }
            $savedField.SetValue($item, $savedFlag)
        }
        $memoryRebuilt = $true
        $removedFromMemory = $currentItems.Count - $remainingCommands.Count
    } elseif ($currentItems.Count -gt 0) {
        Write-Warning 'このシェルのメモリ内の履歴は、作り直せませんでした (PSReadLine の内部が、確かめた版 2.4.5 と違います)。シェルを開き直すまで、予測に残ります。'
    }

    [pscustomobject]@{
        SelectedCount     = $targets.Count
        RemovedFromFile   = $removedFromFile
        RemovedFromMemory = $removedFromMemory
        MemoryRebuilt     = $memoryRebuilt
    }
}
