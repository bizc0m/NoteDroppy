# NoteDroppy

<p align="center">
  <img src="assets/notedroppy-logo.png" alt="NoteDroppy logo" width="128">
</p>

NoteDroppy is a small native macOS AppKit app that quickly adds a task to today's NotePlan note from the Dock, a macOS Service, or a global shortcut.

French version: [README.md](README.md)

Help: [HELP.md](HELP.md) / [HELP.en.md](HELP.en.md)

Repository: [https://github.com/bizc0m/NoteDroppy](https://github.com/bizc0m/NoteDroppy)

Verified stable download:
[NoteDroppy v1.25.1 new icon](https://github.com/bizc0m/NoteDroppy-page/releases/tag/notedroppy-v1.25.1-new-icon)

GitHub download page:
[https://bizc0m.github.io/NoteDroppy-page/](https://bizc0m.github.io/NoteDroppy-page/)

Multilingual docs:
[FR](docs/README.fr.md) · [EN](docs/README.en.md) · [ES](docs/README.es.md) · [DE](docs/README.de.md) · [IT](docs/README.it.md) · [PT](docs/README.pt.md)

## Stable Blue v1.25

Use this package when you need the stable blue-icon build:

```text
NoteDroppy v1.25 build 35
```

GitHub package:

```text
releases/NoteDroppy-v1.25-blue-service.zip
```

Validated on 2026-08-03:

- historical blue `URL -> NP` icon;
- macOS Service `NotePlan : ajouter en tâche`;
- real write into today's NotePlan note through `noteDate=today`;
- validation test line removed afterwards.

Note: the package is locally/ad-hoc signed and is not Apple-notarized. macOS may require Gatekeeper approval on first launch. The `docs/index.html` page is ready in the repository, but GitHub Pages is not enabled for this repository.

## New Icon v1.25.1

The current installable variant with the provided new icon is:

```text
NoteDroppy v1.25.1 build 36
```

Public package:

```text
https://github.com/bizc0m/NoteDroppy-page/releases/tag/notedroppy-v1.25.1-new-icon
```

Verified:

- macOS icon applied to the installed bundle;
- macOS Service `NotePlan : ajouter en tâche`;
- real write into today's NotePlan note;
- validation test line removed afterwards.

## What It Does

NoteDroppy sends this task format to NotePlan:

```text
- [ ] <content> #capture
```

NotePlan URL command:

```text
noteplan://x-callback-url/addText?noteDate=today&text=<encoded_text>&mode=append&openNote=yes
```

## Usage

Drag onto the `NoteDroppy` Dock icon:

- Web URL: adds the URL as a task.
- `.webloc` or `.url` file: extracts the URL and adds it as a task.
- Text, `.md`, `.rtf`, or `.textclipping` file: adds the file content as a task.

Selected text:

- Right-click -> Services -> `NotePlan : ajouter en tâche`.
- If an app does not show the Services menu, keep NoteDroppy open and use the global shortcut.

Settings:

- Click the Dock icon without dropping a file.
- On first launch, the settings window opens automatically.
- Row 1 default is App `NotePlan` with destination `Today (NotePlan)`.
- Each shortcut can choose App `NotePlan` or `Obsidian beta`.
- Obsidian beta writes directly to a `.md` note in the configured vault/path.
- After that, normal launches stay silent so the app can remain ready in the background.

## Global Shortcut

The global shortcut is configurable in settings.

Default:

```text
Ctrl+Option+Cmd+N
```

The shortcut requires macOS Accessibility permission because NoteDroppy must read the active selection or simulate `Cmd+C` to retrieve the selected text.

If Accessibility is not granted, the app receives the shortcut but does not send any task.

## macOS Service

Default Service name:

```text
NotePlan : ajouter en tâche
```

This name can be changed in settings. NoteDroppy then updates its `Info.plist`, signs the app again, and refreshes LaunchServices/PBS.

If the Service does not appear after installation, relaunch the app or run the install script.

## Installation

From the repository:

```zsh
scripts/install-notedroppy.sh
```

Installed app:

```text
/Applications/NoteDroppy.app
```

On this machine, the script signs with the local identity `NoteDroppy Local Code Signing` when it exists. This stable signature prevents macOS from losing Accessibility permission on every rebuild. Without that identity, the script falls back to ad-hoc signing.

## Distributable Package Without Apple Developer

Create an installable ZIP:

```zsh
scripts/package-notedroppy.sh
```

The package is created in `releases/` with:

- `NoteDroppy.app`
- `install-notedroppy.sh`
- `INSTALL.md`
- `INSTALL.fr.md`
- a `.sha256` checksum

This package is not Apple-notarized. On another Mac, macOS may ask for Gatekeeper approval on first launch. The app is still cleanly installable by copying it to `/Applications` or by running the install script.

## Settings

- macOS Service name.
- Task tag, default `#capture`.
- Open NotePlan after adding.
- 10 configurable global shortcuts.
- For each shortcut: Enabled, key combo, destination, Note/Path, comma-separated tags.
- Destinations: Today (`noteDate=today`), Named note (`noteTitle=<title>`), Note path (`notePath=<path>` with NotePlan `fileName` compatibility).
- Direct NotePlan note search from each shortcut row, filtered by title, path, `#tag`, or `#context`, with validation into `Note/Path`.
- Button to open macOS Accessibility settings.
- In-app Help window with a GitHub repository link.

## macOS Limits

Dragging selected raw text directly onto the Dock icon is not reliable on macOS: the Dock does not consistently pass selected text to apps.

For selected text, use:

- the macOS Service when the source app exposes it;
- the global shortcut when the Service is not available.

The global shortcut is intentionally ignored while NoteDroppy, System Settings, or a system alert is frontmost, to avoid sending settings text instead of the intended selection.
