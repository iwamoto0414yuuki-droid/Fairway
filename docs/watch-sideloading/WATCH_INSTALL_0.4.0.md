# 0.4.0のWatch導入失敗とSideStore経路の調査

更新日: 2026-10-25。診断途中。実機復旧済みという意味ではない。

## 利用者の目的・現在地

- Fairwayを改修版SideStore経由で導入し、iPhoneだけで自動期限更新する。
- Windows Watch LoaderでFairwayを入れ直す方法は採らない。成功実装の比較資料として利用する。
- 0.4.0のiPhone導入後、Watchアプリからの導入が `This app couldn't be installed at this time.` で失敗。Watch上にFairwayはない。
- 過去の0.3.0は①でRefresh後にWatch起動の報告がある。ただし先に②でWatchへ導入済みだった。Watchのバイナリが①で置き換わったこと、旧署名の期限後の起動、自動Refreshの実行成功は証明されていない。

## 固定成果物の比較

対象IPAのハッシュはstate.jsonを参照。未署名0.3.0と0.4.0のiPhone・WatchのInfo.plistを比較した。差分はバージョンとビルド番号のみ。Watchのarm64_32/arm64スライス、親子ID、対象OS・端末条件は同じ。

これは未署名IPAの比較であり、SideStoreが端末内で作成した署名が正しい証拠ではない。

## 実装上の差分

### 署名の証明書チェーン

SideSignのKeyStoreは証明書1枚をP12へ出力する。しかし固定依存CodeSignKit `d0c67710fda9a2646b9e829cb2cf443892728371` の `Sources/CMSSigner.swift` は中間証明書がP12にない場合、組み込みWWDR G3とApple RootをCMSへ追加する。

したがって「KeyStoreにチェーンがないので署名にもない」という仮説は、ソース確認で棄却した。別の署名差分がないと断定したわけではない。

### Watch本体へ導入する処理

成功したLoaderの固定ソース `Rzbck/isideload@06248a85a1b34ab6278b8849474bef6cc798dcf6` には `isideload/src/sideload/watch_install.rs` があり、iPhoneへの導入後に次を行う。

1. 新しいcompanion_proxy接続でWatchのlockdownを転送。
2. Watchとpair/sessionを確立。
3. Watchの `com.apple.streaming_zip_conduit` を転送。
4. 再署名済みWatch.appをPayload付きストリームで送信。
5. Watchが返す `DataComplete` まで待つ。

固定SideStoreの `InstallAppOperation.swift` はiPhoneへのIPA/appBundle導入で完了し、現行の個人用パッチにもWatchへの直接転送はない。この差分は確認済み。ただし今回の実機エラーがこの差分だけで説明できるかは未確認。

Loader実装には既存Watchアプリを削除する処理もあるが、期限更新でそのまま移植してはいけない。Watch側データ保持・再同期を壊さない更新処理が必要。iPhone導入だけの成功をWatch更新成功として保存してはいけない。

## 次に確認すること

- SideStoreが使うMinimuxer/IDeviceのRemote Pairing経路からcompanion_proxyと転送先ポートを利用できるか。
- 成功したLoaderが指定するServiceNameと、固定IDevice C APIの転送引数の違い。
- Watch選択をUDIDで照合し、別のWatchへ誤転送しないこと。
- 初回導入とRefreshの両方でWatchの導入結果を待ち、失敗を利用者に返すこと。
- 実機ではWatch新規導入、バージョン確認、手動Refresh、自動実行、旧署名期限後の起動を別々に記録する。

実機のpairing file・秘密鍵・profile・端末IDを公開ログへ出さない。
