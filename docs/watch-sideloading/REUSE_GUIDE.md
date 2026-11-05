# Apple Watchアプリ導入・期限更新：完成版の再利用手順

更新日: 2026-11-05。最初に README.md と state.json を読むこと。

## 確認済みの結果

利用者が無料Apple AccountとWindowsで初期導入し、改修版SideStoreからFairwayをiPhone・Watchへ導入した。その後、App Group修正版でFairwayのRefreshが成功し、Watchでも使用できることを報告した。これは利用者の実機報告であり、AIが端末を直接測定した結果ではない。

利用者は今回の目的の完了を宣言した。手動Refreshとその後のWatch起動は確認済み。自動更新の設定も報告済みだが、自動実行ログ、旧署名期限後の起動、他アプリでの実機成功は未確認として扱う。

## 成功した基準を取り出す

- Repository: https://github.com/iwamoto0414yuuki-droid/Fairway
- Build branch: `fairway-watch-direct-ci-20261104`
- 成功した実行コード: `cc13860`。文書更新コミットはこの後に追加される。
- CI: https://github.com/iwamoto0414yuuki-droid/Fairway/actions/runs/42030957798
- 最終IPA: `release/SideStore-Refresh-GroupFix-20261105/SideStore-Refresh-GroupFix.ipa`
- SHA256: `bac78a7feb5ca8f9b37fa58c917a3b8b9840353a6ffa2977a760a8f233978708`
- 対応ソース: 同じフォルダの `SideStore-Refresh-GroupFix-source.zip`
- テスト: Rust 8件、Swift署名回帰27件。Fairway本体0.4.0は既存44件。

IPAと対応ソースZIPはローカル保存済み。`release/`はGit管理外であり、GitHubのActions artifactは期限付き。GitHubにIPAが永続公開されているとは考えない。固定したコミット、上流pin、パッチ、ワークフローから再ビルドする。

## 利用者がiPhoneで行う操作

1. SideStoreを更新する場合、現在動くSideStoreの「My Apps」→「＋」で改修版SideStoreのIPAを選び、同じアプリへ上書きする。拡張機能の選択は成功した導入時と同じ「Keep App Extensions (Register App ID for Each Extension)」。別のSideStoreが増えた場合は継続せず識別子を確認する。
2. Wi-FiとLocalDevVPNを接続する。既存のApple Account、証明書、Remote Pairingを維持する。
3. 初回だけ設定の「Watch対応」でWatchのUDIDを登録する。新規端末で接続準備が必要なら、ロック解除したWatchを近くに置いて「Watchペアリングを準備」。既存の保存済みWatchペアリングは再利用される。
4. 「My Apps」→「＋」からiPhone版とWatch版を含む完全な未署名IPAを選ぶ。署名後にiPhoneへ導入し、その後Watchへ直接転送する。
5. 両端末で起動確認。「My Apps」で対象アプリの期限表示からRefreshし、完了後Watchでも開く。保存済みデータも確認する。
6. 再度Refreshし、同じ操作でIDが増えたりエラーが再発したりしないか確認する。自動更新は、手動成功後に設定と実行履歴を確認する。

Fairwayの削除・アカウント変更・証明書取消・ペアリング初期化を標準の復旧手順にしない。SideStoreの通常版への更新は独自Watch処理を失う可能性があるため、上流更新はパッチとの統合・検証後に行う。

## 別のアプリのIPAを作る

詳しくは APP_IPA.md と examples/project.yml、examples/build_unsigned.sh、examples/inspect_ipa.py を使う。

- iPhoneターゲットとWatchターゲットを用意し、iPhoneの `.app/Watch/` にWatch `.app` を埋め込む。
- Watchの `WKCompanionAppBundleIdentifier` は元のiPhone Bundle IDと一致させ、WatchのBundle IDは親配下にする。旧式のWatch extensionがあればそれも含める。
- 未署名の完全版IPAを作る。端末・証明書に依存するプロファイルや秘密鍵は同梱しない。SideStore側が現在のアカウントで専用プロファイル取得・署名を行う。
- 別アプリでは独自のBundle IDを使用する。同じアプリを更新する際はID・チームを維持する。
- アプリ独自のentitlements/capabilitiesが無料アカウントで利用可能か個別に確認する。Fairwayの成功をすべてのWatchアプリへ一般化しない。
- App Groupを使用するアプリはコンテナIDの変更でデータが見えなくなる場合がある。FairwayはApplication Supportの `rounds-v1.json` に保存するため、今回のApp Group補正とは保存場所が異なる。他アプリへ補正規則を無条件に拡張しない。

## SideStoreを再ビルドする開発者向け手順

Windows上でXcodeは動かない。GitHub ActionsのMac runnerで `.github/workflows/sidestore-watch-probe.yml` をビルド用ブランチから手動実行する。ワークフロー名は履歴上probeだが、現在は直接導入と修正を含む完成基準のビルド。

