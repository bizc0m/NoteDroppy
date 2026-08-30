#!/bin/zsh
# Installe NoteDroppy V4 dans /Applications.
# Ne touche jamais NoteDroppy V3, NoteDroppy.app ou Note Droopy.app.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT_DIR/outputs/NoteDroppy V4.app"
TARGET="/Applications/NoteDroppy V4.app"

if [ ! -d "$APP" ]; then
  echo "Erreur : $APP absent. Lance d'abord ./scripts/build-notedroppy-v4.sh" >&2
  exit 1
fi

codesign --verify --deep --strict "$APP" || { echo "Erreur : signature invalide, installation refusee." >&2; exit 1; }

if [ -d "$TARGET" ]; then
  echo "$TARGET existe deja."
  printf "Remplacer ? [o/N] "
  read -r answer
  case "$answer" in
    o|O|oui|y|Y) ;;
    *) echo "Installation annulee." ; exit 0 ;;
  esac
  rm -rf "$TARGET"
fi

ditto --norsrc --noextattr "$APP" "$TARGET"
xattr -cr "$TARGET" 2>/dev/null || true
echo "Installe : $TARGET"
echo "V3 et les anciens bundles n'ont pas ete modifies."
