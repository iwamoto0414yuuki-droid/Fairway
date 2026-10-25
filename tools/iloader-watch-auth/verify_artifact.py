"""Validate downloaded CI artifacts before preparing the recipient package."""
from pathlib import Path, PurePosixPath
import hashlib
import json
import sys
import zipfile

ROOT=Path(__file__).resolve().parents[2]


def verify(archive_path, run_url, commit, expected_archive_sha256):
    archive_path=Path(archive_path)
    assert hashlib.sha256(archive_path.read_bytes()).hexdigest()==expected_archive_sha256
    out=ROOT/'release/watch-auth-loader';out.mkdir(exist_ok=True)
    with zipfile.ZipFile(archive_path) as archive:
        assert archive.testzip() is None
        for name in archive.namelist():
            path=PurePosixPath(name)
            assert not path.is_absolute() and '..' not in path.parts and '\\' not in name
        archive.extractall(out)
    report=json.loads((out/'verification.json').read_text(encoding='utf-8'))
    for name,key in [('Fairway-Watch-Loader.exe','exe_sha256'),('Fairway-Watch-Loader-source.zip','source_sha256')]:
        assert hashlib.sha256((out/name).read_bytes()).hexdigest()==report[key]
    assert report['auth_backport_tests_passed']==21
    assert report['certificate_reuse_tests_passed']==5
    assert report['physical_login_verified'] is False and report['physical_watch_install_verified'] is False
    assert report['automatic_certificate_revocation'] is False
    assert 'Packaged GUI window initialized' in (out/'gui-smoke.txt').read_text(encoding='utf-8-sig')
    patch=json.loads((out/'patch-manifest.json').read_text())
    with zipfile.ZipFile(out/'Fairway-Watch-Loader-source.zip') as source:
        assert source.testzip() is None
        assert not any('.git' in PurePosixPath(n).parts or n.endswith(('.p12','.mobileprovision')) for n in source.namelist())
        for path,digest in patch['watch_signing_install_files_unchanged'].items():
            assert hashlib.sha256(source.read('isideload/'+path)).hexdigest()==digest,path
        config=json.loads(source.read('iloader/src-tauri/tauri.conf.json'))
        assert config['identifier']==report['app_identifier']=='local.fairway.watchloader.auth20261025'
        assert config['plugins']=={} and not config['bundle']['createUpdaterArtifacts']
        account=source.read('iloader/src-tauri/src/account.rs').decode('utf-8')
        assert 'MaxCertsBehavior::Error' in account and 'MaxCertsBehavior::Prompt' not in account
        assert report['keyring_service'] in account
        assert 'pub async fn reuse_original_certificate' in account
        assert 'KeyringStorage::new("iloader".into())' in account
        interface=source.read('iloader/src/App.tsx').decode('utf-8')
        assert 'Fairway Watch Loader' in interface
        assert '通常版iloaderの署名鍵を再利用' in interface
        assert config['version']=='2.3.1-auth.20261025.2'
        assert 'installSideStoreOperation' not in interface and 'installLiveContainerOperation' not in interface
        assert interface.count('t("app.import_ipa")')==1
    report.update(run_url=run_url,source_commit=commit,artifact_sha256=expected_archive_sha256,
                  ci_packaged_gui_smoke_passed=True,packaged_watch_source_hashes_verified=True,
                  local_account_login_attempted=False)
    (out/'verification.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report,indent=2))


if __name__=='__main__':verify(*sys.argv[1:])
