# Aide NoteDroppy

NoteDroppy capture du texte, des URL et des chemins de fichiers, puis ajoute une tâche dans NotePlan ou dans un fichier Markdown/TXT selon le raccourci choisi.

## Capture

- Dock : déposer une URL, un `.webloc`, un `.url`, un fichier texte ou Markdown.
- Service macOS : envoyer le texte sélectionné depuis une app compatible.
- Raccourci global : capturer la sélection active.
- Fichier non texte : capturer un lien cliquable vers le fichier.

Format de base :

```text
- [ ] Texte capturé #capture
```

## Raccourcis

Les préférences affichent 20 raccourcis configurables.

- `Action` : capturer, capturer + ouvrir, ouvrir.
- `+` : options avancées de la ligne.
- `Sortie` : NotePlan Today, NotePlan Note, Markdown `.md`, Obsidian `.md`, `.txt`.
- `Cible` : nom du fichier uniquement.
- `Tag & Config` : tags visibles + config résumée en rouge.

Le bouton `+` devient rouge quand une config avancée est active.

## Options avancées

Le panneau `+` montre l'ordre de construction :

```text
marqueur -> priorité -> contenu -> date -> tags -> config
```

Options :

- Marqueur : `- [ ]`, `*`, `+`, texte.
- Priorité NotePlan : aucune, `!`, `!!`, `!!!`.
- Date : aucune, demain, week-end, semaine pro.
- Contenu : déplié ou plié.
- Section et position d'insertion.
- Routage : ouvrir après capture, source web, source fichier.
- Gouvernance : secret/public, indexation, LLM local/distant.

L'aperçu en bas montre la ligne produite avant validation.

## Permissions

Le raccourci global demande Accessibilité macOS, car NoteDroppy doit copier la sélection active.

Si la capture sélection ne marche pas :

1. Ouvrir NoteDroppy.
2. Cliquer `Autoriser Accessibilité`.
3. Activer NoteDroppy dans macOS.
4. Quitter et relancer l'app.

GitHub : https://github.com/bizc0m/NoteDroppy
