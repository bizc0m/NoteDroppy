# Peak Crypto Document Exporter

Extension Chrome **locale, non publiée** (Manifest V3) permettant de lister
puis d'exporter, sur votre demande explicite, les documents accessibles
depuis votre espace personnel :

```
https://peakimmobilier.crypto-extranet.com/xnet#documents
```

## Ce que fait l'extension

1. **Aperçu** : dès l'ouverture du popup, elle analyse le DOM déjà affiché
   par la page Documents (donc uniquement ce que votre compte connecté peut
   déjà voir) et liste les documents détectés, avec leur mécanisme
   d'ouverture probable (lien direct ou clic déclenché par le site). Aucune
   requête n'est faite, aucun onglet n'est ouvert, aucun fichier n'est
   téléchargé à cette étape — c'est une lecture seule du DOM. Un bouton
   « Actualiser l'aperçu » permet de relancer la détection à la demande
   (ex. après un changement de page ou de filtre sur le site).
2. **Sélection** : vous cochez les documents voulus (ou « Tout
   sélectionner »). Cocher une case sélectionne aussi automatiquement toutes
   les autres entrées qui portent exactement le même nom détecté (utile
   quand un même document apparaît plusieurs fois sur la page). Ce
   regroupement automatique ne s'applique jamais aux entrées dont le
   « nom » n'est en réalité que l'intitulé générique d'un bouton
   (« Télécharger », « Voir »…, sans texte de ligne distinctif) : plusieurs
   documents différents peuvent partager cet intitulé, donc ces entrées
   restent toujours sélectionnées une par une.
3. **Débit** : vous réglez le délai entre deux documents (2 secondes par
   défaut, jamais moins d'1 seconde).
4. **Téléchargement** : en cliquant sur « Télécharger la sélection », une
   confirmation explicite vous est demandée avant que quoi que ce soit ne se
   déclenche. Après confirmation, l'extension traite les documents un par un,
   au rythme réglé, en rejouant exactement l'action qu'un clic manuel
   produirait sur le site (lien de téléchargement direct, ou clic sur le
   bouton/lien « Ouvrir »/« Télécharger » du site).
5. **Arrêt immédiat** : un bouton stoppe le traitement à tout moment, avant
   le prochain document.
6. **Journal local** : chaque tentative est consignée (date, libellé du
   document, statut `succès` / `échec` / `déclenché`), stocké uniquement
   dans `chrome.storage.local` de votre navigateur.

## Ce que l'extension NE fait PAS

- Elle n'agit sur aucun autre domaine que
  `https://peakimmobilier.crypto-extranet.com` (`host_permissions` et
  `content_scripts.matches` du `manifest.json` sont restreints à ce domaine,
  et chaque message reçu est revérifié contre cette origine).
- Elle ne lit, ne stocke, ne transmet et ne contourne jamais d'identifiants,
  cookies, jetons ou mécanismes de sécurité. Les téléchargements utilisent
  la session déjà authentifiée du navigateur, exactement comme un clic
  manuel — l'extension n'y touche pas.
- Elle ne télécharge que ce qui est déjà visible et accessible sur la page
  pour votre compte connecté.
- Elle n'effectue **aucun appel réseau vers un service tiers** : aucune
  télémétrie, aucun serveur externe, aucune dépendance chargée depuis
  Internet.
- Elle ne journalise ni le contenu des documents ni leur URL — seulement la
  date, le libellé affiché et un statut.
- Elle ne déclenche jamais de téléchargement automatiquement : tout part
  d'un clic explicite sur « Aperçu » puis d'un clic explicite + confirmation
  sur « Télécharger la sélection ».

## Permissions demandées et pourquoi

| Permission | Usage |
|---|---|
| `downloads` | Lancer, via `chrome.downloads.download()`, le téléchargement natif d'un fichier lié directement (mécanisme « lien direct »). |
| `storage` | Stocker localement le réglage de débit et le journal (date/libellé/statut). |
| `scripting` | Injecter `content.js` si la page Documents était déjà ouverte avant l'installation/rechargement de l'extension. |
| `host_permissions` : `https://peakimmobilier.crypto-extranet.com/*` | Seul domaine sur lequel l'extension a le droit d'agir (scan de page, clic, téléchargement). |

Aucune permission large (`<all_urls>`, `tabs`, `webRequest`, etc.) n'est
demandée.

## Mécanisme réel de téléchargement

Comme ce projet a été construit sans accès direct à votre navigateur, le
mécanisme exact du site (lien direct, nouvel onglet, visionneuse,
fetch/Blob…) n'a pas pu être observé à l'avance. L'extension gère donc les
deux cas les plus courants :

- **Lien direct** (`<a href="…fichier.pdf">` par exemple) : l'extension
  demande au navigateur de télécharger cette URL via l'API native
  `chrome.downloads`. Le statut `succès` signifie que Chrome a démarré le
  téléchargement (vérifiez `chrome://downloads` pour la confirmation finale
  du fichier).
- **Clic déclenché par le site** (bouton « Ouvrir », « Télécharger »,
  « Voir »… géré en JavaScript par le site) : l'extension simule un clic
  réel sur cet élément, exactement comme si vous cliquiez vous-même. Le
  statut est alors noté `déclenché` : l'extension ne peut pas vérifier
  automatiquement ce qui se passe ensuite (nouvel onglet, visionneuse,
  téléchargement en arrière-plan), c'est au site lui-même de gérer l'action,
  sans que l'extension ne contourne rien.

## Limites connues

- La détection des documents dans le mode Aperçu est **heuristique**
  (liens vers des extensions de fichiers connues + boutons/liens portant un
  intitulé du type « Télécharger »/« Ouvrir »/« Voir »). Selon la structure
  réelle de la page, elle peut rater certains documents ou remonter des
  faux positifs (ex. un bouton « Voir la fiche » sans rapport). Testez le
  mode Aperçu et signalez les écarts pour affiner les sélecteurs.
- Le statut `déclenché` est une confirmation d'intention (le clic a bien été
  émis), pas une confirmation que le fichier a été enregistré sur disque.
