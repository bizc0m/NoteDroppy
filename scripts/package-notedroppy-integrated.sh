#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="NoteDroppy Integrated"
APP="$ROOT_DIR/outputs/${APP_NAME}.app"
VERSION="${1:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")}"
RELEASE_DIR="$ROOT_DIR/releases"
STAGING="$RELEASE_DIR/NoteDroppyIntegrated-v${VERSION}"
DMG="$RELEASE_DIR/NoteDroppyIntegrated-v${VERSION}.dmg"
SHA="$RELEASE_DIR/NoteDroppyIntegrated-v${VERSION}.sha256"
SIGN_IDENTITY="${NOTEDROPPY_CODESIGN_IDENTITY:-NoteDroppy Local Code Signing}"

if ! security find-identity -v -p codesigning | grep -Fq "\"$SIGN_IDENTITY\""; then
  SIGN_IDENTITY="-"
fi

if [[ ! -d "$APP" ]]; then
  echo "App introuvable: $APP" >&2
  exit 1
fi

mkdir -p "$RELEASE_DIR"
rm -rf "$STAGING" "$DMG" "$SHA"
xattr -cr "$APP" 2>/dev/null || true
codesign --force --deep --options runtime -s "$SIGN_IDENTITY" "$APP"

mkdir -p "$STAGING"
ditto --norsrc --noextattr "$APP" "$STAGING/${APP_NAME}.app"
if [[ -d "$ROOT_DIR/examples" ]]; then
  ditto --norsrc --noextattr "$ROOT_DIR/examples" "$STAGING/examples"
fi
cat > "$STAGING/install-notedroppy-integrated.sh" <<'EOF'
#!/bin/zsh
set -euo pipefail

PACKAGE_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="NoteDroppy Integrated"
APP_SRC="$PACKAGE_DIR/${APP_NAME}.app"
APP_DST="/Applications/${APP_NAME}.app"
BACKUP_DIR="$HOME/Library/Application Support/${APP_NAME}/backups"
SIGN_IDENTITY="${NOTEDROPPY_CODESIGN_IDENTITY:-NoteDroppy Local Code Signing}"

if [[ ! -d "$APP_SRC" ]]; then
  echo "${APP_NAME}.app introuvable dans le paquet: $APP_SRC" >&2
  exit 1
fi

if ! security find-identity -v -p codesigning | grep -Fq "\"$SIGN_IDENTITY\""; then
  SIGN_IDENTITY="-"
fi

if [[ -d "$APP_DST" ]]; then
  mkdir -p "$BACKUP_DIR"
  mv "$APP_DST" "$BACKUP_DIR/${APP_NAME}.app.previous-$(date +%Y%m%d-%H%M%S).bundle-backup"
fi

ditto --norsrc --noextattr "$APP_SRC" "$APP_DST"
xattr -cr "$APP_DST" 2>/dev/null || true
codesign --force --deep --options runtime -s "$SIGN_IDENTITY" "$APP_DST"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP_DST"
/System/Library/CoreServices/pbs -flush 2>/dev/null || true
/System/Library/CoreServices/pbs -update 2>/dev/null || true

echo "Installed: $APP_DST"
EOF
chmod +x "$STAGING/install-notedroppy-integrated.sh"

cat > "$STAGING/INSTALL.md" <<'EOF'
# NoteDroppy Integrated Install

This build installs side-by-side with the public stable `NoteDroppy.app`.
It does not touch `/Users/JOB/Desktop/NoteDroppy.app`.

Install target:

```text
/Applications/NoteDroppy Integrated.app
```

For scripted install:

```zsh
./install-notedroppy-integrated.sh
```

Global shortcuts require Accessibility permission for `NoteDroppy Integrated`.
EOF

hdiutil create -volname "NoteDroppy Integrated ${VERSION}" -srcfolder "$STAGING" -ov -format UDZO "$DMG"
xattr -cr "$DMG" 2>/dev/null || true
(cd "$RELEASE_DIR" && shasum -a 256 "NoteDroppyIntegrated-v${VERSION}.dmg" > "NoteDroppyIntegrated-v${VERSION}.sha256")

echo "$DMG"
