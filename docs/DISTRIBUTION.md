# 別の人へ渡す配布セット

WindowsでSideStore未導入の人向けに、最新版0.2.0の完全版IPAと導入資料をまとめた。

ローカル出力:

- `release/Fairway-0.2.0-Windows-配布セット.zip`
- `release/配布用_Fairway_0.2.0_Windows/02_導入手順_Windows.pdf`
- 同名のWord（.docx）・Markdown版。
- `Fairway-0.2.0-full.ipa`（初回・更新共通）。

完全版IPAは、検証済み `Fairway-0.2.0-unsigned.ipa` と同一のバイト列。旧版・更新版を両方インストールする必要はない。アプリの再ビルドや実行コードの変更は行っていない。

配布セットには、受取人本人のアカウントでSideStoreを準備する手順、Fairway導入、Watch導入の確認、操作、7日期限のRefresh、アプリ更新、つまずいた時の確認先を含む。第三者のインストーラー、アカウント、署名証明書、ペアリングファイル、ラウンドデータは含めていない。

SideStore公式資料を2026-10-24に確認し、iloader＋LocalDevVPNの現行ルートで記述。WatchへのSideStore経由の実機導入は未検証であることを案内した。出典リンクは文書内に掲載している。

生成は `scripts/build_distribution.py`。PDF全7ページを画像で目視確認し、Wordのページ区切り・リンク構造を確認。ZIPの破損チェック、IPAが1本のみであること、元の検証済みIPAとのSHA256一致を検査した。

IPA SHA256:

```text
5a9786d519dc59ed9adaccbdc65e982b787b69c99ee635aa9b71ebdade07ec66
```
