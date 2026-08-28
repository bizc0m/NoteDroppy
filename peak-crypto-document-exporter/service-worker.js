/**
 * Peak Crypto Document Exporter — service worker (MV3)
 *
 * Rôle unique : recevoir une URL de fichier détectée par le content script
 * (uniquement des URL du domaine autorisé, cf. host_permissions) et lancer un
 * téléchargement natif via chrome.downloads. Le téléchargement utilise la
 * session déjà authentifiée du navigateur (comme un clic normal) : ce script
 * ne manipule et ne lit aucun identifiant, cookie ou jeton.
 *
 * Aucun appel réseau n'est effectué vers un service tiers.
 */

const ALLOWED_ORIGIN = 'https://peakimmobilier.crypto-extranet.com';

chrome.runtime.onMessage.addListener((msg, sender, sendResponse) => {
  if (!msg || msg.type !== 'PEAK_DOWNLOAD_URL') return false;

  let parsed;
  try {
    parsed = new URL(msg.url);
  } catch (e) {
    sendResponse({ ok: false });
    return false;
  }

  if (parsed.origin !== ALLOWED_ORIGIN) {
    // Garde-fou : on ne télécharge jamais en dehors du domaine autorisé.
    sendResponse({ ok: false });
    return false;
  }

  chrome.downloads.download({ url: parsed.href, saveAs: false }, (downloadId) => {
    if (chrome.runtime.lastError || downloadId === undefined) {
      sendResponse({ ok: false });
    } else {
      sendResponse({ ok: true, downloadId });
    }
  });

  return true; // réponse asynchrone
});
