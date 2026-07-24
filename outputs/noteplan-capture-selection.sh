#!/usr/bin/env zsh
set -euo pipefail

# Send selected text to NotePlan.
# Best path: macOS Automator Quick Action passes the selection through stdin.
# Fallback: when run manually, the script simulates Cmd+C and reads the clipboard.

timestamp="$(date '+%Y-%m-%d %H:%M')"

selected=""
if [[ ! -t 0 ]]; then
  selected="$(cat)"
fi

if [[ -z "${selected//[[:space:]]/}" ]]; then
  old_clipboard="$(osascript -e 'try' -e 'the clipboard as text' -e 'on error' -e 'return ""' -e 'end try')"

  osascript -e 'tell application "System Events" to keystroke "c" using command down'
  sleep 0.15

  selected="$(osascript -e 'try' -e 'the clipboard as text' -e 'on error' -e 'return ""' -e 'end try')"
  printf '%s' "$old_clipboard" | pbcopy
fi

if [[ -z "${selected//[[:space:]]/}" ]]; then
  osascript -e 'display notification "Aucune selection detectee." with title "NotePlan Capture"'
  exit 1
fi

choice="$(osascript <<'APPLESCRIPT'
set options to {"Todo aujourd'hui", "Creer une note"}
set picked to choose from list options with title "NotePlan Capture" with prompt "Que faire avec la selection ?" default items {"Todo aujourd'hui"}
if picked is false then
  return "cancel"
end if
return item 1 of picked
APPLESCRIPT
)"

if [[ "$choice" == "cancel" ]]; then
  exit 0
fi

urlencode() {
  python3 - "$1" <<'PY'
import sys
from urllib.parse import quote
print(quote(sys.argv[1], safe=""))
PY
}

if [[ "$choice" == "Todo aujourd'hui" ]]; then
  task="- [ ] ${selected} #capture"
  encoded_text="$(urlencode "$task")"
  open "noteplan://x-callback-url/addText?noteDate=today&text=${encoded_text}&mode=append&openNote=no"
  osascript -e 'display notification "Todo ajoutee a aujourd hui." with title "NotePlan Capture"'
  exit 0
fi

default_title="Capture ${timestamp}"
title="$(osascript <<APPLESCRIPT
set answer to text returned of (display dialog "Titre de la note :" default answer "${default_title}" buttons {"Annuler", "Creer"} default button "Creer")
return answer
APPLESCRIPT
)"

body="## Source
Capture clavier - ${timestamp}

## Todo
- [ ] Traiter cette capture

## Contenu
${selected}
"

encoded_title="$(urlencode "$title")"
encoded_body="$(urlencode "$body")"

open "noteplan://x-callback-url/addNote?noteTitle=${encoded_title}&text=${encoded_body}&folder=Inbox&openNote=yes"
osascript -e 'display notification "Note creee dans NotePlan." with title "NotePlan Capture"'
