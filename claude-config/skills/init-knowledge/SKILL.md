---
name: init-knowledge
description: カレントリポジトリにナレッジベースを適用する。骨格の作成はスクリプトに任せ、事実の聞き取りと重複の解消だけを行う。
disable-model-invocation: true
allowed-tools:
  - Read
  - Glob
  - Grep
  - Edit
  - Write
  - PowerShell(& "C:\Users\mt\.claude\scripts\New-KnowledgeBase.ps1"*)
  - PowerShell(& "C:\Users\mt\.claude\scripts\Add-KnowledgeBase.ps1"*)
  - PowerShell(git status*)
  - PowerShell(git diff*)
---

# ナレッジベースの適用

骨格・`CLAUDE.md` の追記・`.gitignore` は**スクリプトが決定的に行う**。
このスキルは、スクリプトにできない判断（事実の聞き取り、重複の解消）だけを担当する。
手でディレクトリを作らない。

## 1. 新規か既存かを判定する

カレントディレクトリに `CLAUDE.md` があるかを見る。

| 状態 | 使うスクリプト |
|---|---|
| `CLAUDE.md` が**無い** | `New-KnowledgeBase.ps1` |
| `CLAUDE.md` が**有る** | `Add-KnowledgeBase.ps1` |

判定を誤ってもスクリプト側が中止して正しい方を案内するので、迷ったら片方を実行する。

## 2. 既存リポジトリなら、先に作業ツリーを確認する

```powershell
git status --porcelain -- CLAUDE.md
```

未コミットの変更があれば、**先にコミットするか退避するようユーザーに求める**。
汚れたままだと、スクリプトの追記と既存の変更を `git diff` で切り分けられない。

## 3. スクリプトを実行する

まず `-WhatIf` で何が起きるかを見せ、ユーザーの承認を得てから本実行する。

```powershell
# 新規
& "C:\Users\mt\.claude\scripts\New-KnowledgeBase.ps1" -WhatIf
& "C:\Users\mt\.claude\scripts\New-KnowledgeBase.ps1"

# 既存
& "C:\Users\mt\.claude\scripts\Add-KnowledgeBase.ps1" -WhatIf
& "C:\Users\mt\.claude\scripts\Add-KnowledgeBase.ps1"
```

`areas/` の名前を変えたいときだけ `-AreaNames env, <もう 1 つ>` を付ける。
常時ロードされるため **2 つまで**。

## 4. 出力を確認する

既存リポジトリの場合、スクリプトの「既存を壊していないことの検証」で
**削除行が 0** であることを必ず確認する。0 でなければ次を提案する。

```powershell
git checkout -- CLAUDE.md
```

常時ロード合計が予算（250 行）を超えていたら、その場でユーザーに伝える。

## 5. CLAUDE.md を仕上げる

### 新規リポジトリ

スクリプトが作った `CLAUDE.md` は雛形で、HTML コメントが残っている。
リポジトリの中身を読んで概要・構成・ビルド手順の案を作り、
**ユーザーに見せて承認を得てから** 書く。`@import` の行は動かさない。

### 既存リポジトリ

既存の `CLAUDE.md` を読み、**同じ事実が `areas/` と両方に来ないように**仕分ける。
スクリプトが見出し一覧と移し先の目安を出しているので、それを起点に提案する。

| 既存 CLAUDE.md の記述 | 移す先 |
|---|---|
| ビルドコマンド、環境の前提、バージョン | `knowledge/10-silver/areas/env.md` |
| 継続的な方針、守るべき制約 | `knowledge/10-silver/areas/` |
| 進行中の案件、TODO | `knowledge/10-silver/work/index.md` |
| 言語が限定できるコーディング規則 | `.claude/rules/`（`paths:` 付き。常時ロードから外れる） |
| リポジトリの概要、構成 | `CLAUDE.md` に残す |

移したら**移し元から必ず消す**。両方に残すと、食い違ったとき Claude が恣意的に選ぶ。
移動は 1 か所ずつ提案し、承認を得てから行う。

## 6. 事実を聞き取る

`areas/` と `work/index.md` の中身は**推測で書かない**。次を質問して埋める。

1. このリポジトリで終わりなく続く責任領域は何か（2 つまで）
2. この環境で、知らないと無駄に失敗する制約は何か
3. 今進行中の作業単位は何か（1 件 1 行。無ければ空でよい）

答えを書き込むときは `/update-facts` と同じ規則に従う。断定文で書き、
コードから導出できる情報（ディレクトリ構成、依存一覧）は書かない。

## 7. 報告する

- 作成・変更したファイルの一覧
- 常時ロードされる合計行数と予算に対する比
- 既存リポジトリなら、`CLAUDE.md` から `knowledge/` へ移した項目
- 次に実行してもらう確認: **claude を再起動**してから `/context`、`/hooks`、`/skills`
