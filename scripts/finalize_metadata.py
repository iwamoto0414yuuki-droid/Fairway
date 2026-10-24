"""Normalize unsigned IPA bundle metadata; preserve every executable byte.

XcodeGen's default Info.plist version is 1.0/1 unless properties are explicit.
The original CI artifact is retained separately before this packaging step.
"""
from pathlib import Path
import hashlib
import plistlib
import zipfile


def finalize(ipa: Path):
    original = hashlib.sha256(ipa.read_bytes()).hexdigest()
    infos = {'Payload/Fairway.app/Info.plist', 'Payload/Fairway.app/Watch/FairwayWatch.app/Info.plist'}
    with zipfile.ZipFile(ipa) as archive:
        entries = [(entry, archive.read(entry)) for entry in archive.infolist()]
    changed = []
    rewritten = []
    for entry, data in entries:
        if entry.filename in infos:
            info = plistlib.loads(data)
            if info.get('CFBundleShortVersionString') != '0.2.0' or info.get('CFBundleVersion') != '2':
                assert (info.get('CFBundleShortVersionString'), info.get('CFBundleVersion')) == ('1.0', '1')
                info['CFBundleShortVersionString'] = '0.2.0'
                info['CFBundleVersion'] = '2'
                data = plistlib.dumps(info, fmt=plistlib.FMT_BINARY)
                changed.append(entry.filename)
        rewritten.append((entry, data))
    if changed:
        temp = ipa.with_suffix('.ipa.tmp')
        with zipfile.ZipFile(temp, 'w') as archive:
            for entry, data in rewritten:
                archive.writestr(entry, data)
        with zipfile.ZipFile(temp) as archive:
            for entry, data in entries:
                if entry.filename not in infos:
                    assert archive.read(entry.filename) == data, 'Packaging changed a non-metadata file'
        temp.replace(ipa)
    return {'ci_ipa_sha256': original, 'metadata_files_normalized': changed, 'all_non_metadata_files_preserved': True}
