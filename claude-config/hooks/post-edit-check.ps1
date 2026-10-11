#Requires -Version 7
# PostToolUse (matcher: Edit|Write)
# 編集直後に構文チェックを行う。.ps1 / .psm1 は PowerShell パーサ、.py は py_compile。
# それ以外の拡張子では何もしない。

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-PropertyNames {
    param($Target)
    if ($null -eq $Target) { return @() }
    return @($Target.PSObject.Properties | Select-Object -ExpandProperty Name)
}

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
if (-not (Test-Path -LiteralPath $targetPath -PathType Leaf)) { exit 0 }

$extension = [System.IO.Path]::GetExtension($targetPath).ToLowerInvariant()

if ($extension -eq '.ps1' -or $extension -eq '.psm1') {
    $tokens = $null
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile(
        $targetPath, [ref]$tokens, [ref]$parseErrors)

    if ($null -ne $parseErrors -and $parseErrors.Count -gt 0) {
        $lines = foreach ($parseError in $parseErrors) {
            '  行 {0}: {1}' -f $parseError.Extent.StartLineNumber, $parseError.Message
        }
        [Console]::Error.WriteLine(('PowerShell 構文エラー: ' + $targetPath))
        foreach ($line in $lines) { [Console]::Error.WriteLine($line) }
        exit 2
    }
    exit 0
}

if ($extension -eq '.py') {
    $pythonCommand = Get-Command -Name 'python' -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($null -eq $pythonCommand) { exit 0 }

    $compileOutput = & $pythonCommand.Source -m py_compile $targetPath 2>&1
    if ($LASTEXITCODE -ne 0) {
        [Console]::Error.WriteLine(('Python 構文エラー: ' + $targetPath))
        [Console]::Error.WriteLine(($compileOutput | Out-String))
        exit 2
    }
    exit 0
}

exit 0
