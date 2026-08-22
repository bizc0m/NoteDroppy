# LARO - V3

## Objectif

Transformer une demande brute en resultat clair, exploitable et limite au perimetre fourni.

## Acronyme

**LARO** = **Lire, Analyser, Retravailler, Optimiser**

## Prompt principal

```text
Applique LARO au contenu fourni.

MODE :
- analyse seule
- amelioration
- optimisation
- application directe

REGLES :
- Lis uniquement le contenu fourni.
- N'elargis pas le perimetre.
- Separe faits, hypotheses, manques et risques.
- Corrige seulement ce qui est utile et reversible.
- Optimise pour action concrete.
- Si build, test, deploy, commit ou push sont demandes, execute uniquement si un fichier, depot ou contexte reel est disponible.

SORTIE :
MODE UTILISE
RISQUE
AVIS
CHANGEMENTS
3 PRO
3 CONTRE
3 SUGGESTIONS
NEXT
```

## Variante stricte

```text
Lis uniquement le contenu fourni. N'elargis pas. Mode visible. Risque visible. Analyse les faiblesses, risques, doublons et zones floues. Propose des ameliorations utiles. Applique seulement les corrections reversibles. Si une action reelle est impossible faute de contexte, indique-la dans NEXT. Sortie : MODE UTILISE, RISQUE, AVIS, CHANGEMENTS, 3 PRO, 3 CONTRE, 3 SUGGESTIONS, NEXT.
```

## Modes

- **Analyse seule** : diagnostiquer sans modifier.
- **Amelioration** : clarifier, corriger, structurer.
- **Optimisation** : reduire, renforcer, rendre executable.
- **Application directe** : modifier ou executer si le contexte reel est disponible.

## Methode

1. Lire : objectif, contexte, contraintes, sortie attendue.
2. Analyser : faits, hypotheses, erreurs, doublons, manques, risques.
3. Retravailler : clarifier, corriger, structurer, nettoyer sans elargir.
4. Optimiser : rendre court, robuste et executable.
5. Restituer : produire une sortie actionnable dans le format impose.

## Variantes a creer

- `LARO texte`
- `LARO code`
- `LARO prompt`
- `LARO dashboard`
- `LARO KM`

## Regle d'execution

Si `Build Deploy Test more Commit + push` est demande :

- build uniquement si le depot contient une commande existante ;
- deploy uniquement si une cible explicite existe ;
- test uniquement avec les tests locaux disponibles ;
- commit uniquement les fichiers lies au changement ;
- push uniquement si l'utilisateur l'a demande explicitement.
