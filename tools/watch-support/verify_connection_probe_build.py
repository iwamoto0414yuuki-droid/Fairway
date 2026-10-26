"""Verify a downloaded diagnostic artifact before giving its IPA to the user.

Usage: python verify_connection_probe_build.py ARTIFACT_ZIP SOURCE_COMMIT RUN_URL
This establishes build/source correspondence, not physical Watch support.
"""
from pathlib import Path
import hashlib
import io
import json
import plistlib
import shutil
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[2]


def bundle_ids(archive):
    values = {}
    for name in archive.namelist():
        parent = name.removesuffix('/Info.plist')
        if name.endswith('/Info.plist') and parent.endswith(('.app', '.appex')):
            values[name] = plistlib.loads(archive.read(name))['CFBundleIdentifier']
    return values


def verify(artifact_path, source_commit, run_url):
    artifact_path = Path(artifact_path)
    required = ['SideStore-Watch-personal.ipa', 'SideStore-Watch-personal-source.zip',
                'SideStore-Watch-build.json', 'watch-tests.log', 'watch-probe-tests.log']
    with zipfile.ZipFile(artifact_path) as archive:
        assert archive.testzip() is None
        data = {name: archive.read(name) for name in required}
    report = json.loads(data['SideStore-Watch-build.json'])
    for filename, key in [('SideStore-Watch-personal.ipa', 'ipa_sha256'),
                          ('SideStore-Watch-personal-source.zip', 'source_sha256')]:
        assert hashlib.sha256(data[filename]).hexdigest() == report[key]
    assert report['watch_connection_probe'] is True
    assert report['probe_changes_apps'] is False
    assert report['physical_probe_verified'] is False
    assert report['idevice_base'] == '3e55c8486b2057e40c1f74aaaa1155c82341cf76'
    assert '5 passed; 0 failed' in data['watch-probe-tests.log'].decode()
    assert 'Executed 26 tests, with 0 failures' in data['watch-tests.log'].decode()
    with zipfile.ZipFile(io.BytesIO(data['SideStore-Watch-personal.ipa'])) as ipa:
        assert ipa.testzip() is None
        info = plistlib.loads(ipa.read('Payload/SideStore.app/Info.plist'))
        assert info['CFBundleIdentifier'] == 'com.SideStore.SideStore'
        baseline = ROOT/'release/SideStore_Watch_iOS系プロファイル対応版/SideStore-Watch-ios-family-fix.ipa'
        with zipfile.ZipFile(baseline) as previous:
            assert bundle_ids(ipa) == bundle_ids(previous), 'Host/extension IDs changed'
        binary = ipa.read('Payload/SideStore.app/' + info['CFBundleExecutable'])
        for marker in ['WCP_SERVICE', 'WCP_REGISTRY', 'WCP_FORWARD', 'WCP_CONNECT',
                       'WCP_IDENTITY', 'WCP_CLEANUP', 'Watch通信を診断']:
            assert marker.encode() in binary, marker
    with zipfile.ZipFile(io.BytesIO(data['SideStore-Watch-personal-source.zip'])) as source:
        assert source.testzip() is None
        gateway = source.read('SideStore/Dependencies/minimuxer/DeviceGateway/idevice/IdeviceGateway.swift').decode()
        assert 'fairway_watch_connection_probe(isolated.adapter, isolated.handshake' in gateway
        assert 'let isolated = IdeviceGateway()' in gateway
        native = source.read('SideStore/NativeIDeviceSource/ffi/src/watch_connection_probe.rs')
        assert b'fairway_watch_connection_probe' in native
        assert b'stop_forwarding_service_port(PORT)' in native
        assert 'PersonalBuild/sidestore-watch-probe.yml' in source.namelist()
        assert any(name.endswith('/NativeIDeviceSource/idevice/Cargo.toml') for name in source.namelist())
        assert not any(Path(name).suffix in {'.p12', '.mobileprovision'} for name in source.namelist())
        assert not any('/.git/' in name or '/NativeIDevice.xcframework/' in name for name in source.namelist())
        previous_source = ROOT/'release/SideStore_Watch_iOS系プロファイル対応版/SideStore-Watch-personal-source.zip'
        with zipfile.ZipFile(previous_source) as previous:
            for path in ['SideStore/SideStore/Core/Auth/AuthManager.swift',
                         'SideStore/SideStore/Core/Certificates/CertificateManager.swift']:
                assert source.read(path).replace(b'\r\n', b'\n') == previous.read(path).replace(b'\r\n', b'\n')
    out = ROOT / 'release/SideStore_Watch_通信診断版_20261026'
    out.mkdir(parents=True, exist_ok=True)
    (out/'SideStore-Watch-connection-probe.ipa').write_bytes(data['SideStore-Watch-personal.ipa'])
    (out/'SideStore-Watch-connection-probe-source.zip').write_bytes(data['SideStore-Watch-personal-source.zip'])
    for name in ['watch-tests.log', 'watch-probe-tests.log']:
        (out/name).write_bytes(data[name])
    shutil.copyfile(ROOT/'docs/watch-sideloading/CONNECTION_PROBE.md', out/'01_説明と手順.md')
    report.update(source_commit=source_commit, run_url=run_url,
                  artifact_sha256=hashlib.sha256(artifact_path.read_bytes()).hexdigest(),
                  native_probe_unit_tests=5, watch_signing_tests=26,
                  native_probe_present_in_ipa=True,
                  host_extension_ids_match_previous_build=True,
                  auth_certificate_manager_sources_unchanged=True,
                  isolated_probe_tunnel_verified_in_source=True,
                  physical_watch_install_verified=False,
                  phone_only_watch_automatic_refresh_verified=False)
    (out/'verification.json').write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    (out/'SHA256.txt').write_text('\n'.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+p.name
                                              for p in sorted(out.iterdir()) if p.is_file() and p.name != 'SHA256.txt')+'\n', encoding='utf-8')
    with zipfile.ZipFile(out.with_suffix('.zip'), 'w', zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(out.iterdir()):
            if path.is_file(): archive.write(path, out.name+'/'+path.name)
    print(json.dumps(report, indent=2))
    print(out)


if __name__ == '__main__':
    verify(*sys.argv[1:])
