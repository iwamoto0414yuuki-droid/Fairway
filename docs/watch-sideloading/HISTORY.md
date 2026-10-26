# 試行錯誤・判断・利用者操作の履歴

会話とコード・CI記録を突き合わせた2026-10-25時点の整理。順番を示すための段階番号であり、すべての実施日時を厳密に確定した時刻表ではない。実際の端末ID・メール・氏名・鍵は転記しない。

## 段階ごとの経緯

アプリ側の方針も途中で変わった。当初はGPS距離も要望されたが、Watch導入を最優先にして検証とIPAを小さくするため、0.3.0ではGPS・地図・運動計測を外した。打数・パット・ホール別管理・前半/後半の集計・任意のクラブ記録を残した。参考アプリは「ゴルフスコアカウンター」。この縮小は利用者の指示によるもので、今後GPS等を戻すかは別の仕様判断。

初回版と更新版をまとめる相談もあったが、再利用する手順では最新版の完全なIPAを初回導入・上書き更新の両方に使う。異なる世代のアプリを1つのIPAへ合体する方式を前提にしない。

| 段階 | 起きたこと / 利用者が行ったこと | 判断・変更 | 結果と残った課題 |
| --- | --- | --- | --- |
| 1 | 通常のSideStoreからFairwayを入れ、WKCompanionAppBundleIdentifierのエラー | 再署名後のiPhone IDとWatch親参照の不一致を確認。アカウント別ID修正IPAを作成 | iPhoneで起動。Watchは整合性エラー。ID修正だけで完了とはならなかった |
| 2 | iPhone版のみ起動、無料アカウント・Windowsのみと判明 | Watchの登録、専用profile、個別署名を扱う必要があると判断 | Mac/Xcodeを本人が使う手順は条件から除外 |
| 3 | 既存iloaderより古いインストーラーの画面が出た | 利用者はキャンセル。通常版を消してダウングレードする方針を採らなかった | 後の個人用Loaderは別identifier・別保存領域のポータブルEXEにした |
| 4 | 非公式Watch対応iloaderで−45061、503、−80045 | Watch転送より前のApple認証で停止。Watch実装自体の不成功とは区別 | 既存SideStoreはログイン・Refreshできていたため、その認証を使う①を開発 |
| 5 | ①の改修版SideStoreを作成 | Watch登録・profile・親子ID・署名・Refreshを改修。小さい署名fixtureの後、実Fairway IPAでも検査 | 19件のオフライン検査とビルド成功。ただし当時は実機未確認 |
| 6 | 利用者が別の方法も検証するよう希望 | 公式側の新しい認証処理とWatch forkの差分を調査。動的client metadata、限定的ADI再準備、2FA応答対応等を②へ移植 | ②の認証更新版をビルド。通常版を上書きしない設計 |
| 7 | ②で認証後、7460「Maximum number of certificates reached」 | 証明書の自動取消を停止したまま、元の鍵の再利用を開発 | 認証が通った証拠。まだWatch導入の証明ではない |
| 8 | 利用者が「同じWindows PCの通常版iloaderでSideStoreを入れた」と確認 | 同じメールの既存鍵だけを元のkeyringから読み、有効なApple証明書と公開鍵一致時に試験版へコピー。machine_name一致だけに依存しない | パスワード/ADIコピーなし、取消なし。`.2`版の29テスト・EXE起動検査成功 |
| 9 | ②でExpected usbmuxd device idというエラー | 選択時の一時接続番号が古くなった。USB再接続・Refresh Devices・再選択 | 利用者が②でインストール完了、Watch起動を報告。Windows Loaderは成功した復旧経路になった |
| 10 | 毎週PC接続が面倒、スマホだけの更新を希望 | ①へ切替検証。②のアプリ・鍵・証明書を元に戻したり取り消したりせず残した | ①で署名と期限更新が成立するか別に確認を開始 |
| 11 | ①の自己更新でセッション期限切れ。再認証や拡張選択の画面を進めた | 同じaccountでログイン。SideStore拡張は各拡張ごとのApp IDを維持する選択を案内 | ログアウトが鍵/証明書のローカル保存を消す場合があるため無条件に勧めない |
| 12 | Pairing Fileの初期画面、device registration pending等 | Placeと読み込みの違いを確認。最初の「あとで設定」だけでは進めなかった | 初期化・削除は不要。方式別読み込みへ進めた |
| 13 | 統合plistのformat is ambiguous | LoaderはLockdown/Remote両形式を同じplistへ格納。SideStoreの事前検査がpreferred:nil固定だった | `inspectPairingFile`へ方式を渡す修正と初期画面の選択欄を追加。修正版を②で上書き |
| 14 | 利用者がLockdownファイルをInstalledにし、Preferredに設定 | Installedは配置状態と区別。LocalDevVPN接続・再起動を確認 | LockdownではBroken pipeが再発 |
| 15 | 同じ統合ファイルをRemote Pairingとして読み込み、rppairingをPreferredへ | 新たに別人のファイルや鍵を使わず、元の統合ファイルの別方式を使用 | 処理がWatch profileの検査まで進んだ。今回の最終運用はRemote |
| 16 | Watch情報ツールのUDIDを設定し登録確認を完了。Fairway導入で一括profile不一致 | 利用者が入力UDIDとWatchツールの値が同じと確認。原因を推測で決めず診断版を追加 | 21テスト成功。値を公開せずWPF_*コードで項目を分離 |
| 17 | 実機診断がWPF_PLATFORMのみ、OS表記はiOS/visionOS | 端末/ID/team/期限の条件は不一致なし。Apple公式のiOS開発用profileの対象にwatchOSが含まれることも確認 | こちらのwatchOS文字列必須条件が今回の停止原因だった。合成正常例の偏りがテストの穴だった |
| 18 | iOS系表記をWatch専用取得経路だけで受け入れる修正 | generic検査の既定は厳格なまま。端末/ID/team/期限/実署名証明書の照合を維持。26テスト成功 | 成功版`SideStore-Watch-ios-family-fix.ipa`を作成 |
| 19 | 利用者が①からFairway導入成功、続いてRefresh成功とWatch起動を報告 | ①を通常運用、②を復旧用にする状態へ更新 | スマホだけの手動更新経路は1回成功。長期更新と自動実行はまだ別の確認事項 |
| 20 | 利用者がスマホだけでの自動更新も設定したと報告 | 設定済みとして記録 | 実行履歴、旧期限後の起動、自動更新の安定性を未確認として残す |

