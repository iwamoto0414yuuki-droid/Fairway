"""Package an unsigned personal experiment with its corresponding modified source."""
from pathlib import Path
import hashlib
import json
import shutil
import sys
import zipfile

root = Path(sys.argv[1]).resolve()
out = root.parent
ipa = root/'SideStore.ipa'
with zipfile.ZipFile(ipa) as archive:
    assert archive.testzip() is None
    assert 'Payload/SideStore.app/Info.plist' in archive.namelist()
dest = out/'SideStore-Watch-personal.ipa'
shutil.copyfile(ipa, dest)
source = out/'SideStore-Watch-personal-source.zip'
with zipfile.ZipFile(source, 'w', zipfile.ZIP_DEFLATED) as archive:
    for path in root.rglob('*'):
        if not path.is_file():
            continue
        relative = path.relative_to(root)
        if any(part in {'.git', '.build', 'SideStore.xcarchive', 'build', 'Payload'} for part in relative.parts):
            continue
        if path.suffix in {'.ipa', '.p12', '.mobileprovision'} or path.name == 'CodeSigning.xcconfig':
            continue
        archive.write(path, 'SideStore/'+relative.as_posix())
    here = Path(__file__).resolve().parent
    for path in here.rglob('*'):
        if path.is_file() and '__pycache__' not in path.parts:
            archive.write(path, 'PersonalBuild/'+path.relative_to(here).as_posix())
report = {'sideStore_base': 'd97ec133719d79916675bdaf722b82a8d091d545',
          'sideSign_base': '752d1ef602aa792a432ffa1e71646dc1ecf7363c',
          'ipa_sha256': hashlib.sha256(dest.read_bytes()).hexdigest(),
          'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
          'unsigned': True, 'personal_experiment': True,
          'physical_watch_install_verified': False, 'session_migration_verified': False}
(out/'SideStore-Watch-build.json').write_text(json.dumps(report, indent=2)+'\n')
print(json.dumps(report))
