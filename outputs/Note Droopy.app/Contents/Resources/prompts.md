# NoteDroopy prompts.json

JSON actif :

`~/Library/Application Support/NoteDroopy/prompts.json`

## Objectif

Charger des prompts locaux personnalisables sans recompiler l'app.

## Champs

- `id` : identifiant stable.
- `enabled` : active ou desactive le prompt.
- `title` : nom affiche dans NoteDroppy.
- `apps` : noms d'apps macOS indicatifs.
- `bundleIds` : identifiants bundle indicatifs.
- `domains` : domaines indicatifs.
- `tags` : tags ajoutes a la ligne NotePlan.
- `template` : texte du prompt.

## Variables

- `$date`
- `$day`
- `$time`
- `$datetime`
- `$month`
- `$year`
- `$app`
- `$bundleId`
- `$url`
- `$title`
- `$source`
- `$selection`

## Exemple

```json
{
  "id": "resume-lien",
  "enabled": true,
  "title": "Resumer ce lien",
  "apps": ["Perplexity", "Claude", "Codex", "ChatGPT"],
  "tags": ["#LLM", "#prompt"],
  "template": "Resume cette page en 5 points : $url\nTitre : $title\nSource : $source"
}
```
