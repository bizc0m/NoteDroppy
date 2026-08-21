#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT_DIR/outputs/Note Commander.app"
VERSION="${1:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")}"
RELEASE_DIR="$ROOT_DIR/releases"
STAGE="$RELEASE_DIR/NoteCommander-v${VERSION}"
DMG="$RELEASE_DIR/NoteCommander-v${VERSION}.dmg"
SHA="$RELEASE_DIR/NoteCommander-v${VERSION}.sha256"

if [[ ! -d "$APP" ]]; then
  echo "App introuvable: $APP" >&2
  exit 1
fi

if [[ -d "$STAGE" ]]; then mv "$STAGE" "/tmp/NoteCommander-stage-old-$(date +%s)"; fi
if [[ -f "$DMG" ]]; then mv "$DMG" "$DMG.old-$(date +%s)"; fi
if [[ -f "$SHA" ]]; then mv "$SHA" "$SHA.old-$(date +%s)"; fi

mkdir -p "$STAGE"
ditto --norsrc --noextattr "$APP" "$STAGE/Note Commander.app"
ln -s /Applications "$STAGE/Applications"
cat > "$STAGE/INSTALL.md" <<'EOF'
# Note Commander

Drag `Note Commander.app` to Applications.

Scope: local NotePlan Markdown editor, search, sorting, and note operations.
This app is separate from Note Droopy.
EOF

xattr -cr "$STAGE" 2>/dev/null || true
hdiutil create -volname "Note Commander" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
shasum -a 256 "$DMG" > "$SHA"
hdiutil verify "$DMG"

echo "$DMG"
