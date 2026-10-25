# Watch対応SideStoreとFairway最小版の導入

**2026-10-25の最終到達点：利用者が改修版SideStoreからの導入と手動Refresh後のWatch起動に成功。最新の手順は[再利用用の運用手順](docs/watch-sideloading/OPERATIONS.md)を参照。以下は初期検証時の手順で、当時の未確認事項や旧IPA名が残っています。**

2026-10-25追記：SideStoreの改修と別の選択肢として、Windows用の「Fairway Watch Loader」試験版も作成しました。認証更新後に証明書上限7460が報告されたため、[元の署名鍵の照合・再利用版](docs/WATCH_LOADER_CERTIFICATE_REUSE.md)を追加しました。この別経路では、iPhoneのSideStoreを更新せず、Windows側で新しくログインします。新版ZIPの「01_導入手順_既存証明書再利用版.pdf」に従い、Login後に「通常版iloaderの署名鍵を再利用」を押します。成功してからImport IPAへ進みます。以下は改修版SideStoreを使う場合の手順です。

この手順は、現在のSideStore 0.7系でFairwayのRefreshが成功している利用者向けの個人用試験経路です。Windowsと無料Apple Accountが前提です。実機でのログイン引継ぎ・Watch導入は未確認です。現在のSideStoreとFairwayは削除しないでください。

1. 完成した試験セットをすべて展開し、同梱の「01_Watch導入手順.pdf」を読みます。
2. 現在のSideStoreから `SideStore-Watch-personal.ipa` を、同じSideStoreの更新として導入します。別のSideStoreとして増える、削除やチーム変更が必要と表示される場合は進めません。
3. 更新後、ログイン状態とMy Appsが残っているか確認します。設定のDeveloper Portalに「Watch対応」が追加されます。ログアウトや証明書の無効化は行いません。
4. Windowsで `Fairway-WatchInfo.exe` を開き、USB接続したiPhoneにペアリングされたWatchのUDIDを読み取ります。Apple Accountのログインは不要です。値を公開したり作成者へ送ったりする必要はありません。
5. SideStoreの「Watch対応」でWatchのUDIDを入力し、登録を確認します。シリアル番号やiPhoneのUDIDとは異なります。
6. 改修版SideStoreの＋から `Fairway-0.3.0-unsigned.ipa` を導入します。以前のアカウントID専用修正IPAは使用しません。
7. iPhoneのWatchアプリからFairwayをインストールし、Watchでの起動・記録・同期を確認します。
8. 無料アカウントの期限が切れる前に、この改修版SideStoreからRefreshします。Watchを含むアプリは個別署名を含む再導入を行う設計です。更新後のWatchでの起動も別途確認が必要です。

認証情報が失われる、証明書の無効化を求められる、Watchだけが整合性エラーになる場合は、その段階で結果を確認します。iPhoneへの導入成功だけではWatchへの導入成功とは扱いません。パスワード・証明書・秘密鍵・ペアリングファイルを送らないでください。

初めてSideStoreを入れる人への初期設定は[公式手順](https://docs.sidestore.io/docs/installation/install)を参照します。この試験経路は、既存SideStoreの認証を利用するため、未導入端末へ無条件にそのまま適用できるとは限りません。

[0.2.0の旧手順](docs/INSTALL_0.2.0_ARCHIVE.md)は過去版の記録です。GPS・地図は今回の0.3.0にはありません。
