---
topic: reusable-watch-sideloading
updated: 2026-10-25
status: sidestore-fresh-watch-install-failed-investigating
scope: self-built-ios-app-with-embedded-watch-app
---

# Apple Watch対応サイドロード：再利用用の入口

今後のAI・開発者は、このファイルを最初に読む。過去の調査資料には、その時点の「未確認」や、後で修正した仮説が残っている。現在の判断はこの資料群を優先し、履歴は削除せず参照する。

## 現在の到達点

**最新の実機結果を優先する。0.4.0はSideStoreでiPhoneへ入ったが、Watchへの導入は `This app couldn't be installed at this time.` で失敗。現在WatchにFairwayはない。SideStore経由のWatch新規導入・自動更新は、成功確認できていない。**

下表の0.3.0起動報告時には、先に②で入れたWatchアプリが残っていた可能性がある。その起動が①で更新されたバイナリだった証拠はない。以前の報告を取り消すのではなく、証明できる範囲を限定する。調査は[今回の比較記録](WATCH_INSTALL_0.4.0.md)を参照。

2026-10-25の利用者報告で確認したこと（対象アプリは0.3.0）：

| 項目 | 状態・根拠 |
| --- | --- |
| ② Windows Watch LoaderからのFairway導入 | 利用者がインストール完了とWatchでの起動を報告 |
| ① 改修版SideStoreからのFairway導入 | iOS系profile対応版へ更新後、利用者が完了を報告 |
| ① iPhoneだけでの手動Refresh | 利用者がRefresh成功と、その後のWatch起動を報告 |
| 自動更新 | 利用者が設定済みと報告。自動実行の成功ログは未確認 |
| 旧署名の期限後も起動可能か | まだ未確認。Refresh直後の起動だけでは長期更新を証明しない |
| スコア保存・同期・電池持ちの実地総合検証 | 本資料では成功と断定しない。個別に確認する |
| 他のWatchアプリへの適用 | 設計とコードを再利用可能。実機成功を確認したアプリはFairwayのみ |

利用者環境：Windows、無料Apple Account、iPhone 16e、Apple Watch Series 7。OSは本人申告でiOS 26.6.2／watchOS 26.6。OS表記はツールで再確認した値ではない。Macは使えないため、ビルドはGitHub ActionsのMac環境を使用した。

## 読む順番

1. [実機で通った導入・更新手順](OPERATIONS.md)
2. [SideStoreの改修・再ビルド・参考コード](SIDESTORE_DEVELOPMENT.md)
3. [他アプリの未署名IPAの作り方](APP_IPA.md)
4. [失敗・判断・利用者側の操作の履歴](HISTORY.md)
5. [新しいアプリの構造検査コード](examples/inspect_ipa.py)、[XcodeGenの最小例](examples/project.yml)、[実機ビルドの例](examples/build_unsigned.sh)
6. [AI向けの再開情報](state.json)

新版0.4.0は別途ビルド・44件テスト・画面確認済み。ただしWatchへの実機導入は失敗している。[変更内容](../APP_0.4.0.md)とstate.jsonのlatest_app_buildを参照。

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
