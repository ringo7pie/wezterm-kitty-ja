---
description: PowerShell スクリプトの規則
paths:
  - "**/*.ps1"
  - "**/*.psm1"
---

- 先頭で `Set-StrictMode -Version Latest` と `$ErrorActionPreference = 'Stop'` を宣言する
- 関数名は承認済み動詞（`Get-Verb` の一覧）のみを使う
- 変数名は 1 文字にしない
- 外部コマンドを呼んだ直後に `$LASTEXITCODE` を検査する。`$?` では外部コマンドの失敗を捕捉できない
- パス結合は文字列連結ではなく `Join-Path` を使う
- StrictMode 下では存在しないプロパティへのアクセスが例外になる。`$obj.PSObject.Properties` で確認してから触る
- 出力は `Write-Output` / `Write-Error` / `Write-Verbose` を使い分ける。`Write-Host` はパイプに乗らない
- `SupportsShouldProcess` を持つ関数をモジュールに置いたら、呼び出し側は `-WhatIf:$WhatIfPreference` を
  明示的に渡す。設定変数はモジュールのスコープに流れ込まないため、省くと `-WhatIf` が黙って無視される
- 改行コードに依存する検証を書かない。`Add-Content` は CRLF、`Set-Content` に単一文字列を渡すと LF になる。
  行の一致は正規表現の `$` ではなく `Get-Content` の配列と `-contains` で見る
