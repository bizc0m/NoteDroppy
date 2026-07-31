# NoteDroppy

NoteDroppy aggiunge un'attività alla nota giornaliera di NotePlan dal Dock, da un Servizio macOS o da una scorciatoia globale.

## Uso

- Trascina un URL sull'icona del Dock.
- Trascina un file `.webloc`, `.url`, `.txt`, `.md`, `.rtf` o `.textclipping`.
- Usa il Servizio macOS per il testo selezionato.
- Usa la scorciatoia globale quando il Servizio non è disponibile.

Formato inviato:

```text
- [ ] <contenuto> #capture
```

## Installazione

```zsh
scripts/install-notedroppy.sh
```

Pacchetto installabile:

```text
releases/NoteDroppy-v1.22.zip
```

## Limite macOS

Il Dock non passa in modo affidabile il testo selezionato alle app.

Per il testo selezionato, usa il Servizio macOS o la scorciatoia globale.
