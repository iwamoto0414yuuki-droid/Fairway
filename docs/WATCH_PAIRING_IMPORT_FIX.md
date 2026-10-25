# 改修版SideStore：統合ペアリングファイルの読み込み修正

2026-10-25。①への切替中、初期設定で以下の表示が利用者から報告された。

> The pairing file format is ambiguous.

②のLoaderは、対応iOSではLockdownとRemote Pairingの両方の情報を同じplistへ格納する。
したがって、この表示は必ずしもファイル破損を意味しない。SideStoreの自動判定では方式を一意に選べなかった。

## 原因と修正

初期設定のファイル選択には方式選択がなく、`importPairingFile`の最初の検査も常に`preferred: nil`を渡していた。
設定画面などから方式を指定しても、この事前検査が先に失敗する。

- 初期設定に方式選択を追加。②の統合ファイルはまずLockdownとして読み込む。
- 選択した方式を事前検査と保存時の解析へ一貫して渡す。
- 読み込み成功後に、選択した方式を起動時の優先方式として保存する。
- 無効なファイルを検査なしで受け入れたり、秘密情報をログへ出したりしない。
- Watchの署名・プロファイル処理、Apple認証、証明書選択は今回変更しない。

## 利用者の手順

1. 現在のSideStore、iPhone/WatchのFairwayを残す。
2. 成功した②のWindows用Fairway Watch Loaderで、同じApple Accountにログインする。
3. USB接続したiPhoneを選び、Import IPAから今回の修正版SideStore IPAを選ぶ。
4. SideStore本体への上書き更新として進める。別アプリが増える、証明書取消・Revokeを求める場合は停止。
5. 必要ならManage Pairing FileのSideStoreの行でPlaceを押す。
6. SideStoreを終了して開き直す。ペアリング画面に新しい「Pairing Protocol」選択があることを確認。
7. 「Lockdown (Windows USB)」を選び、「Select Pairing File」から「このiPhone内 → SideStore → ALTPairingFile.mobiledevicepairing」を選ぶ。
8. 読み込み成功後、次の画面へ進む。ここではまだFairwayをRefreshしない。

この修正はファイル形式の曖昧さを解消するもの。VPN経由の端末接続、認証引継ぎ、①によるWatch更新の実機成功とは分けて確認する。
選択がない場合は旧版の可能性がある。ファイルを何度も選び直さず、開いている画面を確認する。

ペアリングファイルには認証用の秘密情報が含まれるため、チャットや公開GitHubには添付しない。

## ビルド・検証記録

- [CI 40177569334](https://github.com/iwamoto0414yuuki-droid/Fairway/actions/runs/40177569334)でIPA作成成功。対象ソースは`8fda260d850e84ab9b04ab6a49c1a8a53a9783c6`。
- Watch署名関連の既存19テストが成功。今回のペアリング読込そのものの実機成功は未確認。
- IPA SHA256：`46f0336eac00aa416717784597f7499cce2b868f6325a3f75ac3cc15e91ef1f4`。
- 対応ソースZIP SHA256：`9819e05db1f87405e99eaba673828fa7f6d0444bd44230f2d986ee0ee45a0637`。
- 取得成果物のハッシュをGitHubの値と照合し、対応ソースの方式指定・優先設定の修正を確認。
- AuthManagerとCertificateManagerが元ソースと同じことを照合。
- ②でのWatch起動は利用者が確認済み。①でのWatch更新は引き続き未確認。
