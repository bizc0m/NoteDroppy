#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT_DIR/outputs/NoteDroppy V2.5.app"
VERSION="${1:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")}"
RELEASE_DIR="$ROOT_DIR/releases"
PACKAGE_DIR="$RELEASE_DIR/NoteDroppy-v${VERSION}"
ZIP="$RELEASE_DIR/NoteDroppy-v${VERSION}.zip"
SIGN_IDENTITY="${NOTEDROPPY_CODESIGN_IDENTITY:-NoteDroppy Local Code Signing}"

if ! security find-identity -v -p codesigning | grep -Fq "\"$SIGN_IDENTITY\""; then
  SIGN_IDENTITY="-"
fi

if [[ ! -d "$APP" ]]; then
  echo "App introuvable: $APP" >&2
  exit 1
fi

mkdir -p "$RELEASE_DIR"
rm -rf "$PACKAGE_DIR" "$ZIP" "$RELEASE_DIR/NoteDroppy-v${VERSION}.sha256"
xattr -cr "$APP" 2>/dev/null || true
codesign --force --deep --options runtime -s "$SIGN_IDENTITY" "$APP"

mkdir -p "$PACKAGE_DIR"
ditto --norsrc --noextattr "$APP" "$PACKAGE_DIR/NoteDroppy V2.5.app"
if [[ -d "$ROOT_DIR/examples" ]]; then
  ditto --norsrc --noextattr "$ROOT_DIR/examples" "$PACKAGE_DIR/examples"
fi
cat > "$PACKAGE_DIR/install-notedroppy-v25.sh" <<'EOF'
#!/bin/zsh
set -euo pipefail

PACKAGE_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_SRC="$PACKAGE_DIR/NoteDroppy V2.5.app"
APP_DST="/Applications/NoteDroppy V2.5.app"
BACKUP_DIR="$HOME/Library/Application Support/NoteDroppy V2.5/backups"
SIGN_IDENTITY="${NOTEDROPPY_CODESIGN_IDENTITY:-NoteDroppy Local Code Signing}"

if [[ ! -d "$APP_SRC" ]]; then
  echo "NoteDroppy V2.5.app introuvable dans le paquet: $APP_SRC" >&2
  exit 1
fi

if ! security find-identity -v -p codesigning | grep -Fq "\"$SIGN_IDENTITY\""; then
  SIGN_IDENTITY="-"
fi

if [[ -d "$APP_DST" ]]; then
  mkdir -p "$BACKUP_DIR"
  mv "$APP_DST" "$BACKUP_DIR/NoteDroppy V2.5.app.previous-$(date +%Y%m%d-%H%M%S).bundle-backup"
fi

ditto --norsrc --noextattr "$APP_SRC" "$APP_DST"
xattr -cr "$APP_DST" 2>/dev/null || true
codesign --force --deep --options runtime -s "$SIGN_IDENTITY" "$APP_DST"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP_DST"
/System/Library/CoreServices/pbs -flush 2>/dev/null || true
/System/Library/CoreServices/pbs -update 2>/dev/null || true

echo "Installed: $APP_DST"
EOF
chmod +x "$PACKAGE_DIR/install-notedroppy-v25.sh"

cat > "$PACKAGE_DIR/INSTALL.md" <<'EOF'
# NoteDroppy V2.5 Install

This is the V2.5 track. It installs side-by-side with the stable NoteDroppy.app
(different bundle id, different app name) and does not touch it.

## Install

Double-click `NoteDroppy V2.5.app`, or copy it to `/Applications`.

For a scripted install, run:

```zsh
./install-notedroppy-v25.sh
```

The app is installed here:

```text
/Applications/NoteDroppy V2.5.app
```

## macOS Gatekeeper

This package is signed locally or ad-hoc. It is not Apple-notarized.

If macOS blocks the first launch:

1. Open System Settings.
2. Go to Privacy & Security.
3. Approve opening NoteDroppy V2.5, or right-click `NoteDroppy V2.5.app` and choose Open.

## Accessibility

The global shortcuts need Accessibility permission:

System Settings -> Privacy & Security -> Accessibility -> enable `NoteDroppy V2.5`.
EOF

COPYFILE_DISABLE=1 ditto -c -k --norsrc --noextattr "$PACKAGE_DIR" "$ZIP"
(cd "$RELEASE_DIR" && shasum -a 256 "NoteDroppy-v${VERSION}.zip" > "NoteDroppy-v${VERSION}.sha256")

echo "$ZIP"
