# SideStoreのWatch対応改修を再現する

対象は[入口に記録した成功構成](README.md)。現在のupstreamへ無条件にパッチを当てる手順ではない。固定版で再現した後、新版へ移植する場合は差分を読み直す。

## 固定ソースと主なファイル

| 対象 | 固定コミット / 参照 |
| --- | --- |
| SideStore | `d97ec133719d79916675bdaf722b82a8d091d545` |
| SideSign | `752d1ef602aa792a432ffa1e71646dc1ecf7363c`。SideStoreのsubmoduleを確認 |
| 成功した改修のビルド対象 | Fairway repo `c61107c80a8121f27f4f39e0dd8cc6e3b91e7cf9` |
| パッチ入口 | [apply.py](../../tools/watch-support/apply.py) |
| Watch探索・ID・profile検査・Apple API | [WatchBundleSupport.swift](../../tools/watch-support/SideSign/WatchBundleSupport.swift) |
| Watch UDID設定・現行証明書照合 | [WatchSupportSettings.swift](../../tools/watch-support/SideStore/WatchSupportSettings.swift) |
| 回帰検査 | [WatchSupportTests.swift](../../tools/watch-support/SideSign/WatchSupportTests.swift) |
| ビルド | [sidestore-watch.yml](../../.github/workflows/sidestore-watch.yml) |
| IPA・対応ソースの包装 | [package.py](../../tools/watch-support/package.py) |
| ダウンロード後の照合 | [verify_pairing_build.py](../../tools/watch-support/verify_pairing_build.py) |

## 改修する7つの接続点

1. **Watchを探索する**：`Host.app/Watch/*.app`を読み、元の親子IDとシンボリックリンクの逸脱を検査する。配下のWatch拡張も署名対象に含める。
2. **Watchを登録する**：既存SideStoreのsession/teamを使い、`DTDK_Platform=watchos`で端末登録・照合する。別ログインや証明書取消で回避しない。
3. **Watch用profileを取得する**：Watch子IDを別App IDとして照合・作成し、Watch指定で`downloadTeamProvisioningProfile`を呼ぶ。iPhoneのprofileを子へ流用しない。
4. **親子IDを同時に書き換える**：iPhoneの実際の再署名後IDを基準に子ID・WKCompanionAppBundleIdentifier・旧式拡張のWKAppBundleIdentifierを更新する。単なる全ファイル文字列置換をしない。
5. **Watchを個別署名する**：子profileと子entitlementsで署名する。Watch内のframework/dylibに実行アプリのentitlementsを配らない。対応するprofileがなければ止める。
6. **Refreshを再署名・再導入へ切り替える**：通常のiPhone向けprofile注入でWatchの期限更新まで済んだと扱わない。
7. **統合pairingを方式指定で読む**：ファイルの事前解析にもpreferredを渡し、保存後の優先方式を保持する。初期設定に方式選択を追加した。

apply.pyは既知の置換元がちょうど1回現れることをassertする。失敗はupstreamの差分を確認する合図であり、assertを外して続行しない。

## Platform判定で再発させないこと

