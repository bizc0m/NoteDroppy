# NoteDroopy capture-rules.json

JSON actif :

`~/Library/Application Support/NoteDroopy/capture-rules.json`

## Objectif

Configurer les captures par nature de lien sans recompiler l'app.

## Champs

- `id` : nom stable de la règle.
- `enabled` : active ou désactive la règle.
- `match.domains` : domaines à détecter. `www.` est ignoré.
- `match.pathContains` : fragments de chemin optionnels.
- `title.fallback` : titre si le vrai titre navigateur est absent.
- `tags` : tags ajoutés automatiquement.
- `destination` : prévu pour la prochaine passe de routage par règle.
- `format` : prévu pour les formats avancés.
- `source` : `textOnly` = ajouter Source seulement quand la capture est du texte.

## Formats

URL seule :

```md
- [ ] [Titre](url) #capture #LLM #GPT
```

Texte sélectionné :

```md
- [ ] texte sélectionné #capture #LLM #GPT
> Source : [Titre](url)
```

Fichier local :

```md
- [ ] [Nom du fichier](file:///chemin/fichier.pdf) #capture
```

Multi-ligne :

```md
- [ ] première ligne #capture
> ligne 2
> ligne 3
```

## Exemple de règle

```json
{
  "id": "llm-gpt",
  "enabled": true,
  "match": { "domains": ["chatgpt.com", "chat.openai.com"] },
  "title": { "fallback": "GPT Chat" },
  "tags": ["#LLM", "#GPT"],
  "destination": { "engine": "noteplan", "type": "slot" },
  "format": "linkTask",
  "source": "textOnly"
}
```
