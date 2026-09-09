#!/bin/zsh
# Bootstrap complet : clone (ou met a jour) le repo, build les deux apps,
# les ouvre. A executer directement sur un Mac.
#
# Usage en une commande (depuis n'importe quel dossier) :
#   curl -fsSL https://raw.githubusercontent.com/bizc0m/NoteDroppy/claude/notedroppy-swift-audit-l173vl/scripts/bootstrap-mac.sh | bash
set -uo pipefail

BRANCH="claude/notedroppy-swift-audit-l173vl"
REPO_URL="https://github.com/bizc0m/NoteDroppy.git"
TARGET_DIR="$HOME/NoteDroppy"

echo "=== 1/4 : localisation du repo ==="
if [ -d "$TARGET_DIR/.git" ]; then
  echo "Repo deja present : $TARGET_DIR"
  cd "$TARGET_DIR" || exit 1
  git fetch origin "$BRANCH" || { echo "ECHEC : git fetch"; exit 1; }
  git checkout "$BRANCH" || { echo "ECHEC : git checkout"; exit 1; }
  git pull origin "$BRANCH" || { echo "ECHEC : git pull"; exit 1; }
else
  echo "Clonage dans $TARGET_DIR"
  git clone "$REPO_URL" "$TARGET_DIR" || { echo "ECHEC : git clone"; exit 1; }
  cd "$TARGET_DIR" || exit 1
  git checkout "$BRANCH" || { echo "ECHEC : git checkout"; exit 1; }
fi
echo "OK : $(pwd) sur la branche $(git branch --show-current)"

echo ""
echo "=== 2/4 : build Note Droopy (original) ==="
chmod +x scripts/*.sh
if ./scripts/build-note-droopy.sh; then
  echo "OK : Note Droopy compile"
  NOTEDROOPY_OK=1
else
  echo "ECHEC : build-note-droopy.sh (voir erreurs swiftc ci-dessus)"
  NOTEDROOPY_OK=0
fi

echo ""
echo "=== 3/4 : build NoteDroppy V4 ==="
if ./scripts/build-notedroppy-v4.sh; then
  echo "OK : NoteDroppy V4 compile"
  V4_OK=1
else
  echo "ECHEC : build-notedroppy-v4.sh (voir erreurs swiftc ci-dessus)"
  V4_OK=0
fi

echo ""
echo "=== 4/4 : ouverture des apps ==="
[ "$NOTEDROOPY_OK" = "1" ] && open "outputs/Note Droopy.app" && echo "Ouvert : Note Droopy.app"
[ "$V4_OK" = "1" ] && open "outputs/NoteDroppy V4.app" && echo "Ouvert : NoteDroppy V4.app"

echo ""
echo "=== Resume ==="
echo "Dossier   : $(pwd)"
echo "Note Droopy : $([ "$NOTEDROOPY_OK" = "1" ] && echo OK || echo ECHEC)"
echo "NoteDroppy V4 : $([ "$V4_OK" = "1" ] && echo OK || echo ECHEC)"
