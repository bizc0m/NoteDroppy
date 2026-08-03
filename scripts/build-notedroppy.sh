#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT_DIR/outputs/NoteDroppy.app"
SRC="$ROOT_DIR/work/NotePlanURLDrop/main.swift"
BIN="$APP/Contents/MacOS/NoteDroppy"
PLIST="$APP/Contents/Info.plist"
VERSION="${1:-1.37}"
BUILD="${2:-47}"
SIGN_IDENTITY="${NOTEDROPPY_CODESIGN_IDENTITY:-NoteDroppy Local Code Signing}"

if ! security find-identity -v -p codesigning | grep -Fq "\"$SIGN_IDENTITY\""; then
  SIGN_IDENTITY="-"
fi

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O \
  -framework AppKit \
  -framework ApplicationServices \
  -framework Carbon \
  "$SRC" \
  -o "$BIN"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD" "$PLIST"

ditto --norsrc --noextattr "$ROOT_DIR/HELP.md" "$APP/Contents/Resources/HELP.md"
ditto --norsrc --noextattr "$ROOT_DIR/HELP.en.md" "$APP/Contents/Resources/HELP.en.md"
ditto --norsrc --noextattr "$ROOT_DIR/README.en.md" "$APP/Contents/Resources/README.en.md"

xattr -cr "$APP" 2>/dev/null || true
codesign --force --deep --options runtime -s "$SIGN_IDENTITY" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

echo "Built: $APP"
