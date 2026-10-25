# ②のWatch Loaderから①の改修版SideStoreへ切り替える検証

2026-10-25。②でFairwayのインストールとWatch起動に成功した後の手順。
①での引継ぎ・更新は未確認。②の成功を①の成功とは扱わない。

以前の①の手順書にある「最初にFairwayをRefresh」は、現在の状況では実施しない。
通常版SideStoreによるFairwayの更新で、②で成功したWatch署名を置き換えないため。
この検証で最初に行うのはSideStore本体だけの更新。

## 残しておくもの

- iPhoneとWatchのFairway。削除しない。
- 現在のSideStore。削除・ログアウトしない。
- 成功した②のWindows版Loaderと元のFairway IPA。復旧用として保存。
- 現在のスコア。大事なものはiPhoneとWatchで表示してスクリーンショットを残す。

②で元の署名鍵と証明書を再利用できたことは有利だが、SideStore内部の証明書が同じとはまだ断定できない。
既存のWatch登録はやり直し不要な可能性があるが、①でも現在のアカウント・Watch UDID・プロファイルを照合する。

## 第1段階：SideStore本体だけを更新

1. iPhoneで現在のSideStoreが開くことを確認する。FairwayのRefreshやRefresh Allはまだ押さない。
2. 配布済み「Watch対応SideStore_Fairway最小版_追加検証セット」のSideStore-Watch-personal.ipaを、iPhoneの「ファイル」へ保存する。
3. LocalDevVPNを接続し、SideStoreのMy Appsの＋から、そのSideStore-Watch-personal.ipaを選ぶ。
4. 今あるSideStoreへの上書き更新として進める。別アプリが増える、アプリID・署名チームの変更、証明書の取消や削除を求める表示が出たら停止する。
5. 更新後にSideStoreを開き直す。元のログイン状態・My Appsが残ることを確認する。
6. 設定のDeveloper Portal内に「個人用Watch試験版」→「Watch対応」があることを確認する。

この段階ではFairwayを更新しない。「Watch対応」画面が出たかと、エラーがあればその文を確認してから次へ進む。
パスワード、秘密鍵、証明書、ペアリングファイルをチャットへ送らない。

## 第2段階：Watchの照合とFairwayの引継ぎ

第1段階が成功してから実施する。

1. 必要なら同梱のFairway-WatchInfo.exeで、USB接続したiPhone経由でWatchのUDIDを表示する。表示した値は公開しない。
2. SideStoreの「Watch対応」へWatchのUDIDを入力し、「Watchの登録を確認」を押す。同じApple Accountを使う。
3. 大事なスコアを控えた上で、改修版SideStoreの＋から元のFairway-0.3.0-unsigned.ipaを選び、既存アプリへ上書きする。ID専用修正IPAは使わない。
4. 別のFairwayが増える、ID・チームの変更や削除を求める場合は停止。既存データの自動移行は保証しない。
5. iPhoneとWatchで起動・スコア保持・同期を確認する。既存Watchアプリを先に削除しない。

## 第3段階：スマホだけでの更新を検証

1. 手動でFairwayだけをRefreshする。改修版はWatchを含む場合に再署名・再導入する設計。
2. iPhoneだけでなくWatchでも起動・保存内容を確認する。
3. 古い署名の期限を過ぎてからもWatchで起動できるか確認する。Refresh直後の起動だけでは期限延長の証明にならない。
4. 手動更新が確認できた後にバックグラウンド更新を試す。自動更新はまだ保証しない。

①に切り替えても、更新の実機検証が済むまでは②のLoaderを残す。
①でエラーが出た場合、削除や証明書取消をせず、成功した②から同じアカウントと元IPAで上書きする復旧を検討する。
