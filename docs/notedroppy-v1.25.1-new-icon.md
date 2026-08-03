# NoteDroppy v1.25.1 new icon

Installable NoteDroppy package based on the stable v1.25 app, with the provided new app icon.

## Build

```text
Version: 1.25.1
Build: 36
App: /Applications/NoteDroppy.app
Package: releases/NoteDroppy-v1.25.1-new-icon.zip
SHA-256: c9d42f56f849feb80add4299285189cb8572f192eed481d890e9574693643e59
```

## Verified Behavior

- New icon applied to `NotePlanURLDrop.icns` in the app bundle.
- Bundle logo updated from the provided PNG.
- macOS Service menu item: `NotePlan : ajouter en tâche`.
- Service handler invoked through `NSPerformService`.
- Task written into today's NotePlan calendar note.
- Test task removed after verification.
- Extracted zip validates as version `1.25.1`, build `36`, with a valid ad-hoc signature.

## About

NoteDroppy is a small macOS helper that sends selected text, URLs, and text files to NotePlan as tasks. This build keeps the stable v1.25 behavior and updates only the distributable identity: app icon, bundle version, package, and public download page.

