#requires -Version 7.0
<#
.SYNOPSIS
配布用の zip を作る。

.DESCRIPTION
配布するファイルだけを一覧から選んで dist\ に集め、zip にまとめる。
git の履歴や、一覧に無いファイル (控え・作業用ファイル・個人のデータ) は入らない。

zip にする前に、次を確かめる。1 つでも当てはまれば中止する。

  - 想定外の種類のファイルが入っていない
  - このユーザーのホームのパス、このリポジトリのパス、メールアドレスが書かれていない
  - install.ps1 / uninstall.ps1 が BOM 付き (Windows PowerShell 5.1 で読める)
  - install.cmd / uninstall.cmd の改行が CRLF

.PARAMETER OutputDirectory
出力先。既定はリポジトリの dist フォルダ。

.OUTPUTS
ZipPath、Sha256、FileCount を持つオブジェクト。
#>
[CmdletBinding()]
param(
    [string] $OutputDirectory
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$PackageName = 'wezterm-kitty-ja'
$AllowedExtensions = @('.lua', '.ps1', '.cmd', '.txt', '.md')
$TopLevelFiles = @('.wezterm.lua', 'install.ps1', 'install.cmd', 'uninstall.ps1', 'uninstall.cmd', 'README.md')
$Directories = @('kitty_ja', 'defaults')
$BomScripts = @('install.ps1', 'uninstall.ps1')
$CrlfScripts = @('install.cmd', 'uninstall.cmd')

$repositoryRoot = Split-Path -Parent $PSScriptRoot
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $repositoryRoot 'dist' }

# ---------------------------------------------------------------- 版の名前

$version = Get-Date -Format 'yyyyMMdd'
$commitHash = git -C $repositoryRoot rev-parse --short HEAD
if ($LASTEXITCODE -eq 0 -and $commitHash) {
    $version = "$version-$commitHash"
    $pendingChanges = git -C $repositoryRoot status --porcelain
    if ($LASTEXITCODE -ne 0) { throw 'git status に失敗しました。' }
    if ($pendingChanges) {
        $version = "$version-dirty"
        Write-Warning 'コミットしていない変更があります。zip の名前に -dirty を付けます。'
    }
} else {
    Write-Warning 'git のコミットを取得できないので、日付だけを版の名前にします。'
}

# ---------------------------------------------------------------- 配布するファイルを集める

$relativePaths = [System.Collections.Generic.List[string]]::new()
foreach ($fileName in $TopLevelFiles) { $relativePaths.Add($fileName) }
foreach ($directoryName in $Directories) {
    $directoryPath = Join-Path $repositoryRoot $directoryName
    foreach ($file in (Get-ChildItem -LiteralPath $directoryPath -Recurse -File -Force)) {
        $relativePaths.Add([System.IO.Path]::GetRelativePath($repositoryRoot, $file.FullName))
    }
}

$unexpected = @($relativePaths | Where-Object { $AllowedExtensions -notcontains [System.IO.Path]::GetExtension($_).ToLowerInvariant() })
if ($unexpected.Count -gt 0) {
    throw "想定外の種類のファイルがあります: $($unexpected -join ', ')"
}

$stagingDirectory = Join-Path $OutputDirectory "$PackageName-$version"
$zipPath = "$stagingDirectory.zip"
if (Test-Path -LiteralPath $stagingDirectory) {
    Remove-Item -LiteralPath $stagingDirectory -Recurse -Force
}
foreach ($relativePath in $relativePaths) {
    $sourcePath = Join-Path $repositoryRoot $relativePath
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) { throw "配布するファイルがありません: $relativePath" }
    $destinationPath = Join-Path $stagingDirectory $relativePath
    $null = New-Item -ItemType Directory -Path (Split-Path -Parent $destinationPath) -Force
    Copy-Item -LiteralPath $sourcePath -Destination $destinationPath
}

# ---------------------------------------------------------------- 中身の確認

$findings = [System.Collections.Generic.List[string]]::new()

# 個人のパスとメールアドレス。ユーザー名だけでは短くて誤検出するので、パスの形で探す
$personalPatterns = @(
    [regex]::Escape([Environment]::GetFolderPath('UserProfile')),
    ('[\\/]Users[\\/]' + [regex]::Escape([Environment]::UserName) + '(?![\w.-])'),
    [regex]::Escape($repositoryRoot),
    '[\w.+-]+@[\w-]+\.[\w.-]+',
    # ドライブ文字で始まる絶対パス (作者の環境のフォルダ構成)。HKLM:\ のようなレジストリのパスと、
    # どの PC にもある C:\Windows と C:\Program Files、存在しないことを示す例の C:\no-such は除く
    '(?<![A-Za-z])[A-Za-z]:\\+(?!Windows\b|Program Files\b|\.\.\.|no-such)[\w.-]',
    # ネットワークのパス。説明用の例として書く \\server\share だけは除く
    '(?<![\\\w])\\\\(?!server\\share\b)[A-Za-z0-9][\w.-]*\\[\w$.-]+'
)
foreach ($stagedFile in (Get-ChildItem -LiteralPath $stagingDirectory -Recurse -File -Force)) {
    foreach ($match in (Select-String -LiteralPath $stagedFile.FullName -Pattern $personalPatterns -Encoding utf8)) {
        $findings.Add(('個人の情報らしき文字列: {0}:{1}: {2}' -f [System.IO.Path]::GetRelativePath($stagingDirectory, $stagedFile.FullName), $match.LineNumber, $match.Line.Trim()))
    }
}

foreach ($scriptName in $BomScripts) {
    $bytes = [System.IO.File]::ReadAllBytes((Join-Path $stagingDirectory $scriptName))
    if ($bytes.Length -lt 3 -or $bytes[0] -ne 0xEF -or $bytes[1] -ne 0xBB -or $bytes[2] -ne 0xBF) {
        $findings.Add("BOM がありません (Windows PowerShell 5.1 で文字化けする): $scriptName")
    }
}
foreach ($scriptName in $CrlfScripts) {
    $bytes = [System.IO.File]::ReadAllBytes((Join-Path $stagingDirectory $scriptName))
    for ($index = 0; $index -lt $bytes.Length; $index++) {
        if ($bytes[$index] -eq 10 -and ($index -eq 0 -or $bytes[$index - 1] -ne 13)) {
            $findings.Add("改行が CRLF ではありません: $scriptName")
            break
        }
    }
}

if ($findings.Count -gt 0) {
    foreach ($finding in $findings) { Write-Warning $finding }
    throw "配布物の確認で $($findings.Count) 件の問題が見つかりました。zip は作っていません。"
}

# ---------------------------------------------------------------- zip

Compress-Archive -LiteralPath $stagingDirectory -DestinationPath $zipPath -Force
$hash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash
Set-Content -LiteralPath "$zipPath.sha256" -Value "$hash  $(Split-Path -Leaf $zipPath)" -Encoding ascii

[pscustomobject]@{
    ZipPath   = $zipPath
    Sha256    = $hash
    FileCount = $relativePaths.Count
}
