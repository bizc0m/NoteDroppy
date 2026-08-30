#!/bin/zsh
# Build NoteDroppy V4 — local, sans reseau, sans dependance externe.
# Usage : ./scripts/build-notedroppy-v4.sh [version] [build]
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT_DIR/outputs/NoteDroppy V4.app"
SRC_DIR="$ROOT_DIR/work/NoteDroppyV4"
BIN="$APP/Contents/MacOS/NoteDroppyV4"
PLIST="$APP/Contents/Info.plist"
VERSION="${1:-4.0}"
BUILD="${2:-400}"
BUNDLE_ID="local.codex.notedroppy.v4"
SIGN_IDENTITY="${NOTEDROPPY_CODESIGN_IDENTITY:-NoteDroppy Local Code Signing}"

if ! security find-identity -v -p codesigning | grep -Fq "\"$SIGN_IDENTITY\""; then
  SIGN_IDENTITY="-"
fi
echo "Identite de signature : $SIGN_IDENTITY"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# Le moteur (Engine.swift) est une copie verbatim du moteur V3 ; main.swift porte l'UI V4.
# ShortcutSlotStore.swift : couche donnees du systeme a 20 slots de raccourcis
# (etape 1 du plan de migration V5, port depuis NotePlanURLDrop/main.swift).
swiftc -O \
  -parse-as-library \
  -framework AppKit \
  -framework Carbon \
  "$SRC_DIR/Engine.swift" \
  "$SRC_DIR/ShortcutSlotStore.swift" \
  "$SRC_DIR/PasteboardResolver.swift" \
  "$SRC_DIR/SlotUIHelpers.swift" \
  "$SRC_DIR/NoteSearchWindowController.swift" \
  "$SRC_DIR/HotkeyRecorder.swift" \
  "$SRC_DIR/ShortcutSlotDropViews.swift" \
  "$SRC_DIR/ShortcutSlotRow.swift" \
  "$SRC_DIR/GlobalShortcutMonitor.swift" \
  "$SRC_DIR/CaptureWriter.swift" \
  "$SRC_DIR/main.swift" \
  -o "$BIN"

cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>NoteDroppyV4</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>NoteDroppy V4</string>
  <key>CFBundleDisplayName</key>
  <string>NoteDroppy V4</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD</string>
  <key>CFBundleIconFile</key>
  <string>NoteDroppy</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSQuitAlwaysKeepsWindows</key>
  <false/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

# Ressources locales : les JSON du depot servent de graine a Application Support.
ditto --norsrc --noextattr "$ROOT_DIR/prompts.json" "$APP/Contents/Resources/prompts.json"
ditto --norsrc --noextattr "$ROOT_DIR/capture-rules.json" "$APP/Contents/Resources/capture-rules.json"
if [ -f "$ROOT_DIR/work/NoteDroppy.icns" ]; then
  ditto --norsrc --noextattr "$ROOT_DIR/work/NoteDroppy.icns" "$APP/Contents/Resources/NoteDroppy.icns"
fi

xattr -cr "$APP" 2>/dev/null || true
codesign --force --deep -s "$SIGN_IDENTITY" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

echo "--- Info.plist ---"
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST"
/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST"
/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$PLIST"
echo "Built: $APP"
