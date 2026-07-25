#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-1.7}"
APP="$ROOT_DIR/outputs/NotePlanURLDrop.app"
RELEASE_DIR="$ROOT_DIR/releases"
ZIP="$RELEASE_DIR/NotePlanURLDrop-v${VERSION}.zip"

if [[ ! -d "$APP" ]]; then
  echo "App introuvable: $APP" >&2
  exit 1
fi

mkdir -p "$RELEASE_DIR"
codesign --force --deep -s - "$APP"
COPYFILE_DISABLE=1 ditto -c -k --norsrc --noextattr --keepParent "$APP" "$ZIP"
(cd "$RELEASE_DIR" && shasum -a 256 "NotePlanURLDrop-v${VERSION}.zip" > "NotePlanURLDrop-v${VERSION}.sha256")

echo "$ZIP"
