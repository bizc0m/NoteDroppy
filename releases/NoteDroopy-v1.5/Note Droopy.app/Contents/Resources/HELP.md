# Aide NoteDroppy

NoteDroppy ajoute rapidement une tâche dans la note du jour NotePlan.

GitHub Repository:

```text
https://github.com/bizc0m/NoteDroppy
```

## Format envoyé

```text
- [ ] <contenu> #capture
```

Le tag peut être changé dans les réglages.

## Envoyer une URL ou un fichier

Glisser-déposer sur l'icone Dock `NoteDroppy` :

- URL depuis un navigateur.
- Fichier `.webloc` ou `.url`.
- Fichier texte `.txt`, `.md`, `.rtf` ou `.textclipping`.

L'envoi est direct vers NotePlan.

## Envoyer du texte sélectionné

Deux méthodes existent.

### Service macOS

Dans les apps compatibles :

```text
App active > Services > NotePlan : ajouter en tâche
```

Selon l'app, le Service peut aussi apparaître dans le clic droit.

### Raccourci global

Pour les apps qui n'affichent pas les Services :

1. Laisser NoteDroppy ouvert.
2. Sélectionner du texte.
3. Utiliser le raccourci global, par défaut `Ctrl+Option+Cmd+N`.

Le raccourci est configurable dans les réglages.

macOS exige l'autorisation Accessibilité pour cette méthode, car NoteDroppy doit simuler `Cmd+C` pour lire la sélection.

Si Accessibilité n'est pas accordée, le raccourci ne peut pas lire la sélection d'une autre app et n'envoie rien.

## Réglages

Cliquer sur l'icone Dock `NoteDroppy` sans déposer de fichier.

Réglages disponibles :

- Nom du Service macOS.
- Tag ajouté à la tâche.
- Ouverture de NotePlan après ajout.
- 10 raccourcis globaux configurables.
- Ligne 1 par défaut : App `NotePlan`, destination `Aujourd'hui (NotePlan)`.
- Pour chaque raccourci : Actif, Raccourci, App, Destination, Note/Path, Tags.
- Apps : `NotePlan` ou `Obsidian beta`.
- Destinations NotePlan : Aujourd'hui, Note nommée, Chemin de note.
- Obsidian beta : écrire directement dans une note `.md` du vault.
- Le bouton `Rechercher` liste les notes NotePlan, filtre par titre, chemin, `#tag` ou `@contexte`, puis valide le chemin dans `Note/Path`.
- Tags séparés par virgule, automatiquement normalisés en tags NotePlan.
- Export JSON et import JSON des préférences.
- Accès direct au panneau Accessibilité macOS.
- Aide intégrée dans l'app avec bouton `GitHub Repository`.

## Autorisation Accessibilité

Si le raccourci global ne fonctionne pas :

1. Ouvrir NoteDroppy.
2. Cliquer `Autoriser Accessibilité`.
3. Dans macOS, activer `NoteDroppy`.
4. Quitter et relancer NoteDroppy.

Sur cette machine, NoteDroppy est signé avec l'identité locale `NoteDroppy Local Code Signing` pour éviter que macOS perde l'autorisation à chaque rebuild.

## Limites macOS

Le glisser-déposer direct de texte sélectionné vers l'icone Dock n'est pas fiable sur macOS. Le Dock ne transmet pas toujours le texte brut sélectionné aux apps.

Le raccourci global est ignoré quand NoteDroppy, Réglages Système ou une alerte système est au premier plan, afin d'éviter d'envoyer le texte des réglages au lieu de la sélection cible.
