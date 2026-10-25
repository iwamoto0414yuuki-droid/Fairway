# Watch導入方法の再点検（2026-10-25）

## 判断

自作Fairway・無料Apple Account・Windows・既存SideStore認証を維持する、という条件では、個人用SideStoreの改修を検証する方針を継続する。ただし、実機成功を確認できた方法でも、成功率を比較できた「最善」の方法でもない。実機で残る段階は下記の通り。

ゴルフの記録をWatchで使うことが目的で、買い切りアプリを購入してよい場合は、参考アプリそのものをApp Storeから導入する方が手順・更新の負担は小さい。自作Fairwayの配布とは別の選択肢になる。

その後の[iloader認証の詳しい再調査](ILOADER_AUTH_INVESTIGATION.md)で、以前のWatch派生版が10月の認証修正へ追従していないことを確認した。Watch対応と新しい認証処理を組み合わせることは、別の開発候補になる。修正版EXEの作成・実アカウントでの成功はまだ確認していない。

## 別の方法との比較

| 方法 | 今回の条件での評価 | 確認・試行の範囲 |
| --- | --- | --- |
| 改修版SideStore | 今の認証を使える設計。無料Watch profileをAppleから取得できるか、実機導入・更新が通るかは未確認 | オフライン署名検査、Mac上のビルド、Windows補助EXEの自己検査。Appleへの実機登録は行っていない |
| 公式iloader 2.4.0 | 認証方法の改善はあるが、そのまま今回のWatch問題を解消する根拠は得られなかった | 公式リリースと現行ソースを確認。バンドル探索はPlugIns/Frameworksで、Watch用登録・親子ID書換えの追加が必要と判断。利用者にログインの再試行は求めていない |
| 以前試したWatch対応iloader派生版 | 作者に実機成功の報告はあるが、今回の利用者環境では認証エラーで止まった | 利用者の実際の試行結果は失敗。公式最新版とWatch派生版を混同しない |
| Sideloadly 0.71.0 | 現行Watch対応は有料Developer Program向け。無料アカウントという条件を満たさない | 公式変更履歴に明記。無関係なインストールや課金は実施していない |
| Xcodeから導入 | Macが必要なので、Windowsのみの条件から外れる | 今回は採用しない |
| 参考アプリをApp Storeから導入 | 打数・パット・ギア記録を提供。自作にこだわらない場合の有力候補 | 公式サイトとApp Store掲載を確認。公式サイトは490円買い切りと記載。実際の購入価格は端末の日本ストアで確認。購入・実機導入は実施していない |

## 今回強めた検証

従来の18件は小さい検査用実行ファイルを使った署名検査を含むが、配布したFairwayそのものを再署名した試験ではなかった。この差を埋めるため、追加テストでは配布済みの0.3.0 IPAをハッシュ照合して取得し、次を検査する。

1. 実IPAを展開し、iPhoneのIDへテスト用チーム文字列を追加する。
2. インストール処理と共通のヘルパーでWatchの親子関係を更新する。
3. 一時生成した検査用証明書と合成profileで、実際のSideSign署名処理を実行する。
4. Watch専用entitlements、ネストした署名、リソースの封印をAppleのcodesignで検査する。
5. `--all-architectures`で全形式を検査し、Series 7に必要なarm64_32とarm64が残ることを照合する。

検査用証明書・合成profileはAppleに承認された実機用署名ではない。検査後のIPAを実機用として配布しない。

Windows補助EXEは、このWindows PCでも`--self-test`が終了コード0で通過した。依存モジュールとパーサーの検査であり、USB経由で実機のWatch UDIDを読めた証明ではない。

このPCのApple USBサービスに読み取り専用の端末一覧要求も行った。サービスには接続できたが、USB・ネットワークとも端末は0台だったため、今回ここから実機のWatch情報読み取りや導入を試すことはできなかった。端末ID、信頼情報、認証情報は取得・出力していない。

既存認証の保存に関係するAuthManager、Keychain、CertificateManagerは元ソースから変更していないことを照合した。同一の更新先アプリID・チーム・keychainアクセス権で導入されることは実機で確認が必要。

## 使いやすさと電池

FairwayはHealthKitの運動セッションを動かさず、画面を常時表示する処理も持たない。参考アプリの「常時起動」と同じ挙動ではない。Watchの設定→一般→時計に戻る→Fairway→カスタム→1時間後を選ぶと、再操作時にカウンターへ戻りやすくできる。これは画面を1時間点灯し続ける設定とは異なる。実際の電池持ちはラウンドで未計測。

## 実機でまだ必要な確認

1. 現在動いているSideStoreを削除せず更新し、アプリ一覧とログイン状態が残ること。
2. Watch UDIDを読み、現在の認証でWatch登録・専用profile取得が成功すること。
3. iPhoneのWatchアプリからFairwayが入り、Watchで起動・スコア保存・クラブ記録ができること。
4. iPhoneへ記録が同期し、Watchを再起動しても保存内容が残ること。
5. FairwayをRefreshした後にもWatchで起動でき、Watch側の期限が更新されること。

この5段階を実機で通過するまでは「導入成功」「無料で確実に使える」とは扱わない。

## 一次資料

- [Sideloadly公式変更履歴](https://sideloadly.io/changelog)
- [公式iloader 2.4.0](https://github.com/nab138/iloader/releases/tag/v2.4.0)
- [公式isideloadのバンドル探索](https://github.com/nab138/isideload/blob/main/isideload/src/sideload/bundle.rs)
- [Watch対応派生版の作者による検証報告](https://github.com/Rzbck/iloader-watch-companion)
- [参考アプリの機能・価格説明](https://golfscorecounter.jp/)
- [参考アプリのApp Store掲載](https://apps.apple.com/app/id1453327924)
- [Apple：時計に戻るまでの時間](https://support.apple.com/ja-jp/guide/watch/-apd748b87e2a/watchos)
