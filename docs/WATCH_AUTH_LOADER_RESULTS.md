# Watch対応iloader 認証更新版のビルド結果

2026-10-25。個人用・非公式の試験版。Windowsと無料Apple Accountで試す導入候補を追加した。本人アカウントでの認証、Watch登録・導入・期限更新は未確認。

## 成果物

- 名称：Fairway Watch Loader。
- WindowsポータブルEXE。インストーラーなし。Windowsコード署名なし（このPCでもNotSignedを確認）。
- ファイル版：2.3.1-auth.20261025.1。このPCでEXEの版情報を読み取り確認。
- EXEサイズ：24,148,992 bytes。
- EXE SHA256：`00f9a52dbcea02dbaf7a33afd07d2930abd7d6b4c872ee436e9229d78c9faa81`。
- 対応ソースZIP SHA256：`4c0668c877ffcf6122db2cf68c35f4c1bddd24ef7402b0df6ffafc55db909637`。
- [成功したCI run 40161976600](https://github.com/iwamoto0414yuuki-droid/Fairway/actions/runs/40161976600)。
- ビルド対象のFairwayリポジトリのコミット：`631e82affeb8bb376cb83b4c3d7dc856627223d6`。
- GitHub成果物ZIPのSHA256：`ee4134c07e9df87d6cf414a4119a1547991d2dbe3311dac7a921effd4d336f2c`。取得後にGitHubの値と照合。

## 変更と確認

- 選択中のAnisetteサーバーからclient_infoとUser-Agentを取得し、同じ認証セッション内では同じ組を使う。
- 不正な空値・改行・過大なヘッダー・HTTPエラー・JSON不正は停止。古い固定文字列には戻さない。
- ADI準備状態が拒否された場合は、回数を制限して準備をやり直す。無関係なエラーでは初期化しない。
- 確認コードが先に届くhsc=409の2FA形式に対応する判定を追加。
- 通常版とは別のアプリID・keyringサービス名・保存領域を使う。ADI状態はサーバー別に保存。
- 証明書の上限時は自動取消を行わずエラーとして停止。認証ボタンの処理はログインとXcodeトークン取得までで、署名・導入はImport IPAの操作から。
- 通常版への自動更新を停止。FairwayのIPA選択に絞り、SideStore／LiveContainerのインストールボタンを画面から除外。
- Watch用の登録・署名・転送の元コードは変更前後のハッシュが一致。取得した対応ソースZIP内のハッシュも照合済み。

## テスト結果

Windows CIで24件成功、失敗0、無視0。

- Anisette準備・復旧・キャッシュ：6件。
- サーバー情報取得・検証・サーバー別保存：8件。
- 2FA応答の判定：7件。
- 元からあるWatchのプラットフォーム指定・URL・親子ID書換え：3件。

ネットワークを使う単体検査はローカルHTTPサーバー、認証データは合成値。Appleへの実アカウントのログイン試験ではない。

EXEのビルドに成功。さらに同梱対象のEXEをCIで実際に起動し、プロセスが継続してFairway Watch Loaderのウィンドウタイトルが現れることを確認。ログイン操作や端末接続は行っていない。この利用者のPCでGUIを起動したとの記録ではない。

公開Anisetteメタデータも別に確認し、2026-10-25 04:29 UTCの時点で初期サーバーを含む4か所がHTTP 200。これはAppleへのログイン成功を意味しない。

## 対応ソースとライセンス

アプリの元：Rzbck/iloader `09332620405e321936b25f0f381256bde08e4f86`。
ライブラリの元：Rzbck/isideload `06248a85a1b34ab6278b8849474bef6cc798dcf6`。
認証の参照：nab138/isideload `065e852b2092f1386c88195ea3a6506f6b917742`。

対応する改修済みソース、Cargo.lock、元のライセンスと個人用パッチを同梱。Rust依存701件、npm依存50件のライセンス情報を生成し、MPL／GPL系として検出した依存7件の対応ソースも含めた。上流の公式リリースや推薦を意味しない。

## Fairwayと次の実機確認

Fairway 0.3.0のIPAは変更していない。SHA256は`1b3e3c21f3f21ce2e7fb716c14bcc35f52a4200cbf0e7e6e88c97e31e15d572e`。既存の38件のネイティブテストに合格した同じIPAを同梱する。

同梱PDFの2ページ目から、まず「認証を確認（Login）」だけを実行する。成功したら、USBでiPhoneを選択し、元のFairway IPAを導入する。Watchでの起動・スコア保存・同期・次回更新後の起動まで確認する。今回の検証でこれらの実機成功を確認したとは扱わない。
