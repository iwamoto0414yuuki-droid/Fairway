"""Package the isolated portable build, exact sources, licenses and test evidence."""
from pathlib import Path
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import zipfile

root = Path(sys.argv[1]).resolve()
out = root/'dist'
out.mkdir(exist_ok=True)
app, lib = root/'iloader', root/'isideload'
exe = app/'src-tauri/target/release/iloader.exe'
assert exe.is_file() and exe.read_bytes()[:2] == b'MZ'
shutil.copyfile(exe, out/'Fairway-Watch-Loader.exe')
log = (root/'auth-tests.log').read_text(encoding='utf-8-sig')
assert re.search(r'test result: ok\. \d+ passed; 0 failed;', log)
auth = [line for line in log.splitlines() if line.startswith('test ') and 'auth_backport_' in line and line.rstrip().endswith(' ... ok')]
assert len(auth) == 21, len(auth)
shutil.copyfile(root/'auth-tests.log',out/'offline-tests.log')
shutil.copyfile(root/'watch-auth-patch.json',out/'patch-manifest.json')
notice = []
source = out/'Fairway-Watch-Loader-source.zip'
def add_tree(archive, directory, prefix):
    directory=directory.resolve()
    for folder,dirs,files in os.walk(directory,followlinks=False):
        dirs[:]=[name for name in dirs if name not in {'.git','target','node_modules','dist','__pycache__'} and not (Path(folder)/name).is_symlink()]
        for name in files:
            p=Path(folder)/name
            if p.is_symlink() or not p.is_file(): continue
            if p.suffix in {'.exe','.p12','.mobileprovision'} or p.name=='.env': continue
            assert p.resolve().is_relative_to(directory)
            archive.write(p,prefix+'/'+p.relative_to(directory).as_posix())
metadata=subprocess.run(['cargo','metadata','--format-version','1','--manifest-path',str(app/'src-tauri/Cargo.toml')],capture_output=True,encoding='utf-8',check=True)
packages=json.loads(metadata.stdout)['packages']
with zipfile.ZipFile(source,'w',zipfile.ZIP_DEFLATED) as archive:
    add_tree(archive,app,'iloader')
    add_tree(archive,lib,'isideload')
    add_tree(archive,Path(__file__).resolve().parent,'PersonalBuild')
    copied=set()
    for p in sorted(packages,key=lambda x:(x['name'],x['version'])):
        directory=Path(p['manifest_path']).parent
        notice.append('\n=== '+p['name']+' '+p['version']+' ===\nLicense: '+str(p.get('license'))+'\nRepository: '+str(p.get('repository'))+'\n')
        files=set(directory.glob('LICENSE*'))|set(directory.glob('COPYING*'))|set(directory.glob('NOTICE*'))
        if p.get('license_file'): files.add(directory/p['license_file'])
        for f in sorted(files):
            if f.is_file() and f.resolve().is_relative_to(directory.resolve()):
                notice.append('\n'+f.name+'\n'+f.read_text(encoding='utf-8',errors='replace'))
        if p.get('source') and any(x in (p.get('license') or '') for x in ('MPL','GPL')):
            key=(p['name'],p['version'])
            if key not in copied:
                add_tree(archive,directory,'ThirdPartySources/'+p['name']+'-'+p['version']);copied.add(key)
npm_seen=set()
for manifest in (app/'node_modules').rglob('package.json'):
    if manifest.is_symlink(): continue
    try: package=json.loads(manifest.read_text(encoding='utf-8'))
    except (ValueError,UnicodeError): continue
    name,version=package.get('name'),package.get('version')
    if not name or not version or (name,version) in npm_seen: continue
    npm_seen.add((name,version))
    notice.append('\n=== npm '+name+' '+version+' ===\nLicense: '+str(package.get('license'))+'\n')
    for pattern in ('LICENSE*','LICENCE*','COPYING*','NOTICE*'):
        for f in manifest.parent.glob(pattern):
            if f.is_file() and f.resolve().is_relative_to((app/'node_modules').resolve()):
                notice.append('\n'+f.name+'\n'+f.read_text(encoding='utf-8',errors='replace'))
(out/'THIRD-PARTY-NOTICES.txt').write_text('\n'.join(notice),encoding='utf-8')
(out/'00_README.txt').write_text(
    'Fairway Watch Loader — 個人用・非公式の認証更新試験版\n'
    '通常版iloaderとは別アプリです。インストーラーは不要です。ZIPをすべて展開してください。\n'
    '最初はApple Accountを入力して「認証を確認（Login）」だけを実行します。\n'
    'この操作はログインと署名用トークンの取得までで、証明書の作成・取消やアプリ導入は行いません。\n'
    '成功後にUSB接続したiPhoneを選び、Import IPAからFairwayの元の完全版IPAを選べます。\n'
    'Import IPAでは署名証明書やアプリIDの作成・端末登録が行われる場合があります。\n'
    '証明書の上限時は既存証明書を取り消さず停止します。別途Revokeを押さないでください。\n'
    'Windowsコード署名なし。利用者のアカウントでの認証・Watch導入・期限更新は未確認です。\n'
    'SideStoreのログイン情報は引き継ぎません。通常版の設定・keyringとは別に保存します。\n'
    'iPhoneだけの成功をWatch導入成功とは扱いません。Watchで起動するところまで確認します。\n'
    'Original iloader: https://github.com/nab138/iloader / https://iloader.app/\n'
    'Watch implementation: https://github.com/Rzbck/iloader-watch-companion\n'
    'Personal changes: https://github.com/iwamoto0414yuuki-droid/Fairway/tree/main/tools/iloader-watch-auth\n'
    'Independent experiment; no upstream endorsement. Exact modified source and original notices accompany this EXE.\n',encoding='utf-8-sig')
report={'ipa_not_required_for_auth_check':True,'auth_backport_tests_passed':len(auth),
        'exe_sha256':hashlib.sha256((out/'Fairway-Watch-Loader.exe').read_bytes()).hexdigest(),
        'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
        'app_identifier':'local.fairway.watchloader.auth20261025','keyring_service':'fairway-watch-loader-auth-20261025',
        'default_anisette_server':'https://ani.jkcoxson.com','server_metadata_cached_per_session':True,
        'automatic_certificate_revocation':False,'physical_login_verified':False,'physical_watch_install_verified':False,
        'windows_code_signature':'NotSigned','dependency_count':len(packages),'npm_dependency_count':len(npm_seen),
        'copyleft_dependency_sources_included':len(copied)}
(out/'verification.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report))
