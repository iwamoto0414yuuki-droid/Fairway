# Watch用プロファイルの不一致を切り分ける診断版

診断後の追記：利用者の結果はWPF_PLATFORMのみで、OS表記はiOS・visionOSだった。必須にしていたwatchOS文字列の判定を見直した[対応版](WATCH_IOS_FAMILY_PROFILE_FIX.md)を作成した。以下は診断版の作成時点の記録。

2026-10-25。①の改修版SideStoreで、Remote Pairingへ切り替えた後に
「取得したWatch用プロファイルの端末・ID・期限・Platformが一致しません」が報告された。
利用者は設定したWatch UDIDとWindowsのWatch情報ツールの値が一致することを確認した。
どの検証条件が失敗したかは、従来の一括メッセージでは分からない。

## 今回の変更

同じ検証条件を維持し、不一致を以下のコードでまとめて表示する。

| コード | 検出した不一致 |
| --- | --- |
| WPF_PLATFORM | profileにwatchOSの指定がない |
| WPF_APP_ID | 対象アプリのIDと一致しない |
| WPF_TEAM | 署名チームが一致しない |
| WPF_DEVICE | profileに入力したWatchのUDIDが含まれていない |
| WPF_EXPIRED | profileの有効期限が過ぎている |

複数の不一致は同時に表示する。実際のUDID・アプリID・チームID・profileの生データは表示しない。
OS種別は既知の公開OS名だけを表示し、未知の値は表示しない。
不正なprofileを通すための条件緩和や、証明書のリセットは行わない。

## 利用者の手順

1. iPhone/WatchのFairwayと現在のSideStoreを残す。②の成功したWindows Loaderを開く。
2. 同じApple Accountでログインし、USB接続したiPhoneを選び、Import IPAで今回のSideStore-Watch-profile-diagnostic.ipaを上書きする。
3. SideStoreを開き直す。今回すでに設定したRemote Pairing（rppairing）とWatch UDIDは、残っていれば変更しない。
4. LocalDevVPNが接続済みの状態で、My Appsの＋から同じFairway-0.3.0-unsigned.ipaを一度選ぶ。
5. エラーが出た場合、WPF_から始まるコードを確認する。診断コードまたはエラー表示部分だけを共有すればよい。ペアリングファイルやprofile自体は送らない。

設定が消えた、同じSideStoreが2つに増えた、証明書取消やRevokeを求められた場合は停止する。
旧メッセージのままなら、診断版に更新できたかを確認する。

## 検証の範囲

既存の不一致拒否テストで各コードを確認し、複数不一致時に全コードを返すことと、識別情報を表示しないことを追加検査する。
元のWatch署名検査も継続する。ビルド結果だけで実機の不一致原因や修復を確認したとは扱わない。
今回の版は原因を特定するための診断版であり、Appleから取得するprofileの内容や実機導入結果は引き続き確認が必要。

## 作成・検証結果

- [CI 40179979044](https://github.com/iwamoto0414yuuki-droid/Fairway/actions/runs/40179979044)でIPA作成成功。
- 対象ソース：`69dff8fbefbb9d80a323a0e9b553e7c8b6237aa9`。
- Watch署名と診断のテスト21件成功・失敗0。各不一致コード、複数不一致の表示、識別情報を含めないことを検査。
- IPA：`SideStore-Watch-profile-diagnostic.ipa`。
- IPA SHA256：`118c3ce67fc86197e91312181e3826eb1bd134e5526bcdecaf05e80b71193970`。
- 対応ソースZIP SHA256：`6b30132b58527002ac8f84ab90d0a848c4f73b09e21696a216a036b7f2be5db4`。
- 取得成果物ハッシュをGitHubと照合。ネイティブ実行ファイルに5種類の診断コードが含まれることを確認。
- 対応ソースの検証条件と、AuthManager／CertificateManagerが元ソースから変更されていないことを照合。
- 利用者の実機での不一致原因・解消は未確認。次にこの版の診断コードを確認する。
