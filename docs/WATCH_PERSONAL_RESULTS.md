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

## 個人用SideStore Watch試験版（追加検証済み）

- [CI run 40157813570](https://github.com/iwamoto0414yuuki-droid/Fairway/actions/runs/40157813570)
- 改修ソース: `acef47d283c2882d70f26cc8703b22fb4b79038c`。
- ベースSideStore: `d97ec133719d79916675bdaf722b82a8d091d545`。
- SideSign: `752d1ef602aa792a432ffa1e71646dc1ecf7363c`。
- Watch関連テスト19件、失敗0件、スキップなし。
- 小さいiPhone／Watch実行ファイルの検査に加え、配布済みFairway 0.3.0の実IPAでも、親子IDの書換えとSideSignによる再署名を検査。
- 実IPAのSHA256: `1b3e3c21f3f21ce2e7fb716c14bcc35f52a4200cbf0e7e6e88c97e31e15d572e`。
- 一時生成した検査用証明書と合成profileを使用。Appleの`codesign --verify --deep --strict --all-architectures`、entitlements表示、arm64_32／arm64の残存を検査。
- 上記はオフラインの署名構造検査。Appleによる実機用profileの発行・受入れを証明するものではない。
- アーカイブとIPA作成成功。アプリIDは`com.SideStore.SideStore`、版表示は0.7.0／0700。
- IPA: 31,170,054 bytes。
- IPA SHA256: `6102667d2721ec01ce0a115aa1545c51f7f76dbccb94fdac627a51ab4df61492`。
- 対応ソースZIP SHA256: `4da9726dfbe175969079b6f1cafe40bec4e8bda385b9f636db7936878f6cd985`。
- Apple Account、利用者の証明書、profile、端末IDをCIへ渡さず作成。
- AuthManager／Keychain／CertificateManagerが元ソースから変わっていないことも照合。実機での引継ぎは未確認。
- Watchを含むRefreshは再署名・再導入経路へ切り替える。実機での次回更新は未確認。
- 前回の18テスト版は[run 40141137347](https://github.com/iwamoto0414yuuki-droid/Fairway/actions/runs/40141137347)。今回の版を新しい追加検証セットに収録する。

## Windows Watch情報ツール

- [CI run 40139494914](https://github.com/iwamoto0414yuuki-droid/Fairway/actions/runs/40139494914)
- 対象ソース: `5e41ddb`。後の変更はライセンスコメントの追加のみ。
- EXE作成と、パッケージ後の依存モジュールの読み込み・パーサーの自己検査に成功。
- 今回のWindows PCでもEXE自己検査が終了コード0で成功。Apple USBサービスの読み取り検査では接続端末0台。実機のWatch情報読み取りは未確認。Apple Accountへのログイン、署名、証明書変更、アプリ削除を行うコードはない。
- Windowsコード署名なし。利用するpymobiledevice3 11.44.0の公式ソースとGPLライセンスを配布セットへ同梱。

## 次の実機確認

現在のSideStoreを削除・ログアウトせず、改修版の更新として導入する。認証とアプリ一覧が残り、「Watch対応」の設定画面が出ることを最初に確認する。次にWatchの登録、Fairwayの署名・導入、Watchでの起動、スコア同期、次回Refresh後の起動を順に確認する。これらを完了したと記録するのは利用者の実機結果を確認した後とする。
