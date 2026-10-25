# Watch用プロファイル：iOS系Platform表記への対応

2026-10-25。診断版の実機結果は `WPF_PLATFORM（OS種別: iOS, visionOS）` のみ。
この検査でアプリID・チーム・入力したWatch UDID・有効期限の不一致は報告されなかった。
署名証明書の一致は、この検査の後の処理で引き続き確認する。

## 原因

こちらの実装はPlatform配列に`watchOS`があることを必須にしていた。
しかしApple公式の「Create a development provisioning profile」は、iOS App DevelopmentがiOSとwatchOSのアプリを対象に含むと明記している。
今回Appleから返された`iOS, visionOS`という実測値と、②のWatch Loaderでの起動成功も踏まえ、Watch専用経路で取得したiOS系プロファイルを受け入れるようにする。

一次資料：[Apple：開発用プロビジョニングプロファイルの作成](https://developer.apple.com/help/account/provisioning-profiles/create-a-development-provisioning-profile)
この資料は対象プラットフォームの範囲を示すもので、今回の配列の実測値そのものの出典は利用者の診断画面。

従来のオフライン検査では`watchOS`表記の合成プロファイルを正常例に使い、今回のiOS系表記を正常例として検査していなかった。
今回、この実測条件と、同じOS表記でも端末・アプリID・チーム・期限が違う場合の拒否を追加検査する。

## 変更の範囲

- `watchOS`の明示指定は従来どおり受け入れる。
- Watch登録と`DTDK_Platform=watchos`指定の取得を行った呼出しだけで、iOS系表記の対応を有効にする。
- iOS系表記は`iOS`を必須とし、追加要素を`xrOS`と`visionOS`に限定する。
- 無指定・tvOS・macOS・visionOSのみ・iOSとtvOSの混在などは拒否する。
- Watch専用経路を指定しない一般の検証では、iOS系表記を自動許可しない。
- アプリID・チーム・Watch UDID・期限と、実際に使う署名証明書の照合は維持する。
- ペアリング・ログイン・証明書の選択や取消の処理は変更しない。

## 利用者の手順

1. Windowsの② Fairway Watch Loaderを開き、同じApple Accountでログインする。
2. USB接続したiPhoneを選び、Import IPAで今回の`SideStore-Watch-ios-family-fix.ipa`を選んでSideStoreへ上書きする。
3. iPhoneでSideStoreを終了して開き直す。Remote Pairing（rppairing）とWatch UDIDが残っていれば変更しない。
4. LocalDevVPNを接続し、My Appsの＋から同じ`Fairway-0.3.0-unsigned.ipa`を一度選ぶ。
5. 完了したら、iPhoneとWatchでFairwayを開き、保存内容・同期を確認する。

既存のFairwayを先に削除しない。証明書取消・Revokeを求められた場合や別アプリが増える場合は停止する。
別のエラーが出た場合は、そのエラー表示を確認する。ペアリングファイルやプロファイル自体を共有する必要はない。

今回の修正は、実機で確認したPlatform判定による停止への対応。①でのWatch導入・Refresh・期限延長の成功は、実機で確認してから記録する。

## 作成・検証記録

- [CI 40182952453](https://github.com/iwamoto0414yuuki-droid/Fairway/actions/runs/40182952453)でIPA作成成功。
- 対象ソース：`c61107c80a8121f27f4f39e0dd8cc6e3b91e7cf9`。
- Watch署名・診断・iOS系表記の検査26件成功、失敗0。
- IPA SHA256：`de762ba007e868ac3fab7bfbc2142882d16947be218c2408f03f7b57a18e09f2`。
- 対応ソースZIP SHA256：`fbf492ab3e7057c6f874ebc31b2f71dc71dbcea718191b3a72c29624a6c782c5`。
- 取得成果物のハッシュをGitHubの値と照合。対応ソースの限定的なiOS系対応と、署名証明書照合の維持を確認。
- AuthManager／CertificateManagerは元ソースと同一。Fairway IPAも以前と同一。
- 修正後の実機導入・Watch起動・期限更新は未確認。
