# Tests NoteDroppy 3.0A — Suivi de progression

**Date de début**: 2026-08-06  
**Baseline**: 3.0A build 1 (tag `notedroppy-v3.0A`)  
**App installée**: `/Applications/NoteDroppy.app`

## Résumé exécutif

| Priorité | Domaine | Tests prévus | Tests réussis | Tests échoués | Bloquants |
|----------|---------|--------------|---------------|---------------|-----------|
| 1 | Éditeur - Fonctions | 12 | 0 | 0 | 0 |
| 2 | Éditeur - Concurrence | 3 | 0 | 0 | 0 |
| 3 | Drag & Drop | 6 | 0 | 0 | 0 |
| 4 | Préférences | 2 | 0 | 0 | 0 |

**Total**: 23 tests à réaliser

## Priorité 1 — Fonctions de l'éditeur (CRITIQUE)

### ✅ 1.1 Compilation
- **Build réussi**: Oui (2026-08-06 09:30)
- **Signing réussi**: Oui
- **Installation**: `/Applications/NoteDroppy.app`

### ✅ 1.2 Tri des priorités (!!!/!!/!)
**Test unitaire**: PASS  
**Test GUI**: ⏳ À faire  
**Procédure**:
1. Ouvrir éditeur (Cmd+E)
2. Charger fichier de test avec priorités mélangées
3. Cliquer "Trier priorités"
4. Vérifier ordre !!! > !! > ! > normal > [x]

### ⏳ 1.3 Tri @ contexte
**Test unitaire**: À créer  
**Test GUI**: À faire

### ⏳ 1.4 Tri # tag
**Test unitaire**: À créer  
**Test GUI**: À faire

### ⏳ 1.5 Tri ^^ importance (A/B/C ou 1/2/3)
**Test unitaire**: À créer  
**Test GUI**: À faire

### ⏳ 1.6 Tri -- minutes
**Test unitaire**: À créer  
**Test GUI**: À faire

### ⏳ 1.7 Aplatir chapitres
**Test unitaire**: À créer  
**Test GUI**: À faire  
**Validation**: Vérifier que les sous-tâches sont remontées au niveau principal

### ⏳ 1.8 Aplatir plage de dates
**Test unitaire**: À créer  
**Test GUI**: À faire  
**Validation**: 
- Créer fichiers Calendar/20260801.md à 20260806.md
- Définir plage et exécuter
- Vérifier backups dans .codex-backups
- Vérifier message de statut

### ⏳ 1.9 Recherche <=15 min
**Test GUI**: À faire

### ⏳ 1.10 Recherche <=30 min
**Test GUI**: À faire

### ⏳ 1.11 Recherche <=60 min
**Test GUI**: À faire

### ⏳ 1.12 Recherche >60 min
**Test GUI**: À faire

### ⏳ 1.13 Génération raccourci .app
**Test GUI**: À faire  
**Validation**:
- Créer raccourci depuis note .md
- Vérifier CFBundleName, CFBundleDisplayName, NotePlanShortcutURL
- Tester ouverture du raccourci
- Tester remplacement existant

## Priorité 2 — Concurrence écriture .md

### ⏳ 2.1 Ouverture simultanée même fichier
**Test GUI**: À faire  
**Procédure**:
1. Ouvrir fichier dans éditeur NoteDroppy
2. Ouvrir même fichier dans NotePlan
3. Modifier dans les deux
4. Vérifier comportement (dernière écriture gagne ? conflit ?)

### ⏳ 2.2 Backup automatique
**Test GUI**: À faire  
**Validation**: Vérifier que .codex-backups contient les sauvegardes

## Priorité 3 — Drag & Drop

### ⏳ 3.1 Drag Finder .md → slot 1
**Test GUI**: À faire  
**État partiel**: Validé x3, pas complété

### ⏳ 3.2 Drag Finder .md → slot 2
**Test GUI**: À faire

### ⏳ 3.3 Drag Finder .md → slot 3
**Test GUI**: À faire

### ⏳ 3.4 Drag NotePlan → slot 1
**Test GUI**: À faire  
**État**: Jamais testé  
**Action**: Diagnostic pasteboard via `/tmp/NotePlanURLDrop.log`

### ⏳ 3.5 Drag NotePlan → slot 2
**Test GUI**: À faire

### ⏳ 3.6 Drag NotePlan → slot 3
**Test GUI**: À faire

## Priorité 4 — Préférences

### ⏳ 4.1 Focus-guard sur "Nom du Service"
**Code**: À modifier  
**Fichier**: `work/NotePlanURLDrop/main.swift`  
**Action**: Ajouter validation avant save pour éviter frappes parasites

## Bloqueurs identifiés

_Aucun pour le moment_

## Notes de test

- Les tests unitaires de logique pure (tri) sont passés avec succès
- Les tests GUI nécessitent une validation manuelle
- Logger: `/tmp/NotePlanURLDrop.log`
- Backups: `<vault>/.codex-backups/`

## Prochaines étances

1. Tester tri @, #, ^^, -- via GUI
2. Tester aplatissement chapitres
3. Tester recherche par tranches
4. Tester génération raccourci .app
5. Diagnostiquer drag NotePlan → slots
