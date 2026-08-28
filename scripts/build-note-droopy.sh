#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT_DIR/outputs/Note Droopy.app"
SRC="$ROOT_DIR/work/NotePlanURLDrop/main.swift"
BIN="$APP/Contents/MacOS/NoteDroopy"
PLIST="$APP/Contents/Info.plist"
VERSION="${1:-3.7}"
BUILD="${2:-370}"
SIGN_IDENTITY="${NOTEDROPPY_CODESIGN_IDENTITY:-NoteDroppy Local Code Signing}"

if ! security find-identity -v -p codesigning | grep -Fq "\"$SIGN_IDENTITY\""; then
  SIGN_IDENTITY="-"
fi

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O \
  -framework AppKit \
  -framework ApplicationServices \
  -framework Carbon \
  -framework UniformTypeIdentifiers \
  "$SRC" \
  -o "$BIN"

cat > "$PLIST" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDisplayName</key>
  <string>Note Droopy</string>
  <key>CFBundleDocumentTypes</key>
  <array>
    <dict>
      <key>CFBundleTypeExtensions</key>
      <array>
        <string>webloc</string>
        <string>url</string>
        <string>textclipping</string>
        <string>txt</string>
        <string>rtf</string>
        <string>md</string>
        <string>*</string>
      </array>
      <key>CFBundleTypeName</key>
      <string>Internet Location / URL</string>
      <key>CFBundleTypeRole</key>
      <string>Viewer</string>
      <key>LSHandlerRank</key>
      <string>Alternate</string>
      <key>LSItemContentTypes</key>
      <array>
        <string>com.apple.web-internet-location</string>
        <string>public.url</string>
        <string>public.file-url</string>
        <string>public.text</string>
        <string>public.plain-text</string>
        <string>public.utf8-plain-text</string>
        <string>public.utf16-plain-text</string>
        <string>public.rtf</string>
        <string>public.content</string>
        <string>public.item</string>
        <string>public.data</string>
        <string>com.apple.finder.textclipping</string>
        <string>com.apple.textclipping</string>
        <string>com.apple.traditional-mac-plain-text</string>
      </array>
    </dict>
  </array>
  <key>CFBundleExecutable</key>
  <string>NoteDroopy</string>
  <key>CFBundleIconFile</key>
  <string>NotePlanURLDrop</string>
  <key>CFBundleIdentifier</key>
  <string>local.codex.notedroopy</string>
  <key>CFBundleName</key>
  <string>Note Droopy</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>3.7</string>
  <key>CFBundleURLTypes</key>
  <array>
    <dict>
      <key>CFBundleURLName</key>
      <string>Web URL</string>
      <key>CFBundleURLRole</key>
      <string>Viewer</string>
      <key>CFBundleURLSchemes</key>
      <array>
        <string>http</string>
        <string>https</string>
      </array>
    </dict>
  </array>
  <key>CFBundleVersion</key>
  <string>370</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSServices</key>
  <array>
    <dict>
      <key>NSMenuItem</key>
      <dict>
        <key>default</key>
        <string>NotePlan : ajouter en tâche</string>
      </dict>
      <key>NSMessage</key>
      <string>addSelectionAsTodo</string>
      <key>NSPortName</key>
      <string>Note Droopy</string>
      <key>NSSendTypes</key>
      <array>
        <string>public.utf8-plain-text</string>
        <string>public.plain-text</string>
        <string>NSStringPboardType</string>
      </array>
    </dict>
  </array>
  <key>NSSupportsOpeningDocumentsInPlace</key>
  <true/>
</dict>
</plist>
PLIST

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD" "$PLIST"

ditto --norsrc --noextattr "$ROOT_DIR/work/NotePlanURLDrop.icns" "$APP/Contents/Resources/NotePlanURLDrop.icns" 2>/dev/null || true
ditto --norsrc --noextattr "$ROOT_DIR/assets/notedroppy-logo.png" "$APP/Contents/Resources/notedroppy-logo.png" 2>/dev/null || true
ditto --norsrc --noextattr "$ROOT_DIR/HELP.md" "$APP/Contents/Resources/HELP.md" 2>/dev/null || true
ditto --norsrc --noextattr "$ROOT_DIR/HELP.en.md" "$APP/Contents/Resources/HELP.en.md" 2>/dev/null || true
ditto --norsrc --noextattr "$ROOT_DIR/README.en.md" "$APP/Contents/Resources/README.en.md" 2>/dev/null || true
ditto --norsrc --noextattr "$ROOT_DIR/capture-rules.json" "$APP/Contents/Resources/capture-rules.json" 2>/dev/null || true
ditto --norsrc --noextattr "$ROOT_DIR/docs/capture-rules.md" "$APP/Contents/Resources/capture-rules.md" 2>/dev/null || true
ditto --norsrc --noextattr "$ROOT_DIR/prompts.json" "$APP/Contents/Resources/prompts.json" 2>/dev/null || true
ditto --norsrc --noextattr "$ROOT_DIR/docs/prompts.md" "$APP/Contents/Resources/prompts.md" 2>/dev/null || true

xattr -cr "$APP" 2>/dev/null || true
codesign --force --deep --options runtime -s "$SIGN_IDENTITY" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

echo "Built: $APP"
