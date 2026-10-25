# Watch対応iloaderの認証失敗の調査

確認日：2026-10-25。対象は、利用者が提示した3種類のエラーログ、配布したWatch派生版の固定ソース、上流の修正履歴。Apple Accountへの新しいログイン試行は行っていない。

## 結論

Watch対応版の認証実装が、10月以降のApple認証・Anisetteの変更に追従できていないことが有力。9月の503修正を入れた版でも、クライアント情報は固定値で、サーバーに拒否されたAnisette状態の自動復旧もない。

一方、利用者の最後の`-80045`について、Apple側が何を理由に拒否したかまでは確定できない。公開メタデータの不一致と上流の修正・成功報告はあるが、同じ実機・同じアカウントで新旧認証処理を比較した結果はない。

以前用意した「503修正版」は、9月の一つの認証不具合を直したものだった。10月の変更まで反映した最新版ではなかった。この区別を前回の説明で十分に明示していなかった。

## エラーごとの切り分け

| エラー | ログとコードが示す場所 | 判断と確度 |
| --- | --- | --- |
| `not provisioned (-45061)` | Anisetteサーバーの`/v3/get_headers`で、保存済みADI状態からヘッダーを作れない | 準備状態が拒否されたことは確認できる。サーバー側の状態変更か、古い保存状態か、その組合せかはログだけでは区別不能 |
| HTTP `503` at `GsService2` | Appleへの最初の要求。旧ソースはXcodeを名乗る固定ヘッダーを送っていた | 同じヘッダーによる503が上流で再現・修正されており、有力。単なる混雑と決めつけるべきではない |
| `Auth error -80045` | 修正版の`login_inner`内、SRPの`init`要求への応答 | Appleが初期要求を拒否。パスワードの証明、2FA、開発者チーム選択、Watch登録・署名には未到達。拒否の内部理由は未確定 |

`-45061`のAnisette準備と、Watchへ入れるためのprovisioning profile作成は別の処理である。

## 試した実体をログから特定できる

最初のログにはisideloadの`f7b9f3d`、最後のログには`06248a8`が含まれている。

- 最初のWatch版：isideload `f7b9f3da570edd6824c29680545e710846d07df5`。
- 503修正版：iloader `09332620405e321936b25f0f381256bde08e4f86`、isideload `06248a85a1b34ab6278b8849474bef6cc798dcf6`。
- 後者のisideloadの変更日は2026-09-10。差分は`get_client_info`のXcode文字列をakdへ変えた1行のみ。
- 画面に通常版iloader 2.4.0があっても、最後のエラーログが示す認証ライブラリはこの9月の派生版。ログの固定コミットと通常版の表示を分けて判断する。
- `C:\Users\runneradmin\...`はビルド環境のソース位置をエラーに埋め込んだもの。利用者のPCにそのフォルダーを作る必要はない。

## 503の修正が十分でなかった理由

9月の上流PR #11は、AppleがXcodeを名乗る`X-Mme-Client-Info`を拒否する現象を切り分け、akdへ変更した。Watch派生版の作者もWindowsで当時のログイン成功を報告している。これは当時の根拠がある修正だった。

しかし10月12日以降には、別の`-80045`が上流でも報告された。10月14日の公式コミット`d424b1786664f1b9b6b98dd70d5826b161c12f45`は、クライアント情報を固定値から`/v3/client_info`の取得へ変更している。上流issue #921には、この変更を含む構成・2.3.8での成功報告がある。報告者の環境での成功であり、今回のアカウントでの成功証明ではない。

確認した最新公式isideloadは`065e852b2092f1386c88195ea3a6506f6b917742`（2026-10-22）。`get_client_info`はサーバーが返す`client_info`と`user_agent`を使い、`-45061`を受けた際の再準備経路もある。

今回使った派生版は、その両方を持っていない。さらに作者の別のWatch対応固定版`d898f5f36a463b216fe5cfb2b8fa4073fa1e4b30`も、同じMac情報の固定値と、`-45061`自動復旧なしの実装だった。ブランチ一覧を再取得したが、前回の調査から更新された枝は見つからなかった。

## 今回実行した、認証情報を使わない検査

`tools/iloader-auth-diagnostics/public_anisette_check.py`で公開の`GET /v3/client_info`だけを取得した。OTP取得、Anisetteの新規登録、Appleログイン、署名、証明書変更は行っていない。

確認時刻：2026-10-25 03:41:35 UTC（日本時間12:41:35）。

| サーバー | HTTP | 公開された情報の概要 | 旧Watch版の固定値との一致 |
| --- | --- | --- | --- |
| `ani.sidestore.io` | 200 | MacBookPro13,2／macOS 13.1／CFNetwork 808.1.4 | 不一致 |
| `new.ani.sidestore.io` | 200 | MacBookPro13,3／Mac OS X 10.12.6／CFNetwork 811.5.4 | 不一致 |
| `ani.jkcoxson.com` | 200 | 同上 | 不一致 |
| `ani.iloader.app` | 200 | 同上 | 不一致 |

旧Watch版の固定値はMac15,7／macOS 27.0／CFNetwork 808.1.4。特に後ろ3か所はUser-Agentも異なる。

これにより「URLを変えても、旧版がAppleへ送るクライアント情報はサーバーへ追従しない」と確認できる。ただし、文字列の完全一致があらゆる場面で必須だと証明したものではなく、不一致だけで`-80045`の原因を確定しない。現在HTTP 200でも、過去の障害や、そのアカウント用のAnisetteデータが正常だったことまでは判断できない。

