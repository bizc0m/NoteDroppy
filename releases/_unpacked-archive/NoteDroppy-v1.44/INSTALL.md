# NoteDroppy Install

## Install

Double-click `NoteDroppy.app`, or copy it to `/Applications`.

For a scripted install, run:

```zsh
./install-notedroppy.sh
```

The app is installed here:

```text
/Applications/NoteDroppy.app
```

## macOS Gatekeeper

This package is signed locally or ad-hoc. It is not Apple-notarized.

If macOS blocks the first launch:

1. Open System Settings.
2. Go to Privacy & Security.
3. Approve opening NoteDroppy, or right-click `NoteDroppy.app` and choose Open.

## Accessibility

The global shortcut needs Accessibility permission:

System Settings -> Privacy & Security -> Accessibility -> enable `NoteDroppy`.

Dock URL/file drops and NotePlan URL sending do not need Accessibility. Selected-text capture with the global shortcut does.
