<#
.SYNOPSIS
install.ps1 で入れた WezTerm の kitty-ja 互換設定を外す。

.DESCRIPTION
設定本体 (<ホーム>\.config\wezterm\kitty_ja) と入口 (<ホーム>\.wezterm.lua) を外す。

  - リンクなら、リンクだけを消す (リンク先には触らない)
  - 実体なら、消さずに名前へ .removed-<日時> を付けて残す
  - .wezterm.lua がこの設定のものでなければ、触らない
  - データ (<ホーム>\.config\wezterm-kitty-ja) は残す

Windows PowerShell 5.1 と PowerShell 7 のどちらでも実行できる。

.PARAMETER HomePath
対象のホームフォルダ。既定は現在のユーザーのホーム。

.EXAMPLE
.\uninstall.ps1 -WhatIf
何をするかを表示するだけで、何も変更しない。
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string] $HomePath = [Environment]::GetFolderPath('UserProfile')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$LinkTypes = @('Junction', 'SymbolicLink')

# リンクならリンクだけを消し、実体なら名前を変えて残す
function Remove-InstalledItem {
    param(
        [string] $Path,
        [string] $Suffix
    )

    $item = Get-Item -LiteralPath $Path -Force
    if ($LinkTypes -contains $item.LinkType) {
        # リンク先は、消す前に取得しておく。取得できないときは表示しない
        $linkTarget = @($item.Target | Where-Object { $_ }) -join ', '
        if ($PSCmdlet.ShouldProcess($Path, 'リンクを削除 (リンク先は残す)')) {
            if ($item.PSIsContainer) {
                [System.IO.Directory]::Delete($Path)
            } else {
                [System.IO.File]::Delete($Path)
            }
            if ($linkTarget) {
                Write-Output "リンクを削除しました: $Path (リンク先: $linkTarget)"
            } else {
                Write-Output "リンクを削除しました: $Path"
            }
        }
        return
    }
    $removedName = $item.Name + $Suffix
    Rename-Item -LiteralPath $Path -NewName $removedName
    if (-not $WhatIfPreference) {
        Write-Output "名前を変えて残しました: $(Join-Path (Split-Path -Parent $Path) $removedName)"
    }
}

if (-not (Test-Path -LiteralPath $HomePath -PathType Container)) {
    throw "ホームフォルダがありません: $HomePath"
}
# 絶対パスにそろえる。相対パスのままだと、PowerShell のコマンドと .NET の呼び出しが別の場所を指しうる
$HomePath = (Resolve-Path -LiteralPath $HomePath).ProviderPath

$configDirectory = Join-Path (Join-Path $HomePath '.config') 'wezterm'
$targetModuleDirectory = Join-Path $configDirectory 'kitty_ja'
$targetEntryFile = Join-Path $HomePath '.wezterm.lua'
$dataDirectory = Join-Path (Join-Path $HomePath '.config') 'wezterm-kitty-ja'
$removedSuffix = '.removed-' + (Get-Date -Format 'yyyyMMdd-HHmmss')

if (Test-Path -LiteralPath $targetModuleDirectory) {
    Remove-InstalledItem -Path $targetModuleDirectory -Suffix $removedSuffix
} else {
    Write-Output "設定本体はありません: $targetModuleDirectory"
}

if (Test-Path -LiteralPath $targetEntryFile -PathType Leaf) {
    # この設定の入口かどうかは、kitty_ja を読み込んでいるかで見分ける
    $entryLines = @(Get-Content -LiteralPath $targetEntryFile -Encoding UTF8)
    $isOurEntry = @($entryLines | Where-Object { $_ -like "*require*'kitty_ja'*" }).Count -gt 0
    if ($isOurEntry) {
        Remove-InstalledItem -Path $targetEntryFile -Suffix $removedSuffix
    } else {
        Write-Output "この設定のものではないので、触りません: $targetEntryFile"
    }
} else {
    Write-Output "入口はありません: $targetEntryFile"
}

if ($WhatIfPreference) {
    Write-Output '-WhatIf のため、何も変更していません。'
    return
}

Write-Output ''
Write-Output 'アンインストールしました。WezTerm を起動し直すと反映されます。'
if (Test-Path -LiteralPath $dataDirectory) {
    Write-Output "データは残しています。不要なら手で削除してください: $dataDirectory"
}
$backups = @(Get-ChildItem -LiteralPath $HomePath -Filter '.wezterm.lua.bak-*' -Force -ErrorAction SilentlyContinue)
if ($backups.Count -gt 0) {
    Write-Output 'インストール前の .wezterm.lua が残っています。戻す場合は、名前を .wezterm.lua に変えてください。'
    foreach ($backup in $backups) { Write-Output "  $($backup.FullName)" }
}
