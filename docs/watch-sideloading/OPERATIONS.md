# 実機導入・更新・復旧の手順

この手順は[現在の状態](README.md)を前提にする。今回の既存アカウント・端末で通った手順と、他端末で要検証の部分を混同しない。

## 1. 用意するもの

- iPhoneとペアリング済みWatch、Windows PC、USBケーブル、ネット接続。
- 同じ無料Apple Account。確認コードは本人の端末とツールの入力画面で扱う。
- 正常動作したFairway Watch Loader `.2`、改修版SideStore、元の完全な未署名アプリIPA。
- iPhoneのLocalDevVPN。必要なデベロッパモードとPCへの信頼。
- WatchのUDID。シリアル番号やiPhoneのUDIDではない。

別人への導入にはその人のアカウント・その人のiPhone/Watchで署名・ペアリングする。自分の証明書・秘密鍵・pairing fileを渡さない。今回の既存SideStore認証や元PC鍵の再利用は、新規利用者に必ず存在する前提ではない。

## 2. ② Windows Loaderで初期導入またはSideStore更新

1. ZIPをすべて展開し、`Fairway-Watch-Loader.exe`を起動する。通常版iloaderのインストーラーでダウングレードする操作ではない。
2. 同じApple Accountで「認証を確認（Login）」を押す。この操作とImport IPAの署名・導入段階を区別する。
3. 証明書上限7460で止まった利用者は「通常版iloaderの署名鍵を再利用」を使用した。通常版を最初に使った同じPCに鍵が残っており、有効なApple証明書との一致を確認できた場合だけ再利用する。
4. USB接続したiPhoneをロック解除し、Refresh Devices→USBのiPhoneを選ぶ。
5. Import IPAから、改修版`SideStore-Watch-ios-family-fix.ipa`を選ぶ。既存SideStoreは削除せず上書きする。
6. 同名アプリが2つ増える、異なるID・チームへの変更、証明書取消を求められる場合は結果を確認する。現在の構成を当然に引き継げたとは考えない。

今回の拡張機能選択では「Keep App Extensions (Register App ID for Each Extension)」を使った。これは**SideStore自身の拡張**についての選択であり、Watchアプリの代わりではない。無料アカウントのApp ID枠も使うため、別アプリで不要な拡張をどう扱うかはその構成を確認する。

元のWindows鍵の再利用に成功した後は通常毎回押さなくてよい。Revokeで枠を空ける方法は今回採用しなかった。

## 3. SideStoreのペアリング

1. Windows LoaderのManage Pairing Fileを開き、SideStoreの行のPlaceを押す。
2. iPhoneでSideStoreを完全に終了して開き直す。
3. 手動選択が必要なら「このiPhone内 → SideStore → ALTPairingFile.mobiledevicepairing」を読み込む。Placeは配置であり、方式の選択・読み込み完了とは同義ではない。
4. 初期画面で進めない場合は、設定のPairing File Managementから方式別の欄で読み込む。
5. **今回の最終運用はRemote Pairing（rppairing）**。Remote Pairing Fileに同じ`ALTPairingFile.mobiledevicepairing`を読み込み、その欄を長押し→Set as Preferred。
6. Preferred Protocolがrppairingであることを確認し、LocalDevVPN接続中にSideStoreを終了・再起動する。

今回のLoaderは対応iOSでLockdownとRemote両方の情報を1つのplistに格納する。「format is ambiguous」は破損と断定できない。改修版は、選択した方式を**事前検査にも保存時にも**渡す。

ファイル詳細のInstalledは配置状態。実接続や認証の成功を証明しない。今回LockdownではVPN再接続後もBroken pipeが続き、Remoteへ切り替えた後に次の処理へ進んだ。別OS・端末でもLockdownが必ず失敗するという結論ではない。

ペアリングの生XMLには秘密情報がある。RAW XML画面やファイル自体を公開・添付しない。

## 4. Watch登録・アプリ導入

1. 設定→Developer Portal Services→「個人用Watch試験版」→「Watch対応」。
2. 必要ならWindowsでLoaderを閉じ、`Fairway-WatchInfo.exe`からペアリング済みWatchのUDIDを表示する。端末IDは本人だけが扱う。
3. Watch UDIDを入力し「Watchの登録を確認」。②ですでに登録済みでも、①での照合と端末内保存のために実施した。
4. LocalDevVPN接続中にMy Appsの＋から元の`Fairway-0.3.0-unsigned.ipa`を選ぶ。
5. **SideStoreのIPAとFairwayのIPAを取り違えない**。過去のアカウントID専用修正IPAも使わない。
6. iPhone・Watchで起動する。Watchにない場合はiPhoneのWatchアプリの利用可能なAppを確認する。既存Watchアプリは先に削除しない。
7. スコア保持・打数・パット・同期を別に確認する。アプリIDが変わった場合に自動移行すると保証しない。

## 5. スマホだけで期限更新

1. まず改修版SideStoreでFairway**だけ**を手動Refreshする。
2. 完了表示に加えWatchで起動する。今回この段階までは利用者が成功を報告した。
3. 次に自動更新を設定する。今回利用者は設定済みと報告したが、設定の全詳細と実際の自動実行結果は未記録。自動成功と断定しない。
4. 次回はRefresh履歴・エラー・残日数とWatch起動を確認する。古い署名の期限を過ぎても起動できるかを見る。

Appleの無料Personal Teamプロファイルは発行から7日で期限切れになる。[Apple公式](https://developer.apple.com/help/account/basics/about-your-developer-account)。実際の期限はprofileのExpirationDateによる。週末の同じ時刻まで必ず使える等とは推定しない。

改修版はWatchを含むRefreshを再署名・再導入へ切り替える。iPhoneのprofile注入だけで済ませない。SideStore自身の更新も必要。公式版・Nightlyへの更新で個人改修が失われ得るため、更新先にWatch処理があるかを先に確認する。

## 6. 復旧の順番

| 症状 | 最初の対応 | 避けること |
| --- | --- | --- |
| WindowsのExpected usbmuxd device id | USB再接続→Refresh Devices→同じiPhoneを再選択。必要ならLoader再起動 | 証明書やpairingのリセット |
| セッション期限切れ | 同じアカウントで再認証。画面にログイン導線がなければ確認する | 無条件のSign Out。元ソースでは証明書のローカル保存を消す経路がある |
| pairing未設定 | 配置・方式別読込・Preferred・再起動を確認 | Installedだけで接続済みと決める |
| Lockdown Broken pipe | VPN再接続を1回確認。今回の環境ではRemoteへ切替 | 同じインストールを繰り返す |
| WPF_PLATFORM: iOS,visionOS | 最新iOS系対応版か確認 | 古いwatchOS文字列必須版へ戻す |
| WPF_APP_ID / TEAM / DEVICE / EXPIRED | 該当条件・取得経路を確認。値自体を公開しない | すべての検証を削除する |
| 証明書がprofileに含まれない | 使用鍵・有効な証明書・profileの組合せを調査 | 自動Revoke、公開の証明書配布 |
| Watchのみ整合性エラー | Watch profile・個別署名・親子ID・再導入を確認 | iPhoneの成功をWatch成功と扱う |

①で更新できなくなった場合は、まずエラーを保存し、成功した②のLoaderと同じアカウント・元IPAで上書きする復旧を検討する。②が常に無条件で復旧できるとの保証ではない。②の認証・鍵が残るかも確認する。
