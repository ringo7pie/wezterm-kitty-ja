---
name: archive-work
description: 引数の作業単位を knowledge/10-silver/work/ から archive/ へ移し、index.md から該当行を削除する。
disable-model-invocation: true
argument-hint: <作業単位の ID>
allowed-tools: Read, Glob, Grep, Edit, Write, Bash
---

# 作業単位の終了

終了する作業単位の ID: $ARGUMENTS

## 手順

### 1. 対象の確認

`knowledge/10-silver/work/<ID>.md` が存在するか確認する。
無ければ `knowledge/10-silver/work/index.md` を読み、近い ID を候補として提示して終了する。

### 2. 昇格の判定（移動前に必ず行う）

`work/<ID>.md` の記述のうち、**この作業単位が終わっても真であり続ける事実** を探す。
見つかったら、その行を `knowledge/10-silver/areas/` の適切なファイルへ移すことを提案する。
ユーザーの承認を得てから移し、`work/<ID>.md` 側からは削除する。

この手順を飛ばすと、確定した事実が archive に埋もれてロードされなくなる。

### 3. 移動する

```powershell
# Windows / PowerShell 7
Move-Item -LiteralPath 'knowledge\10-silver\work\<ID>.md' `
          -Destination 'knowledge\10-silver\archive\<ID>.md'
```

```bash
# Ubuntu / bash
mv 'knowledge/10-silver/work/<ID>.md' 'knowledge/10-silver/archive/<ID>.md'
```

### 4. index.md から削除する

`knowledge/10-silver/work/index.md` から `<ID>` の行を削除する。
index.md は常時ロードされるため、消し忘れると終了した作業単位を毎セッション読み続ける。

### 5. 報告

移動先のパス、`areas/` へ昇格した事実、`index.md` の残り件数を報告する。
