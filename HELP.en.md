# NoteDroppy Help

NoteDroppy quickly adds a task to today's NotePlan note.

GitHub repository:

```text
https://github.com/bizc0m/NoteDroppy
```

## Sent Format

```text
- [ ] <content> #capture
```

The tag can be changed in settings.

## Send A URL Or File

Drag onto the `NoteDroppy` Dock icon:

- URL from a browser.
- `.webloc` or `.url` file.
- Text file: `.txt`, `.md`, `.rtf`, or `.textclipping`.

The item is sent directly to NotePlan.

## Send Selected Text

There are two methods.

### macOS Service

In compatible apps:

```text
Active app > Services > NotePlan : ajouter en tâche
```

Depending on the app, the Service may also appear in the right-click menu.

### Global Shortcut

For apps that do not expose macOS Services:

1. Keep NoteDroppy open.
2. Select text.
3. Press the global shortcut, default `Ctrl+Option+Cmd+N`.

The shortcut is configurable in settings.

macOS requires Accessibility permission for this method because NoteDroppy must simulate `Cmd+C` to read the selection.

## Settings

Click the `NoteDroppy` Dock icon without dropping a file.

Available settings:

- macOS Service name.
- Task tag.
- Open NotePlan after adding.
- Global shortcut.
- Direct button to macOS Accessibility settings.
- In-app Help window with `GitHub Repository` button.

## Accessibility Permission

If the global shortcut does not work:

1. Open NoteDroppy.
2. Click `Autoriser Accessibilité`.
3. In macOS, enable `NoteDroppy`.
4. Quit and relaunch NoteDroppy.

On this machine, NoteDroppy is signed with the local identity `NoteDroppy Local Code Signing` so macOS does not lose Accessibility permission on every rebuild.

## macOS Limits

Dragging selected raw text directly onto the Dock icon is not reliable on macOS. The Dock does not consistently pass selected text to apps.

The global shortcut is ignored while NoteDroppy, System Settings, or a system alert is frontmost, to avoid sending settings text instead of the intended selection.
