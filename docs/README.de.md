# NoteDroppy

NoteDroppy erstellt eine Aufgabe in der heutigen NotePlan-Notiz über das Dock, einen macOS-Dienst oder einen globalen Kurzbefehl.

## Nutzung

- Eine URL auf das Dock-Symbol ziehen.
- Eine Datei `.webloc`, `.url`, `.txt`, `.md`, `.rtf` oder `.textclipping` ziehen.
- Den macOS-Dienst für markierten Text verwenden.
- Den globalen Kurzbefehl verwenden, wenn der Dienst nicht verfügbar ist.

Gesendetes Format:

```text
- [ ] <inhalt> #capture
```

## Installation

```zsh
scripts/install-notedroppy.sh
```

Installierbares Paket:

```text
releases/NoteDroppy-v1.22.zip
```

## macOS-Grenze

Das Dock übergibt markierten Rohtext nicht zuverlässig an Apps.

Für markierten Text den macOS-Dienst oder den globalen Kurzbefehl verwenden.
