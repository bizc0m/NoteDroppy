# Rapport de Tests — NoteDroppy 3.0A

**Date**: 2026-08-06
**Baseline**: Tag `notedroppy-v3.0A`, commit `5a9ca0a`
**App**: `/Applications/NoteDroppy.app` version 3.0A build 1

---

## ✅ Tests Automatisés Réussis

### 1. Compilation
- **Build**: ✅ Succès
- **Signing**: ✅ Réussi (NoteDroppy Local Code Signing)
- **Installation**: ✅ `/Applications/NoteDroppy.app`

### 2. Tests Unitaires Logique
- **Tri des priorités**: ✅ PASS
  - Ordre !!! > !! > ! validé
  - Tâches [x] déplacées en fin
  - Préservation des titres et structure

### 3. Vérification Présence Code
- **Fonctions Editor***: ✅ 12/12 présentes
  - sortPriorities, sortAtContext, sortHashContext
  - sortImportance, sortMinutes
  - flattenChapters, flattenDateRange
  - search15, search30, search60, searchMore60
  - generateShortcutApp

- **Classes/Structs Editor***: ✅ 5/5 présents
  - EditorPrioritySorter (enum)
  - EditorTaskSorter (enum)
  - EditorChapterFlattener (enum)
  - EditorTaskSearch (class)
  - EditorNotePlanShortcutGenerator (struct)

- **Boutons UI**: ✅ 11/11 présents
  - Trier priorités, @, #, ^^, --
  - Aplatir chapitres, Aplatir plage
  - Recherche <=15, <=30, <=60, >60

---

## ⏳ Tests GUI Requis (Validation Manuelle)

### Priorité 1 — Fonctions Éditeur (CRITIQUE)

#### 1.1 Tri des priorités (!!! !! !)
**Statut**: ⏳ À tester via GUI
**Procédure**:
1. Ouvrir éditeur (Cmd+E)
2. Charger fichier test avec priorités mélangées
3. Cliquer "Trier priorités"
4. Vérifier: !!! en tête, puis !!, !, normal, [x] en fin

**Fichier de test**: Créer `Calendar/20260806-test.md` avec:
```markdown
# Test Priorités
- [ ] Tache normale
- !!! Haute priorite
- !! Moyenne priorite
- ! Basse priorite
- [x] Tache terminee
```

#### 1.2 Tri @ contexte
**Statut**: ⏳ À tester
**Validation**: Tri alphabétique par @contexte

#### 1.3 Tri # tag
**Statut**: ⏳ À tester
**Validation**: Tri alphabétique par #tag

#### 1.4 Tri ^^ importance
**Statut**: ⏳ À tester
**Validation**: Tri A/1 avant B/2 avant C/3

#### 1.5 Tri -- minutes
**Statut**: ⏳ À tester
**Validation**: Tri numérique croissant par durée

#### 1.6 Aplatir chapitres
**Statut**: ⏳ À tester
**Validation**: Sous-tâches remontées au niveau principal

#### 1.7 Aplatir plage de dates
**Statut**: ⏳ À tester
**Validation**:
- Traitement de tous les fichiers Calendar/YYYYMMDD.md
- Backups créés dans .codex-backups
- Message de statut correct

#### 1.8 Recherche <=15 min
**Statut**: ⏳ À tester
**Validation**: Résultats uniquement tâches ≤ 15 min

#### 1.9 Recherche <=30 min
**Statut**: ⏳ À tester

#### 1.10 Recherche <=60 min
**Statut**: ⏳ À tester

#### 1.11 Recherche >60 min
**Statut**: ⏳ À tester

#### 1.12 Génération raccourci .app
**Statut**: ⏳ À tester
**Validation**:
- .app créé avec CFBundleName correct
- URL NotePlan fonctionnelle
- Remplacement existant géré

### Priorité 2 — Concurrence Écriture

#### 2.1 Ouverture simultanée même fichier
**Statut**: ⏳ À tester
**Procédure**:
1. Ouvrir fichier dans éditeur NoteDroppy
2. Ouvrir même fichier dans NotePlan
3. Modifier dans les deux
4. Vérifier comportement

#### 2.2 Backup automatique
**Statut**: ⏳ À tester
**Validation**: Vérifier `.codex-backups/` contient sauvegardes

### Priorité 3 — Drag & Drop

#### 3.1-3.3 Drag Finder .md → slots
**Statut**: ⏳ Partiellement validé (x3), à compléter
**Action**: Tester drag complet avec clic sur raccourci

#### 3.4-3.6 Drag NotePlan → slots
**Statut**: ⏳ Jamais testé
**Action**: Diagnostic via `/tmp/NotePlanURLDrop.log`

### Priorité 4 — Préférences

#### 4.1 Focus-guard "Nom du Service"
**Statut**: ⏳ À implémenter
**Action**: Ajouter validation avant save

---

## 📋 Checklist Sommaire

- [x] Compilation OK
- [x] Tests unitaires logique OK
- [x] Code Editor* fusionné et présent
- [ ] Tests GUI fonctions éditeur (12 tests)
- [ ] Tests concurrence écriture (2 tests)
- [ ] Tests drag & drop complets (6 tests)
- [ ] Amélioration champ Service Name

**Progression globale**: ~25% (3/23 tests complétés)

---

## 🎯 Prochaines Actions Recommandées

1. **Tester GUI fonctions éditeur** (Priorité 1)
   - Commencer par tri priorités (déjà validé en logique)
   - Tester tri @, #, ^^, --
   - Tester aplatissement chapitres
   - Tester recherche par tranches

2. **Diagnostiquer drag NotePlan → slots**
   - Activer logging dans `/tmp/NotePlanURLDrop.log`
   - Analyser types de pasteboard

3. **Implémenter focus-guard Service Name**
   - Modifier préférences pour ajouter validation

4. **Tester concurrence écriture**
   - Vérifier comportement avec deux fenêtres

---

## 📝 Notes

- Tests unitaires créés: `test-editor-logic.swift`, `test-all-editor-functions.swift`
- Guide de test manuel: `test-editor-functions.md`
- Plan de test: `TESTING-3.0A.md`
- Logger: `/tmp/NotePlanURLDrop.log`
- Backups: `<vault>/.codex-backups/`

**Build testé**: 2026-08-06 09:30
**Signing**: NoteDroppy Local Code Signing
