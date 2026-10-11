---
name: update-facts
description: 引数で受けた事実を knowledge/10-silver/ の適切なファイルに追記する。矛盾する既存記述があれば削除案を提示してから書き換える。
disable-model-invocation: true
argument-hint: <追記する事実>
allowed-tools: Read, Glob, Grep, Edit, Write
---

# 事実の追記

追記する事実: $ARGUMENTS

## 手順

### 1. 前提の確認

カレントディレクトリに `knowledge/10-silver/` があるか確認する。
無ければ「このリポジトリにはナレッジベースがありません。`/init-knowledge` で作成してください」
と伝えて終了する。

### 2. 追記先を決める

| 事実の性質 | 追記先 |
|---|---|
| その作業単位が終わっても真であり続ける | `knowledge/10-silver/areas/` |
| 進行中の作業単位にだけ関係する | `knowledge/10-silver/work/<id>.md` |
| 外部資料の要約 | `knowledge/10-silver/resources/` |

判断できない場合はユーザーに聞く。推測で決めない。

### 3. 矛盾の検査（追記前に必ず実行する）

```powershell
# Windows / PowerShell 7
Select-String -Path 'knowledge\10-silver\*\*.md' -Pattern '<事実のキーワード>'
```

```bash
# Ubuntu / bash
grep -rn '<事実のキーワード>' knowledge/10-silver/
```

ヒットした行のうち、今回の事実と食い違うものを列挙する。
食い違いがあれば **削除案をユーザーに提示し、承認を得てから** 書き換える。
同じ事実が 2 か所に残る状態にしてはならない。食い違ったまま放置すると、
Claude はどちらかを恣意的に選ぶ。

### 4. 追記する

- 断定文で書く。「〜かもしれない」「〜のようだ」は使わない。
- コードから導出できる情報（ディレクトリ構成、依存一覧）は書かない。
- 1 ファイル = 1 トピックを保つ。
- 関連ファイルはリンクではなく指示形で書く（Claude はリンクを辿らない）。
  例: 「hooks を書くときは `knowledge/10-silver/resources/claude-code-spec.md` を Read する」

### 5. 行数を確認する

`areas/` の 1 ファイルが 50 行を超えたら、`resources/` への分割案を提示する。
自動では分割しない。

## 禁止事項

- `knowledge/20-bronze/` には決して書かない。原本層であり、PreToolUse hook が拒否する。
- `knowledge/30-gold/` にも書かない。生成物の出力先であり、事実の置き場ではない。
