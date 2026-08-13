#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="NoteDroppy Integrated"
APP_SRC="$ROOT_DIR/outputs/${APP_NAME}.app"
APP_DST="/Applications/${APP_NAME}.app"
BACKUP_DIR="$HOME/Library/Application Support/${APP_NAME}/backups"
SIGN_IDENTITY="${NOTEDROPPY_CODESIGN_IDENTITY:-NoteDroppy Local Code Signing}"

if ! security find-identity -v -p codesigning | grep -Fq "\"$SIGN_IDENTITY\""; then
  SIGN_IDENTITY="-"
fi

if [[ ! -d "$APP_SRC" ]]; then
  echo "App source introuvable: $APP_SRC" >&2
  exit 1
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
