# Prompt - App capture selection vers NotePlan

Construis une mini-app macOS locale nommee `noteplan-capture`.

Objectif:
- Un raccourci clavier global capture le texte actuellement selectionne dans n'importe quelle app.
- L'utilisateur choisit rapidement entre:
  - ajouter la selection comme todo dans la note NotePlan du jour;
  - creer une nouvelle note NotePlan pre-remplie a partir de la selection.
- L'app doit etre simple, fiable, locale, sans backend.

Contraintes:
- macOS.
- Integration NotePlan via x-callback-url officiel.
- Pour une todo dans la note du jour, utiliser:
  `noteplan://x-callback-url/addText?noteDate=today&text=<encoded>&mode=append&openNote=no`
- Pour creer une note, utiliser:
  `noteplan://x-callback-url/addNote?noteTitle=<encoded>&text=<encoded>&folder=Inbox&openNote=yes`
- Encoder correctement tous les parametres URL.
- Preserver le presse-papiers utilisateur apres capture de selection.
- Ne pas envoyer de donnees sur internet.
- Demander les permissions macOS necessaires: Accessibility et Automation.

UX attendue:
- Raccourci global configurable, par defaut `Ctrl+Option+Cmd+N`.
- Si aucun texte n'est selectionne: notification discrete.
- Si texte selectionne:
  - afficher une palette courte:
    - `Todo aujourd'hui`
    - `Nouvelle note`
  - `Todo aujourd'hui`: ajoute `- [ ] <selection> #capture` a la note du jour.
  - `Nouvelle note`: propose un titre par defaut `Capture YYYY-MM-DD HH:mm`, modifiable, puis cree une note dans `Inbox`.
- Afficher une notification de succes ou d'erreur.

Implementation recommandee:
- SwiftUI + AppKit menu bar app.
- Global hotkey avec `KeyboardShortcuts` ou Carbon Event HotKey.
- Capture selection:
  - sauvegarder le clipboard;
  - simuler Cmd+C;
  - lire le clipboard;
  - restaurer le clipboard;
  - si vide, notifier et abandonner.
- Ouverture NotePlan:
  - `NSWorkspace.shared.open(url)`.
- Logs locaux simples en cas d'erreur.

Livrables:
- Projet Xcode ou Swift Package complet.
- README avec installation, permissions macOS, configuration du raccourci, et test manuel.
- Tests unitaires sur l'encodage URL et la generation des liens NotePlan.

Critere d'acceptation:
- Depuis Safari, Mail, Notes, ou n'importe quel editeur texte, je selectionne une phrase, j'appuie sur le raccourci, je choisis `Todo aujourd'hui`, et la todo apparait dans la note NotePlan du jour.
- Je selectionne un paragraphe, j'appuie sur le raccourci, je choisis `Nouvelle note`, je valide le titre, et une note s'ouvre dans NotePlan avec le contenu selectionne.
