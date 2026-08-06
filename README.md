# NoteDroppy

<p align="center">
  <img src="assets/notedroppy-logo.png" alt="Logo NoteDroppy" width="128">
</p>

NoteDroppy est une petite app macOS AppKit qui ajoute rapidement une tâche dans la note du jour NotePlan depuis le Dock, un Service macOS ou un raccourci global.

English version: [README.en.md](README.en.md)

Aide: [HELP.md](HELP.md) / [HELP.en.md](HELP.en.md)

Repo: [https://github.com/bizc0m/NoteDroppy](https://github.com/bizc0m/NoteDroppy)

Téléchargement stable vérifié:
[NoteDroppy v1.25.2 gatekeeper fix](https://github.com/bizc0m/NoteDroppy-page/releases/tag/notedroppy-v1.25.2-gatekeeper-fix)

Page de téléchargement GitHub:
[https://bizc0m.github.io/NoteDroppy-page/](https://bizc0m.github.io/NoteDroppy-page/)

Docs multilingues:
[FR](docs/README.fr.md) · [EN](docs/README.en.md) · [ES](docs/README.es.md) · [DE](docs/README.de.md) · [IT](docs/README.it.md) · [PT](docs/README.pt.md)

## Version v3 locale

La piste v3 ajoute un editeur NotePlan Markdown natif, separe de la piste stable:

```text
NoteDroppy V3.app
```

Fonctions principales:

- ouverture automatique de la note du jour `Calendar/YYYYMMDD.md`;
- edition directe du fichier texte Markdown;
- choix du dossier NotePlan;
- sauvegarde avec backup local dans `.codex-backups`;
- menu `Undo`, `About` et `Changelog`;
- tri par priorite `!!!`;
- tri par contexte `@contexte`;
- tri par tag `#tag`;
- tri par importance `^^ A/B/C` ou `^^ 1/2/3`;
- tri par duree utilisateur `-- minutes`;
- recherche agenda uniquement pour la recherche texte;
- recherche de taches par tranches `<=15`, `<=30`, `<=60`, `>60` dans `Calendar` et `Notes`.
- formatage des URL avec le nom du serveur avant le lien, par exemple `poney.com https://poney.com/page`.

Build local:

```zsh
scripts/build-notedroppy-v3.sh
```

Package local:

```zsh
scripts/package-notedroppy-v3.sh
```

## Version stable v1.25 bleue

La version recommandée pour revenir à la base stable avec icône bleue est:

```text
NoteDroppy v1.25 build 35
```

Paquet GitHub:

```text
releases/NoteDroppy-v1.25-blue-service.zip
```

Cette version a été vérifiée le 2026-08-03 avec:

- icône bleue historique `URL -> NP`;
- Service macOS `NotePlan : ajouter en tâche`;
- ajout réel dans la note du jour NotePlan via `noteDate=today`;
- nettoyage de la ligne de test après validation.

Note: le paquet est signé localement et n'est pas notarise Apple. macOS peut demander une validation Gatekeeper au premier lancement. La page HTML `docs/index.html` est prête dans le repo, mais GitHub Pages n'est pas activé sur ce dépôt.

## Version v1.25.1 nouvelle icône

La variante installable actuelle avec la nouvelle icône fournie est:

```text
NoteDroppy v1.25.1 build 36
```

Paquet public:

```text
https://github.com/bizc0m/NoteDroppy-page/releases/tag/notedroppy-v1.25.1-new-icon
```

Vérifications:

- icône macOS appliquée au bundle installé;
- Service macOS `NotePlan : ajouter en tâche`;
- ajout réel dans la note du jour NotePlan;
- ligne de test supprimée après validation.

## Version v1.25.2 correction Gatekeeper locale

Cette variante garde la nouvelle icône et remplace la signature ad hoc par l'identité locale:

```text
NoteDroppy Local Code Signing
```

Paquet public:

```text
https://github.com/bizc0m/NoteDroppy-page/releases/tag/notedroppy-v1.25.2-gatekeeper-fix
```

SHA-256:

```text
9717c521a9373d161655744488e86535555123a7f5d176ebc3e1d69de3a89467
```

Limite: ce n'est toujours pas une notarisation Apple Developer ID. Sur un autre Mac ou après téléchargement navigateur, macOS peut encore demander une validation manuelle. Sur cette machine, la copie locale `NoteDroppy 2.app` a été remplacée par un bundle signé propre sans quarantine.

## Ce que ça fait

NoteDroppy envoie ce format dans NotePlan:

```text
- [ ] <contenu> #capture
```

Commande NotePlan utilisée:

```text
noteplan://x-callback-url/addText?noteDate=today&text=<texte_encode>&mode=append&openNote=yes
```

## Utilisation

Glisser-déposer sur l'icone Dock `NoteDroppy`:

- URL web: ajoute l'URL en tâche.
- Fichier `.webloc` ou `.url`: extrait l'URL et l'ajoute en tâche.
- Fichier texte, `.md`, `.rtf` ou `.textclipping`: ajoute le contenu en tâche.

Texte sélectionné:

- Clic droit -> Services -> `NotePlan : ajouter en tâche`.
- Si le menu Services n'apparait pas dans une app, garder NoteDroppy ouvert et utiliser le raccourci global.

Réglages:

- Cliquer l'icone Dock sans déposer de fichier.
- Au premier lancement, la fenêtre de réglages s'ouvre automatiquement.
- Ensuite, les lancements normaux restent silencieux pour laisser l'app prête en arrière-plan.

## Raccourci global

Le raccourci global est configurable dans les réglages.

Par défaut:

```text
Ctrl+Option+Cmd+N
```

Le raccourci a besoin de l'autorisation macOS Accessibilité, car NoteDroppy doit lire la sélection active ou simuler `Cmd+C` pour récupérer le texte.

Si Accessibilité n'est pas accordée, le raccourci est reçu par l'app mais aucune tâche n'est envoyée.

## Service macOS

Nom par défaut du Service:

```text
NotePlan : ajouter en tâche
```

Ce nom peut être changé dans les réglages. NoteDroppy met alors à jour son `Info.plist`, ressigne l'app et rafraichit LaunchServices/PBS.

Si le Service n'apparait pas après installation, relancer l'app ou exécuter le script d'installation.

## Installation

Depuis le repo:

```zsh
scripts/install-notedroppy.sh
```

App installée:

```text
/Applications/NoteDroppy.app
```

Sur cette machine, le script signe avec l'identité locale `NoteDroppy Local Code Signing` si elle existe. Cette signature stable évite que macOS perde l'autorisation Accessibilité à chaque rebuild. Sans cette identité, le script retombe en signature ad-hoc.

## Paquet diffusable sans Apple Developer

Créer un ZIP installable:

```zsh
scripts/package-notedroppy.sh
```

Le paquet est créé dans `releases/` avec:

- `NoteDroppy.app`
- `install-notedroppy.sh`
- `INSTALL.md`
- `INSTALL.fr.md`
- un checksum `.sha256`

Ce paquet n'est pas notarise par Apple. Sur un autre Mac, macOS peut demander une validation Gatekeeper au premier lancement. L'app reste installable proprement par copie dans `/Applications` ou par script.

## Réglages disponibles

- Nom du Service macOS.
- Tag ajouté à la tâche, par défaut `#capture`.
- Ouverture de NotePlan après ajout.
- 10 raccourcis globaux configurables.
- Ligne 1 par défaut : App `NotePlan`, destination `Aujourd'hui (NotePlan)` (`noteDate=today`).
- Pour chaque raccourci : Actif, combinaison clavier, App, destination, Note/Path, tags séparés par virgule.
- Apps : `NotePlan` ou `Obsidian beta`.
- Destinations NotePlan : Aujourd'hui (`noteDate=today`), Note nommée (`noteTitle=<titre>`), Chemin de note (`notePath=<chemin>` avec compatibilité NotePlan `fileName`).
- Obsidian beta : écriture directe dans une note `.md` du vault configuré.
- Recherche directe dans les notes NotePlan depuis chaque ligne de raccourci, avec filtre par titre, chemin, `#tag` ou `#contexte`, puis validation du chemin dans `Note/Path`.
- Bouton vers le panneau Accessibilité macOS.
- Aide intégrée avec lien vers le repo GitHub.

## Limites macOS

Le glisser-déposer direct de texte sélectionné vers l'icone Dock n'est pas fiable sur macOS: le Dock ne transmet pas toujours le texte brut sélectionné aux apps.

Pour le texte sélectionné, utiliser:

- le Service macOS quand l'app source l'affiche;
- le raccourci global quand le Service n'est pas disponible.

Le raccourci global est volontairement ignoré quand NoteDroppy, Réglages Système ou une alerte système est au premier plan, afin d'éviter d'envoyer le texte des réglages au lieu de la sélection cible.
