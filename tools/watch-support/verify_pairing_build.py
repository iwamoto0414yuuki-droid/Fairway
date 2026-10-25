"""Verify the recipient pairing fix and retain exact CI/source provenance."""
from pathlib import Path, PurePosixPath
import hashlib
import json
import plistlib
import shutil
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[2]


def verify(artifact, digest, run_url, commit, expected_tests=19,
           folder='SideStore_Watch_ペアリング修正版',
           guide='WATCH_PAIRING_IMPORT_FIX.md'):
    artifact = Path(artifact)
    assert hashlib.sha256(artifact.read_bytes()).hexdigest() == digest
    out = ROOT/'release'/folder
    out.mkdir(exist_ok=True)
    with zipfile.ZipFile(artifact) as archive:
        assert archive.testzip() is None
        for name in archive.namelist():
            p = PurePosixPath(name)
            assert not p.is_absolute() and '..' not in p.parts and '\\' not in name
        archive.extractall(out)
    report = json.loads((out/'SideStore-Watch-build.json').read_text())
    for name, key in [('SideStore-Watch-personal.ipa', 'ipa_sha256'),
                      ('SideStore-Watch-personal-source.zip', 'source_sha256')]:
        assert hashlib.sha256((out/name).read_bytes()).hexdigest() == report[key]
    with zipfile.ZipFile(out/'SideStore-Watch-personal.ipa') as ipa:
        assert ipa.testzip() is None
        info = plistlib.loads(ipa.read('Payload/SideStore.app/Info.plist'))
        assert info['CFBundleIdentifier'] == 'com.SideStore.SideStore'
        binary = ipa.read('Payload/SideStore.app/'+info['CFBundleExecutable'])
        assert b'Lockdown (Windows USB)' in binary
        if expected_tests == 21:
            for code in ['WPF_PLATFORM', 'WPF_APP_ID', 'WPF_TEAM', 'WPF_DEVICE', 'WPF_EXPIRED']:
                assert code.encode() in binary
    with zipfile.ZipFile(out/'SideStore-Watch-personal-source.zip') as source:
        assert source.testzip() is None
        base = 'SideStore/SideStore/'
        manager = source.read(base+'Core/Pairing/PairingFileManager.swift').decode()
        onboarding = source.read(base+'Views/Onboarding/OnboardingView.swift').decode()
        assert 'inspectPairingFile(from: url, preferred: preferred)' in manager
        assert 'let parsed = try parse(content: content, preferred: nil)' not in manager
        assert 'Picker("Pairing Protocol"' in onboarding
        assert 'preferred: selectedPairingProtocol' in onboarding
        assert 'preferredProtocol = selectedPairingProtocol' in onboarding
        if expected_tests == 21:
            watch = source.read('SideStore/Dependencies/SideSign/Sources/Models/WatchBundleSupport.swift').decode()
            assert 'failures.joined(separator:' in watch
            assert 'profile.bundleIdentifier != bundleID' in watch
            assert 'profile.teamIdentifier != teamID' in watch
            assert 'profile.expirationDate <= now' in watch
        for path in ['Core/Auth/AuthManager.swift', 'Core/Certificates/CertificateManager.swift']:
            pristine = ROOT/'build/watch-sidestore/SideStore/SideStore'/path
            assert source.read(base+path).decode().replace('\r\n', '\n') == pristine.read_text(encoding='utf-8')
    log = (out/'watch-tests.log').read_text(encoding='utf-8')
    assert f'Executed {expected_tests} tests, with 0 failures' in log
    shutil.copyfile(ROOT/'docs'/guide, out/'01_説明と導入手順.md')
    shutil.copyfile(ROOT/'tools/watch-support/SOURCE.md', out/'SOURCE-and-notices.md')
    report.update(pairing_protocol_selection=True, preferred_protocol_forwarding=True,
                  auth_certificate_managers_unchanged=True, watch_regression_tests_passed=expected_tests,
                  physical_pairing_import_verified=False, run_url=run_url, source_commit=commit,
                  artifact_sha256=digest)
    if expected_tests == 21:
        report.update(profile_diagnostic_codes_verified=True, physical_profile_diagnosis_verified=False)
        filename = 'SideStore-Watch-profile-diagnostic.ipa'
        (out/'SideStore-Watch-personal.ipa').replace(out/filename)
        report['ipa_filename'] = filename
    (out/'verification.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
    (out/'SHA256.txt').write_text('\n'.join(
        hashlib.sha256(p.read_bytes()).hexdigest()+'  '+p.name
        for p in sorted(out.iterdir()) if p.is_file() and p.name != 'SHA256.txt')+'\n', encoding='utf-8')
    destination = out.with_suffix('.zip')
    with zipfile.ZipFile(destination, 'w', zipfile.ZIP_DEFLATED) as archive:
        for p in sorted(out.iterdir()):
            if p.is_file(): archive.write(p, out.name+'/'+p.name)
    with zipfile.ZipFile(destination) as archive: assert archive.testzip() is None
    print(json.dumps(report, indent=2))
    print(destination)


if __name__ == '__main__':
    verify(*sys.argv[1:])
