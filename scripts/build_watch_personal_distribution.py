"""Package the personal SideStore experiment with the minimal Fairway app."""
from pathlib import Path
import hashlib
import json
import shutil
import zipfile
import build_distribution as guide

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'release/Watch対応SideStore_Fairway最小版_試験セット'
PAGES = [
    ('このセットで試すこと', [
        ('lead', 'Windows・無料Apple Account・既存のSideStore認証を使う試験版'),
        ('box', 'SideStore本体を改修した個人用の試験版です。公式SideStoreではありません。コンパイルやオフライン検査に通っても、今回の実機で認証の引継ぎ・Watch導入・更新が成功することはまだ確認できていません。動いているSideStoreやFairwayは削除しないでください。'),
        ('h', '前提'),
        ('p', '現在のSideStore 0.7系でログイン済みで、FairwayのRefreshが成功している状態から始めます。試験版iloaderへのログインをやり直す操作はありません。パスワード、証明書、ペアリングファイルを作成者へ送る必要もありません。'),
        ('h', '入っているファイル'),
        ('p', 'SideStore-Watch-personal.ipa：Watch用の登録・署名を追加したSideStore。Fairway-0.3.0-unsigned.ipa：打数・パット・スコアカード・任意のクラブ記録に絞ったアプリ。Fairway-WatchInfo.exe：WatchのUDIDをWindowsで読み取る補助ツール。'),
        ('p', '署名済みアプリではありません。IPAは今動いているSideStoreで署名して導入します。Watch情報ツールもWindowsコード署名なしの個人用ツールです。'),
        ('h', '何を確認したら成功か'),
        ('p', 'iPhoneへの導入完了だけでは完了ではありません。WatchでFairwayが起動し、スコアを記録できること、iPhoneへ同期できること、次回の期限更新後にもWatchで起動できることを順に確認します。'),
    ]),
    ('今のSideStoreから改修版へ更新', [
        ('h', '1　現在の動作を確認する'),
        ('p', 'iPhoneでLocalDevVPNを接続します。SideStoreのMy AppsからFairwayをRefreshできることを確認します。既存のアプリ一覧、SideStoreの詳しいバージョン表示を本人用に控えておきます。ログアウトや証明書の無効化は行いません。'),
        ('h', '2　SideStoreの試験IPAを選ぶ'),
        ('p', 'このZIPをWindowsで「すべて展開」します。SideStore-Watch-personal.ipaをiPhoneの「ファイル」から選べる場所へ転送し、現在のSideStoreのMy Appsの＋から選択します。'),
        ('p', '同じSideStoreを更新する形で進めます。別のSideStoreが増える、Bundle IDや署名チームの変更を求められる、既存SideStoreの削除が必要と表示される場合は進めず、その表示を確認します。動いているSideStoreを消して入れ直す手順ではありません。'),
        ('h', '3　更新後に認証が残っているか確認する'),
        ('p', 'SideStoreを開き直します。My Appsとログイン状態が残っているか確認し、設定のDeveloper Portal内に「個人用Watch試験版」→「Watch対応」が追加されているか確認します。'),
        ('box', 'ログイン状態やアプリ一覧が失われた場合は、そこで止めます。認証情報を引き継げるかは実機で未確認です。証明書の無効化・Revokeを求められた場合も、既存アプリへの影響を確認するまで進めないでください。'),
    ]),
    ('Watchの端末IDを登録', [
        ('h', '4　WindowsでWatchのUDIDを表示する'),
        ('p', 'iPhoneをWindowsへUSB接続し、iPhoneとWatchのロックを解除します。iPhoneの「このコンピュータを信頼」を済ませ、既存iloaderを閉じます。同梱のFairway-WatchInfo.exeを開き、「WatchのUDIDを表示」を押してください。'),
        ('p', 'このツールはUSB接続したiPhone経由で、ペアリングされたWatchの情報を読み取ります。Apple Accountの入力、署名、アプリ削除、証明書変更、端末IDのアップロードは行いません。読み取りそのものは実機で未検証です。'),
        ('h', '5　iPhone側の「Watch対応」に入力する'),
        ('p', '表示されたWatchのUDIDを、SideStoreの設定→Developer Portal→Watch対応へ入力します。シリアル番号やiPhoneのUDIDではありません。Windows画面をiPhoneのカメラのテキスト認識でコピーするか、正確に入力してください。'),
        ('p', '「Watchの登録を確認」を押します。現在のSideStoreの認証を使ってApple側へ登録・照合します。UDIDはこのiPhoneの設定に保存され、以後のWatch署名にも利用されます。チャットや公開GitHubへ送る必要はありません。'),
        ('h', 'ここでエラーになった場合'),
        ('p', 'エラー文と、登録ボタンを押した段階で失敗したことを控えてください。Watch用の登録が通っていない状態では、Fairwayを何度入れ直しても解決しません。SideStoreのログアウトや端末の初期化は不要です。'),
    ]),
    ('FairwayをiPhoneとWatchへ導入', [
        ('h', '6　最小版Fairwayを選ぶ'),
        ('p', '改修版SideStoreのMy Appsの＋からFairway-0.3.0-unsigned.ipaを選びます。前回の9P2から始まるID専用修正IPAや、SideStore-Watch-personal.ipaと取り違えないようにしてください。既存のFairwayは削除しません。'),
        ('p', 'iPhone本体とWatchについて別々にプロファイルを取得し、親子IDを揃えて署名します。Watch用のPlatform・端末ID・アプリID・期限・署名証明書が一致しない場合は、導入を停止する実装です。'),
        ('h', '7　Watchへインストールする'),
        ('p', 'iPhone版Fairwayが起動したら、iPhoneの「Watch」アプリを開き、利用可能なAppのFairwayからインストールします。両端末のデベロッパモード、接続、ロック解除を確認してください。'),
        ('h', '8　Watchで起動・保存・同期を確認する'),
        ('p', 'WatchでFairwayを開き、9ホールまたは18ホールを選びます。打数を3回、パットを2回追加すると、打数5・パット2になります。ホールを横スワイプで切り替え、戻って値が保存されているか確認します。'),
        ('p', '任意でクラブを記録し、iPhoneに同じラウンド・スコアが届くか確認します。各タップは端末へ保存し、ホールを離れたときやアプリが非アクティブになったときにまとめて転送します。'),
        ('box', 'Watchだけが再び整合性エラーになる場合は、そこで結果を確認します。正しい署名に加えてWatchへの転送方法の対応が必要な可能性が残っています。この試験版での実機成功はまだ確認できていません。'),
    ]),
    ('操作と期限更新', [
        ('h', 'カウンターの操作'),
        ('p', '大きい左の数字が総打数、右がパット数です。それぞれの上下の−／＋で操作します。パットの＋は総打数にも1打を加えます。パットで打ったときは、左右両方の＋を押す必要はありません。'),
        ('p', 'クラブは「クラブ（任意）」から、記録したい打だけ選びます。選択は自動保存です。ホールを横スワイプし、最後のページで前半・後半・合計の打数とパット数を確認できます。iPhoneでは一覧のスコアカードを見られます。'),
        ('h', '今回外した機能と省電力'),
        ('p', 'GPS距離・地図・打点位置・運動計測・常時測位は含めていません。常時通信やポーリングもしません。過去データとの互換性のため、旧版で保存した項目はデータから消さず、今回の画面では使いません。'),
        ('h', '無料アカウントの期限更新'),
        ('p', '期限が切れる前に、この改修版SideStoreからFairwayをRefreshします。Watchを含むアプリは、iPhone向けprofileの注入だけで終わらず、Watchの個別署名を含む再導入処理を実行する設計です。初回成功後も、更新後にWatchで起動できるかを実機で確認してください。'),
        ('p', '以後のFairwayの改修は、小さいFairwayのIPAだけを更新します。SideStore側の修正が必要な場合に限り、SideStoreの試験版も更新します。通常版SideStoreへ戻した場合のWatch更新は保証できません。'),
        ('h', '出典・ソース'),
        ('link', ('SideStoreの元ソース', 'https://github.com/SideStore/SideStore')),
        ('link', ('個人用の改修・ビルド手順', 'https://github.com/iwamoto0414yuuki-droid/Fairway/tree/main/tools/watch-support')),
        ('p', '同梱の対応ソース、元の著作権表示、依存ライブラリ情報、SHA256とビルド検証記録も確認できます。'),
    ]),
]