サーバーの「Mac」はサーバー側の生成方式・情報を示す。Windowsから利用できない、という意味ではない。旧版もV3の通信自体は使っており、「Mac系サーバーとプロトコルが全面的に非互換」とする説明は正確ではない。

## Anisette状態の再利用も影響し得る

旧版は保存済み`adi_pb`があるとそれを使い、サーバーから`-45061`が返っても通常のエラーとして止まる。新公式版はこれを`IncorrectlyProvisioned`として扱い、準備をやり直す回数制限付きの経路を持つ。

また、旧派生版と公式iloader 2.4.0の`secure_storage.rs`は、どちらもWindowsのkeyringサービス名`iloader`を使う。単に別フォルダーでEXEを起動しても、保存状態まで完全に分離されるとは限らない。今回、実際にどのADI状態が入っていたかは読んでおらず、共有が発生したと確定してはいない。

## SideStoreでRefreshできることと矛盾しない

調査したSideStoreの`AuthManager.getAuthenticatedSession`は、保存済みの認証トークンと新しいAnisetteデータから開発者サービス用のセッションを構成する。毎回パスワードを使ったSRPの初期要求からやり直す処理ではない。

そのため「今のSideStoreのRefreshは成功するが、別のiloaderで新規ログインは失敗する」は成立する。SideStoreとiloaderではAnisetteの生成元・設定が違う可能性もある。Refresh成功だけから、新しい認証要求も受け入れられる、あるいはアカウント単位の制限が絶対にないとは判断できない。

## WindowsローカルAnisetteという別案

上流issue #27には、従来版iCloud for WindowsのローカルAnisetteと、それに対応する端末情報、2FA処理の修正を組み合わせ、2台のiPhoneの署名に成功したとの報告がある。単にサーバーURLを変える方法ではなく、追加実装が必要になる。

今回のPCでは、その報告が前提とする従来版の標準配置の`AOSKit.dll`、`objc.dll`、`Foundation.dll`は見つからなかった。Windows全体・全バージョンでの不在を調べたわけではない。DLLの実行やiCloudログの読み取りは行っていない。現時点でそのまま試せる解決策とは扱わない。

## 次に修正・検証するなら

1. Watch対応処理を維持し、認証側へ10月以降の修正を取り込む。公式iloaderへの単純な置換だけでは、Watch登録・署名が加わるとは限らない。
2. `client_info`と`user_agent`を同じ選択サーバーから取得する。別の固定文字列へ置換して終わらせない。
3. 拒否されたADI状態を回数制限付きで再準備できるようにする。検証用の保存先を通常版と分離し、現在のSideStoreの認証は触らない。
4. 最初の実機試験はログインと必要なトークン取得までに限定する。署名証明書の作成・削除・無効化、アプリ導入は分ける。
5. サーバーと回線を固定し、認証修正版で試す。記録するのは失敗段階・HTTP状態・Appleエラー番号・時刻までとし、パスワード・トークン・OTPは記録しない。
6. 認証が通ってから、現在の証明書を使ってWatch登録・専用profile・署名・導入を確認する。

上記は原因調査時点の記録。その後、認証更新版のWindows EXEを作成し、24件のテストとCIでの起動検査に成功した。[ビルド結果](WATCH_AUTH_LOADER_RESULTS.md)を参照。利用者のアカウントでの認証成功やWatch導入はまだ確認していない。既存の改修SideStoreは変更していない。

## 一次資料・固定ソース

- [9月の503修正PR #11](https://github.com/nab138/isideload/pull/11)
- [Watch派生版の503修正差分](https://github.com/Rzbck/isideload/compare/f7b9f3da570edd6824c29680545e710846d07df5...06248a85a1b34ab6278b8849474bef6cc798dcf6)
- [旧版の初期要求とパスワード証明の順序](https://github.com/Rzbck/isideload/blob/06248a85a1b34ab6278b8849474bef6cc798dcf6/isideload/src/auth/apple_account.rs#L675)
- [旧版の固定クライアント情報](https://github.com/Rzbck/isideload/blob/06248a85a1b34ab6278b8849474bef6cc798dcf6/isideload/src/anisette/remote_v3/mod.rs#L162)
- [10月14日のサーバー情報取得への変更](https://github.com/nab138/isideload/commit/d424b1786664f1b9b6b98dd70d5826b161c12f45)
- [上流issue #921：0.4.6／2.3.8の成功報告と、その後の障害報告](https://github.com/nab138/iloader/issues/921)
- [最新確認ソース：公開情報の取得と-45061の判定](https://github.com/nab138/isideload/blob/065e852b2092f1386c88195ea3a6506f6b917742/isideload/src/anisette/remote_v3/mod.rs)
- [最新確認ソース：再準備の回数制限](https://github.com/nab138/isideload/blob/065e852b2092f1386c88195ea3a6506f6b917742/isideload/src/anisette/mod.rs)
- [WindowsローカルAnisetteを使った実験報告 #27](https://github.com/nab138/isideload/issues/27)
- [SideStoreの保存トークンからのセッション構成](https://github.com/SideStore/SideStore/blob/d97ec133719d79916675bdaf722b82a8d091d545/SideStore/Core/Auth/AuthManager.swift#L99)
