# NoteDroppy V2.5 Install

This is the V2.5 track. It installs side-by-side with the stable NoteDroppy.app
(different bundle id, different app name) and does not touch it.

## Install

Double-click `NoteDroppy V2.5.app`, or copy it to `/Applications`.

For a scripted install, run:

```zsh
./install-notedroppy-v25.sh
```

The app is installed here:

```text
/Applications/NoteDroppy V2.5.app
```

## macOS Gatekeeper

This package is signed locally or ad-hoc. It is not Apple-notarized.

If macOS blocks the first launch:

1. Open System Settings.
2. Go to Privacy & Security.
3. Approve opening NoteDroppy V2.5, or right-click `NoteDroppy V2.5.app` and choose Open.

## Accessibility

The global shortcuts need Accessibility permission:

System Settings -> Privacy & Security -> Accessibility -> enable `NoteDroppy V2.5`.
