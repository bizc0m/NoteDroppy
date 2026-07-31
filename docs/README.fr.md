# NoteDroppy

NoteDroppy ajoute une tâche dans la note du jour NotePlan depuis le Dock, un Service macOS ou un raccourci global.

## Utilisation

- Glisser une URL sur l'icône Dock.
- Glisser un fichier `.webloc`, `.url`, `.txt`, `.md`, `.rtf` ou `.textclipping`.
- Utiliser le Service macOS pour le texte sélectionné.
- Utiliser le raccourci global si le Service n'est pas disponible.

Format envoyé:

```text
- [ ] <contenu> #capture
```

## Installation

```zsh
scripts/install-notedroppy.sh
```

Paquet installable:

```text
releases/NoteDroppy-v1.22.zip
```

## Limite macOS

Le Dock ne transmet pas toujours le texte brut sélectionné aux apps.

Pour le texte sélectionné, utiliser le Service macOS ou le raccourci global.
