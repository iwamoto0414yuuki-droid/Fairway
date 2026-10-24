"""Prepare the unsigned Watch metadata for an observed SideStore account suffix.

SideStore rewrites the iPhone ID during signing, but the reported failure shows
that WKCompanionAppBundleIdentifier remains unchanged. Keep the input iPhone ID
unchanged to avoid a double suffix; target the expected post-signing parent ID.
No account credential, signing certificate or pairing record is required.
"""
from pathlib import Path
import argparse
import hashlib
import json
import plistlib
import re
import zipfile

ROOT = Path(__file__).resolve().parents[1]
BASE_SHA256 = '5a9786d519dc59ed9adaccbdc65e982b787b69c99ee635aa9b71ebdade07ec66'
PHONE_INFO = 'Payload/Fairway.app/Info.plist'
WATCH_INFO = 'Payload/Fairway.app/Watch/FairwayWatch.app/Info.plist'


def prepare(team_id: str):
    if not re.fullmatch(r'[A-Z0-9]{10}', team_id):
        raise ValueError('Use the 10-character suffix from the expected ID in the installation error')
    source = ROOT / 'release/Fairway-0.2.0-unsigned.ipa'
    if hashlib.sha256(source.read_bytes()).hexdigest() != BASE_SHA256:
        raise ValueError('Unexpected source IPA; preserve and verify the approved full release first')
    with zipfile.ZipFile(source) as archive:
        entries = [(entry, archive.read(entry)) for entry in archive.infolist()]
    data_by_name = {entry.filename: data for entry, data in entries}
    phone = plistlib.loads(data_by_name[PHONE_INFO])
    old_watch = plistlib.loads(data_by_name[WATCH_INFO])
    base_id = phone['CFBundleIdentifier']
    assert base_id == 'local.fairway.score'
    assert old_watch['WKCompanionAppBundleIdentifier'] == base_id
    assert old_watch['CFBundleIdentifier'] == base_id + '.watchkitapp'
    expected_parent = base_id + '.' + team_id
    watch = dict(old_watch)
    watch['WKCompanionAppBundleIdentifier'] = expected_parent
    watch['CFBundleIdentifier'] = expected_parent + '.watchkitapp'
    out = ROOT / 'release' / ('SideStore_' + team_id)
    out.mkdir(exist_ok=True)
    dest = out / ('Fairway-0.2.0-SideStore-' + team_id + '.ipa')
    with zipfile.ZipFile(dest, 'w') as archive:
        for entry, data in entries:
            archive.writestr(entry, plistlib.dumps(watch, fmt=plistlib.FMT_BINARY) if entry.filename == WATCH_INFO else data)
    with zipfile.ZipFile(dest) as archive:
        assert archive.testzip() is None
        assert set(archive.namelist()) == set(data_by_name)
        for name, original in data_by_name.items():
            if name != WATCH_INFO:
                assert archive.read(name) == original, 'Unexpected file change: ' + name
        patched = plistlib.loads(archive.read(WATCH_INFO))
        assert {key for key in set(patched) | set(old_watch) if patched.get(key) != old_watch.get(key)} == {
            'CFBundleIdentifier', 'WKCompanionAppBundleIdentifier'
        }
        # Validate the topology after the exact iPhone ID rewrite observed in the error.
        assert patched['WKCompanionAppBundleIdentifier'] == expected_parent
        assert patched['CFBundleIdentifier'].startswith(expected_parent + '.')
        assert plistlib.loads(archive.read(PHONE_INFO))['CFBundleIdentifier'] == base_id
        for prefix, info in [('Payload/Fairway.app/', phone), ('Payload/Fairway.app/Watch/FairwayWatch.app/', patched)]:
            executable = prefix + info['CFBundleExecutable']
            assert archive.read(executable) == data_by_name[executable]
    digest = hashlib.sha256(dest.read_bytes()).hexdigest()
    report = {
        'source_sha256': BASE_SHA256, 'sha256': digest,
        'expected_post_signing_phone_id': expected_parent,
        'watch_companion_id': watch['WKCompanionAppBundleIdentifier'],
        'watch_bundle_id': watch['CFBundleIdentifier'],
        'input_phone_id_unchanged': True,
        'changed_file': WATCH_INFO,
        'changed_keys': ['CFBundleIdentifier', 'WKCompanionAppBundleIdentifier'],
        'all_other_files_byte_identical': True,
        'native_executables_byte_identical': True,
        'signed': False, 'device_install_verified': False,
        'scope': 'Only the account suffix observed in the error; not a universal distribution IPA',
    }
    dest.with_suffix('.ipa.sha256').write_text(digest + '  ' + dest.name + '\n', encoding='ascii')
    (out / 'verification.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    instructions = f'''Fairway：04のインストールエラーに対応したIPA

対象のエラー：InvalidCompanionAppBundleIdentifier
対象：SideStoreがiPhone側IDを {expected_parent} にするApple Account。

1. このフォルダの {dest.name} をiPhoneの「ファイル」に保存します。
2. これまでと同じApple AccountのSideStoreを使います。
3. Wi-FiとLocalDevVPNに接続し、SideStore → My Apps → ＋で新しいIPAを選びます。
4. インストール後、iPhoneの「Watch」アプリからFairwayの導入を確認します。

SideStore初期設定のやり直しや、元のIPAを先に入れる操作は不要です。
既にFairwayが起動している場合は、アプリを削除せず上書きしてください。

変更したのはWatchのアプリIDと、iPhoneアプリへの参照先だけです。
スコア・クラブ・GPS機能と実行コードは同一です。Watchも残しています。
実機での導入成功はまだ未確認です。
追記：このID修正後にiPhoneは起動したが、Watchで整合性エラーになる報告があります。
本ツールはWatch用の署名・プロファイルを作るものではありません。
Watchへの導入を完成させるには別の署名経路の確認が必要です。

別のApple AccountにはこのIPAをそのまま使わないでください。
別の人で同じエラーが出る場合は、エラー内の expected（必要なID）を確認して
その人のIDに合わせる必要があります。パスワードや確認コードは不要です。

再試行して別のエラーが出た場合は、そのエラー文をそのまま制作者へ伝えてください。
'''
    (out / '04で止まった場合の再試行手順.txt').write_text(instructions, encoding='utf-8-sig')
    package = out.with_suffix('.zip')
    with zipfile.ZipFile(package, 'w', zipfile.ZIP_DEFLATED) as archive:
        for file in sorted(out.iterdir()):
            if file.is_file(): archive.write(file, out.name + '/' + file.name)
    print(json.dumps({'ipa': str(dest), 'zip': str(package), **report}, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--team-id', required=True)
    prepare(parser.parse_args().team_id)
