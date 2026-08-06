#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT_DIR/outputs/NoteDroppy V3.app"
SRC="$ROOT_DIR/work/NoteDroppyV3/main.swift"
BIN="$APP/Contents/MacOS/NoteDroppyV3"
PLIST="$APP/Contents/Info.plist"
VERSION="${1:-3.0}"
BUILD="${2:-300}"
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
  <key>CFBundleExecutable</key>
  <string>NoteDroppyV3</string>
  <key>CFBundleIdentifier</key>
  <string>local.codex.notedroppy.v3</string>
  <key>CFBundleName</key>
  <string>NoteDroppy V3</string>
  <key>CFBundleDisplayName</key>
  <string>NoteDroppy V3</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>3.0</string>
  <key>CFBundleVersion</key>
  <string>300</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSQuitAlwaysKeepsWindows</key>
  <false/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD" "$PLIST"

ditto --norsrc --noextattr "$ROOT_DIR/README.md" "$APP/Contents/Resources/README.md"
ditto --norsrc --noextattr "$ROOT_DIR/CHANGELOG.md" "$APP/Contents/Resources/CHANGELOG.md" 2>/dev/null || true

xattr -cr "$APP" 2>/dev/null || true
codesign --force --deep -s "$SIGN_IDENTITY" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

echo "Built: $APP"
