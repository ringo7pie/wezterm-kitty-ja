# 行動規則

## シェル
- シェルコマンドは PowerShell 7 構文で書く。bash 構文（`&&`、`$(...)`、`export`）を使わない
- 条件実行は `if ($LASTEXITCODE -eq 0) { ... }` を使う
- `$PROFILE` は読まれない前提で、エイリアスに依存しない（完全名コマンドレットを使う）
- 全文検索は `Select-String` を使う

## 出力
- 出力は日本語。専門用語は日本語（English）併記
- 事実と意見を分ける。推測で実装仕様を語らない。分からないことは分からないと書く
- UE / 低レイヤ / システム系は実装・仕様・制約を優先する

## コード
- 変数名は原則 1 文字にしない

## ナレッジベース（`knowledge/` があるプロジェクトでのみ適用）
- 不明点は `knowledge/10-silver/` を全文検索してから質問する
- `knowledge/20-bronze/` は原本層。読まない・書かない
- `knowledge/30-gold/` は出力先としてのみ使う
- 事実の追記は `/update-facts`、作業単位の終了は `/archive-work` を使う。手で書き換えない
- 新しいリポジトリで骨格を作るときは `/init-knowledge` を使う
- 同じ訂正を 2 回受けたら、成果物ではなくプロジェクトの `CLAUDE.md` か
  `knowledge/10-silver/` の修正を提案する

## 作業フォルダ（`zzz-Temp`）
- `zzz-Temp` という名前のフォルダは、ユーザーの作業フォルダ。Claude Code は読み取りだけ行う
- 書き込み・作成・削除・移動・コピー先への指定をしない。Claude 自身の一時ファイルは scratchpad に置く
- `zzz-Temp` の中身を `git add` / `git commit` / `git push` しない。「全てコミット」と言われても含めない
- `git add -A` / `git add .` / `git commit -a` の前に `git status` を見て、`zzz-Temp/` が混ざるときはパスを指定して add する
- 強制は hook `~\.claude\hooks\protect-workspace.ps1` が行う。文字列照合なので取りこぼしはあり得る。この規則自体を守る

## 進め方
- 曖昧なタスクは実装前に plan を提示する

## エージェントのモデル割り当て
- オーケストレーター（メインセッション）は Opus 5.5 / effort medium。settings.json で固定してある
- サブエージェントは作業内容で次の subagent_type を選ぶ。model と effort は定義側で固定してあるので `model` は渡さない
  - アルゴリズムの設計・調査: `algorithm-designer`（Opus 5.5 / max）
  - 難しいアルゴリズムの設計・調査: `algorithm-designer-hard`（Fable 5.1 / max）
  - ファイル・ソースコードの調査・実装: `code-worker`（Sonnet 5 / xhigh）
  - 難しいファイル・ソースコードの調査・実装: `code-worker-hard`（Opus 5.5 / xhigh）
- 組み込みの Explore / Plan を使うときは、上の割り当てに合う `model` を渡す
