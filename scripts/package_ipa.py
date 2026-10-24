"""Package the actual device build, preserving the embedded Watch app."""
from pathlib import Path
import hashlib
import plistlib
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def package():
    app = ROOT / "build/device/Build/Products/Release-iphoneos/Fairway.app"
    if not app.is_dir():
        raise SystemExit("Device build missing; a simulator build is not an installable IPA")
    with (app / "Info.plist").open("rb") as f:
        phone = plistlib.load(f)
    watches = list((app / "Watch").glob("*.app"))
    if len(watches) != 1:
        raise SystemExit("Exactly one embedded Watch app is required")
    with (watches[0] / "Info.plist").open("rb") as f:
        watch = plistlib.load(f)
    assert phone["CFBundleSupportedPlatforms"] == ["iPhoneOS"]
    assert watch["CFBundleSupportedPlatforms"] == ["WatchOS"]
    assert watch["WKCompanionAppBundleIdentifier"] == phone["CFBundleIdentifier"]
    assert watch["CFBundleIdentifier"].startswith(phone["CFBundleIdentifier"] + ".")
    for bundle, info in [(app, phone), (watches[0], watch)]:
        executable = bundle / info["CFBundleExecutable"]
        if not executable.is_file() or executable.stat().st_size < 1024:
            raise SystemExit("Native executable missing: " + str(executable))
    dest = ROOT / "build/Fairway-0.2.0-unsigned.ipa"
    with zipfile.ZipFile(dest, "w", zipfile.ZIP_DEFLATED) as archive:
        for file in sorted(app.rglob("*")):
            if file.is_file():
                archive.write(file, "Payload/Fairway.app/" + file.relative_to(app).as_posix())
    digest = hashlib.sha256(dest.read_bytes()).hexdigest()
    dest.with_suffix(".ipa.sha256").write_text(digest + "  " + dest.name + "\n", encoding="utf-8")
    print(f"Packaged {dest.name}: {dest.stat().st_size} bytes; Watch bundle verified")


if __name__ == "__main__":
    package()
