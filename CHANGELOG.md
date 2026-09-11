# Changelog

## 4E.4

- Tag & Config : la coloration des tokens s'affiche pendant la frappe (les
  attributs sont ecrits dans le field editor, pas seulement dans le champ).

## 4E.2

- Tag & Config : autocomplétion des tokens (Échap) — natifs, variables perso, `#capture`/`@contexte`.
- Fix autocomplétion : le sigil `# $ ! @` précédant le mot partiel n'est plus dupliqué (`$da` + `$date` donnait `$$date`).
- Tag & Config : le caret reste en place pendant la frappe (plus de saut en fin de champ).
- Coloration Tag & Config : regex compilées une seule fois au lieu de 4 par frappe (0,205 ms → 0,003 ms).

## 4E.0

- Fenêtre Capture adaptative (épouse le contenu, suit les changements).
- Garde-fou capture : 2000 signes max, tronqué avec marqueur.
- Deeplink : exige l'URL de discussion pour les chats LLM (retry + omission si stub).
- Variables perso `nom=valeur` étendues comme les natives.
- Miroirs : chaque capture aussi ajoutée aux notes listées.
- Référence grammaire : `docs/GRAMMAIRE.md`.

## 3.8

- Porte `Note Droopy.app` et `NoteDroppy V3.app` en version 3.8 build 380.
- Ajoute le gestionnaire local de prompts JSON.
- Ajoute l'ecriture directe depuis la fenetre Fonctions avec option de confirmation.

## 3.0

- Ajoute la piste separee `NoteDroppy V3.app`.
- Ouvre automatiquement la note agenda du jour `Calendar/YYYYMMDD.md`.
- Edite directement les fichiers Markdown NotePlan.
- Ajoute le choix du dossier NotePlan.
- Ajoute les tris locaux `!!!`, `@`, `#`, `^^`, `--`.
- Ajoute la convention `^^ A/B/C` ou `^^ 1/2/3` pour l'importance.
- Ajoute la convention `-- minutes` pour l'estimation utilisateur.
- Ajoute les tranches de recherche `<=15`, `<=30`, `<=60`, `>60`.
- Limite la recherche texte normale a l'agenda `Calendar`.
- Recherche les taches par tranche dans `Calendar` et `Notes`.
- Formate les URL avec le nom du serveur avant le lien.
- Ajoute une sous-fenetre `Fonctions` avec versions et fonctions NoteDroppy / NoteplanShorty.
- Ajoute `Undo`, `About` et `Changelog`.
- Cree un backup local avant chaque sauvegarde de note.

## 2.7

- Valide la piste `NoteDroppy V2.5` comme build 270.
