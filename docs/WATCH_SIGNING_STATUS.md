# Watchへの導入：署名経路の調査

2026-10-24。ユーザー報告ではiPhone側のFairwayは起動し、WatchアプリからのWatchへの導入時だけ「整合性を確認できない」で失敗。iOS 26.6.2、watchOS 26.6、無料Apple Account、Windowsのみ。

前段のWKCompanionAppBundleIdentifier不一致は個別IPAのID修正で先に進んだが、Watch用の署名・プロファイルまで成立したことを意味しなかった。実機の署名済みIPAやインストールログ自体は取得していないため、原因の完全な確定ではない。

## 公開ソースから確認したこと

- [SideSign AppBundle](https://github.com/SideStore/SideSign/blob/main/Sources/Models/AppBundle.swift) のloadExtensionsはPlugIns直下のappexを列挙し、Watch内のappは列挙しない。
- [SideStoreのプロファイル準備](https://github.com/SideStore/SideStore/blob/develop/SideStore/Core/Operations/PipelineOperations/FetchProvisioningProfilesOperation.swift) は本体とappExtensionsを準備対象とする。
- [SideSignの署名処理](https://github.com/SideStore/SideSign/blob/main/Sources/CodeSigning/CodeSignerAPI.swift) も同じ列挙を使ってprofileを埋め込み、配下の未分類実行ファイルには本体側entitlementsを返す。

確認した実装では、Watchを独立したプロファイル準備対象として扱う経路が見当たらない。今回の症状からWatch用署名・プロファイル不備を有力と判断した。インストール済みSideStoreの正確な版との照合は未完了であり、全バージョンについて断定はしない。

## Windowsだけで試す次の候補

[RzbckのWatch companion対応](https://github.com/Rzbck/iloader-watch-companion) は、通常版のiloaderとは別の非公式試験実装。作者が示した回帰確認用の組合せ:

- iloader: `70f37e9b4afc659ab44ec1944c034093f4cda416`
- isideload: `f7b9f3da570edd6824c29680545e710846d07df5`
- [Windowsビルド](https://github.com/Rzbck/iloader/actions/runs/34436587217) の成功をAPIで確認。
- 調査時点の上流isideload PR #12はclosed・未merge。上流mainにはWatch専用ソースファイルやapplication.rsのWatch処理が見当たらず、通常版へ取り込み済みとは扱わない。
- windows-exe artifact `10136476786`、取得時は期限内。
- [作者による互換性説明](https://github.com/Rzbck/iloader-watch-companion/blob/main/docs/COMPATIBILITY.md) は別の実機でiPhone/Watch双方の導入・起動を報告している。対象OS・機種・無料アカウントでの普遍的な成功は示していない。

固定SHAのソースで、Watchの端末登録、watchOS向けプロファイル取得、個別署名、companion経由の導入処理が存在することを確認した。作者のバイナリをそのまま取得し、GitHub提供のアーカイブSHA256との一致を検査した。インストーラーはWindowsコード署名なし（NotSigned）。こちらでは実行、ログイン、証明書操作、実機導入を行っていない。

ローカルの候補セット:

`release/Watch_Windows_試験用_再導入.zip`

元の完全版Fairway IPA、作者の未変更インストーラー、出典・MITライセンス・非公式である旨、PDF/Word手順、検証記録を含む。この経路はID書換えを自ら行うため、SideStore向けに手動補正した個別IPAではなく、元の汎用IPAを入力に使う。

## 未確認事項

今回のiOS/watchOS・無料アカウントでの認証・プロファイル取得・導入・起動、既存iloaderとの共存、SideStoreの自動Refreshとの競合。Windows試験版を使っても成功が保証されるとは扱わない。本人のApple Accountを使う非公式ツールなので、手順と注意事項を明示して利用者が判断する。

Appleの標準経路はXcodeで両端末を登録し署名する方法だが、今回Macは使えない。Macを必須の次手順にせず、上記のWindows候補を準備した。有料契約だけで今回の通常SideStore経路が直るとも判断していない。
