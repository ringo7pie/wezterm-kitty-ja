# セキュリティ

## 脆弱性の報告

セキュリティ上の問題を見つけたときは、公開の Issue に書かず、GitHub の
**Security タブ → 「Report a vulnerability」** (Private vulnerability reporting) から報告してください。

報告には、次の内容を書いてもらえると調べやすくなります。

- 影響 (何ができてしまうか)
- 再現の手順 (WezTerm と PowerShell 7 の版、設定の変更点)
- 想定している攻撃の前提 (例: ssh 先のホストが悪意を持つ、悪意のあるファイルを表示する)

## 対象

このプロジェクトが守ろうとしているのは、端末に表示された文字列や、表示したファイルの中身が、
設定を介して意図しないファイルを開かせたり、プログラムを実行させたりすることです。
考え方と、制限ごとの実装は [docs/SECURITY-MODEL.md](docs/SECURITY-MODEL.md) にあります。

次は対象外です。

- WezTerm 本体、PowerShell、kitty、Notepad++ などの脆弱性 (それぞれのプロジェクトへ報告してください)
- 利用者が自分で `settings.lua` や `colors.txt` を書き換えて生じる問題

## 対応する版

最新のリリースだけを対象にします。
