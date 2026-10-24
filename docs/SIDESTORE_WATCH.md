# SideStoreのWatch参照IDエラー

2026-10-24、配布ガイド04のインストール中に、InvalidCompanionAppBundleIdentifierが報告された。汎用IPAのWatch参照先が元のiPhone IDのままで、SideStoreが再署名で付与したアカウント別サフィックスに一致していなかった。

**その後、ID修正版でiPhoneは起動したが、Watch側は整合性エラーで導入できないと報告された。ID修正だけでは導入完了に至らない。Watch用の署名・プロファイルを扱う別経路の検討は [署名状況の調査](WATCH_SIGNING_STATUS.md) を参照。**

[AppleのWKCompanionAppBundleIdentifier仕様](https://developer.apple.com/documentation/bundleresources/information-property-list/wkcompanionappbundleidentifier) と、[SideStoreの再署名処理](https://github.com/SideStore/SideStore/blob/develop/SideStore/Core/Operations/PipelineOperations/ResignAppOperation.swift) を参照。

## 対応

エラーに示された再署名後のiPhone IDを正として、未署名IPA内のWatch Info.plistの2項目を準備する。

- WKCompanionAppBundleIdentifier: 再署名後のiPhone ID。
- Watch自身のCFBundleIdentifier: 再署名後のiPhone ID + `.watchkitapp`。
- 入力IPAのiPhone IDは元のままにする。そこへSideStoreがサフィックスを付けるため、事前に二重で付与しない。

これはアカウント別の導入用IPAで、汎用配布版ではない。別アカウントには、その人の実際のエラーに示される必要IDに合わせた準備が必要。パスワード・証明書・確認コードは不要。

生成ツール:

```sh
python scripts/build_sidestore_ipa.py --team-id YOURTEAMID
python scripts/build_distribution.py --team-id YOURTEAMID
```

YOURTEAMIDはエラーの必要IDに含まれる10文字のサフィックスに置き換える。

検証済み0.2.0 IPAのSHA256を確認してから生成し、Watch Info.plistの上記2項目以外に変更がないこと、全実行ファイルと資産が元と同一であること、観測された再署名後の親子関係が整合することを機械的に検査する。結果と最終IPAハッシュはrelease内の個別検証記録に保存する。個別アカウントIDを含む配布物は公開ソースに追加しない。

SideStoreの初期設定を繰り返す必要はない。同じアカウントのSideStoreで修正版を選んで再試行する。実機の再署名・導入成功はまだ未確認であり、この整合性検査を成功実績とは扱わない。さらに別の署名エラーが出た場合は、そのエラーを別途確認する。
