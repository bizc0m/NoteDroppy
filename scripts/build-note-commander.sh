#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT_DIR/outputs/Note Commander.app"
SRC="$ROOT_DIR/work/NoteDroppyV3/main.swift"
BIN="$APP/Contents/MacOS/NoteCommander"
PLIST="$APP/Contents/Info.plist"
VERSION="${1:-1.0}"
BUILD="${2:-100}"
SIGN_IDENTITY="${NOTEDROPPY_CODESIGN_IDENTITY:-NoteDroppy Local Code Signing}"

if ! security find-identity -v -p codesigning | grep -Fq "\"$SIGN_IDENTITY\""; then
  SIGN_IDENTITY="-"
fi

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O \
  -parse-as-library \
  -framework AppKit \
  "$SRC" \
  -o "$BIN"

cat > "$PLIST" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDisplayName</key>
  <string>Note Commander</string>
  <key>CFBundleExecutable</key>
  <string>NoteCommander</string>
  <key>CFBundleIdentifier</key>
  <string>local.codex.notecommander</string>
  <key>CFBundleName</key>
  <string>Note Commander</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>100</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>NSQuitAlwaysKeepsWindows</key>
  <false/>
</dict>
</plist>
PLIST

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD" "$PLIST"

ditto --norsrc --noextattr "$ROOT_DIR/README.md" "$APP/Contents/Resources/README.md" 2>/dev/null || true
ditto --norsrc --noextattr "$ROOT_DIR/CHANGELOG.md" "$APP/Contents/Resources/CHANGELOG.md" 2>/dev/null || true

xattr -cr "$APP" 2>/dev/null || true
codesign --force --deep --options runtime -s "$SIGN_IDENTITY" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

echo "Built: $APP"
