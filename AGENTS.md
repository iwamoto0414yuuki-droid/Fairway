# Watchサイドロード作業の再開情報

Watch対応SideStore、署名、IPA包装、Windows Loader、期限更新の作業では、最初に
[docs/watch-sideloading/README.md](docs/watch-sideloading/README.md)と
[docs/watch-sideloading/state.json](docs/watch-sideloading/state.json)を読む。

実機で確認済みの現在の状態と、古い調査資料の「未確認」を区別する。
PlatformにwatchOS文字列を必須とする旧判定へ戻さない。
Fairwayの機能変更だけならSideStore/Loaderまで再ビルドしない。
署名鍵・pairing file・実端末IDをソースや公開ログへ入れない。
