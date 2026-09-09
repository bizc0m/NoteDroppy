#!/bin/zsh
# Un seul script : pull + build NoteDroppy V4/V5 + rapport clair.
# Usage : ./scripts/verify-v5.sh
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR" || { echo "FAIL: dossier repo introuvable"; exit 1; }

echo "=== 1/3 git pull ==="
if ! git pull origin claude/notedroppy-swift-audit-l173vl; then
  echo "FAIL: git pull a échoué (voir ci-dessus)"
  exit 1
fi

echo ""
echo "=== 2/3 build NoteDroppy V4 ==="
if ./scripts/build-notedroppy-v4.sh; then
  BUILD_OK=1
else
  BUILD_OK=0
fi

echo ""
echo "=== 3/3 résultat ==="
if [ "$BUILD_OK" = "1" ]; then
  echo "OK — ça compile. Colle-moi juste 'OK' et je passe à la suite."
  echo "(Optionnel si tu veux tester en vrai : killall NoteDroppyV4 2>/dev/null; open \"$ROOT_DIR/outputs/NoteDroppy V4.app\")"
else
  echo "ECHEC — colle-moi tout ce qui s'est affiché au-dessus (l'erreur swiftc), rien d'autre à faire de ton côté."
fi
