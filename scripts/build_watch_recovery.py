"""Package a documented, unexecuted Windows Watch-sideload experiment.
Third-party binary is preserved from its author's exact GitHub Actions artifact.
This does not sign an IPA, log in, revoke certificates, install software or touch devices.
"""
from pathlib import Path
import hashlib
import json
import shutil
import zipfile
import build_distribution as guide

ROOT=Path(__file__).resolve().parents[1]
AUDIT=ROOT/'build/signing-audit'
OUT=ROOT/'release/Watch_Windows_試験用_再導入'
EXE='iloader_2.3.1_x64-setup.exe'
EXE_HASH='34bb3422ba7983490c501e65d388bd60140f341a708aa75e00fa64d8a9f92b9a'
IPA_HASH='5a9786d519dc59ed9adaccbdc65e982b787b69c99ee635aa9b71ebdade07ec66'
PROJECT='https://github.com/Rzbck/iloader-watch-companion'
RUN='https://github.com/Rzbck/iloader/actions/runs/34436587217'

PAGES=[
 ('今回のエラーと次の方法',[
  ('lead','Windowsのみ・無料Apple Accountで試すための資料'),
  ('box','同梱ツールは公式iloaderではなく、Watch対応を追加した非公式の試験版です。今回のiOS 26.6.2／watchOS 26.6／無料アカウントでは未検証です。Windowsのコード署名もありません。本人の判断で試すためのセットで、導入成功を保証するものではありません。'),
  ('h','何が分かったか'),
  ('p','iPhoneのFairwayは起動し、Watchへのインストールだけが整合性エラーになる状況です。前回はアプリIDを直しましたが、Watch用のプロファイル・署名も必要です。'),
  ('p','確認したSideStore/SideSignの公開実装では、プロファイル準備対象はiPhone本体とPlugIns内のappexで、Watchディレクトリのappを独立して準備する処理が見当たりませんでした。署名済み実物を解析していないため、原因は有力な推定です。'),
  ('h','次の候補：WindowsからWatch用に署名・導入する'),
  ('p','Rzbckのiloader拡張は、Watchの登録、Watch用プロファイル取得、独立した署名、ペアリング先への転送を実装しています。作者は別環境でiPhoneとWatchの実機導入・起動を報告しています。今回の端末での成功実績ではありません。'),
  ('link',('作者の説明・実機検証の範囲',PROJECT)),
  ('h','このセットに入っているもの'),
  ('p','iloader_2.3.1_x64-setup.exe：作者のWindowsビルドを変更せず収録。Fairway-0.2.0-original.ipa：Watch対応署名ツールに渡す元の完全版。手順書PDF・Word、出典、ライセンス、チェックサム。'),
  ('p','インストーラーのGitHub由来とハッシュ一致を確認しましたが、こちらでは実行・ログイン・実機導入はしていません。セキュリティ全般の保証を意味しません。'),
 ]),
 ('Windowsで再導入する手順',[
  ('h','1　接続と開発者モードを確認する'),
  ('p','iPhoneをWindowsへUSB接続し、ロック解除・信頼を確認します。WatchをiPhoneと接続し、両方を起動・ロック解除しておきます。iPhoneとWatchのデベロッパモードも確認します。Watch側に設定が見つからない場合は、その状態を伝えてください。'),
  ('h','2　試験版ツールを準備する'),
  ('p','通常のiloaderを終了し、同梱インストーラーを使います。非公式・未署名の試験版であることを確認してから判断してください。既存の新しいiloaderとのバージョン競合等が出る場合は、自己判断で削除せず、その表示文を確認します。'),
  ('h','3　本人のApple Accountで操作する'),
  ('p','本人がiloaderへログインし、USBでつないだiPhoneを選びます。パスワードや確認コードを作成者に送る必要はありません。証明書の無効化・Revokeを求められた場合は、既存のSideStore等に影響し得るため、その場で進めず対象を確認してください。'),
  ('h','4　元の完全版IPAをインポートする'),
  ('p','「IPAをインポート」から、同梱のFairway-0.2.0-original.ipaを選びます。前回の9P2から始まるアカウント専用修正IPAではなく、この元IPAを使います。新しい経路は親子IDとWatch署名をまとめて処理します。'),
  ('p','今回はSideStoreの＋から入れる操作ではありません。「SideStoreをインストール」も選ばず、FairwayのIPAを直接選びます。既存のFairwayは削除せず、同じApple Accountを使用してください。'),
  ('h','5　Watchの導入・起動まで確認する'),
  ('p','ツールの処理完了後、iPhone版とWatch版の両方を起動します。Watchへの導入だけ失敗した場合は、iPhone側の成功表示だけで完了とは扱いません。新しいエラー文の確認へ進みます。'),
 ]),
 ('確認・期限更新・出典',[
  ('h','成功したか確認する'),
  ('p','WatchでFairwayが起動し、iPhoneで作ったラウンドが届くか確認します。Watchで1ホール保存し、iPhoneのカードに反映されれば次の段階です。GPSは屋外で別途確認します。'),
  ('h','無料アカウントでの期限更新'),
  ('p','無料アカウントの期限更新は引き続き必要です。Watch対応の署名を維持するため、この試験経路を使う場合は同じWatch対応iloaderから再導入します。通常のSideStoreでFairwayをRefreshすると、Watch用署名を再び損なう可能性があります。自動Refreshとの併用は未検証です。'),
  ('h','また失敗した場合'),
  ('p','失敗した段階、エラー全文、iPhone／WatchのOS、使用したツールの版を記録します。ログには端末IDやアカウント情報が含まれることがあるので、公開せず、パスワード・確認コード・証明書・ペアリングファイルは送らないでください。'),
  ('h','取得元と確認範囲'),
  ('link',('Watch対応拡張の説明',PROJECT)),
  ('link',('作者が示す実機検証の範囲',PROJECT+'/blob/main/docs/COMPATIBILITY.md')),
  ('link',('Windowsビルドの取得元（GitHub Actions）',RUN)),
  ('link',('SideSign：アプリ・拡張の発見処理','https://github.com/SideStore/SideSign/blob/main/Sources/Models/AppBundle.swift')),
  ('link',('SideSign：署名とプロファイル準備','https://github.com/SideStore/SideSign/blob/main/Sources/CodeSigning/CodeSignerAPI.swift')),
  ('p','取得ビルド：iloader 70f37e9b4afc659ab44ec1944c034093f4cda416。isideload f7b9f3da570edd6824c29680545e710846d07df5を参照。GitHubアーカイブと同梱EXEのSHA256は検証記録に保存しています。'),
  ('p','この資料は試験手順です。通常のSideStoreでWatchまで導入できるという従来の案内は、この状況では成立していません。Macや有料契約を使う方法への切替を前提にはしていません。'),
 ]),
]

