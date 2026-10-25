"""Read-only structural check of an unsigned iPhone IPA with embedded Watch apps.

Standard library only. Does not extract files or inspect pairing/profile secrets.
Not an Apple signature, entitlement, installation, or renewal validator.
"""
from pathlib import Path, PurePosixPath
import argparse
import hashlib
import json
import plistlib
import struct
import zipfile


def require(condition, message):
    if not condition:
        raise ValueError(message)


def macho_slices(data):
    """Return (CPU, target-platform) pairs for thin/fat physical Mach-O files."""
    require(len(data) >= 8, 'Missing/truncated native executable')
    magic = struct.unpack_from('>I', data)[0]
    if magic in (0xCAFEBABE, 0xCAFEBABF):
        count = struct.unpack_from('>I', data, 4)[0]
        width = 32 if magic == 0xCAFEBABF else 20
        require(0 < count <= 32 and 8+count*width <= len(data), 'Invalid fat Mach-O header')
        result = []
        for i in range(count):
            pos = 8+i*width
            offset, size = struct.unpack_from('>QQ' if width == 32 else '>II', data, pos+8)
            require(offset >= 8+count*width and size > 0 and offset+size <= len(data), 'Invalid Mach-O slice')
            # Avoid recursive fat containers in malformed inputs.
            chunk = data[offset:offset+size]
            require(struct.unpack_from('>I', chunk)[0] not in (0xCAFEBABE, 0xCAFEBABF), 'Nested fat Mach-O')
            result.extend(macho_slices(chunk))
        return result
    little = struct.unpack_from('<I', data)[0]
    endian = '<' if little in (0xFEEDFACE, 0xFEEDFACF) else '>'
    value = struct.unpack_from(endian+'I', data)[0]
    require(value in (0xFEEDFACE, 0xFEEDFACF), 'Not a native Mach-O executable')
    header = 32 if value == 0xFEEDFACF else 28
    require(len(data) >= header, 'Truncated Mach-O header')
    cpu = struct.unpack_from(endian+'I', data, 4)[0]
    ncmds, command_size = struct.unpack_from(endian+'II', data, 16)
    require(ncmds <= 10000 and header+command_size <= len(data), 'Invalid load commands')
    position, platform = header, None
    for _ in range(ncmds):
        require(position+8 <= header+command_size, 'Truncated load command')
        command, size = struct.unpack_from(endian+'II', data, position)
        require(size >= 8 and position+size <= header+command_size, 'Invalid load command size')
        if command == 0x32:  # LC_BUILD_VERSION
            require(size >= 24, 'Truncated build version')
            platform = struct.unpack_from(endian+'I', data, position+8)[0]
        elif command in (0x25, 0x30):  # legacy iPhoneOS / watchOS
            platform = 2 if command == 0x25 else 4
        position += size
    require(platform is not None, 'Missing Mach-O target-platform metadata')
    return [(cpu, platform)]


def inspect(path, require_watch_arm64_32=False):
    path = Path(path)
    with zipfile.ZipFile(path) as archive:
        require(archive.testzip() is None, 'Corrupt ZIP')
        names = archive.namelist()
        require(len(names) == len(set(names)), 'Duplicate ZIP paths')
        for name in names:
            p = PurePosixPath(name)
            require(not p.is_absolute() and '..' not in p.parts and '\\' not in name, 'Unsafe ZIP path')
        roots = [n[:-len('/Info.plist')] for n in names
                 if len(PurePosixPath(n).parts) == 3 and n.startswith('Payload/')
                 and n.endswith('.app/Info.plist')]
        require(len(roots) == 1, 'Expected one iPhone app at Payload/*.app')
        host = roots[0]
        children = [n[:-len('/Info.plist')] for n in names
                    if n.startswith(host+'/Watch/') and n.endswith('.app/Info.plist')
                    and len(PurePosixPath(n).parts) == 5]
        require(children, 'No embedded Watch app found')

        def bundle(root, expected_plist_platform, expected_macho_platform):
            info = plistlib.loads(archive.read(root+'/Info.plist'))
            require(expected_plist_platform in info.get('CFBundleSupportedPlatforms', []), 'Wrong plist platform: '+root)
            executable = info.get('CFBundleExecutable', '')
            require(executable and '/' not in executable and '\\' not in executable, 'Invalid executable name')
            require(root+'/'+executable in names, 'Missing executable: '+root)
            slices = macho_slices(archive.read(root+'/'+executable))
            require(all(platform == expected_macho_platform for _, platform in slices), 'Wrong native platform / simulator: '+root)
            require(bool(info.get('CFBundleIdentifier')), 'Missing bundle ID')
            return info, slices

        phone, phone_slices = bundle(host, 'iPhoneOS', 2)
        watches = []
        for child in children:
            watch, slices = bundle(child, 'WatchOS', 4)
            require(watch.get('WKCompanionAppBundleIdentifier') == phone['CFBundleIdentifier'], 'Wrong companion ID')
            require(watch['CFBundleIdentifier'].startswith(phone['CFBundleIdentifier']+'.'), 'Watch ID outside parent namespace')
            for key in ('CFBundleShortVersionString', 'CFBundleVersion'):
                require(bool(phone.get(key)) and watch.get(key) == phone[key], 'Version mismatch: '+key)
            if require_watch_arm64_32:
                require(any(cpu == 0x0200000C for cpu, _ in slices), 'Required Watch arm64_32 slice missing')
            watches.append({'bundle_id': watch['CFBundleIdentifier'], 'slices': slices})
    return {'scope': 'structure-only', 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
            'phone_bundle_id': phone['CFBundleIdentifier'], 'phone_slices': phone_slices,
            'watch_bundles': watches, 'apple_signing_or_installation_verified': False}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('ipa')
    parser.add_argument('--require-watch-arm64-32', action='store_true')
    args = parser.parse_args()
    try:
        print(json.dumps(inspect(args.ipa, args.require_watch_arm64_32), ensure_ascii=False, indent=2))
    except (ValueError, KeyError, OSError, zipfile.BadZipFile, plistlib.InvalidFileException, struct.error) as error:
        parser.exit(1, 'IPA structure check failed: '+str(error)+'\n')
