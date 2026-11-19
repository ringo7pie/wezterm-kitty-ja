# WezTerm の GUI を起動し直す (描画方式の切り替え。appearance.lua の toggle_render_mode から呼ぶ)。
# mux-server 構成専用。シェルは mux-server が持っているので、GUI を終わらせても残る。
# 新しい GUI の窓が出たら、古い窓と同じ位置・大きさ (ピクセル。最大化なら最大化) に合わせ、
# 古い GUI で開いていたタブを開き直してから、古い GUI を終わらせる。新しい窓が出なければ、古い GUI はそのまま残す。
# - connect で既存の窓に繋ぐときは、--config initial_cols / initial_rows と --position が効かない
#   (WezTerm 20240203-110809-5046fc22 で確認) ので、窓を出したあとに動かす
# - 新しい GUI は 1 枚目のタブを開くので、wezterm cli activate-tab で開き直す
# 動きは %TEMP%\kitty-ja-restart-gui.log に書く (毎回上書き)。
# -NoProfile -NonInteractive -WindowStyle Hidden -File で呼び出す。
param(
    [Parameter(Mandatory)] [string] $GuiPath,
    [Parameter(Mandatory)] [string] $Domain,
    [Parameter(Mandatory)] [int] $OldProcessId,
    # 以下は省略できる。CliPath が無い・ActiveTabIndex が負ならタブを開き直さない。
    # ActiveTabIndex は古い窓で開いていたタブが左から何枚目か (0 始まり)、TabCount はその窓のタブの数。
    # GUI の tab_id は mux-server の tab_id と違うので、mux-server の一覧から tab_id を引く
    [string] $CliPath = '',
    [int] $ActiveTabIndex = -1,
    [int] $TabCount = 0
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$logPath = Join-Path ([System.IO.Path]::GetTempPath()) 'kitty-ja-restart-gui.log'
$null = New-Item -ItemType File -Path $logPath -Force
function Write-RestartLog([string] $Message) {
    Add-Content -Path $logPath -Value ('{0:HH:mm:ss.fff} {1}' -f (Get-Date), $Message)
}

Add-Type -Namespace KittyJa -Name NativeWindow -MemberDefinition @'
[StructLayout(LayoutKind.Sequential)]
public struct Rect { public int Left; public int Top; public int Right; public int Bottom; }
[DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr window, out Rect rect);
[DllImport("user32.dll")] public static extern bool IsZoomed(IntPtr window);
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr window, int command);
[DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr window, int x, int y, int width, int height, bool repaint);
'@

function Format-Rect($Rect) {
    return '{0},{1},{2},{3}' -f $Rect.Left, $Rect.Top, $Rect.Right, $Rect.Bottom
}

function Get-WindowRect([IntPtr] $Window) {
    $rect = New-Object KittyJa.NativeWindow+Rect
    if ([KittyJa.NativeWindow]::GetWindowRect($Window, [ref] $rect)) {
        return $rect
    }
    return $null
}

# mux-server の tab_id を引く。タブの数が TabCount と同じ窓のうち最初の窓の、左から ActiveTabIndex 枚目。見つからなければ -1。
# GUI から起動されると WEZTERM_UNIX_SOCKET が古い GUI を指すので、消して mux-server へ繋ぐ
function Resolve-MuxTabId {
    if (-not $CliPath -or $ActiveTabIndex -lt 0) {
        return -1
    }
    Remove-Item Env:WEZTERM_UNIX_SOCKET -ErrorAction SilentlyContinue
    $json = & $CliPath cli --prefer-mux list --format json 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-RestartLog "list exit=$LASTEXITCODE"
        return -1
    }
    # 一覧はペインごとの行で、窓ごとにタブの並び順に出る
    $windows = [ordered]@{}
    # Windows PowerShell 5.1 の ConvertFrom-Json は行ごとに渡すと読めないので、1 つの文字列にする
    foreach ($entry in (($json -join "`n") | ConvertFrom-Json)) {
        $windowKey = [string] $entry.window_id
        if (-not $windows.Contains($windowKey)) {
            $windows[$windowKey] = [System.Collections.Generic.List[int]]::new()
        }
        if (-not $windows[$windowKey].Contains([int] $entry.tab_id)) {
            $windows[$windowKey].Add([int] $entry.tab_id)
        }
    }
    foreach ($windowKey in $windows.Keys) {
        $tabIds = $windows[$windowKey]
        if ($tabIds.Count -eq $TabCount -and $ActiveTabIndex -lt $tabIds.Count) {
            Write-RestartLog "mux window=$windowKey tabs=$($tabIds -join ',') index=$ActiveTabIndex"
            return $tabIds[$ActiveTabIndex]
        }
    }
    Write-RestartLog "no mux window with $TabCount tabs"
    return -1
}

