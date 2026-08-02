# Installation NoteDroppy

## Installer

Double-cliquer `NoteDroppy.app`, ou copier l'app dans `/Applications`.

Pour installer par script:

```zsh
./install-notedroppy.sh
```

L'app est installee ici:

```text
/Applications/NoteDroppy.app
```

## Gatekeeper macOS

Ce paquet est signe localement ou en ad-hoc. Il n'est pas notarise par Apple.

Si macOS bloque le premier lancement:

1. Ouvrir Reglages Systeme.
2. Aller dans Confidentialite et securite.
3. Autoriser l'ouverture de NoteDroppy, ou clic droit sur `NoteDroppy.app` puis Ouvrir.

## Accessibilite

Le raccourci global a besoin de l'autorisation Accessibilite:

Reglages Systeme -> Confidentialite et securite -> Accessibilite -> activer `NoteDroppy`.

Les drops URL/fichiers vers le Dock et l'envoi NotePlan n'ont pas besoin d'Accessibilite. La capture du texte selectionne par raccourci global en a besoin.
