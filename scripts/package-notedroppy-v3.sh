#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT_DIR/outputs/NoteDroppy V3.app"
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
ditto --norsrc --noextattr "$APP" "$PACKAGE_DIR/NoteDroppy V3.app"
cat > "$PACKAGE_DIR/install-notedroppy-v3.sh" <<'EOF'
#!/bin/zsh
set -euo pipefail

PACKAGE_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_SRC="$PACKAGE_DIR/NoteDroppy V3.app"
APP_DST="/Applications/NoteDroppy V3.app"
BACKUP_DIR="$HOME/Library/Application Support/NoteDroppy V3/backups"
SIGN_IDENTITY="${NOTEDROPPY_CODESIGN_IDENTITY:-NoteDroppy Local Code Signing}"

if [[ ! -d "$APP_SRC" ]]; then
  echo "NoteDroppy V3.app introuvable dans le paquet: $APP_SRC" >&2
  exit 1
fi

if ! security find-identity -v -p codesigning | grep -Fq "\"$SIGN_IDENTITY\""; then
  SIGN_IDENTITY="-"
fi

if [[ -d "$APP_DST" ]]; then
  mkdir -p "$BACKUP_DIR"
  mv "$APP_DST" "$BACKUP_DIR/NoteDroppy V3.app.previous-$(date +%Y%m%d-%H%M%S).bundle-backup"
fi

ditto --norsrc --noextattr "$APP_SRC" "$APP_DST"
xattr -cr "$APP_DST" 2>/dev/null || true
codesign --force --deep --options runtime -s "$SIGN_IDENTITY" "$APP_DST"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP_DST"
/System/Library/CoreServices/pbs -flush 2>/dev/null || true
/System/Library/CoreServices/pbs -update 2>/dev/null || true

echo "Installed: $APP_DST"
EOF
chmod +x "$PACKAGE_DIR/install-notedroppy-v3.sh"

cat > "$PACKAGE_DIR/INSTALL.md" <<'EOF'
# NoteDroppy V3 Install

NoteDroppy V3 is a separate local macOS app for direct NotePlan Markdown editing
and task sorting. It installs side-by-side with existing NoteDroppy builds.

## Install

Double-click `NoteDroppy V3.app`, copy it to `/Applications`, or run:

```zsh
./install-notedroppy-v3.sh
```

Installed app:

```text
/Applications/NoteDroppy V3.app
```

## Scope

- Opens today's NotePlan calendar file automatically.
- Edits plain Markdown directly.
- Sorts by `!!!`, `@`, `#`, `^^`, and `--`.
- Searches agenda by default.
- Searches tasks across `Calendar` and `Notes` for time buckets.
- Creates backups before writes.

The app is locally signed or ad-hoc signed. It is not Apple-notarized.
EOF

COPYFILE_DISABLE=1 ditto -c -k --norsrc --noextattr "$PACKAGE_DIR" "$ZIP"
(cd "$RELEASE_DIR" && shasum -a 256 "NoteDroppy-v${VERSION}.zip" > "NoteDroppy-v${VERSION}.sha256")

echo "$ZIP"
