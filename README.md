# NotePlanURLDrop

App macOS AppKit pour ajouter rapidement des tâches dans NotePlan.

## Utilisation

- URL vers l'icone Dock `NotePlanURLDrop` : ajoute l'URL en tâche.
- Fichier `.webloc` / `.url` vers l'icone Dock : extrait l'URL et l'ajoute en tâche.
- Fichier texte / `.md` / `.rtf` / `.textclipping` vers l'icone Dock : ajoute le contenu en tâche.
- Texte sélectionné : clic droit -> Services -> `NotePlan : ajouter en tâche`.

Format envoyé à NotePlan :

```text
- [ ] <contenu> #capture
```

## Service macOS

Le nom du Service est fixe :

```text
NotePlan : ajouter en tâche
```

Si le Service n'apparait pas après installation, relancer l'app source ou exécuter le script d'installation, qui rafraichit LaunchServices et PBS.

## Installation

```zsh
scripts/install-noteplan-url-drop.sh
```

L'app installée se trouve ensuite ici :

```text
/Applications/NotePlanURLDrop.app
```

## Limite macOS

Le drag direct de texte sélectionné vers l'icone Dock ne marche pas : le Dock ne transmet pas ce texte brut à l'app. Utiliser le Service macOS pour le texte sélectionné.
