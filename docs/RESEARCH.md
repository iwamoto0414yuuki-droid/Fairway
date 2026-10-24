# 調査と設計判断

調査日: 2026-10-24。目的: 一人分のスコア入力を短時間で済ませ、Apple Watch Series 7でGPS距離も必要なときに確認する。

## 主要アプリから採用する操作

| 公式資料 | 確認した特徴 | 初版で採用 |
| --- | --- | --- |
| [18Birdies: Using Apple Watch](https://help.18birdies.com/article/273-using-18birdies-on-apple-watch) | Watchでスコアと任意統計を入力し、保存して次ホールへ進む | 打数→任意パット→保存して次へ。複雑な統計は省略 |
| [Golf Pad: Apple Watch guide](https://support.golfpadgps.com/support/solutions/articles/6000122036-golf-pad-apple-watch-user-guide) | ホール情報と距離を表示し、画面下部から打数記録。スクロールで追加操作 | ホール/PAR、距離、打数、保存ボタンを縦の順序で配置 |
| [Golfshot: iOS guide](https://szuserguides.s3.amazonaws.com/en/golfshot-ios-user-guide.pdf) | スコアカード・Watch・省電力の説明を含む | 比較の補助資料。古い資料なので現行UIの完全な根拠には使わない |

公式ガイドに記載された操作構造を参考にした。ブランド名・ロゴ・画像・画面の完全複製は行わず、独自のFairway UIを作成。黒地に黄緑のアクセント、44pt以上の打数ボタン、大きな数字、保存操作を明示する。

## 最小機能

必須: ラウンド開始、9/18ホール、PAR、打数と修正、合計と対パー、未入力の区別、履歴、ローカル保存、Watch同期。

追加要望: GPS距離。初版はグリーン中央への直線距離に限定。既成の全国コースデータを持たず、iPhoneのMapKit検索と航空写真で位置登録する。コース位置とグリーン位置を混同しないよう、検索後のグリーン指定を別操作にする。登録後は座標をWatchへ転送し、Watchの距離計算にネット接続や地図ダウンロードを不要にする。

任意: パット数、CSVテキスト共有、同じコースの再利用。後回し: ハンディキャップ、複数人、SNS、クラブ別統計、スイング自動検出、グリーン前後/高低差、スコア画像。

## 省電力

[Apple Watch Best Practices](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/EnergyGuide-iOS/AppleWatchExtensionBestPractices.html) は通信の集約、不要な画面更新の削減、黒い背景を推奨。[位置情報の省電力ガイド](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/EnergyGuide-iOS/LocationBestPractices.html) は短い位置取得にはrequestLocationを使用し、必要な精度と時間に抑えることを推奨する。

実装判断:

- 自動GPS追跡なし。更新ボタンでrequestLocation、希望精度10m、最大20秒の一度だけの打切りタイマー。
- 50mより不正確、15秒より古い結果は距離として使わない。希望精度は取得結果の精度保証ではない。
- 画面が非アクティブになった時と離脱時にstopUpdatingLocation。権限は使用中のみ。
- Watchに地図を表示しない。保存したグリーン座標と測位座標から端末内で計算。
- スコアボタンを押すたびに通信せず、保存操作で1ラウンド分を送る。起動時に最新ラウンドを再送。
- 常時タイマー、ワークアウト、心拍、モーション、Always On専用更新、バックグラウンド測位なし。

[AppleのWatchConnectivity解説](https://developer.apple.com/videos/play/wwdc2021/10003/) に基づき、即時接続依存のsendMessageではなく、システムが管理するtransferUserInfoを利用。即時同期は保証しない。

これらは消費を抑える設計判断であり、節電率・18ホール後の残量は未測定。実機のバッテリー最大容量、天候/GPS受信、画面輝度、Always On、呼出回数を揃えた比較が必要。

## SideStoreとビルド

[SideStore FAQ](https://docs.sidestore.io/docs/faq) はiOSアプリの再署名と通常7日の更新周期、無料Apple Accountのインストール制約を説明する。しかし今回のiOS+watchOS構成の導入可否を保証する記述は確認できなかった。WatchアプリがIPAに含まれていても、親子ID・プロビジョニング・再署名が揃わないと導入できない可能性が残る。

[Apple: watchOS project](https://developer.apple.com/documentation/watchos-apps/setting-up-a-watchos-project)、[Bundle ID設定](https://help.apple.com/xcode/mac/current/en.lproj/deve21d0239c.html)、[XcodeGen仕様](https://github.com/yonaskolb/XcodeGen/blob/master/Docs/ProjectSpec.md) を基に、SwiftUIのiOSアプリとwatchOSアプリの2ターゲットにした。

Windows上にXcode/Swiftは見つからず。既存UTubeMusicと同じ、GitHub Actionsの公開リポジトリ＋macos-15でIPAを作成した。公開とCI実行はユーザーの承認を得て実施し、ネイティブ20テストと実機向けビルドに成功。実機では①iPhoneへの導入、②Watchへの導入、③同期、④GPS、⑤省電力を別々に判定する。

画面確認後、Watchでは打数と保存を先頭へ置き、GPSを専用画面から開く配置に調整した。40mmシミュレーターで主要入力が初期表示内に収まることを確認した。iPhoneの3画面も描画して確認済み。詳細は [検証結果](RESULTS.md)。
