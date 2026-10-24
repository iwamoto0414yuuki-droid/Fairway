"""Verify the actual 0.3.0 device IPA and its native test artifact."""
from pathlib import Path, PurePosixPath
import hashlib
import json
import plistlib
import re
import shutil
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def verify(artifact, run, commit):
    out = ROOT/'release/minimal-0.3.0'
    out.mkdir(exist_ok=True)
    with zipfile.ZipFile(artifact) as archive:
        assert archive.testzip() is None
        for name in archive.namelist():
            path = PurePosixPath(name)
            assert not path.is_absolute() and '..' not in path.parts and '\\' not in name
        archive.extractall(out)
    ipa = out/'Fairway-0.3.0-unsigned.ipa'
    digest = hashlib.sha256(ipa.read_bytes()).hexdigest()
    assert digest == ipa.with_suffix('.ipa.sha256').read_text().split()[0]
    log = (out/'native-tests.log').read_text(encoding='utf-8')
    assert '** TEST SUCCEEDED **' in log
    assert re.search(r'Executed 38 tests, with 0 failures', log)
    with zipfile.ZipFile(ipa) as archive:
        phone_root = 'Payload/Fairway.app/'
        watch_root = phone_root+'Watch/FairwayWatch.app/'
        phone = plistlib.loads(archive.read(phone_root+'Info.plist'))
        watch = plistlib.loads(archive.read(watch_root+'Info.plist'))
        assert phone['CFBundleSupportedPlatforms'] == ['iPhoneOS']
        assert watch['CFBundleSupportedPlatforms'] == ['WatchOS']
        assert watch['WKCompanionAppBundleIdentifier'] == phone['CFBundleIdentifier']
        assert watch['CFBundleIdentifier'].startswith(phone['CFBundleIdentifier']+'.')
        for root, info in [(phone_root, phone), (watch_root, watch)]:
            assert info['CFBundleShortVersionString'] == '0.3.0'
            assert info['CFBundleVersion'] == '3'
            assert 'NSLocationWhenInUseUsageDescription' not in info
            binary = archive.read(root+info['CFBundleExecutable'])
            assert binary[:4].hex() in {'cffaedfe','cefaedfe','cafebabe','bebafeca'}
    shutil.copyfile(ipa, ROOT/'release'/ipa.name)
    shutil.copyfile(ipa.with_suffix('.ipa.sha256'), ROOT/'release'/(ipa.name+'.sha256'))
    report = {'version':'0.3.0','native_tests_passed':38,'sha256':digest,
              'bytes':ipa.stat().st_size,'source_commit':commit,
              'run_url':f'https://github.com/iwamoto0414yuuki-droid/Fairway/actions/runs/{run}',
              'phone_watch_bundle_relationship_verified':True,'location_permission_removed':True,
              'physical_device_install_verified':False,'physical_battery_tested':False}
    (ROOT/'release/verification-0.3.0.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,ensure_ascii=False))


if __name__=='__main__':verify(Path(sys.argv[1]),sys.argv[2],sys.argv[3])
