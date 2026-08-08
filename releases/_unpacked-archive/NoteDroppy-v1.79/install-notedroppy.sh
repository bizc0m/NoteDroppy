#!/bin/zsh
set -euo pipefail

PACKAGE_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_SRC="$PACKAGE_DIR/NoteDroppy.app"
APP_DST="/Applications/NoteDroppy.app"
BACKUP_DIR="$HOME/Library/Application Support/NoteDroppy/backups"
SIGN_IDENTITY="${NOTEDROPPY_CODESIGN_IDENTITY:-NoteDroppy Local Code Signing}"

if [[ ! -d "$APP_SRC" ]]; then
  echo "NoteDroppy.app introuvable dans le paquet: $APP_SRC" >&2
  exit 1
fi

if ! security find-identity -v -p codesigning | grep -Fq "\"$SIGN_IDENTITY\""; then
  SIGN_IDENTITY="-"
fi

if [[ -d "$APP_DST" ]]; then
  mkdir -p "$BACKUP_DIR"
  mv "$APP_DST" "$BACKUP_DIR/NoteDroppy.app.previous-$(date +%Y%m%d-%H%M%S).bundle-backup"
fi

cp -R "$APP_SRC" "$APP_DST"
xattr -cr "$APP_DST" 2>/dev/null || true
codesign --force --deep -s "$SIGN_IDENTITY" "$APP_DST"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP_DST"
/System/Library/CoreServices/pbs -flush 2>/dev/null || true
/System/Library/CoreServices/pbs -update 2>/dev/null || true

echo "Installed: $APP_DST"
