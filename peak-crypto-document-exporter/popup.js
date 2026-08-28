/**
 * Peak Crypto Document Exporter — popup
 *
 * Interface de contrôle. L'aperçu (lecture seule, aucune ouverture ni
 * téléchargement) se lance automatiquement à l'ouverture du popup ; le
 * téléchargement réel, lui, exige toujours un clic explicite sur
 * « Télécharger la sélection » puis une confirmation supplémentaire.
 */

const ALLOWED_ORIGIN = 'https://peakimmobilier.crypto-extranet.com';
const LOG_KEY = 'peakExportLog';

const el = {
  domainBadge: document.getElementById('domainBadge'),
  warningSection: document.getElementById('warningSection'),
  scanBtn: document.getElementById('scanBtn'),
  scanMeta: document.getElementById('scanMeta'),
  resultsSection: document.getElementById('resultsSection'),
  resultsList: document.getElementById('resultsList'),
  selectAll: document.getElementById('selectAll'),
  selectionCount: document.getElementById('selectionCount'),
  settingsSection: document.getElementById('settingsSection'),
  rateLimit: document.getElementById('rateLimit'),
  downloadSection: document.getElementById('downloadSection'),
  downloadBtn: document.getElementById('downloadBtn'),
  confirmPanel: document.getElementById('confirmPanel'),
  confirmText: document.getElementById('confirmText'),
  confirmBtn: document.getElementById('confirmBtn'),
  cancelBtn: document.getElementById('cancelBtn'),
  progressPanel: document.getElementById('progressPanel'),
  progressText: document.getElementById('progressText'),
  stopBtn: document.getElementById('stopBtn'),
  clearLogBtn: document.getElementById('clearLogBtn'),
  logList: document.getElementById('logList')
};

let activeTabId = null;
let lastItems = []; // [{index, label, mechanism}]
let pollTimer = null;

function isAllowedUrl(url) {
  try {
    return new URL(url).origin === ALLOWED_ORIGIN;
  } catch (e) {
    return false;
  }
}

async function getActiveTab() {
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  return tab || null;
}

async function ensureContentScript(tabId) {
  try {
    const resp = await chrome.tabs.sendMessage(tabId, { type: 'PEAK_PING' });
    if (resp && resp.ok) return true;
  } catch (e) {
    // pas encore injecté (page ouverte avant l'installation, par ex.)
  }
  try {
    await chrome.scripting.executeScript({ target: { tabId }, files: ['content.js'] });
    return true;
  } catch (e) {
    return false;
  }
}

function setSelectionCount() {
  const boxes = el.resultsList.querySelectorAll('input[type="checkbox"]');
  const total = boxes.length;
  const checked = Array.from(boxes).filter((b) => b.checked).length;
  el.selectionCount.textContent = `${checked} sélectionné(s) sur ${total}`;
  el.downloadBtn.disabled = checked === 0;
  el.selectAll.checked = total > 0 && checked === total;
}

/**
 * Quand une case est cochée/décochée, applique le même état à toutes les
 * autres entrées qui partagent exactement le même libellé (même nom de
 * document détecté plusieurs fois sur la page).
 */
function onItemCheckboxChange(e) {
  const cb = e.target;
  const label = cb.dataset.label;
  if (label) {
    el.resultsList.querySelectorAll('input[type="checkbox"]').forEach((other) => {
      if (other !== cb && other.dataset.label === label) {
        other.checked = cb.checked;
      }
    });
  }
  setSelectionCount();
}

function renderResults(items) {
  lastItems = items;
  el.resultsList.innerHTML = '';
  items.forEach((item) => {
    const li = document.createElement('li');
    li.className = 'result-item';

    const label = document.createElement('label');
    label.className = 'checkbox-line';

    const checkbox = document.createElement('input');
    checkbox.type = 'checkbox';
    checkbox.dataset.index = String(item.index);
    checkbox.dataset.label = item.label;
    checkbox.addEventListener('change', onItemCheckboxChange);

    const text = document.createElement('span');
    text.textContent = item.label;

    const tag = document.createElement('span');
    tag.className = `tag tag-${item.mechanism === 'lien-direct' ? 'direct' : 'clic'}`;
    tag.textContent = item.mechanism === 'lien-direct' ? 'lien direct' : 'clic déclenché';

    label.appendChild(checkbox);
    label.appendChild(text);
    label.appendChild(tag);
    li.appendChild(label);
    el.resultsList.appendChild(li);
  });

  el.resultsSection.classList.toggle('hidden', items.length === 0);
  el.settingsSection.classList.toggle('hidden', items.length === 0);
  el.downloadSection.classList.toggle('hidden', items.length === 0);
  el.scanMeta.textContent = items.length
    ? `${items.length} document(s) détecté(s).`
    : 'Aucun document détecté sur cette page.';
  setSelectionCount();
}

function getSelectedIndexes() {
  return Array.from(el.resultsList.querySelectorAll('input[type="checkbox"]'))
    .filter((b) => b.checked)
    .map((b) => Number(b.dataset.index));
}

function getRateLimitMs() {
  const seconds = Math.max(1, Number(el.rateLimit.value) || 2);
  return Math.round(seconds * 1000);
}

function formatDate(iso) {
  try {
    return new Date(iso).toLocaleString('fr-FR');
  } catch (e) {
    return iso;
  }
}

