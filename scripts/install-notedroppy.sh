#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_SRC="$ROOT_DIR/outputs/NoteDroppy.app"
APP_DST="/Applications/NoteDroppy.app"
SIGN_IDENTITY="${NOTEDROPPY_CODESIGN_IDENTITY:-NoteDroppy Local Code Signing}"

if ! security find-identity -v -p codesigning | grep -Fq "\"$SIGN_IDENTITY\""; then
  SIGN_IDENTITY="-"
fi

if [[ ! -d "$APP_SRC" ]]; then
  echo "App source introuvable: $APP_SRC" >&2
  exit 1
fi

if [[ -d "$APP_DST" ]]; then
  mv "$APP_DST" "/Applications/NoteDroppy.app.previous-$(date +%Y%m%d-%H%M%S)"
fi

cp -R "$APP_SRC" "$APP_DST"
codesign --force --deep -s "$SIGN_IDENTITY" "$APP_DST"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP_DST"
/System/Library/CoreServices/pbs -flush 2>/dev/null || true
/System/Library/CoreServices/pbs -update 2>/dev/null || true

echo "Installe: $APP_DST"
