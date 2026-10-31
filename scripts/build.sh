#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
configuration="${CONFIGURATION:-release}"
swift build -c "$configuration"
bin_dir="$(swift build -c "$configuration" --show-bin-path)"
app="dist/Cadence.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin_dir/Cadence" "$app/Contents/MacOS/Cadence"
cp Resources/Info.plist "$app/Contents/Info.plist"
if [[ -f Resources/AppIcon.icns ]]; then cp Resources/AppIcon.icns "$app/Contents/Resources/"; fi
codesign --force --sign - --identifier com.aryanrathore.cadence \
  --requirements '=designated => identifier "com.aryanrathore.cadence"' "$app"
codesign --verify --strict "$app"
ditto -c -k --sequesterRsrc --keepParent "$app" dist/Cadence-macOS.zip
echo "Built $app and dist/Cadence-macOS.zip"
