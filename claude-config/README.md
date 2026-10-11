# claude-config

この PC の Claude Code の自作環境 (hook・スクリプト・スキル・エージェント・規則・グローバルの指示) を、
他の PC で再現するためのもの。WezTerm 設定の配布物 (zip) には入らない。

## 入っているもの

| ここ | 配置先 (`<ホーム>\.claude\`) | 内容 |
|---|---|---|
| `CLAUDE.global.md` | `CLAUDE.md` | グローバルの行動規則 |
| `hooks\` | `hooks\` | 書き込み前の拒否 (原本層・`zzz-Temp`)、編集後の構文チェック、通知 |
| `scripts\` | `scripts\` | ナレッジベースの骨格を作る・検証するスクリプト |
| `skills\archive-work` `init-knowledge` `update-facts` | 同じ | 自作のスキル |
| `agents\` `rules\` `templates\` | 同じ | サブエージェントの定義、言語ごとの規則、設計メモ |
| `settings.template.json` | `settings.json` (無いときだけ) | hook の登録・シェル・autoMode の雛形 |
| `Sync-ClaudeConfig.ps1` | (配置しない) | 配置・取り込み・差分表示 |

入っていないもの: `.credentials.json`、メモリとセッション (`projects\` `sessions\`)、プラグイン (`plugins\`)、
自作でないスキル (`skills\synced`)、`*.bak`。
個人の設定 (テーマ、モデル、`chatgpt-project-bridge` の hook、autoMode の環境記述の大半) は雛形に含めていない。

## 他の PC で再現する

前提: PowerShell 7、git、Claude Code。

1. リポジトリを clone する (所有者のチェックで拒否されたときは、README の「開発」を見る)。
2. 何が起きるかを確かめる。`-WhatIf` は何も書かない。

   ```powershell
   .\claude-config\Sync-ClaudeConfig.ps1 -Mode Install -WhatIf
   ```

3. 配置する。内容が違う既存ファイルは、名前に `.bak-<日時>` を付けて残してから置き換える。

   ```powershell
   .\claude-config\Sync-ClaudeConfig.ps1 -Mode Install
   ```

4. `settings.json` を確認する。無ければ雛形から作られる。有れば上書きせず、未登録の hook を表示する。
   表示されたら `settings.template.json` を見て手で追記する。
5. Claude Code を起動し直して、`/hooks` で hook が登録されていることを確認する。

- 通知 (`win-notify.ps1`) は `C:\WinNotify\publish\WinNotify.exe` がある PC でだけ出る。無ければ何もしない。
- 編集後の構文チェック (`post-edit-check.ps1`) の Python 判定は、`python` が PATH にあるときだけ働く。
- 配置先のパスは、ファイルの中の `C:\Users\mt\.claude` を配置先の `<ホーム>\.claude` に置き換えて合わせる。

## この PC の `~\.claude` を直したとき

リポジトリはコピーなので、直しただけでは反映されない。次の手順で取り込む。

```powershell
.\claude-config\Sync-ClaudeConfig.ps1                 # 差分を見る (differs / home-only)
.\claude-config\Sync-ClaudeConfig.ps1 -Mode Export    # claude-config\ へ取り込む
```

取り込んだら、git でコミットする。`C:\Users\mt\.claude` はリポジトリ側の基準のパスで、取り込むときにこの形へ戻る。

## 状態の見かた

| State | 意味 |
|---|---|
| `same` | 内容が同じ (改行の違いは無視する) |
| `differs` | 両方にあるが内容が違う。Install は配置先を退避して置き換え、Export はリポジトリ側を置き換える |
| `repo-only` | リポジトリにだけある。Install で配置する |
| `home-only` | `<ホーム>\.claude` にだけある。Export で取り込む |

自作の skills を足したときは、`Sync-ClaudeConfig.ps1` の `$managedSkillNames` に名前を足す。
