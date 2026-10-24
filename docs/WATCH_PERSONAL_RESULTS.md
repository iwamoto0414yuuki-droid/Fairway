# Watch対応SideStoreとFairway最小版のビルド結果

2026-10-25。個人用・非公式の試験版。実機のログイン引継ぎ、無料アカウントでのWatch登録・導入、期限更新後のWatch起動は未確認。

## Fairway 0.3.0

- [CI run 40140421334](https://github.com/iwamoto0414yuuki-droid/Fairway/actions/runs/40140421334)
- テスト対象ソース: `ad565069f56d6b8e645a6581eb829b0363aa1cbf`
- ネイティブテスト38件、失敗0件。iPhone／Watch向けの実機バイナリと未署名IPAを生成。
- IPA: 444,064 bytes。
- SHA256: `1b3e3c21f3f21ce2e7fb716c14bcc35f52a4200cbf0e7e6e88c97e31e15d572e`
- iPhone／Watchの版番号、親子ID、実機プラットフォーム、ネイティブ実行ファイル、Watch同梱を検査。
- GPSの利用説明キーは両アプリから削除。地図・GPSコードを今回のビルドから除外。
- 40mm Watchシミュレーターのネイティブ画面を確認。クラブボタンの見切れを修正。

## 個人用SideStore Watch試験版

- [CI run 40141137347](https://github.com/iwamoto0414yuuki-droid/Fairway/actions/runs/40141137347)
- 改修ソース: `edc20892969b7beb341e05cad3e417b947721693`
- ベースSideStore: `d97ec133719d79916675bdaf722b82a8d091d545`。
- SideSign: `752d1ef602aa792a432ffa1e71646dc1ecf7363c`。
- Watch関連テスト18件、失敗0件。署名用プロファイルの端末・Platform・期限・ID照合、親子ID書換え、Watchの検出と構成検査を含む。
- 検査専用に一時生成したコード署名用証明書と、iPhone／Watch用に実際にコンパイルしたMach-Oを使い、Watch専用のentitlementsを検査。Appleの`codesign --verify --deep --strict`とentitlements表示でも照合。
- 上記はオフラインの署名構造検査であり、Appleから実機用profileを取得できた証明ではない。
- アーカイブとIPA作成成功。アプリIDは既存の更新経路を利用するため`com.SideStore.SideStore`のまま。版表示は0.7.0／0700。
- IPA: 31,165,263 bytes。
- SHA256: `a9dbe740851dda59fc3263b980d938e56c7b31ec02c2929c2e1072c5832dc504`
- 改修を適用した対応ソースZIPのSHA256: `03b784446e74511875ff41947ea52787ca47ee2dad4912b71d8b692862a8149b`
- Apple Account、実機の証明書、profile、端末IDをCIへ渡さず作成。
- 本物のWatch署名情報とprofileの一致を、インストール前にも検査する。
- 通常のiPhone向けprofile注入のみではWatchの期限更新が成立したことにならないため、Watchを含むRefreshは再署名・再導入経路へ切り替える。
- Watchのバンドルは別の集合として扱い、既存のiPhone向けカスタマイズ処理へ混入させない。

## Windows Watch情報ツール

- [CI run 40139494914](https://github.com/iwamoto0414yuuki-droid/Fairway/actions/runs/40139494914)
- 対象ソース: `5e41ddb`。後の変更はライセンスコメントの追加のみ。
- EXE作成と、パッケージ後の依存モジュールの読み込み・パーサーの自己検査に成功。
- 実機のWatch情報読み取りは未確認。Apple Accountへのログイン、署名、証明書変更、アプリ削除を行うコードはない。
- Windowsコード署名なし。利用するpymobiledevice3 11.44.0の公式ソースとGPLライセンスを配布セットへ同梱。

## 次の実機確認

現在のSideStoreを削除・ログアウトせず、改修版の更新として導入する。認証とアプリ一覧が残り、「Watch対応」の設定画面が出ることを最初に確認する。次にWatchの登録、Fairwayの署名・導入、Watchでの起動、スコア同期、次回Refresh後の起動を順に確認する。これらを完了したと記録するのは利用者の実機結果を確認した後とする。
