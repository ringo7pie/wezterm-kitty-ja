# クリップボードは変更せず、画像があれば一意な名前の PNG に保存する。
# -NoProfile -NonInteractive -STA -File で呼び出す。標準出力は JSON だけにする。
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

try {
    Add-Type -AssemblyName System.Windows.Forms

    function Save-KittyJaClipboardImage {
        param([System.Drawing.Image] $Image)

        $imageDirectory = Join-Path ([System.IO.Path]::GetTempPath()) 'wezterm-clipboard'
        $null = [System.IO.Directory]::CreateDirectory($imageDirectory)
        $imagePath = Join-Path $imageDirectory ('clipboard-' + [guid]::NewGuid().ToString('N') + '.png')
        $Image.Save($imagePath, [System.Drawing.Imaging.ImageFormat]::Png)
        return $imagePath
    }

    $clipboardImage = $null
    for ($attempt = 0; $attempt -lt 3; $attempt++) {
        try {
            $clipboardImage = [System.Windows.Forms.Clipboard]::GetImage()
            break
        } catch [System.Runtime.InteropServices.ExternalException] {
            if ($attempt -eq 2) { throw }
            Start-Sleep -Milliseconds 50
        }
    }

    if ($null -eq $clipboardImage) {
        @{ kind = 'text' } | ConvertTo-Json -Compress
        return
    }

    try {
        $imagePath = Save-KittyJaClipboardImage -Image $clipboardImage
        @{ kind = 'image'; path = $imagePath } | ConvertTo-Json -Compress
    } finally {
        $clipboardImage.Dispose()
    }
} catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}