## 判断の変更を消さない

- 「SideStoreは不要」は②だけで運用する場合の説明。その後スマホ更新を希望したので①を再び使った。最終状態ではSideStoreを残す。
- 「Lockdownを選ぶ」は最初の接続試験。今回の接続ではRemoteが必要になった。全端末でLockdownを禁止する意味ではない。
- 「profileのPlatformにwatchOS必須」は誤った制約だった。旧テストの正常fixtureだけでは実際のiOS系profileを網羅できていなかった。
- 「署名検査に成功」は実機profile取得やWatch起動とは別。最初の19件・診断版21件・対応版26件の違いを区別する。
- 「②でWatch起動成功」は①での期限更新成功を意味しなかった。その後、利用者が①の導入と手動Refresh後の起動を別に確認した。
- 手動Refresh直後のWatch起動も、自動実行や旧期限後の継続起動まで証明したわけではない。

## 再試行を増やさないための教訓

1. 最初から失敗した条件を個別コードで返す。秘密値をログへ出さず、実測した条件でテストを増やす。
2. UIの「Installed」「Login成功」「Operation completed」を混同しない。次の層を実機で確認する。
3. 先に配布IPAそのものを検査する。検査用の小さいバンドルだけで完了としない。
4. 新しいIPAはファイル名・ソースcommit・ハッシュを区別する。全版が0.7.0/0700を表示し得るため、版表示だけでは個人改修を識別できない。
5. 固定ソースに狭いパッチを当て、既存認証・証明書管理を変更したかどうかを証拠で確認する。
6. ②の既存鍵再利用では、鍵を持つこととApple側の証明書が一致することの両方を検査する。ラベル一致や証明書だけでは署名できない。
7. 接続番号の変化を証明書問題と誤診しない。再接続エラーだけで再ビルドしない。

## 他の選択肢を採らなかった理由（調査時点）

- Sideloadly 0.71.0のWatch対応は有料Developer Program向けと公式変更履歴に記載。無料アカウントという今回の条件から採用しなかった。将来版の状況は再調査する。
- Xcodeからの直接導入は本人のMacが必要となるため採用しなかった。CIのMacで未署名IPAを作るのは別の工程。
- Wi-FiでのWindows更新や②の自動化は候補だったが、今回実機で確認した通常運用は①。候補を成功済み手順に書き換えない。
- 参考の市販ゴルフアプリを購入する方法は自作Fairwayとは別の選択肢。購入や配布はしていない。

## 詳細調査と証拠へのリンク

- [最初の親子IDエラー](../SIDESTORE_WATCH.md)
- [Watch署名の調査](../WATCH_SIGNING_STATUS.md)、[SideStore改修の検討](../SIDESTORE_WATCH_FEASIBILITY.md)
- [初期19件と実IPA検査](../WATCH_RECHECK.md)、[初期ビルド結果](../WATCH_PERSONAL_RESULTS.md)
- [認証エラーの調査](../ILOADER_AUTH_INVESTIGATION.md)、[Windows認証版](../WATCH_AUTH_LOADER_RESULTS.md)
- [証明書上限と鍵再利用](../WATCH_LOADER_CERTIFICATE_REUSE.md)
- [①への切替](../WATCH_SIDESTORE_MIGRATION.md)、[pairing曖昧判定の修正](../WATCH_PAIRING_IMPORT_FIX.md)
- [profile診断版](../WATCH_PROFILE_DIAGNOSTICS.md)、[最終Platform対応](../WATCH_IOS_FAMILY_PROFILE_FIX.md)

これらは過去時点の記録。現在の実機確認状況は[入口](README.md)と[state.json](state.json)を参照する。

## 追加: 0.4.0の新規Watch導入失敗（2026-10-25〜26）

0.4.0はSideStoreでiPhoneへ入ったがWatchへの導入は失敗し、Watchアプリはなくなった。0.3.0のRefresh後起動は、それ以前に②で入れたバイナリだった可能性を除外できない。利用者は②でのFairway入れ直しを希望せず、①で導入・自動更新する目標を明示した。

Astraで独立に調査方針と接続寿命をレビューし、Solで署名差分を点検、非破壊Rust接続probeを実装した。成功LoaderとSideStoreの直接転送処理の差は確認できたが、RSDトンネルから返却ポートへ届くかは実機ゲート。共有接続を借りる案は並行heartbeatとの解放競合のため、専用の独立接続に変更した。[今回の調査](WATCH_INSTALL_0.4.0.md)と[通信診断](CONNECTION_PROBE.md)を参照する。