固定上流:

- SideStore: `d97ec133719d79916675bdaf722b82a8d091d545`
- SideSign: `752d1ef602aa792a432ffa1e71646dc1ecf7363c`
- idevice: `3e55c8486b2057e40c1f74aaaa1155c82341cf76`

適用順（リポジトリルートから）:

```sh
python3 tools/watch-support/apply.py build/SideStore build/SideStore/Dependencies/SideSign
python3 tools/watch-support/apply_connection_probe.py build/SideStore build/SideStore/NativeIDeviceSource
python3 tools/watch-support/apply_watch_install.py build/SideStore build/SideStore/NativeIDeviceSource
python3 tools/watch-support/apply_refresh_diagnostic.py build/SideStore
python3 tools/watch-support/apply_group_refresh_fix.py build/SideStore
```

その後はワークフローに従い、`companion_proxy,pair` を有効にしたRustテスト・iOSライブラリ作成、Swift署名テスト、SideStoreアーカイブ、未署名IPAと対応ソースZIPの包装を行う。パッチは固定ソースの一致を検査するため、上流が変わった場合は強制適用せず差分を確認する。

## 再利用するコードと役割

| ファイル | 役割 |
| --- | --- |
| `tools/watch-support/apply.py` | Watch専用プロファイル・親子ID・個別署名、Refreshを再署名へ変換 |
| `SideSign/WatchBundleSupport.swift`（上記フォルダ内） | Watch登録、プロファイル取得と照合 |
| `idevice/WatchConnectionProbe.rs` / `.swift` | RSDからWatch本人へ接続する非破壊診断 |
| `idevice/WatchInstall.rs` | Watch専用pair/session、署名済みアプリ送信、DataComplete確認、転送解除 |
| `idevice/WatchInstall.swift` | 独立トンネル、共有直列キュー、Watch鍵のKeychain保存・再利用 |
| `apply_watch_install.py` | iPhone導入後、成功日時記録前にWatch導入を実行 |
| `apply_refresh_diagnostic.py` | どの署名準備段階で失敗したかをFWDIAGコードで表示 |
| `apply_group_refresh_fix.py` | 更新ごとのチームID重複追加を防ぎ、Fairwayの既知重複を補正 |

Watchのpairing file、秘密鍵、パスワード、実機UDID、実プロファイルをコード・資料・公開CIログへ保存しない。Watch信頼情報はiPhoneのKeychainに保存する。Remote PairingレコードをWatch LockdownのHostID/SystemBUIDとして流用しない。

## 試行錯誤と判断

1. 通常SideStoreでは親子Bundle IDの再署名とWatch専用プロファイルが不足していたため、専用取得・照合・署名を追加した。Watch profileのPlatformがiOS系表記でも必要条件を満たす例があり、Watch取得経路だけで許容した。
2. WindowsのWatch LoaderはWatch起動に成功したが、ログイン、証明書上限、USB再接続の問題があった。既存鍵を再利用し、証明書取消を避けた。PCを毎週使わない目的のため、最終経路はSideStoreにした。
3. iPhone導入成功・Watch起動だけでは、古いLoader版が残っている可能性を排除できなかった。Watchが消えた状態での直接導入へ進めた。
4. 接続診断のWCP 7項目が利用者の実機で全成功。これを根拠にWatch専用pair/sessionとstreaming zip転送を追加した。接続成功を導入成功と混同しなかった。
5. 利用者がSideStore経由のiPhone・Watch導入を確認。その後Refreshで `SideSign.ServerError 3` / Apple -1 が発生。再ログインでSideStore自身は回復したがFairwayは回復しなかった。
6. Watch登録確認は成功。Anisetteの切替でもFairwayは同じエラー。FWDIAGでiPhone側の署名準備に絞り、Console LogからApp GroupのチームID重複を発見した。
7. App Group変換を安定化し、Fairwayの重複を補正。利用者がRefresh成功と、その後Watchで使えることを確認した。

Apple -1だけでは原因は特定できない。App Group作成失敗は今回の実機ログで確認できた。Apple側の詳細な拒否理由は未公開として扱う。

## 次のAIへ渡す指示

```text
このリポジトリの docs/watch-sideloading/README.md、REUSE_GUIDE.md、state.json を読んでください。
Fairwayは最終修正版でSideStore経由の導入・手動Refresh・その後のWatch動作が利用者確認済みです。
古い失敗記録を現在の未解決状態として扱わないでください。
新アプリではBundle ID、Watch構成、無料アカウントのcapabilities、データ保存先を確認し、基準コードを再利用してください。
App GroupのチームIDをRefreshごとに追加する旧実装に戻さないでください。
アプリ機能のみの更新ではSideStore本体を再ビルドしないでください。
```
