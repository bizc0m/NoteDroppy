# NoteDroppy Help

NoteDroppy captures text, URLs, and file paths, then adds a task to NotePlan or writes to Markdown/TXT depending on the selected shortcut.

## Capture

- Dock: drop a URL, `.webloc`, `.url`, text file, or Markdown file.
- macOS Service: send selected text from a compatible app.
- Global shortcut: capture the active selection.
- Non-text file: capture a clickable file link.

Base format:

```text
- [ ] Captured text #capture
```

## Shortcuts

Preferences show 20 configurable shortcuts.

- `Action`: capture, capture + open, open.
- `+`: advanced options for the row.
- `Output`: NotePlan Today, NotePlan Note, Markdown `.md`, Obsidian `.md`, `.txt`.
- `Target`: file name only.
- `Tag & Config`: visible tags + red config summary.

The `+` button turns red when advanced config is active.

## Advanced Options

The `+` panel shows the construction order:

```text
marker -> priority -> content -> date -> tags -> config
```

Options:

- Marker: `- [ ]`, `*`, `+`, text.
- NotePlan priority: none, `!`, `!!`, `!!!`.
- Date: none, tomorrow, weekend, next week.
- Content: expanded or folded.
- Section and insertion position.
- Routing: open after capture, web source, file source.
- Governance: secret/public, indexing, local/remote LLM.

The preview at the bottom shows the generated line before saving.

## Permissions

The global shortcut requires macOS Accessibility permission because NoteDroppy must copy the active selection.

If selection capture does not work:

1. Open NoteDroppy.
2. Click `Autoriser Accessibilité`.
3. Enable NoteDroppy in macOS.
4. Quit and relaunch the app.

GitHub: https://github.com/bizc0m/NoteDroppy
