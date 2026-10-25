"""Synthetic positive/negative cases for the reusable read-only inspector."""
import plistlib
from pathlib import Path
import struct
import tempfile
import unittest
import zipfile
from inspect_ipa import inspect


def binary(cpu, platform):
    # Minimal Mach-O header + LC_BUILD_VERSION; not executable application code.
    return struct.pack('<8I', 0xFEEDFACF, cpu, 0, 2, 1, 24, 0, 0) + struct.pack('<6I', 0x32, 24, platform, 0, 0, 0)


class InspectorTests(unittest.TestCase):
    def fixture(self, path, companion='local.example', watch_platform=4,
                omit_watch=False, omit_executable=False, watch_cpu=0x0200000C):
        phone = {'CFBundleIdentifier': 'local.example', 'CFBundleSupportedPlatforms': ['iPhoneOS'],
                 'CFBundleExecutable': 'Phone', 'CFBundleShortVersionString': '1.0', 'CFBundleVersion': '1'}
        watch = {**phone, 'CFBundleIdentifier': 'local.example.watchkitapp',
                 'CFBundleSupportedPlatforms': ['WatchOS'], 'CFBundleExecutable': 'Watch',
                 'WKCompanionAppBundleIdentifier': companion}
        with zipfile.ZipFile(path, 'w') as z:
            z.writestr('Payload/Phone.app/Info.plist', plistlib.dumps(phone))
            z.writestr('Payload/Phone.app/Phone', binary(0x0100000C, 2))
            if not omit_watch:
                z.writestr('Payload/Phone.app/Watch/Watch.app/Info.plist', plistlib.dumps(watch))
                if not omit_executable:
                    z.writestr('Payload/Phone.app/Watch/Watch.app/Watch', binary(watch_cpu, watch_platform))

    def check_case(self, expected_error=None, **kwargs):
        # Keep synthetic files inside the caller's writable workspace rather
        # than a restricted Windows sandbox's process-wide TEMP directory.
        workspace = Path.cwd().resolve()
        with tempfile.TemporaryDirectory(prefix='.ipa-test-', dir=workspace) as directory:
            path = Path(directory)/'test.ipa'
            assert path.resolve().is_relative_to(workspace)
            self.fixture(path, **kwargs)
            before = path.read_bytes()
            if expected_error:
                with self.assertRaisesRegex(ValueError, expected_error):
                    inspect(path, require_watch_arm64_32=True)
            else:
                self.assertFalse(inspect(path, True)['apple_signing_or_installation_verified'])
            self.assertEqual(before, path.read_bytes())

    def test_valid_structure_is_read_only(self): self.check_case()
    def test_wrong_companion(self): self.check_case('Wrong companion', companion='wrong.parent')
    def test_missing_watch(self): self.check_case('No embedded Watch', omit_watch=True)
    def test_simulator_even_when_plist_says_watchos(self): self.check_case('simulator', watch_platform=9)
    def test_missing_executable(self): self.check_case('Missing executable', omit_executable=True)
    def test_required_architecture_missing(self): self.check_case('arm64_32', watch_cpu=0x0100000C)


if __name__ == '__main__': unittest.main()