def build():
    source_exe=AUDIT/EXE
    source_ipa=ROOT/'release/Fairway-0.2.0-unsigned.ipa'
    assert hashlib.sha256(source_exe.read_bytes()).hexdigest()==EXE_HASH
    assert hashlib.sha256(source_ipa.read_bytes()).hexdigest()==IPA_HASH
    OUT.mkdir(exist_ok=True)
    shutil.copyfile(source_exe,OUT/EXE)
    shutil.copyfile(source_ipa,OUT/'Fairway-0.2.0-original.ipa')
    shutil.copyfile(AUDIT/'Rzbck-iloader-LICENSE',OUT/'LICENSE-iloader.txt')
    shutil.copyfile(AUDIT/'Rzbck-iloader-watch-companion-NOTICE.md',OUT/'NOTICE-third-party.md')
    guide.OUT=OUT;guide.GUIDE_NAME='01_Watch導入の再試行手順';guide.PAGES=PAGES
    guide.pdf();guide.word()
    text=['# Watch導入の再試行（非公式試験版）\n']
    for title,blocks in PAGES:
        text.append('\n## '+title+'\n')
        for kind,body in blocks:
            if kind=='link':text.append(f'[{body[0]}]({body[1]})\n')
            else:text.append(body+'\n')
    (OUT/'01_Watch導入の再試行手順.md').write_text('\n'.join(text),encoding='utf-8')
    report={
        'source_project':PROJECT,'source_run':RUN,
        'source_commit':'70f37e9b4afc659ab44ec1944c034093f4cda416',
        'artifact_id':10136476786,
        'artifact_zip_sha256':'d64fa863e6961d157ee2699242f57362afb770753fdfed071483b55e6da085c2',
        'installer_sha256':EXE_HASH,'installer_windows_signature':'NotSigned',
        'ipa_sha256':IPA_HASH,
        'installer_modified':False,'installer_executed_by_assistant':False,
        'credentials_entered_by_assistant':False,'device_install_verified_by_assistant':False,
        'reported_target':'Windows / iOS 26.6.2 / watchOS 26.6 / free Apple Account',
        'target_configuration_verified':False,
    }
    (OUT/'検証記録.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    (OUT/'SHA256.txt').write_text(EXE_HASH+'  '+EXE+'\n'+IPA_HASH+'  Fairway-0.2.0-original.ipa\n',encoding='ascii')
    package=OUT.with_suffix('.zip')
    with zipfile.ZipFile(package,'w',zipfile.ZIP_DEFLATED) as z:
        for file in sorted(OUT.iterdir()):
            if file.is_file():z.write(file,OUT.name+'/'+file.name)
    print(json.dumps({'zip':str(package),'bytes':package.stat().st_size,'guide':str(OUT/'01_Watch導入の再試行手順.pdf')},ensure_ascii=False,indent=2))

if __name__=='__main__':build()
