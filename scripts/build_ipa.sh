#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
xcodegen generate
xcodebuild -project Fairway.xcodeproj -scheme Fairway -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath build/device \
  CODE_SIGNING_ALLOWED=NO build 2>&1 | tee build/device-build.log
python3 scripts/package_ipa.py
