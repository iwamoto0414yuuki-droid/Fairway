---
topic: reusable-watch-sideloading
updated: 2026-11-05
status: physical-install-and-manual-refresh-verified
scope: self-built-ios-app-with-embedded-watch-app
---

# Apple Watch対応サイドロード：再利用用の入口

今後のAI・開発者は、このファイルを最初に読む。過去の調査資料には、その時点の「未確認」や、後で修正した仮説が残っている。現在の判断はこの資料群を優先し、履歴は削除せず参照する。

## 現在の到達点（2026-11-05）

**利用者が、改修版SideStore経由でiPhone・Apple Watchへの導入、修正版でのFairwayのRefresh成功、その後のWatch動作を確認した。** 当初の導入・手動期限更新の目標を達成した。現在の成功基準は [再利用手順書](REUSE_GUIDE.md) と [state.json](state.json) を参照する。

完成基準のコードは `cc13860`、[CI 42030957798](https://github.com/iwamoto0414yuuki-droid/Fairway/actions/runs/42030957798)。通信テスト8件と署名テスト27件が成功。最終修正は [App Group ID重複の原因と修正](REFRESH_APP_GROUP_SUFFIX.md)。

自動更新は設定済みという利用者報告があるが、自動実行ログと旧署名期限後の起動は別途未確認。他のアプリにも方法とコードを再利用できるが、実機で成功確認したアプリはFairway。

環境はWindows、無料Apple Account、iPhone 16e、Apple Watch Series 7。Refresh障害時のiOSは本人申告27.0.1。最終時点のwatchOSは未再確認。ビルドはGitHub ActionsのMacを使用し、利用者にMacは不要だった。

以下にリンクする過去資料には当時の失敗・未確認状態が残る。履歴として保存しており、この最新結果を優先する。

## 読む順番

0. [完成版を使う・他アプリに再利用する手順](REUSE_GUIDE.md)
1. [過去の導入報告と操作手順](OPERATIONS.md)（最新の未解決事項は上記を優先）
2. [SideStoreの改修・再ビルド・参考コード](SIDESTORE_DEVELOPMENT.md)
3. [他アプリの未署名IPAの作り方](APP_IPA.md)
4. [失敗・判断・利用者側の操作の履歴](HISTORY.md)
5. [新しいアプリの構造検査コード](examples/inspect_ipa.py)、[XcodeGenの最小例](examples/project.yml)、[実機ビルドの例](examples/build_unsigned.sh)
6. [AI向けの再開情報](state.json)

新版0.4.0は44件テスト・画面確認済み。過去のWatch導入失敗は改修版SideStoreの直接転送とApp Group修正により解消した。[変更内容](../APP_0.4.0.md)とstate.jsonのlatest_app_buildを参照。

## 今後の基本方針

- 目標は①の改修版SideStoreからFairwayを導入し、iPhoneだけでWatch分も期限更新すること。利用者はFairwayを②から入れ直す切り分けを希望していない。②は成功した実装の比較資料として扱う。
- Fairway本体だけの変更なら、小さいFairway IPAだけを作る。SideStore本体の再ビルドは署名・転送・認証処理の修正時に限る。
- 他アプリではアプリID・ターゲット・capabilityを置き換える。同じApple Accountというだけで、別IDのアプリへデータが自動移行するとは考えない。
- `watchOS`というPlatform文字列を必須にする旧検証へ戻さない。iOS系表記を許可する範囲は専用のWatch取得経路に限定する。
- エラーは接続→認証→証明書→profile→署名→iPhone導入→Watch導入→Refresh→期限後起動の順で分ける。
- 証明書の自動取消を復旧の既定手段にしない。正常な鍵・証明書を再利用する。
- ペアリングファイル、秘密鍵、パスワード、実機profile、実端末IDはこの資料群・CI・公開リポジトリに保存しない。
- 既存アプリの削除を前提にしない。まず同じアカウント・同じIDでの上書きを確認する。

## 成功した成果物の識別

| 成果物 | ソース・検証 |
| --- | --- |
| SideStore-Watch-ios-family-fix.ipa | build対象`c61107c80a8121f27f4f39e0dd8cc6e3b91e7cf9`、[CI 40182952453](https://github.com/iwamoto0414yuuki-droid/Fairway/actions/runs/40182952453)、26テスト |
| Fairway-0.3.0-unsigned.ipa | build対象`ad565069f56d6b8e645a6581eb829b0363aa1cbf`、[CI 40140421334](https://github.com/iwamoto0414yuuki-droid/Fairway/actions/runs/40140421334)、38テスト |
| Fairway Watch Loader 2.3.1-auth.20261025.2 | build対象`ec1ca778c1ef345833400fb0ebec9bc05d9ffbfe`、[CI 40174027549](https://github.com/iwamoto0414yuuki-droid/Fairway/actions/runs/40174027549)、29テスト |

SHA256とローカル配布場所は[state.json](state.json)に記録した。`release/`はGit管理対象外。GitHub Actionsのartifact URLは保持期限があるため、永続ダウンロード先とは考えない。手元の配布ファイルと対応ソースZIPを保持し、失われた場合は固定したソースから再ビルドする。再ビルドでは署名・時刻等によりハッシュが変わり得るため、旧ハッシュとの完全一致を再現性の必須条件にはしない。

この資料は個人用の非公式改修の記録。公式SideStore・iloaderの対応保証や、すべてのアプリでの成功保証ではない。

## 別のチャットへ渡す短い指示例

```text
Fairwayリポジトリのdocs/watch-sideloading/README.mdとstate.jsonを読んでから作業してください。
今回は［新しいアプリ名／変更内容］です。
実機成功の範囲と未確認事項を区別し、固定ソースと参考コードを確認してください。
アプリ機能だけの変更ならSideStoreまで再ビルドしないでください。
```