- Le traitement s'exécute dans l'onglet de la page Documents : si vous
  fermez ou rechargez cet onglet pendant un lot, le traitement s'arrête.
- Un seul lot à la fois par onglet.
- L'extension n'a pas été testée sur le site réel dans cet environnement
  (pas d'accès navigateur depuis cette session) : validez d'abord en mode
  Aperçu avant tout téléchargement.

## Installation (mode développeur)

1. Ouvrez Chrome et allez sur `chrome://extensions`.
2. Activez le **Mode développeur** (interrupteur en haut à droite).
3. Cliquez sur **Charger l'extension non empaquetée**.
4. Sélectionnez le dossier `peak-crypto-document-exporter/` (celui qui
   contient `manifest.json`).
5. L'extension apparaît dans la liste et son icône dans la barre d'outils
   (icône par défaut de Chrome, aucune icône personnalisée n'étant fournie).

## Utilisation

1. Ouvrez `https://peakimmobilier.crypto-extranet.com/xnet#documents` et
   connectez-vous normalement.
2. Cliquez sur l'icône de l'extension dans la barre d'outils.
3. La liste des documents détectés s'affiche automatiquement ; vérifiez-la
   (cliquez sur **Actualiser l'aperçu** si vous changez de page/filtre sur
   le site).
4. Cochez les documents voulus, réglez le débit si besoin.
5. Cliquez sur **Télécharger la sélection**, puis confirmez.
6. Suivez la progression dans le popup ; cliquez sur **Arrêt immédiat** si
   nécessaire.
7. Consultez le **Journal** en bas du popup pour l'historique des tentatives.

## Vie privée

Toutes les données (réglages, journal) restent dans le stockage local de
votre navigateur (`chrome.storage.local`), propre à ce profil Chrome.
Aucune donnée n'est envoyée à Anthropic, à un serveur de l'auteur de
l'extension, ni à aucun tiers. Désinstaller l'extension supprime ces
données.
