# SideStoreを使うWatch導入経路の調査

2026-10-24。これは調査・設計であり、動作確認済みの導入手順ではない。

## 確認された条件

- Windowsのみ、無料Apple Account。iPhone版Fairwayは起動する。
- ユーザー報告のSideStoreは0.7.0。現在もログイン済みでFairwayのRefreshが成功する。
- Watch導入は整合性エラー。署名済みIPA・Watchのインストールログを解析した確定診断ではない。
- 非公式iloaderの旧回帰ビルドはAnisette -45061、503。公式と同じ503修正を含む作者の別ビルドでも、-80045で認証が止まった。
- 接続先の変更を繰り返すことを主経路にしない。通常版iloaderへの変更だけでWatch対応が得られるとは確認できていない。

## 提案

SideStoreの既存認証と証明書を利用してWatchを個別に登録・署名・期限更新する専用改修を、次の開発候補とする。FairwayのIPAを修正するだけの対処ではない。現行SideStoreの設定だけで無料アカウントのWatch導入が成功する既成手順は、今回の調査では確認できなかった。

既存セッションがあることは有利だが、改修版への更新後にセッション・証明書が引き継がれ、再認証なしでWatch用の新規API要求が通ることは未確認。Refresh成功はこの点の証明にはならない。

## 調べた実装

調査したSideStore develop: `d97ec133719d79916675bdaf722b82a8d091d545`。
調査したSideSign main: `752d1ef602aa792a432ffa1e71646dc1ecf7363c`。
ユーザーの0.7.0という表示だけでは、このSHAと実機ビルドを一致させられない。公開リリースには0.7.0-alphaと0.7.0の版文字列を持つNightlyがあり、実装前にビルド番号も照合する。

| 層 | 確認した処理 | 必要な検証・改修 |
| --- | --- | --- |
| バンドルの検出 | SideSign AppBundleはPlugInsのappexを列挙する | Watch/*.appと必要な子バンドルを別の署名対象にする |
| アプリID | SideStoreのプロファイル準備は本体とappExtensionsを使う | 親子IDとWKCompanionAppBundleIdentifierを一貫して書き換える |
| Watch登録 | SideSignにはappleWatch型があるが、registerDeviceの分岐はiPhone/iPadとAppleTV | Watch向けの登録パラメーターと無料チームでの受理を検証する |
| プロファイル | 汎用APIにsubPlatform指定があるが、自動分岐にはWatchがない。SideStoreはcurrentDeviceTypeを使う | Watch用のプロファイルを個別要求し、対象Watch・ID・証明書・期限・Platformを確認する |
| 署名 | mainとappExtensionsをprepareする。未分類の子実行ファイルはmainの扱いになる可能性がある | Watchの正しいprofile/entitlementsを埋め込み、内側から署名する。iPhoneのprofileへの暗黙fallbackを認めない |
| 導入 | iPhoneへの導入成功だけではWatch導入の成功を示さない | 最初はiPhoneのWatchアプリから導入を試す。必要ならcompanionサービスでの転送を別に実装・検証する |
| 更新 | 通常Refreshと同じ期間でWatchも期限が切れる | 新規導入だけでなく再署名・更新後の両端末起動を確認する |

## 最小の検証順序

1. 実機のSideStoreの詳細ビルドを特定し、同じ系統のソースと依存関係を固定する。
2. まず署名・プロフィールの検査を実装する。変更前後のID、profileのPlatform、有効期限、端末登録の一致を秘密情報を含めず判定する。
3. 既存認証を利用してWatch登録・Watch用profile取得が可能か検証する。取得できない場合は署名・導入へ進まない。
4. 最小Watchアプリを個別署名し、Watchでの起動まで実機確認する。
5. Fairway本体を導入し、スコア同期・GPS・次回Refresh後の起動を確認する。

改修版SideStoreの実機導入前には、同じbundle ID・署名チーム・Keychain access group・保存領域・データ形式を維持できるかと、元の版へ戻せるかを確認する。別IDのSideStoreを入れれば既存の認証や証明書を自動共有できるとは扱わない。Appleのパスワード、セッショントークン、秘密鍵、profile、pairing recordはGitHubやチャットに持ち出さず端末内で扱う。

署名が成立してもiPhone経由でのWatch転送に失敗する場合は、Apple Accountへ再ログインしない転送専用Windows補助ツールを検討できる。ただし、対応するWatch接続処理の実装と実機検証が別途必要であり、既に使える手順とは扱わない。

## 他経路との比較

- 非公式iloaderの現状ビルド: Watch対応の実装はあるが、今回の認証を通過できない。サーバー設定変更を繰り返さない。
- 通常SideStore: 現在動いているiPhoneの管理には使える。Watch対応が既に完成しているとは確認できない。
- Watch対応SideStoreの改修: 無料・Windowsという条件を維持する開発候補。完成IPA・実機成功の実績はまだない。
- Sideloadly 0.71.0: 公式変更履歴にWatch署名対応があるが有料Developer Program向け。無料Apple Account対応は今後とされるため、現条件での解決策にはしない。
- 有料の標準配布: 条件変更を伴う別案。契約だけで通常SideStoreのWatch処理が直るとは説明しない。

## 出典

- [SideStore 0.7系を含むリリース一覧](https://github.com/SideStore/SideStore/releases)
- [SideSign AppBundle](https://github.com/SideStore/SideSign/blob/752d1ef602aa792a432ffa1e71646dc1ecf7363c/Sources/Models/AppBundle.swift)
- [SideStore profile準備](https://github.com/SideStore/SideStore/blob/d97ec133719d79916675bdaf722b82a8d091d545/SideStore/Core/Operations/PipelineOperations/FetchProvisioningProfilesOperation.swift)
- [SideSign署名](https://github.com/SideStore/SideSign/blob/752d1ef602aa792a432ffa1e71646dc1ecf7363c/Sources/CodeSigning/CodeSignerAPI.swift)
- [SideSign端末登録](https://github.com/SideStore/SideSign/blob/752d1ef602aa792a432ffa1e71646dc1ecf7363c/Sources/DeveloperPortal/Devices.swift)
- [SideSign profile API](https://github.com/SideStore/SideSign/blob/752d1ef602aa792a432ffa1e71646dc1ecf7363c/Sources/DeveloperPortal/Profiles.swift)
- [独立したWatch対応の実装例と実機確認の限界](https://github.com/Rzbck/iloader-watch-companion)
- [Sideloadly公式変更履歴](https://sideloadly.io/changelog)

この文書作成時点では、SideStoreの改修・ビルド・差し替えは行っていない。
