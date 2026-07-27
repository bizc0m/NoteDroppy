# NoteDroppy

Native macOS AppKit app for quickly adding tasks to NotePlan.

## Usage

- Drop a URL onto the `NoteDroppy` Dock icon: adds the URL as a task.
- Drop a `.webloc` / `.url` file onto the Dock icon: extracts the URL and adds it as a task.
- Drop a text / `.md` / `.rtf` / `.textclipping` file onto the Dock icon: adds its content as a task.
- Selected text: right-click -> Services -> `NotePlan : ajouter en tâche`.
- Click the Dock icon without dropping a file: opens settings.
- Selected text in apps where Services are unreliable: use the configurable global shortcut, default `Ctrl+Option+Cmd+N`, after granting Accessibility permission to NoteDroppy.

Sent format:

```text
- [ ] <content> #capture
```

## macOS Service

Default Service name:

```text
NotePlan : ajouter en tâche
```

It can be changed in the app settings. NoteDroppy updates its `Info.plist`, signs the app again, and refreshes LaunchServices/PBS.

If the Service does not appear after installation, relaunch the source app or run the install script, which refreshes LaunchServices and PBS.

## Settings

Open `NoteDroppy` from the Dock or Finder without dropping a file.

Available settings:

- macOS Service name.
- Task tag, default `#capture`.
- Open NotePlan after adding.
- Configurable global shortcut.
- Button to open macOS Accessibility settings.

## Installation

```zsh
scripts/install-notedroppy.sh
```

Installed app path:

```text
/Applications/NoteDroppy.app
```

On this machine, the scripts sign with the local identity `NoteDroppy Local Code Signing` when it exists. This stable signature prevents macOS from invalidating Accessibility permission on every rebuild. Without that identity, scripts fall back to ad-hoc signing.

## macOS Limit

Dragging selected raw text directly onto the Dock icon does not work reliably: the Dock does not pass that raw selected text to apps. Use the macOS Service or the global shortcut for selected text.

Some apps do not show macOS Services in their menus. In that case, keep NoteDroppy open and use the global shortcut. macOS requires Accessibility permission so NoteDroppy can simulate `Cmd+C` and read the selection.

The global shortcut is intentionally ignored while NoteDroppy, System Settings, or a system alert is frontmost, to avoid sending settings text instead of the intended selection.
