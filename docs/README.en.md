# NoteDroppy

NoteDroppy adds a task to today's NotePlan note from the Dock, a macOS Service, or a global shortcut.

## Usage

- Drop a URL onto the Dock icon.
- Drop a `.webloc`, `.url`, `.txt`, `.md`, `.rtf`, or `.textclipping` file.
- Use the macOS Service for selected text.
- Use the global shortcut when the Service is not available.

Sent format:

```text
- [ ] <content> #capture
```

## Install

```zsh
scripts/install-notedroppy.sh
```

Installable package:

```text
releases/NoteDroppy-v1.22.zip
```

## macOS Limit

The Dock does not reliably pass selected raw text to apps.

For selected text, use the macOS Service or the global shortcut.
