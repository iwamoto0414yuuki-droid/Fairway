#!/bin/bash
# macOS/Xcode example. Run from the new application's project root.
# Assumes ordinary Xcode-generated app layout; inspect special symlink frameworks separately.
set -euo pipefail
xcodegen generate
xcodebuild -project ExampleApp.xcodeproj -scheme ExampleApp \
  -configuration Release -destination 'generic/platform=iOS' \
  -derivedDataPath build/device CODE_SIGNING_ALLOWED=NO build
python3 - <<'PY'
from pathlib import Path
import hashlib, plistlib, zipfile

app = Path('build/device/Build/Products/Release-iphoneos/ExampleApp.app')
if not app.is_dir():
    raise SystemExit('Missing physical-device app; do not use a simulator product')
phone = plistlib.loads((app/'Info.plist').read_bytes())
watches = list((app/'Watch').glob('*.app'))
if len(watches) != 1:
    raise SystemExit('This minimal example expects exactly one embedded Watch app')
watch = plistlib.loads((watches[0]/'Info.plist').read_bytes())
assert phone['CFBundleSupportedPlatforms'] == ['iPhoneOS']
assert watch['CFBundleSupportedPlatforms'] == ['WatchOS']
assert watch['WKCompanionAppBundleIdentifier'] == phone['CFBundleIdentifier']
assert watch['CFBundleIdentifier'].startswith(phone['CFBundleIdentifier']+'.')
for key in ('CFBundleShortVersionString', 'CFBundleVersion'):
    assert phone[key] == watch[key]
for bundle, info in ((app, phone), (watches[0], watch)):
    assert (bundle/info['CFBundleExecutable']).is_file()
dest = Path('build/ExampleApp-unsigned.ipa')
with zipfile.ZipFile(dest, 'w', zipfile.ZIP_DEFLATED) as archive:
    for file in sorted(app.rglob('*')):
        if file.is_symlink():
            raise SystemExit('Symlink found; use an archive method preserving its semantics')
        if file.is_file():
            archive.write(file, 'Payload/'+app.name+'/'+file.relative_to(app).as_posix())
digest = hashlib.sha256(dest.read_bytes()).hexdigest()
dest.with_suffix('.ipa.sha256').write_text(digest+'  '+dest.name+'\n', encoding='utf-8')
print(dest, digest)
PY
