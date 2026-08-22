#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT_DIR/outputs/Note Droopy.app"
VERSION="${1:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")}"
RELEASE_DIR="$ROOT_DIR/releases"
STAGE="$RELEASE_DIR/NoteDroopy-v${VERSION}"
DMG="$RELEASE_DIR/NoteDroopy-v${VERSION}.dmg"
SHA="$RELEASE_DIR/NoteDroopy-v${VERSION}.sha256"

if [[ ! -d "$APP" ]]; then
  echo "App introuvable: $APP" >&2
  exit 1
fi

if [[ -d "$STAGE" ]]; then mv "$STAGE" "/tmp/NoteDroopy-stage-old-$(date +%s)"; fi
if [[ -f "$DMG" ]]; then mv "$DMG" "$DMG.old-$(date +%s)"; fi
if [[ -f "$SHA" ]]; then mv "$SHA" "$SHA.old-$(date +%s)"; fi

mkdir -p "$STAGE"
ditto --norsrc --noextattr "$APP" "$STAGE/Note Droopy.app"
ln -s /Applications "$STAGE/Applications"
cat > "$STAGE/INSTALL.md" <<'EOF'
# Note Droopy

Drag `Note Droopy.app` to Applications.

Scope: fast capture to NotePlan through Dock drops, URL files, macOS Service,
and global shortcuts. The Commander tab integrates local NotePlan editing,
search and sorting tools directly inside Note Droopy.
EOF

xattr -cr "$STAGE" 2>/dev/null || true
hdiutil create -volname "Note Droopy" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
shasum -a 256 "$DMG" > "$SHA"
hdiutil verify "$DMG"

echo "$DMG"
