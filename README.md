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

## Reglage du nom du Service

Lancer l'app normalement depuis Finder, Dock ou Spotlight ouvre une fenêtre de réglage.

Le champ permet de changer le nom affiché dans :

```text
clic droit -> Services
```

Après enregistrement, l'app modifie son `Info.plist`, se re-signe en adhoc, rafraîchit LaunchServices/PBS, et active le Service sous le nouveau nom. Si une app source garde l'ancien menu en cache, la relancer.

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
