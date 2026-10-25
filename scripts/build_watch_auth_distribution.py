"""Recipient package for the independent Windows Watch/auth alternative."""
from pathlib import Path
import hashlib
import json
import shutil
import zipfile
import build_distribution as guide

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'release/Watch用iloader_認証更新版_試験セット'
PAGES=[
    ('新しい導入方法を試すセット',[
        ('lead','Windows・無料Apple Accountで、FairwayをWatchへ入れる別の方法'),
        ('box','非公式の個人用試験版です。以前のWatch対応iloaderへ、サーバー情報の取得・認証準備状態の復旧・2FAの互換修正を追加しています。利用者のアカウントでの認証、Watchへの導入、期限更新は未確認です。'),
        ('h','通常版とは別のアプリです'),
        ('p','Fairway-Watch-Loader.exeを直接起動します。インストーラーはなく、通常版iloaderをアンインストールしたり、上書きしたりする手順ではありません。設定・保存データ・Windowsのkeyringも別の名前で扱います。'),
        ('p','iPhoneのSideStoreのログインは引き継ぎません。この試験版ではApple Accountへ新しくログインします。現在動いているSideStoreは削除・ログアウトせず、そのまま残してください。'),
        ('h','同梱したもの'),
        ('p','ポータブルEXE、Fairway-0.3.0-unsigned.ipa、対応ソースZIP、元のライセンス、依存ライブラリの表示、検証ログとSHA256を含みます。Fairwayは打数・パット・前半／後半の集計・任意のクラブ記録に絞った版です。'),
        ('h','最初の確認は認証だけ'),
        ('p','最初は2ページ目まで実施し、「認証を確認（Login）」が成功するかを見ます。この操作はログインと署名用トークンの取得までで、証明書の作成・取消やアプリ導入は行いません。'),
        ('p','Windowsコード署名のない試験用EXEです。ビルドやオフラインテストの成功だけで、実機成功とは扱いません。'),
    ]),
    ('まずAppleへの認証を確認',[
        ('h','1　ZIPをすべて展開する'),
        ('p','WindowsでこのZIPを右クリックし、「すべて展開」を選びます。既存のiloaderや、以前のWatch用iloaderは終了してください。ZIPの中から直接実行せず、展開先のFairway-Watch-Loader.exeを開きます。'),
        ('h','2　新しい試験版の画面か確認する'),
        ('p','タイトルが「Fairway Watch Loader」、版番号が2.3.1-auth.20261025.1の画面であることを確認します。通常版の2.4.0や、以前の2.3.1を開いている場合は対象が違います。'),
        ('p','Anisette Serverの初期値はJkcoxson (Mac)です。「Mac」はサーバー側の方式で、使うパソコンはWindowsのままで構いません。最初はサーバーを次々に変更せず、この値で確認します。'),
        ('h','3　本人のアカウントで認証を確認する'),
        ('p','Apple ID欄へ本人のメールアドレスとパスワードを入力し、「認証を確認（Login）」を一度押します。認証だけの確認にはiPhoneのUSB選択は不要です。パスワードや認証コードをチャットへ送る必要はありません。'),
        ('p','Fairwayをすでに入れている場合は、その導入に使った同じApple Accountで確認します。別アカウントでは別のアプリIDになり、既存のスコアが自動で引き継がれるとは限りません。'),
        ('p','Appleから本人の端末へ確認が来た場合は確認し、表示された6桁のコードをこの試験版の入力画面へ入れます。先にコードが届く形式の2FAにも対応する修正を入れています。'),
        ('h','4　成功・失敗を分ける'),
        ('p','ログイン成功の表示と、アカウントがログイン済みになることを確認します。ここまでが成功したら3ページ目へ進みます。エラーの場合はここで止め、エラー番号・表示された段階・時刻を控えてください。Import IPAを何度も実行する必要はありません。'),
    ]),
    ('FairwayをiPhoneとWatchへ導入',[
        ('h','5　iPhoneをWindowsへ接続する'),
        ('p','認証成功後、iPhoneをUSB接続し、ロックを解除します。iPhone側の「このコンピュータを信頼」を確認し、Devicesで対象のiPhoneを選択します。AppleのWindows用ドライバーが必要です。既存のiloaderで端末が見えていたPCなら同じ接続を使います。'),
        ('p','Watchを近くに置き、ロック解除とiPhoneとの接続を確認します。iPhone／Watchのデベロッパモードを求められた場合は、本人が端末上で確認します。'),
        ('h','6　Fairwayの元のIPAを選ぶ'),
        ('p','「Fairwayを導入」欄のImport IPA（IPAをインポート）から、同梱のFairway-0.3.0-unsigned.ipaを選びます。SideStore本体のIPAや、以前のアカウント専用ID修正版は選びません。'),
        ('p','この操作から、署名証明書・アプリIDの作成、端末登録、プロファイル取得、アプリ導入が行われる場合があります。証明書の上限に達したときは、既存証明書を自動で取り消さず停止します。Revokeを使って既存証明書を消さないでください。'),
        ('h','7　Watchで実際に起動する'),
        ('p','導入が完了したら、iPhoneとWatchの両方でFairwayを確認します。Watchに見当たらない場合は、iPhoneのWatchアプリで利用可能なAppも確認します。iPhoneだけが起動しても、Watch導入成功とは扱いません。'),
        ('p','Watchで9ホールを開始し、打数を3回、パットを2回追加して5打2パットになるか確認します。ホールを移動して戻り、値が残ること、任意のクラブ記録、iPhoneへの同期も確認します。'),
    ]),
    ('エラーの見方と次回の更新',[
        ('h','どの段階で止まったか'),
        ('p','AUTH_METADATAや/v3/client_info：サーバー情報の取得段階です。−45061：認証に使う準備状態です。−80045や503：Appleへの認証段階です。これらは、FairwayやWatchへの導入より前に発生することがあります。'),
        ('p','認証が通った後の証明書上限、App ID、Watch登録・プロファイル・転送エラーは、認証エラーと分けて確認します。成功した段階までと、最後のエラー番号を控えると切り分けられます。'),
        ('p','Reset Anisette Stateを使う場合、この試験版の選択中サーバーの準備状態だけが対象です。認証に失敗している状態で実施し、試験版を閉じて開き直します。通常版やSideStoreの初期化ではありません。'),
        ('h','無料アカウントの期限更新'),
        ('p','無料アカウントの署名には期限があります。今回の経路では、期限前にこのWindows用Loaderで同じ元IPAを再署名・再導入して、両端末で起動を確認する運用を検証します。SideStore側のRefresh表示だけで、Watchの期限も更新されたとは判断できません。'),
        ('p','Windows経由での初回導入・更新とも実機で未確認です。更新でスコアが残るかも確認します。SideStore経由の改修版セットは別の選択肢として残っています。今回のセットに改修版SideStoreのIPAは含めていません。'),
        ('h','出典と検証記録'),
        ('link',('元のiloader公式プロジェクト','https://github.com/nab138/iloader')),
        ('link',('Watch対応の作者による説明','https://github.com/Rzbck/iloader-watch-companion')),
        ('link',('今回の認証修正とビルド手順','https://github.com/iwamoto0414yuuki-droid/Fairway/tree/main/tools/iloader-watch-auth')),
        ('p','対応する改修ソース、オフラインテストのログ、ビルド・起動検査の記録を同梱しています。Appleの認証情報や実機の証明書は配布物へ含めていません。'),
    ]),
]