async function loadLog() {
  const stored = await chrome.storage.local.get(LOG_KEY);
  const log = Array.isArray(stored[LOG_KEY]) ? stored[LOG_KEY] : [];
  el.logList.innerHTML = '';
  log.slice().reverse().forEach((entry) => {
    const li = document.createElement('li');
    li.className = `log-item log-${entry.status === 'échec' ? 'fail' : entry.status === 'succès' ? 'ok' : 'warn'}`;
    li.textContent = `${formatDate(entry.date)} — ${entry.label} — ${entry.status}`;
    el.logList.appendChild(li);
  });
}

function renderProgress(status) {
  if (!status || !status.running) {
    el.progressPanel.classList.add('hidden');
    el.confirmPanel.classList.add('hidden');
    el.downloadBtn.disabled = getSelectedIndexes().length === 0;
    stopPolling();
    loadLog();
    return;
  }
  el.confirmPanel.classList.add('hidden');
  el.progressPanel.classList.remove('hidden');
  el.progressText.textContent =
    `Traitement : ${status.done}/${status.total}` +
    (status.currentLabel ? ` — en cours : ${status.currentLabel}` : '');
}

function startPolling() {
  stopPolling();
  pollTimer = setInterval(async () => {
    if (!activeTabId) return;
    try {
      const resp = await chrome.tabs.sendMessage(activeTabId, { type: 'PEAK_GET_STATUS' });
      if (resp && resp.ok) renderProgress(resp.status);
    } catch (e) {
      // popup peut interroger avant que le content script ne soit prêt
    }
  }, 500);
}

function stopPolling() {
  if (pollTimer) {
    clearInterval(pollTimer);
    pollTimer = null;
  }
}

async function init() {
  const tab = await getActiveTab();
  if (!tab || !tab.url || !isAllowedUrl(tab.url)) {
    el.domainBadge.textContent = 'Hors du domaine autorisé';
    el.domainBadge.className = 'badge badge-no';
    el.warningSection.classList.remove('hidden');
    el.scanBtn.disabled = true;
    await loadLog();
    return;
  }

  activeTabId = tab.id;
  el.domainBadge.textContent = 'Page Peak Immobilier détectée';
  el.domainBadge.className = 'badge badge-ok';

  const ok = await ensureContentScript(tab.id);
  if (!ok) {
    el.scanMeta.textContent = "Impossible d'activer l'extension sur cette page (rechargez la page puis réessayez).";
    el.scanBtn.disabled = true;
    await loadLog();
    return;
  }

  await loadLog();

  try {
    const resp = await chrome.tabs.sendMessage(tab.id, { type: 'PEAK_GET_STATUS' });
    if (resp && resp.ok && resp.status.running) {
      startPolling();
      renderProgress(resp.status);
      return; // un lot est déjà en cours : ne pas relancer un scan par-dessus
    }
  } catch (e) {
    // pas de run en cours
  }

  // Aperçu automatique : lecture seule du DOM déjà affiché, aucune ouverture
  // ni téléchargement. Seul le bouton « Télécharger la sélection » (+ sa
  // confirmation) peut déclencher un téléchargement.
  await performScan();
}

async function performScan() {
  if (!activeTabId) return;
  el.scanBtn.disabled = true;
  el.scanMeta.textContent = 'Analyse en cours…';
  try {
    const resp = await chrome.tabs.sendMessage(activeTabId, { type: 'PEAK_SCAN' });
    if (resp && resp.ok) {
      renderResults(resp.items);
    } else {
      el.scanMeta.textContent = "Échec de l'analyse.";
    }
  } catch (e) {
    el.scanMeta.textContent = "Échec de l'analyse (rechargez la page Documents et réessayez).";
  } finally {
    el.scanBtn.disabled = false;
  }
}

el.scanBtn.addEventListener('click', performScan);

el.selectAll.addEventListener('change', () => {
  const boxes = el.resultsList.querySelectorAll('input[type="checkbox"]');
  boxes.forEach((b) => { b.checked = el.selectAll.checked; });
  setSelectionCount();
});

el.downloadBtn.addEventListener('click', () => {
  const indexes = getSelectedIndexes();
  if (indexes.length === 0) return;
  const seconds = Math.max(1, Number(el.rateLimit.value) || 2);
  el.confirmText.textContent =
    `Confirmez-vous le téléchargement de ${indexes.length} document(s) ? ` +
    `Un document sera traité toutes les ${seconds} seconde(s). Vous pourrez arrêter à tout moment.`;
  el.confirmPanel.classList.remove('hidden');
});

el.cancelBtn.addEventListener('click', () => {
  el.confirmPanel.classList.add('hidden');
});

el.confirmBtn.addEventListener('click', async () => {
  if (!activeTabId) return;
  const indexes = getSelectedIndexes();
  el.confirmPanel.classList.add('hidden');
  try {
    await chrome.tabs.sendMessage(activeTabId, {
      type: 'PEAK_START_DOWNLOAD',
      indexes,
      rateLimitMs: getRateLimitMs()
    });
    startPolling();
  } catch (e) {
    el.scanMeta.textContent = 'Impossible de démarrer le téléchargement.';
  }
});

el.stopBtn.addEventListener('click', async () => {
  if (!activeTabId) return;
  try {
    await chrome.tabs.sendMessage(activeTabId, { type: 'PEAK_STOP' });
  } catch (e) {
    // ignore
  }
});

el.clearLogBtn.addEventListener('click', async () => {
  if (!confirm('Vider le journal local ?')) return;
  await chrome.storage.local.set({ [LOG_KEY]: [] });
  await loadLog();
});

chrome.runtime.onMessage.addListener((msg) => {
  if (msg && msg.type === 'PEAK_PROGRESS') {
    renderProgress(msg.status);
  }
});

init();