function Invoke-ActivateTab([int] $TabId) {
    if ($TabId -lt 0) {
        return
    }
    $output = & $CliPath cli --prefer-mux activate-tab --tab-id $TabId 2>&1
    Write-RestartLog "activate-tab $TabId exit=$LASTEXITCODE $output"
}

try {
    Write-RestartLog "start old=$OldProcessId tab index=$ActiveTabIndex count=$TabCount"
    $muxTabId = Resolve-MuxTabId

    # 古い窓の位置・大きさ。窓が無ければ $null
    $oldRect = $null
    $maximized = $false
    $oldProcess = Get-Process -Id $OldProcessId -ErrorAction SilentlyContinue
    if ($oldProcess -and $oldProcess.MainWindowHandle -ne [IntPtr]::Zero) {
        $maximized = [KittyJa.NativeWindow]::IsZoomed($oldProcess.MainWindowHandle)
        $oldRect = Get-WindowRect $oldProcess.MainWindowHandle
    }
    Write-RestartLog ("old window maximized=$maximized rect=" + $(if ($oldRect) { Format-Rect $oldRect } else { 'なし' }))

    $newProcess = Start-Process -FilePath $GuiPath -ArgumentList 'connect', $Domain -PassThru
    $deadline = [DateTime]::UtcNow.AddSeconds(20)
    while ([DateTime]::UtcNow -lt $deadline) {
        Start-Sleep -Milliseconds 250
        $newProcess.Refresh()
        if ($newProcess.HasExited) {
            Write-RestartLog "new GUI exited code=$($newProcess.ExitCode)"
            exit 1
        }
        if ($newProcess.MainWindowHandle -ne [IntPtr]::Zero) {
            break
        }
    }
    $newWindow = $newProcess.MainWindowHandle
    if ($newWindow -eq [IntPtr]::Zero) {
        Write-RestartLog 'new window did not appear'
        exit 1
    }
    Write-RestartLog ("new window pid=$($newProcess.Id) rect=" + (Format-Rect (Get-WindowRect $newWindow)))

    Invoke-ActivateTab $muxTabId

    if ($maximized) {
        # SW_MAXIMIZE
        $null = [KittyJa.NativeWindow]::ShowWindow($newWindow, 3)
    } elseif ($oldRect) {
        # 窓が出た直後は WezTerm が位置を決め直すことがある (MoveWindow の後に位置だけ戻った) ので、
        # 2 秒続けて合うまで (最長 10 秒) 見張って合わせ直す
        $settleDeadline = [DateTime]::UtcNow.AddSeconds(10)
        $stableSince = $null
        while ([DateTime]::UtcNow -lt $settleDeadline) {
            $currentRect = Get-WindowRect $newWindow
            if (-not $currentRect) {
                break
            }
            if ((Format-Rect $currentRect) -ne (Format-Rect $oldRect)) {
                Write-RestartLog ('move from ' + (Format-Rect $currentRect))
                $null = [KittyJa.NativeWindow]::MoveWindow($newWindow, $oldRect.Left, $oldRect.Top, $oldRect.Right - $oldRect.Left, $oldRect.Bottom - $oldRect.Top, $true)
                $stableSince = $null
            } elseif (-not $stableSince) {
                $stableSince = [DateTime]::UtcNow
            } elseif (([DateTime]::UtcNow - $stableSince).TotalSeconds -ge 2) {
                break
            }
            Start-Sleep -Milliseconds 200
        }
    }

    # 接続の直後に GUI がタブを選び直すことがあるので、もう一度開く
    Invoke-ActivateTab $muxTabId
    Write-RestartLog ('final rect=' + (Format-Rect (Get-WindowRect $newWindow)))

    # 番号が別のプロセスに使い回されていたら終わらせない
    $oldProcess = Get-Process -Id $OldProcessId -ErrorAction SilentlyContinue
    if ($oldProcess -and $oldProcess.ProcessName -eq 'wezterm-gui') {
        Write-RestartLog 'stop old GUI'
        Stop-Process -Id $OldProcessId -Force
    }
} catch {
    Write-RestartLog "error: $_"
    exit 1
}
