# SideStore内からWatchへの通信を診断する

目的はSideStore経由のWatch導入・自動更新を実現すること。この診断は、そのために必要な通信経路がiPhone内から使えるかを確認する。**導入を直した完成版ではない。**

## 判断と分担（2026-10-26）

Astraの独立レビューで、成功Loaderの処理を丸ごと移す前に、RSD経由の転送ポートへ実際に届くかを確かめる方針を採用した。成功Loaderは転送前に既存Watchアプリを削除していたため、「転送処理を足すだけで削除なし更新が成功する」とも断定できない。

Solの署名点検では、新たな確定不具合は見つからなかった。テストが本番の親子ID書換え処理を迂回していたため、本番署名前にも書換え後の親子IDを照合する検査を追加した。

## 実装と検証の範囲

- `tools/watch-support/idevice/WatchConnectionProbe.rs`: 型付きRust内部APIでRSD→companion registry→ServiceName付き転送→転送先接続→Watch実ID照合を実行。
- `WatchConnectionProbe.swift`: 通常更新・heartbeatと別のgateway/接続を所有。共有native handleを借りたり解放したりしない。
- `apply_connection_probe.py`: 固定ソースへ適用し、設定のWatch画面に診断ボタンを追加。
- `.github/workflows/sidestore-watch-probe.yml`: 固定ideviceからiPhone用native libraryを作り、Rust単体テスト、既存の署名テスト、SideStore実機用アーカイブを実行。

Watchへのpair/session、アプリ送信、導入、削除、証明書変更は診断に含まない。確認のため一時的にWatch lockdownの転送ポートを開き、終了・失敗時に解除する。転送は端末のサービスなので、診断中は他のWatch導入ツールを併用しない。

## 実機で行うこと

ビルド成功・成果物検査後の診断版SideStoreを使用する。既存SideStoreやFairwayの削除、サインアウト、証明書取消は不要。現行のRemote Pairing設定とWatchのUDID設定を使う。

1. iPhoneでいつものVPNを有効にし、Watchを近くに置いてロック解除する。
2. 診断版SideStoreの設定内にある「Watch対応」を開く。
3. 「Watch通信を診断」を1回押す。通信処理の制限は約60秒、接続準備等に少し時間が加わる。
4. 表示された `WCP_` の結果だけを共有する。UDIDやpairing fileを送る必要はない。

## 結果の読み方

| 段階 | 確認内容 |
| --- | --- |
| WCP_INPUT | 入力・native接続引数の形式 |
| WCP_SERVICE | RSD上にcompanionサービスがある |
| WCP_REGISTRY | 設定と一致するWatchが1台だけ登録されている |
| WCP_FORWARD | Watch lockdownの転送要求が受理された |
| WCP_CONNECT | 返されたポートに同じRSDトンネルから接続できた |
| WCP_IDENTITY | 接続先のWatch自身が返すIDも一致した |
| WCP_CLEANUP | 一時転送を解除できた |

`passed=true code=OK` が成功。`FAILED` はその段階の失敗、`TIMEOUT` は時間切れ、`NOT_RUN` は前の段階で止まったことを表す。公開結果に実ID、秘密鍵、raw plist、上流の自由文エラーは含めない。

全段階成功でも、Watchへの導入や期限更新が成功した証拠にはならない。次はWatch側pair/sessionとzipサービス到達、その後に削除なし導入、最後に手動・自動Refreshと旧署名期限後の起動を検証する。どこで失敗したかに基づいて次の実装を決める。
