# NoteDroppy Integrated v4.0 - rapport QA

Date: 2026-08-13
Branche: agent/notedroppy-integrated-v4
Bundle: local.codex.notedroppy.integrated
App installee: /Applications/NoteDroppy Integrated.app
DMG: releases/NoteDroppyIntegrated-v4.0.dmg
SHA-256: 19643174938343cfcd751204451ce8e3ae34d853252938757d880630a9254897

## OK

- Build swiftc OK via scripts/build-notedroppy-integrated.sh 4.0 401.
- plutil OK sur /Applications/NoteDroppy Integrated.app/Contents/Info.plist.
- codesign OK sur /Applications/NoteDroppy Integrated.app.
- Bundle separe OK: local.codex.notedroppy.integrated.
- App lancee depuis /Applications: /Applications/NoteDroppy Integrated.app/Contents/MacOS/NoteDroppyIntegrated.
- Fenetre Preferences OK: 10 slots visibles, touches 1 a 9 et 0, 10 boutons Rechercher, version visible "NoteDroppy Integrated 4.0".
- Invite Accessibilite non repetitive OK: premier lancement sans autorisation logue accessibility:prompt:shown, relance logue accessibility:prompt:skipped.
- Bouton manuel Preferences OK: logue accessibility:settings:opened et ouvre Reglages Systeme.
- Service macOS NSPerformService OK: "NotePlan : ajouter en tache (Integrated)".
- Ecriture NotePlan reelle OK dans Calendar/20260813.md.
- Une selection multi-ligne via Service cree une seule tache, avec continuations preservees.
- URL OK, .webloc OK, .url OK.
- txt multi-paragraphes OK, md OK, rtf OK.
- Fichier binaire OK: lien Markdown file://.
- Variables OK: tag literal "#var-$date,#year-$year" ecrit "#var-2026-08-13 #year-2026".
- Recherche locale OK: index 9076 notes, recherche titre/chemin/#tag/@contexte OK, validation remplit la cible du slot.
- Export JSON OK: fichier JSON valide exporte depuis l'UI.
- Service macOS reste OK sans Accessibilite apres ajout de l'invite non repetitive.
- Nettoyage OK: lignes de test NotePlan et note temporaire supprimees, preferences restaurees.

## KO / bloque

- Raccourci global slot 1: le hotkey est recu, mais capture selection bloquee par macOS Accessibilite.
- Preuve log: shortcut:invoked:slot:1 puis shortcut:accessibility-required:no-selection-capture.
- Slot 2/autre slot non validable tant que la meme autorisation Accessibilite manque.
- Import JSON UI non valide en automatisation: le panneau macOS est reste ouvert, aucun statut "Preferences importees" observe.

## Xattrs

- Pas de com.apple.quarantine detecte sur app/DMG.
- com.apple.provenance reste present; non assimile a quarantine.

## Decision release

- DMG candidat cree.
- Pas de tag release complet tant que les tests raccourcis globaux ne passent pas avec l'autorisation Accessibilite.
