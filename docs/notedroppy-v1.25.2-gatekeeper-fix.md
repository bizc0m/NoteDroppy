# NoteDroppy v1.25.2 gatekeeper fix

Installable NoteDroppy package based on the stable v1.25 app, with the provided new app icon and local code signing.

## Build

```text
Version: 1.25.2
Build: 37
App: /Applications/NoteDroppy.app
Package: releases/NoteDroppy-v1.25.2-gatekeeper-fix.zip
SHA-256: 9717c521a9373d161655744488e86535555123a7f5d176ebc3e1d69de3a89467
Signature authority: NoteDroppy Local Code Signing
```

## Verified Behavior

- New icon kept in the macOS bundle.
- Bundle signed with `NoteDroppy Local Code Signing`.
- macOS Service menu item: `NotePlan : ajouter en tâche`.
- Service handler invoked through `NSPerformService`.
- Task written into today's NotePlan calendar note.
- Test task removed after verification.
- Extracted zip validates as version `1.25.2`, build `37`, with a valid local signature.

## Gatekeeper Note

This build removes the ad-hoc signature problem for the local package. It is not Apple Developer ID notarized. If downloaded in a browser on another Mac, macOS can still require manual approval in Privacy & Security.

