# Grammaire Droopy — comportements (V4 B)

| Comportement | Token (lien) | Type |
|---|---|---|
| Ajoute `#tag` en suffixe de ligne | `#capture`, `#projet`… | Tag |
| Ajoute `@contexte` en clair | `@jesus`, `@annecy`… | Contexte |
| Date du jour (profil Standard/Obsidian/NotePlan) | `$date` | Variable |
| Jour en lettres | `$day` | Variable |
| Heure HH:MM | `$time` | Variable |
| Date + heure | `$datetime` | Variable |
| Mois en lettres | `$month` | Variable |
| Année | `$year` | Variable |
| Semaine ISO | `$week` | Variable |
| Secondes epoch (ID unique) | `$timestamp` | Variable |
| Nom de la note cible | `$note` | Variable |
| Nom du service | `$service` | Variable |
| Numéro de ligne | `$row` | Variable |
| Source brute (URL ou fichier) | `$source` | Variable |
| URL (erreur si vide) | `$url` | Variable |
| Fichier (erreur si vide) | `$file` | Variable |
| Conservé littéral (moteur non branché) | `$LLM` | Variable |
| Révèle la note dans le Finder après écriture | `!Open` | Option |
| Exige une URL source | `!Web` | Option |
| Retire l'URL | `!NoWeb` | Option |
| Exige un fichier source | `!File` | Option |
| Retire le fichier | `!NoFile` | Option |
| Ligne `- [ ]` (case) | `!Star` | Format |
| Ligne `-` (puce) | `!Plus` | Format |
| Ligne texte brut | `!Text` | Format |
| Priorité, suffixe (dernier gagne) | `!`, `!!`, `!!!`, `!!!!`, `!!!!!` | Priorité |
| Date planifiée J+1 | `!Demain` | Date |
| Date planifiée samedi | `!Weekend` | Date |
| Date planifiée lundi | `!SemainePro` | Date |
| Date planifiée le 1er | `!MoisProchain` | Date |
| Date planifiée +6 mois | `!Dans6Mois` | Date |
| Ancre nommée pour Before/After | `$section(Nom)` | Section |
| Insère en haut du fichier | `!SectionTop` | Section |
| Insère en bas du fichier | `!SectionBottom` | Section |
| Insère au début de X (erreur si introuvable) | `!BeforeSection` | Section |
| Insère à la fin de X (erreur si introuvable) | `!AfterSection` | Section |

Règles : un token inconnu est une erreur explicite, jamais un silence.
Formats de date planifiée : `>AAAA-MM-JJ` si NotePlan, `AAAA-MM-JJ` sinon.
