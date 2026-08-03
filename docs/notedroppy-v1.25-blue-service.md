# NoteDroppy v1.25 blue service

Stable package for the blue-icon NoteDroppy build.

## Build

```text
Version: 1.25
Build: 35
App: /Applications/NoteDroppy.app
Package: releases/NoteDroppy-v1.25-blue-service.zip
SHA-256: 6bf4fd13b9266d7c217c0f8137f51b1163f7021b72f03eb55344cc2f08a9d138
```

## Verified Behavior

- Blue historical `URL -> NP` icon restored from `noteplan-url-drop-v1.7`.
- macOS Service menu item: `NotePlan : ajouter en tâche`.
- Service handler invoked through `NSPerformService`.
- Task written into today's NotePlan calendar note.
- Test task removed after verification.

## Install

Download the zip from GitHub Releases, unzip it, then copy `NoteDroppy.app` to:

```text
/Applications/NoteDroppy.app
```

The app is locally/ad-hoc signed and not Apple-notarized. On first launch, macOS may require manual approval in Privacy & Security.

