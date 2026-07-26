# NoteDroppy

App macOS AppKit pour ajouter rapidement des tâches dans NotePlan.

## Utilisation

- URL vers l'icone Dock `NoteDroppy` : ajoute l'URL en tâche.
- Fichier `.webloc` / `.url` vers l'icone Dock : extrait l'URL et l'ajoute en tâche.
- Fichier texte / `.md` / `.rtf` / `.textclipping` vers l'icone Dock : ajoute le contenu en tâche.
- Texte sélectionné : clic droit -> Services -> `NotePlan : ajouter en tâche`.
- Clic sur l'icone Dock sans fichier : ouvre les réglages.
- Texte sélectionné dans les apps sans menu Services fiable : `Ctrl+Option+Cmd+N`, avec l'autorisation Accessibilité accordée à NoteDroppy.

Format envoyé à NotePlan :

```text
- [ ] <contenu> #capture
```

## Service macOS

Le nom du Service par défaut est :

```text
NotePlan : ajouter en tâche
```

Il peut être changé dans les réglages de l'app. NoteDroppy réécrit alors son `Info.plist`, ressigne l'app en ad-hoc et rafraîchit LaunchServices/PBS.

Si le Service n'apparait pas après installation, relancer l'app source ou exécuter le script d'installation, qui rafraichit LaunchServices et PBS.

## Réglages

Ouvrir `NoteDroppy` depuis le Dock ou Finder sans déposer de fichier.

Réglages disponibles :

- Nom du Service macOS.
- Tag ajouté à la tâche, par défaut `#capture`.
- Ouverture de NotePlan après ajout.
- Raccourci global `Ctrl+Option+Cmd+N`.
- Bouton d'ouverture du panneau Accessibilité macOS.

## Installation

```zsh
scripts/install-notedroppy.sh
```

L'app installée se trouve ensuite ici :

```text
/Applications/NoteDroppy.app
```

## Limite macOS

Le drag direct de texte sélectionné vers l'icone Dock ne marche pas : le Dock ne transmet pas ce texte brut à l'app. Utiliser le Service macOS pour le texte sélectionné.

Certaines apps n'affichent pas les Services macOS dans leurs menus. Dans ce cas, garder NoteDroppy ouvert et utiliser le raccourci global `Ctrl+Option+Cmd+N`. macOS exige l'autorisation Accessibilité pour que NoteDroppy puisse simuler `Cmd+C` et lire la sélection.
