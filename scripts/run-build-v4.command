#!/bin/zsh
# Lance le build V4 et ecrit toute la sortie dans outputs/build-v4.log
# Usage : double-clic depuis le Finder.
cd "$(dirname "$0")/.."
LOG="outputs/build-v4.log"
mkdir -p outputs
{
  echo "=== BUILD NoteDroppy V4 — $(date) ==="
  echo "--- swiftc ---"
  ./scripts/build-notedroppy-v4.sh 2>&1
  echo "--- codesign --verify ---"
  codesign --verify --deep --strict --verbose=2 "outputs/NoteDroppy V4.app" 2>&1
  echo "--- Info.plist ---"
  /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "outputs/NoteDroppy V4.app/Contents/Info.plist" 2>&1
  /usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "outputs/NoteDroppy V4.app/Contents/Info.plist" 2>&1
  /usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "outputs/NoteDroppy V4.app/Contents/Info.plist" 2>&1
  echo "=== FIN ($(date)) ==="
} > "$LOG" 2>&1
echo "Termine. Sortie : $LOG"
cat "$LOG"
