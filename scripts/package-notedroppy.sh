#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-1.7}"
APP="$ROOT_DIR/outputs/NoteDroppy.app"
RELEASE_DIR="$ROOT_DIR/releases"
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
codesign --force --deep -s "$SIGN_IDENTITY" "$APP"
COPYFILE_DISABLE=1 ditto -c -k --norsrc --noextattr --keepParent "$APP" "$ZIP"
(cd "$RELEASE_DIR" && shasum -a 256 "NoteDroppy-v${VERSION}.zip" > "NoteDroppy-v${VERSION}.sha256")

echo "$ZIP"
