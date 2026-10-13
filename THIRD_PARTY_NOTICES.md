# サードパーティの表示 (Third-Party Notices)

このリポジトリと配布 zip には、下のソフトウェアとフォントのコード・ファイルを**含めていません**。
実行時に、利用者の PC にインストールされているものを呼び出すか、名前で参照するだけです。

| 名前 | このプロジェクトでの用途 | ライセンス | 扱い |
|---|---|---|---|
| [WezTerm](https://wezterm.org/) | 設定の読み込み先 (実行環境) | MIT License, Copyright (c) 2018-Present Wez Furlong | 同梱しない。利用者が別にインストールする |
| [PowerShell 7](https://github.com/PowerShell/PowerShell) | 既定のシェル。シェル連携スクリプト (`integration.ps1`) の実行 | MIT License (Microsoft Corporation) | 同梱しない。利用者が別にインストールする |
| [kitty](https://sw.kovidgoyal.net/kitty/) | 動作とキー割り当ての互換を取る対象 | GPL-3.0 | 同梱しない。kitty のソースコードは含まない。動作を参照して Lua で書き直したもの |
| [Notepad++](https://notepad-plus-plus.org/) | 任意の外部エディタ | GNU General Public License | 同梱しない。インストールされていれば、起動するだけ |
| JetBrains Mono | 表示フォント (名前で指定) | SIL Open Font License 1.1 | 同梱しない。無ければ次のフォントに切り替わる |
| BIZ UDGothic | 日本語のフォールバックフォント (名前で指定) | SIL Open Font License 1.1 | 同梱しない |

## 商標

WezTerm、kitty、Notepad++、PowerShell、JetBrains Mono は、それぞれの権利者の名称または商標です。
このプロジェクトは、これらの権利者とは無関係で、承認も受けていません (not affiliated with, endorsed by, or sponsored by)。
名称は、対象となるソフトを示すためにだけ使っています。

## 移植元

kitty-ja-shortcuts (kitty 0.49.1 用のアドオン) の動作とコマンド名を、WezTerm の Lua 設定として移植したものです。

[[LICENSE-TODO: 移植元の作者とライセンスを確認して、ここに書く。確認できるまで公開しない]]

## このプロジェクト自体

MIT License です。全文は [LICENSE](LICENSE) にあります。
