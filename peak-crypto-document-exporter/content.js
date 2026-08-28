/**
 * Peak Crypto Document Exporter — content script
 *
 * Portée : ce script ne s'exécute QUE sur https://peakimmobilier.crypto-extranet.com/*
 * (voir manifest.json, content_scripts.matches).
 *
 * Rôle :
 *  - "Aperçu" : détecte, dans le DOM déjà rendu par la page (donc uniquement des
 *    documents auxquels le compte connecté a déjà accès), la liste des documents
 *    et leur mode d'ouverture probable. Ne clique sur rien, ne télécharge rien.
 *  - "Téléchargement" : sur ordre explicite du popup (après confirmation par
 *    l'utilisateur), rejoue exactement l'action que l'utilisateur ferait
 *    lui-même (clic sur le bouton/lien d'ouverture du site, ou téléchargement
 *    direct du fichier lié), avec une limite de débit et un arrêt immédiat.
 *
 * Ce script ne lit, ne stocke et ne transmet jamais d'identifiants, cookies,
 * jetons ou contenu de document. Le journal local ne conserve que : date,
 * libellé affiché du document, statut.
 */

(() => {
  const ALLOWED_ORIGIN = 'https://peakimmobilier.crypto-extranet.com';
  if (location.origin !== ALLOWED_ORIGIN) {
    // Garde-fou supplémentaire, en plus des "matches" du manifest.
    return;
  }

  const DOC_EXTENSIONS = new Set([
    'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx',
    'zip', 'rar', '7z', 'png', 'jpg', 'jpeg', 'gif', 'bmp',
    'tif', 'tiff', 'txt', 'csv', 'rtf', 'odt', 'ods', 'odp',
    'xml', 'json'
  ]);

  const ACTION_WORDS = /t[ée]l[ée]charger|download|ouvrir|voir|consulter|afficher|visualiser|export/i;
  const ROW_SELECTOR = 'tr, li, [class*="row"], [class*="item"], [class*="document"], [class*="file"], [class*="ligne"]';

  /** @type {Array<{label:string, mechanism:'lien-direct'|'clic-declenche', url:string|null, el:Element}>} */
  let currentScan = [];

  let runState = {
    running: false,
    total: 0,
    done: 0,
    currentLabel: null,
    stopRequested: false,
    timer: null
  };

  function absoluteUrl(href) {
    try {
      return new URL(href, document.baseURI).href;
    } catch (e) {
      return null;
    }
  }

  function extensionFromUrl(url) {
    try {
      const pathname = new URL(url).pathname;
      const match = pathname.match(/\.([a-z0-9]{2,5})$/i);
      return match ? match[1].toLowerCase() : null;
    } catch (e) {
      return null;
    }
  }

  function guessLabel(el, row) {
    let label = (row.getAttribute && (row.getAttribute('aria-label') || row.getAttribute('title'))) || '';
    label = label.trim();
    if (!label) {
      const text = (row.innerText || row.textContent || '').trim();
      label = text.split('\n').map(s => s.trim()).filter(Boolean)[0] || '';
      label = label.slice(0, 160);
    }
    if (!label) {
      label = (el.textContent || '').trim().slice(0, 160);
    }
    return label || 'Document sans nom détecté';
  }

  /**
   * Scanne le DOM actuel et retourne la liste des documents détectés.
   * Lecture seule : aucun clic, aucune navigation, aucun téléchargement.
   */
  function scan() {
    const byRow = new Map(); // row element -> entry
    const seenEls = new Set();

    // Stratégie 1 : liens pointant directement vers un fichier reconnu.
    document.querySelectorAll('a[href]').forEach((a) => {
      if (seenEls.has(a)) return;
      const url = absoluteUrl(a.getAttribute('href'));
      if (!url) return;
      const ext = extensionFromUrl(url);
      if (!ext || !DOC_EXTENSIONS.has(ext)) return;
      seenEls.add(a);
      const row = a.closest(ROW_SELECTOR) || a;
      byRow.set(row, {
        label: guessLabel(a, row),
        mechanism: 'lien-direct',
        url,
        el: a
      });
    });

    // Stratégie 2 : boutons/liens à intitulé d'action (ouvrir, télécharger, voir…),
    // pour les documents ouverts via JS (nouvel onglet, visionneuse, blob, etc.).
    document.querySelectorAll('a,button,[role="button"]').forEach((el) => {
      if (seenEls.has(el)) return;
      const text = (el.textContent || '').trim();
      const aria = el.getAttribute('aria-label') || '';
      if (!ACTION_WORDS.test(text) && !ACTION_WORDS.test(aria)) return;
      const row = el.closest(ROW_SELECTOR) || el;
      if (byRow.has(row)) return; // une entrée "lien-direct" existe déjà pour cette ligne
      seenEls.add(el);
      byRow.set(row, {
        label: guessLabel(el, row),
        mechanism: 'clic-declenche',
        url: null,
        el
      });
    });

    currentScan = Array.from(byRow.values()).slice(0, 500);
    return currentScan;
  }

  function waitCancelable(ms) {
    return new Promise((resolve) => {
      runState.timer = setTimeout(() => {
        runState.timer = null;
        resolve();
      }, ms);
    });
  }

  async function triggerEntry(entry) {
    try {
      if (entry.mechanism === 'lien-direct' && entry.url) {
        const resp = await chrome.runtime.sendMessage({ type: 'PEAK_DOWNLOAD_URL', url: entry.url });
        return { status: resp && resp.ok ? 'succès' : 'échec' };
      }
      entry.el.scrollIntoView({ block: 'center' });
      entry.el.click();
      return { status: 'déclenché' };
    } catch (e) {
      return { status: 'échec' };
    }
  }

  async function appendLog(label, status) {
    const key = 'peakExportLog';
    const stored = await chrome.storage.local.get(key);
    const log = Array.isArray(stored[key]) ? stored[key] : [];
    log.push({ date: new Date().toISOString(), label, status });
    await chrome.storage.local.set({ [key]: log.slice(-500) });
  }

  function broadcastProgress() {
    chrome.runtime.sendMessage({ type: 'PEAK_PROGRESS', status: getStatus() }).catch(() => {});
  }

  function getStatus() {
    return {
      running: runState.running,
      total: runState.total,
      done: runState.done,
      currentLabel: runState.currentLabel
    };
  }

  function stopRun() {
    runState.stopRequested = true;
    if (runState.timer) {
      clearTimeout(runState.timer);
      runState.timer = null;
    }
    runState.running = false;
    broadcastProgress();
  }

  async function startRun(indexes, rateLimitMs) {
    if (runState.running) return;
    const rate = Math.max(1000, Number(rateLimitMs) || 2000);
    runState = { running: true, total: indexes.length, done: 0, currentLabel: null, stopRequested: false, timer: null };
    broadcastProgress();

    for (const idx of indexes) {
      if (runState.stopRequested) break;
      const entry = currentScan[idx];
      if (!entry) { continue; }

      runState.currentLabel = entry.label;
      broadcastProgress();

      const result = await triggerEntry(entry);
      await appendLog(entry.label, result.status);

      runState.done += 1;
      broadcastProgress();

      if (runState.stopRequested) break;
      await waitCancelable(rate);
    }

    runState.running = false;
    runState.currentLabel = null;
    broadcastProgress();
  }

  chrome.runtime.onMessage.addListener((msg, sender, sendResponse) => {
    if (!msg || typeof msg.type !== 'string') return;

    switch (msg.type) {
      case 'PEAK_PING':
        sendResponse({ ok: true });
        return false;

      case 'PEAK_SCAN': {
        const entries = scan();
        sendResponse({
          ok: true,
          items: entries.map((e, i) => ({ index: i, label: e.label, mechanism: e.mechanism }))
        });
        return false;
      }

      case 'PEAK_START_DOWNLOAD':
        startRun(Array.isArray(msg.indexes) ? msg.indexes : [], msg.rateLimitMs);
        sendResponse({ ok: true });
        return false;

      case 'PEAK_STOP':
        stopRun();
        sendResponse({ ok: true });
        return false;

      case 'PEAK_GET_STATUS':
        sendResponse({ ok: true, status: getStatus() });
        return false;

      default:
        return false;
    }
  });
})();
