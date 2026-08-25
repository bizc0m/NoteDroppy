# Test Editor Functions — NoteDroppy 3.0A

## Objectif
Valider toutes les fonctions de l'éditeur intégré après fusion V3 → 3.0A.

## Date de test
2026-08-06

## Résumé des tests

### 1. Sort Priorities (!!! !! !)
**Statut**: ⏳ À tester
**Procédure**:
1. Ouvrir l'éditeur (Cmd+E)
2. Charger un fichier .md de test avec des priorités mélangées
3. Cliquer "Trier priorités"
4. Vérifier que !!! passe en premier, puis !!, puis !
5. Vérifier que les tâches terminées [x] sont déplacées en fin

**Résultat**: 

---

### 2. Sort @ Context
**Statut**: ⏳ À tester
**Procédure**:
1. Ouvrir l'éditeur avec fichier contenant des @contexte variés
2. Cliquer "Trier @"
3. Vérifier tri alphabétique par contexte
4. Vérifier que les blocs sans @ restent en fin

**Résultat**: 

---

### 3. Sort # Tag
**Statut**: ⏳ À tester
**Procédure**:
1. Ouvrir l'éditeur avec fichier contenant des #tag variés
2. Cliquer "Trier #"
3. Vérifier tri alphabétique par tag

**Résultat**: 

---

### 4. Sort ^^ Importance (A/B/C ou 1/2/3)
**Statut**: ⏳ À tester
**Procédure**:
1. Ouvrir l'éditeur avec fichier contenant des ^^A, ^^B, ^^C ou ^^1, ^^2, ^^3
2. Cliquer "Trier ^^"
3. Vérifier tri par importance (A/1 avant B/2 avant C/3)

**Résultat**: 

---

### 5. Sort -- Minutes
**Statut**: ⏳ À tester
**Procédure**:
1. Ouvrir l'éditeur avec fichier contenant des --15, --30, --60
2. Cliquer "Trier --"
3. Vérifier tri numérique croissant par durée
4. Vérifier que les tâches sans durée restent en fin

**Résultat**: 

---

### 6. Flatten Chapters
**Statut**: ⏳ À tester
**Procédure**:
1. Ouvrir l'éditeur avec fichier contenant des chapitres (## Titre)
2. Cliquer "Aplatir chapitres"
3. Vérifier que les sous-tâches sont remontées au niveau principal
4. Vérifier que les titres de chapitres sont préservés en contexte

**Résultat**: 

---

### 7. Flatten Date Range
**Statut**: ⏳ À tester
**Procédure**:
1. Définir une plage de dates (ex: 20260801 à 20260806)
2. Cliquer "Aplatir plage"
3. Vérifier que tous les fichiers Calendar/YYYYMMDD.md sont traités
4. Vérifier les backups dans .codex-backups
5. Vérifier le message de statut (X modifiée(s), Y absente(s))

**Résultat**: 

---

### 8. Search <=15 min
**Statut**: ⏳ À tester
**Procédure**:
1. Ouvrir l'éditeur
2. Cliquer "<=15"
3. Vérifier que les résultats affichent uniquement des tâches <= 15 min
4. Vérifier que la recherche couvre Calendar + Notes

**Résultat**: 

---

### 9. Search <=30 min
**Statut**: ⏳ À tester
**Procédure**: Similaire à <=15

**Résultat**: 

---

### 10. Search <=60 min
**Statut**: ⏳ À tester
**Procédure**: Similaire à <=15

**Résultat**: 

---

### 11. Search >60 min
**Statut**: ⏳ À tester
**Procédure**: Similaire à <=15

**Résultat**: 

---

### 12. Generate Shortcut .app
**Statut**: ⏳ À tester
**Procédure**:
1. Cliquer "FONCTIONS"
2. Sélectionner une note .md
3. Choisir destination (ex: ~/Applications)
4. Cliquer générer
5. Vérifier que le .app est créé
6. Vérifier que le .app s'ouvre dans NotePlan
7. Vérifier CFBundleName, CFBundleDisplayName, NotePlanShortcutURL dans Info.plist
8. Tester le remplacement d'un .app existant

**Résultat**: 

---

## Notes de test

### Fichier de test à utiliser
Créer un fichier Calendar/20260806.md avec:
- Tâches avec priorités !!!, !!, !
- Tâches avec @contexte, #tag
- Tâches avec ^^A, ^^B, ^^1, ^^2
- Tâches avec --15, --30, --60
- Tâches terminées [x]
- Plusieurs chapitres ## Titre
- Mélange de formats

### Vérifications supplémentaires
- [ ] Les backups sont créés dans .codex-backups avant écriture
- [ ] Les messages de statut sont corrects
- [ ] Pas de crash lors des opérations
- [ ] L'interface reste réactive
