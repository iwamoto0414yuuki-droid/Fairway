"""Validate a downloaded CI artifact before making it available to install."""
from pathlib import Path, PurePosixPath
import hashlib
import json
import plistlib
import re
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def verify(artifact: Path, run_id: str, commit: str):
    release = ROOT / 'release'
    release.mkdir(exist_ok=True)
    with zipfile.ZipFile(artifact) as bundle:
        for entry in bundle.infolist():
            path = PurePosixPath(entry.filename)
            if path.is_absolute() or '..' in path.parts or '\\' in entry.filename:
                raise ValueError('Unsafe artifact path')
            dest = release.joinpath(*path.parts).resolve()
            if not dest.is_relative_to(release.resolve()):
                raise ValueError('Artifact path escapes release directory')
        bundle.extractall(release)
    ipa = release / 'Fairway-0.2.0-unsigned.ipa'
    digest = hashlib.sha256(ipa.read_bytes()).hexdigest()
    expected = ipa.with_suffix('.ipa.sha256').read_text().split()[0]
    assert digest == expected, 'IPA digest does not match CI'
    log = (release / 'native-tests.log').read_text(encoding='utf-8')
    assert '** TEST SUCCEEDED **' in log, 'Native tests did not succeed'
    assert re.search(r'Executed 30 tests, with 0 failures', log), 'Expected 30 passing native tests'
    with zipfile.ZipFile(ipa) as app:
        phone = plistlib.loads(app.read('Payload/Fairway.app/Info.plist'))
        watch_path = 'Payload/Fairway.app/Watch/FairwayWatch.app/'
        watch = plistlib.loads(app.read(watch_path + 'Info.plist'))
        assert phone['CFBundleSupportedPlatforms'] == ['iPhoneOS']
        assert watch['CFBundleSupportedPlatforms'] == ['WatchOS']
        assert watch['WKCompanionAppBundleIdentifier'] == phone['CFBundleIdentifier']
        assert watch['CFBundleIdentifier'].startswith(phone['CFBundleIdentifier'] + '.')
        for prefix, info in [('Payload/Fairway.app/', phone), (watch_path, watch)]:
            executable = app.read(prefix + info['CFBundleExecutable'])
            assert executable[:4] in [bytes.fromhex(h) for h in ['cffaedfe', 'cefaedfe', 'cafebabe', 'bebafeca']], 'Not a Mach-O binary'
    result = {
        'run_url': f'https://github.com/iwamoto0414yuuki-droid/Fairway/actions/runs/{run_id}',
        'tested_source_commit': commit,
        'sha256': digest,
        'ipa_bytes': ipa.stat().st_size,
        'native_tests_passed': 30,
        'embedded_watch_bundle_verified': True,
        'sidestore_device_install_tested': False,
        'real_watch_gps_and_battery_tested': False,
    }
    (release / 'verification.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    verify(Path(sys.argv[1]), sys.argv[2], sys.argv[3])