def build():
    required = {
        'SideStore-Watch-personal.ipa': ROOT/'release/watch-personal/SideStore-Watch-personal.ipa',
        'SideStore-Watch-personal-source.zip': ROOT/'release/watch-personal/SideStore-Watch-personal-source.zip',
        'SideStore-Watch-build.json': ROOT/'release/watch-personal/SideStore-Watch-build.json',
        'Fairway-0.3.0-unsigned.ipa': ROOT/'release/Fairway-0.3.0-unsigned.ipa',
        'Fairway-WatchInfo.exe': ROOT/'build/watch-info-verified/dist/Fairway-WatchInfo.exe',
        'WatchInfo-dependencies.txt': ROOT/'build/watch-info-verified/dist/dependencies.txt',
    }
    for source in required.values():
        assert source.is_file(), source
    OUT.mkdir(exist_ok=True)
    for name, source in required.items():
        shutil.copyfile(source, OUT/name)
    shutil.copyfile(ROOT/'tools/watch-support/watch_info.py', OUT/'WatchInfo-source.py')
    guide.OUT = OUT; guide.PAGES = PAGES
    guide.GUIDE_NAME = '01_Watch導入手順'; guide.GUIDE_BANNER = 'FAIRWAY 0.3.0 / Watch対応SideStore 個人用試験版'
    guide.CHECKED_DATE = '2026-10-25'
    guide.pdf(); guide.word()
    markdown = []
    for title, blocks in PAGES:
        markdown.append('\n## '+title+'\n')
        for kind, body in blocks:
            markdown.append(f'[{body[0]}]({body[1]})\n' if kind == 'link' else body+'\n')
    (OUT/'01_Watch導入手順.md').write_text('\n'.join(markdown), encoding='utf-8')
    (OUT/'00_最初に読む.txt').write_text(
        'Watch対応SideStore＋Fairway最小版の個人用試験セット\n'
        '最初に01_Watch導入手順.pdfの2ページ目を読んでください。\n'
        '現在動いているSideStoreからSideStore-Watch-personal.ipaを更新として導入します。\n'
        'SideStoreとFairwayを削除したり、ログアウトしたりしないでください。\n'
        '実機でのログイン引継ぎ・Watch導入は未確認です。\n', encoding='utf-8-sig')
    (OUT/'SHA256.txt').write_text('\n'.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+p.name for p in sorted(OUT.iterdir()) if p.is_file() and p.name!='SHA256.txt')+'\n', encoding='utf-8')
    dest = OUT.with_suffix('.zip')
    with zipfile.ZipFile(dest, 'w', zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(OUT.iterdir()):
            if path.is_file(): archive.write(path, OUT.name+'/'+path.name)
    with zipfile.ZipFile(dest) as archive: assert archive.testzip() is None
    print(json.dumps({'zip': str(dest), 'bytes': dest.stat().st_size}, ensure_ascii=False))


if __name__ == '__main__':
    build()