実機で返されたprofileは`Platform = [iOS, visionOS]`だった。旧実装の`watchOS`文字列必須条件だけが不一致となった。
[Apple公式](https://developer.apple.com/help/account/provisioning-profiles/create-a-development-provisioning-profile)でもiOS App DevelopmentはwatchOSを対象に含む。

現在の実装要点（完全な実装は上記Swiftファイルを参照）：

```swift
let normalized = Set(platforms.map { $0.lowercased() })
let watchPlatform = normalized.contains("watchos")
let scopedIOSFamily = allowIOSFamily && normalized.contains("ios")
    && normalized.isSubset(of: Set(["ios", "xros", "visionos"]))
// !watchPlatform && !scopedIOSFamily は WPF_PLATFORM として停止する。
// 続いてアプリID・team・Watch UDID・期限を照合する。
```

`allowIOSFamily`の既定値はfalse。Watch登録とWatch指定profile取得を行った`WatchSupportSettings.prepare`だけがtrueにする。取得したprofileの署名証明書が現在使用する証明書と一致することも別に必須とする。

Platformの表示と、そのprofileが許可するbundle/deviceは別の情報。iOS系表記の許可と、iPhone親アプリのprofileをWatch子アプリへ流用することを混同しない。

```swift
try WatchBundleSupport.validate(
    profile, bundleID: id, teamID: team.identifier,
    udid: udid, allowIOSFamily: true
)
guard profile.certificates.contains(where: {
    $0.serialNumberHex == certificate.certificate.serialNumberHex
}) else { /* エラーで停止 */ throw WatchSupportError.invalid("証明書が一致しません") }
```

「iOSと書いてあればすべてのprofileを許可する」「Platform検査を全削除する」へ広げない。tvOS/macOS/visionOS単独や不明な配列、違う端末・ID・team・期限を拒否するテストを維持する。

## Refreshの参考

実際にはapply.pyがPipelineRunner.swiftへ組み込む。概念だけを抜粋：

```swift
let operation: AppOperation
if case .refresh(let app) = requestedOperation,
   let host = ALTApplication(fileURL: app.fileURL),
   !((try WatchBundleSupport.applications(in: host)).isEmpty) {
    operation = .resign(app)
} else {
    operation = requestedOperation
}
```

これは既存pipelineのoperationを切り替える処理であり、独立してコンパイルできるコードではない。進捗UIの参照はrequestedOperationへ残す。上記だけ移植してprofile取得・子署名を省略しない。

## ペアリング読込の参考

```swift
func inspectPairingFile(from url: URL,
                       preferred: PairingProtocol? = nil) throws -> (...) {
    // security-scoped URLの開始・終了、データ読込も実装側に保持する。
    let parsed = try parse(content: content, preferred: preferred)
    // ...
}
// importPairingFileも事前検査へ同じpreferredを渡す。
```

これは説明用の省略コード。実装では`inspectPairingFile`と`savePairingFile`の両方へ方式を渡す。保存後に`preferredProtocol`を設定しないと、ファイルがInstalledでも起動時にどちらを使うか決められない。

## GitHub Actionsで再作成する（利用者のMacは不要）

1. 当リポジトリの`.github/workflows/sidestore-watch.yml`をworkflow_dispatchで実行。
2. 固定SideStoreとsubmodulesをチェックアウトし、apply.pyを適用。
3. macos-26で`swift test --filter WatchSupportTests`を実行。成功版は26件。
4. Apple Accountなしで`make build`、`make fakesign ipa`。
5. IPA、対応する改修ソースZIP、build JSON、テストログをartifactへ保存する。
6. ダウンロード後にZIP/IPAとソースのハッシュ・実装・ログを照合する。artifactの保持期限内にローカル保存する。

本件の公開repoとCI実行は利用者が許可した。他の案件で、同じ前提でソースを新規公開したり、費用が発生し得るrunnerを選んだりしない。認証情報をCIへ入れて実機署名する必要はない。

## Macで同じ処理を再現する例

Fairway repoのルートで実行。ネットワーク・Xcode・Swift・make・Homebrewを用意する。以下は未作成の`build/SideStore`から始める例。既存の作業ツリーを消して合わせない。

```bash
git clone https://github.com/SideStore/SideStore.git build/SideStore
git -C build/SideStore checkout d97ec133719d79916675bdaf722b82a8d091d545
git -C build/SideStore submodule update --init --recursive
git -C build/SideStore/Dependencies/SideSign rev-parse HEAD
# 752d1ef602aa792a432ffa1e71646dc1ecf7363c と一致すること。
python3 tools/watch-support/apply.py build/SideStore build/SideStore/Dependencies/SideSign
brew install ldid
export FAIRWAY_TEST_IPA="$(pwd)/tools/watch-support/fixtures/Fairway-0.3.0-unsigned.ipa"
(cd build/SideStore/Dependencies/SideSign && swift test --filter WatchSupportTests)
(cd build/SideStore && make build && make fakesign ipa)
python3 tools/watch-support/package.py build/SideStore
```

実行の正本はworkflow。26件検査には実Fairway IPAの親子ID書換え・ネストした署名・全architectureのcodesign検証も含む。合成profileと一時証明書による検査を、Appleの実機profileの発行・Watchの受入れ・期限更新成功と混同しない。

`verify_pairing_build.py`はこのrepo専用：固定bundle ID、手元の原版AuthManager/CertificateManager、既知テスト件数とコード文字列を検査する。他repoへ移すときは前提を更新する。汎用IPA検査には[inspect_ipa.py](examples/inspect_ipa.py)を使う。

その原版比較先は`build/watch-sidestore/SideStore/SideStore/Core/`内の2ファイル。新規cloneでは存在しないため、固定したSideStore refから原版を用意して照合するか、確認した原版パスへツールを移植する。ファイル不足を理由に比較条件を削除しない。

## 他アプリへ適用するときの境界

- 対応確認済みは1つの現代的なWatchコンパニオンを含むFairway。Watch-only、複数Watch apps、旧WatchKit拡張、complication/widget、App Groups、iCloud、HealthKit、pushなどは別途検査する。
- コードはWatch拡張と旧式親子キーも扱うが、すべてを実機で通したという意味ではない。
- App ID・entitlements・capabilityはprofileと一致させる。profileを無視したentitlementsの追加で機能を有効化しない。
- 通常版へ自動更新すると改修がなくなる可能性がある。更新するSideStoreのsource diffとWatch pipelineを先に確認する。
- SideStore/SideSignの改修と配布は[元の出典・ライセンス](../../tools/watch-support/SOURCE.md)に従い、対応ソースと原著作権表示を同梱する。Windows LoaderのMIT系fork・依存ライセンスとは分けて扱う。
- 上流へ投稿・PR・問い合わせは今回行っていない。再利用が上流への送信許可を意味するわけではない。
