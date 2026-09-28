#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP="Snipes.app"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

if [[ -f "./make-icon.sh" ]]; then
  echo "Building app icon..."
  bash ./make-icon.sh
fi

echo "Building Snipes 2D (release)..."
swift build -c release

echo "Assembling ${APP}..."
rm -rf "${APP}"
mkdir -p "${APP}/Contents/MacOS"
mkdir -p "${APP}/Contents/Resources"
if [[ -f AppIcon.icns ]]; then
  cp AppIcon.icns "${APP}/Contents/Resources/"
fi
if [[ -f docs/HELP.md ]]; then
  cp docs/HELP.md "${APP}/Contents/Resources/"
fi
cp .build/release/Snipes "${APP}/Contents/MacOS/Snipes"
chmod +x "${APP}/Contents/MacOS/Snipes"
cp AppInfo.plist "${APP}/Contents/Info.plist"

xattr -cr "${APP}" 2>/dev/null || true
if command -v codesign >/dev/null 2>&1; then
  codesign --force --sign - --timestamp=none "${APP}/Contents/MacOS/Snipes" || true
  codesign --force --sign - --timestamp=none "${APP}" || true
fi

echo "Installing to Applications..."
rm -rf "/Users/timbestler/Applications/${APP}"
rm -rf "/Users/timbestler/Applications/Snipes 3D.app"
cp -R "${APP}" "/Users/timbestler/Applications/${APP}"
xattr -cr "/Users/timbestler/Applications/${APP}" 2>/dev/null || true

echo "Done: /Users/timbestler/Applications/${APP}"
echo "Launch: open '/Users/timbestler/Applications/${APP}'"