# 他のWatch対応アプリ用IPAを作る

対象：自作のiPhoneアプリにWatchコンパニオンを同梱する構成。Windowsは実機向けSwift/Xcodeビルド環境の代わりにはならないため、本件ではGitHub ActionsのMac runnerでビルドし、Windows/iPhoneで署名・導入した。

## 成果物を分ける

| 作るもの | 変更時に再ビルドするもの |
| --- | --- |
| アプリのUI・機能・Watch画面 | 対象アプリのiPhone＋Watchを含むIPA |
| SideStoreのprofile・署名・転送・認証処理 | 改修版SideStore IPA |
| Windows Loaderの認証・鍵再利用・USB処理 | Windows Loader EXE |

Fairwayの例ではアプリIPAは444,064 bytes、SideStore IPAは約31MB。アプリ変更のたびにSideStoreまで作り直さない。改修版SideStoreは導入ツールであり、アプリのIPAへ結合して配るものではない。最初のIPAと更新用IPAも同じ最新版を使え、旧バージョンとの合体は不要。

## 最低限のプロジェクト構成

```text
ExampleApp/
  project.yml
  Shared/                 # モデル等。OS別UIは分ける
  iPhone/                 # iOS用 @main と画面
  Watch/                  # watchOS用 @main と画面
  Tests/
```

実例は[rootのproject.yml](../../project.yml)。コピーして名前・ID・バージョンを変更するための小さい例は[examples/project.yml](examples/project.yml)。ソースやAssetsを追加しないとアプリにはならない。

| 設定 | 例・条件 |
| --- | --- |
| iPhone bundle ID | `local.example.counter`。アプリごとに別IDを決める |
| Watch bundle ID | `local.example.counter.watchkitapp`。元の親ID配下 |
| WatchのWKCompanionAppBundleIdentifier | 元のiPhone IDと完全一致 |
| WKApplication | 現代的Watch appでtrue |
| WKRunsIndependentlyOfCompanionApp | 必要な場合true。iPhoneと同梱しなくてよいという意味ではない |
| iPhone target dependencies | Watch targetをembedする |
| Watch SKIP_INSTALL | 本件ではYES。iPhoneの埋込dependencyとしてビルドする |
| 最低OS | 本件iOS17/watchOS10。対象端末に合わせる |
| バージョン | iPhoneとWatchのmarketing/build versionを揃える |

**Apple AccountのTeam IDを未署名IPAのIDへ事前に付けない。** 再署名後の親子関係を導入ツール側で揃える。本件初期のID専用修正IPAは応急処置の履歴であり、他アプリ用の正しいテンプレートではない。

各OS用の`@main`は別ターゲットに入れる。共有コードがiOS専用APIをWatchへ持ち込まないようにする。capabilityを足す場合はInfo.plistだけでなく、利用するaccount/profileと実機の対応も確認する。

## 実機向けビルド・包装

最小コマンド例は[build_unsigned.sh](examples/build_unsigned.sh)。macOSでXcodeとXcodeGenを用意して実行する。Fairway自身では既存の[build_ipa.sh](../../scripts/build_ipa.sh)と[package_ipa.py](../../scripts/package_ipa.py)が正本。

```bash
xcodegen generate
xcodebuild -project ExampleApp.xcodeproj -scheme ExampleApp \
  -configuration Release -destination 'generic/platform=iOS' \
  -derivedDataPath build/device CODE_SIGNING_ALLOWED=NO build
```

期待する中身：

```text
Payload/
  ExampleApp.app/
    Info.plist
    ExampleApp                 # iPhone実機バイナリ
    Watch/
      ExampleWatch.app/
        Info.plist
        ExampleWatch           # Watch実機バイナリ
        PlugIns/...            # 拡張があればそのまま保持
    Frameworks/...             # 必要ならそのまま保持
```

`ExampleApp.app`を`Payload/`直下に置いてZIP化し、拡張子を`.ipa`にする。iPhoneアプリ内のWatch階層・framework・assetsを保持する。シミュレーターの`.app`をZIPにしただけでは実機IPAにならない。Mach-Oの実機platformも確認する。

CIではApple Accountなしで`CODE_SIGNING_ALLOWED=NO`として生成し、実機導入時に改修版SideStore/Loaderが再署名する。署名済み実機IPAや実際のmobileprovisionをCIへ持ち込む運用に変更しない。

例の包装は通常の生成`.app`を対象とする最小例。特殊なsymlink・macOS framework layout等があるアプリではZIP内の属性も保持する包装方法を別に検証する。

## 検査コード

Python標準ライブラリのみで動く読み取り専用ツールを同梱した。

```bash
python3 docs/watch-sideloading/examples/inspect_ipa.py build/ExampleApp-unsigned.ipa
# Series 7を含むarm64_32が必要なターゲットのときだけ指定する：
python3 docs/watch-sideloading/examples/inspect_ipa.py build/ExampleApp-unsigned.ipa --require-watch-arm64-32
```

検査するもの：Payloadの親アプリ、Watchの同梱、元の親子ID、バージョン一致、実行ファイル、Mach-OのCPU/platform、plistの実機platform。
検査しないもの：Appleがprofileを受け入れるか、個別entitlements、証明書・CMSの真正性、Watch転送、保存データ、自動更新、電池。
このツールはprofileやpairingの内容を解析・表示しない。成功JSONは構造検査であり、実機成功の証明ではない。

JSON内のMach-O数値はCPU `16777228=arm64`、`33554444=arm64_32`、platform `2=iOS実機`、`4=watchOS実機`。シミュレーター等の別platformは拒否する。

検査コード自体のテストは、repoルートで次を実行する：

```bash
python3 -m unittest discover -s docs/watch-sideloading/examples -p 'test_*.py' -v
```

6件の合成テストと、既存Fairway実IPAの構造検査をこのWindows環境で実行済み。サンプルshellは`bash -n`の構文検査済み。最小YAMLは参考テンプレートで、このサンプル単体のXcodeGen生成・ネイティブビルドは未実行。実証済みのルートproject.ymlとCIも併せて確認する。

実機系列・OS世代ごとに必要なCPU形式を確認する。本件のFairwayはarm64_32とarm64のWatch実行ファイルを保持し、Series 7で起動を確認した。将来の全Watchアプリへ同じarchitecture構成を一律強制しない。

## GitHub Actionsへ移す

[ios.yml](../../.github/workflows/ios.yml)を参照し、project/scheme、artifact名、IPA名、テスト先とversionを新アプリに合わせる。Fairwayのpackagerは`Fairway.app`というパスを固定しているため、名前だけ変えてそのまま動く汎用ツールではない。

順序：固定runner/依存→XcodeGen→シミュレーターで機能テスト→実機ビルド→構造検査→SHA256→artifactと対応ソース保存。Watchの実機起動は別に行う。

API鍵やAppleパスワードをCI secretsへ追加することは、この方式の前提ではない。将来別の配布方式へ変えるなら別の設計判断として扱う。

## 更新時に維持するもの

- 同じアプリを更新するならbundle IDと署名アカウントを保つ。バージョンを上げる。
- iPhone/Watch双方のデータモデル互換性を考える。アプリを消して入れ直す前提の移行にしない。
- データ永続化・同期を改修したら実機で確認する。機能テストの成功だけでスコア保持を断定しない。
- 初回導入→手動Refresh→Watch再起動→古い期限後の起動→自動更新の実行確認を分けて記録する。
- 他アプリの初回には、このFairwayの26/38件の件数を転記しない。新アプリ固有のテストと実機結果を記録する。