def build():
    source=ROOT/'release/watch-auth-loader'
    assert (source/'Fairway-Watch-Loader.exe').is_file()
    OUT.mkdir(exist_ok=True)
    for p in source.iterdir():
        if p.is_file():shutil.copyfile(p,OUT/p.name)
    for name in ('Fairway-0.3.0-unsigned.ipa','Fairway-0.3.0-source.zip'):
        shutil.copyfile(ROOT/'release'/name,OUT/name)
    shutil.copyfile(ROOT/'release/verification-0.3.0.json',OUT/'Fairway-verification.json')
    shutil.copyfile(ROOT/'docs/ILOADER_AUTH_INVESTIGATION.md',OUT/'02_原因調査.md')
    shutil.copyfile(ROOT/'docs/WATCH_AUTH_LOADER_RESULTS.md',OUT/'03_ビルド検証結果.md')
    shutil.copyfile(ROOT/'build/iloader-auth-audit/public-metadata.json',OUT/'public-server-check.json')
    shutil.copyfile(ROOT/'tools/iloader-watch-auth/SOURCE.md',OUT/'SOURCE-and-notices.md')
    guide.OUT=OUT;guide.PAGES=PAGES;guide.GUIDE_NAME='01_導入手順_認証更新版'
    guide.GUIDE_BANNER='FAIRWAY WATCH LOADER / Windows 個人用試験版';guide.CHECKED_DATE='2026-10-25'
    guide.pdf();guide.word()
    text=[]
    for title,blocks in PAGES:
        text.append('\n## '+title+'\n')
        for kind,body in blocks:text.append(f'[{body[0]}]({body[1]})\n' if kind=='link' else body+'\n')
    (OUT/'01_導入手順_認証更新版.md').write_text('\n'.join(text),encoding='utf-8')
    (OUT/'SHA256.txt').write_text('\n'.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+p.name for p in sorted(OUT.iterdir()) if p.is_file() and p.name!='SHA256.txt')+'\n',encoding='utf-8')
    destination=OUT.with_suffix('.zip')
    with zipfile.ZipFile(destination,'w',zipfile.ZIP_DEFLATED) as z:
        for p in sorted(OUT.iterdir()):
            if p.is_file():z.write(p,OUT.name+'/'+p.name)
    with zipfile.ZipFile(destination) as z:assert z.testzip() is None
    print(json.dumps({'zip':str(destination),'bytes':destination.stat().st_size},ensure_ascii=False))


if __name__=='__main__':build()
