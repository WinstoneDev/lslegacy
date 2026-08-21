/* ════════════════════════════════════════════════════════════════════
   HEALTH INSPECTION — NUI SAMU (mannequin par membre + trousse + BPM)

   Pas de framework (vanilla JS + jQuery UI pour le drag-drop, comme
   inventory/html/js/inventory.js). Pont avec module/samu/client/
   health_inspection.lua : fetchNui('hi:*') / window 'message' listener,
   même convention que module/mdt/html/js/mdt.js.

   Icônes : placeholders SVG inline (aucun asset PNG dédié n'existe encore
   pour ces 9 items dans inventory/html/img/items/) — à remplacer plus tard
   par de vraies icônes sans toucher à la logique.
   ════════════════════════════════════════════════════════════════════ */

const RES = 'lslegacy';

const BODY_PARTS = ['head', 'body', 'arm_l', 'arm_r', 'leg_l', 'leg_r'];

const ITEM_ICONS = {
    bandage:    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="2" y="9" width="20" height="6" rx="3"/><path d="M8 9v6M16 9v6"/></svg>',
    med_kit:    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="7" width="18" height="13" rx="2"/><path d="M9 7V5a2 2 0 0 1 2-2h2a2 2 0 0 1 2 2v2M12 11v6M9 14h6"/></svg>',
    forceps:    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M7 3l5 9-3 9M17 3l-5 9 3 9"/></svg>',
    pliers:     '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M6 3l6 8M18 3l-6 8M12 11v10"/><circle cx="12" cy="11" r="1.5" fill="currentColor" stroke="none"/></svg>',
    suture:     '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M4 12h4M9 8v8M9 8l3-3M9 16l3 3M15 8v8M15 8l3-3M15 16l3 3M16 12h4"/></svg>',
    splint:     '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="4" y="4" width="16" height="16" rx="2"/><path d="M4 9h16M4 15h16"/></svg>',
    burn_cream: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="6" y="4" width="12" height="17" rx="2"/><path d="M9 4V2h6v2"/></svg>',
    ice_pack:   '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 2v20M4.5 6.5l15 11M19.5 6.5l-15 11"/></svg>',
    trauma_kit: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="7" width="18" height="13" rx="2"/><path d="M9 7V5a2 2 0 0 1 2-2h2a2 2 0 0 1 2 2v2M8 13h8M12 9v8"/></svg>',
};
const DEFAULT_ICON = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 2a5 5 0 0 0-5 5v2H5a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-9a2 2 0 0 0-2-2h-2V7a5 5 0 0 0-5-5z"/><path d="M9 12h6M12 9v6"/></svg>';

function el(id) { return document.getElementById(id); }

async function fetchNui(name, data) {
    try {
        const resp = await fetch(`https://${RES}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data || {}),
        });
        return await resp.json();
    } catch (e) {
        return null;
    }
}

function toast(message, kind) {
    const t = document.createElement('div');
    t.className = 'hi-toast ' + (kind || 'ok');
    t.textContent = message;
    el('hi-toasts').appendChild(t);
    setTimeout(() => t.remove(), 3500);
}

/* ── État local (miroir optimiste de l'état serveur) ─────────────── */
let state = {
    open: false,
    parts: {},          // { part: { hp, injuries: {type: count} } }
    supplies: {},        // { item: count }
    itemDefs: {},         // { item: { label, heal, treats } }
    injuryLabels: {},      // { type: label }
    bodyPartLabels: {},     // { part: label }
};
let pollTimer = null;
let expandedPart = null;
let monitorAttaching = false;

/* ── Rendu : grille de la trousse ─────────────────────────────────── */
function renderSupplies() {
    const root = el('hi-supplies');
    root.innerHTML = '';
    Object.keys(state.itemDefs).forEach((name) => {
        const def = state.itemDefs[name];
        const count = state.supplies[name] || 0;
        const div = document.createElement('div');
        div.className = 'hi-item' + (count <= 0 ? ' hi-item-empty' : '');
        div.dataset.item = name;
        div.innerHTML = `
            <div class="hi-item-count">x${count}</div>
            <div class="hi-item-icon">${ITEM_ICONS[name] || DEFAULT_ICON}</div>
            <div class="hi-item-label">${def.label}</div>
        `;
        root.appendChild(div);
    });
    initDraggables();
}

/* ── Rendu : panneau "Total Injuries" (cumul des 6 membres) ───────── */
function renderInjuries() {
    const totals = {};
    Object.keys(state.injuryLabels).forEach((t) => { totals[t] = 0; });
    BODY_PARTS.forEach((part) => {
        const p = state.parts[part];
        if (!p) return;
        Object.keys(p.injuries || {}).forEach((t) => {
            totals[t] = (totals[t] || 0) + p.injuries[t];
        });
    });

    const root = el('hi-injuries');
    root.innerHTML = '';
    Object.keys(state.injuryLabels).forEach((type) => {
        const count = totals[type] || 0;
        const row = document.createElement('div');
        row.className = 'hi-injury-row';
        row.innerHTML = `
            <span>${state.injuryLabels[type]}</span>
            <span class="hi-injury-badge${count > 0 ? ' hi-injury-active' : ''}">${count}</span>
        `;
        root.appendChild(row);
    });
}

/* ── Rendu : mannequin (% + détail par membre) ────────────────────── */
function renderParts() {
    BODY_PARTS.forEach((part) => {
        const wrap = el('hi-part-' + part);
        if (!wrap) return;
        const p = state.parts[part] || { hp: 100, injuries: {} };
        wrap.querySelector('.hi-part-pct').textContent = Math.round(p.hp) + '%';
        wrap.querySelector('.hi-part-name').textContent = state.bodyPartLabels[part] || part;
        wrap.classList.toggle('hi-part-hurt', p.hp < 100);
        wrap.classList.toggle('hi-part-expanded', expandedPart === part);

        const active = Object.keys(p.injuries || {}).filter((t) => p.injuries[t] > 0);
        const detail = wrap.querySelector('.hi-part-detail');
        detail.textContent = active.length
            ? active.map((t) => `${state.injuryLabels[t] || t} x${p.injuries[t]}`).join(' · ')
            : 'Aucune blessure active';
    });
}

/* ── Rendu : moniteur cardiaque ────────────────────────────────────── */
function overallHealthPct() {
    if (typeof state.overallHealthPct === 'number') return state.overallHealthPct;
    const vals = BODY_PARTS.map((p) => (state.parts[p] ? state.parts[p].hp : 100));
    return vals.reduce((a, b) => a + b, 0) / vals.length;
}

function renderHeart() {
    const pct = Math.max(0, Math.min(100, overallHealthPct()));
    const bpm = Math.round(70 + (180 - 70) * (1 - pct / 100) + (Math.random() * 6 - 3));
    el('hi-bpm-value').textContent = bpm;

    const badge = el('hi-status-badge');
    const emergency = pct < 40;
    badge.textContent = emergency ? 'URGENCE' : (pct < 80 ? 'BLESSÉ' : 'STABLE');
    badge.classList.toggle('hi-status-emergency', emergency);

    const amplitude = 6 + (100 - pct) * 0.18;
    const points = [];
    const w = 300, mid = 30, n = 12;
    for (let i = 0; i <= n; i++) {
        const x = (w / n) * i;
        let y = mid;
        if (i === Math.floor(n / 2)) y = mid - amplitude * 2.2;
        else if (i === Math.floor(n / 2) + 1) y = mid + amplitude;
        points.push(x + ',' + y);
    }
    el('hi-ecg-line').setAttribute('points', points.join(' '));
}

function renderAll() {
    renderSupplies();
    renderInjuries();
    renderParts();
    renderHeart();
}

/* ── Drag & drop (jQuery UI) ───────────────────────────────────────── */
function initDraggables() {
    $('.hi-item').each(function () {
        const $this = $(this);
        if ($this.data('draggableInit')) return;
        $this.data('draggableInit', true);
        $this.draggable({
            helper: function () {
                const item = $(this).data('item');
                return $(`<div class="hi-drag-helper">${ITEM_ICONS[item] || DEFAULT_ICON}</div>`);
            },
            appendTo: 'body',
            zIndex: 99999,
            revert: 'invalid',
            disabled: $this.hasClass('hi-item-empty'),
        });
    });
}

function initDroppables() {
    $('.hi-part').droppable({
        accept: '.hi-item:not(.hi-item-empty)',
        hoverClass: 'hi-drop-hover',
        drop: function (event, ui) {
            const item = ui.draggable.data('item');
            const part = $(this).data('part');
            useItem(item, part);
        },
    });
}

/* ── Utilisation d'un item (optimiste, réconcilié à la réponse serveur) ── */
function useItem(item, part) {
    const def = state.itemDefs[item];
    if (!def || (state.supplies[item] || 0) <= 0) return;

    // Optimiste : décrément immédiat (feedback instantané façon "REMOVED 1x")
    state.supplies[item] = state.supplies[item] - 1;
    const p = state.parts[part];
    if (p) {
        p.hp = Math.min(100, p.hp + def.heal);
        (def.treats || []).forEach((t) => {
            if ((p.injuries[t] || 0) > 0) p.injuries[t] -= 1;
        });
    }
    renderSupplies();
    renderInjuries();
    renderParts();
    renderHeart();

    fetchNui('hi:useItem', { item, part });
}

function onUseItemResult(payload) {
    if (!payload) return;
    if (payload.success) {
        if (payload.parts) state.parts = payload.parts;
        if (typeof payload.overallHealthPct === 'number') state.overallHealthPct = payload.overallHealthPct;
        if (payload.item && typeof payload.remainingCount === 'number') state.supplies[payload.item] = payload.remainingCount;
        renderAll();
    } else {
        // Échec côté serveur : on annule l'optimisme en redemandant l'état réel.
        toast(reasonToText(payload.reason), 'err');
        pollNow();
    }
}

function reasonToText(reason) {
    if (reason === 'unconscious') return "Patient inconscient — réanimez-le d'abord.";
    if (reason === 'full_health') return "Le patient n'a pas besoin de soins.";
    if (reason === 'missing_item') return "Vous n'avez plus cet item.";
    return "Action impossible.";
}

/* ── Rafraîchissement léger (mannequin + BPM), pendant que l'UI est ouverte ── */
async function pollNow() {
    if (!state.open) return;
    const res = await fetchNui('hi:poll', {});
    if (res && res.parts) {
        state.parts = res.parts;
        state.overallHealthPct = res.overallHealthPct;
        renderInjuries();
        renderParts();
        renderHeart();
    }
}

function startPolling() {
    stopPolling();
    pollTimer = setInterval(pollNow, 1500);
}
function stopPolling() {
    if (pollTimer) { clearInterval(pollTimer); pollTimer = null; }
}

/* ── Ouverture / fermeture ─────────────────────────────────────────── */
function openUI(payload) {
    state.open = true;
    state.parts = payload.parts || {};
    state.supplies = payload.supplies || {};
    state.itemDefs = payload.itemDefs || {};
    state.injuryLabels = payload.injuryLabels || {};
    state.bodyPartLabels = payload.bodyPartLabels || {};
    state.overallHealthPct = payload.overallHealthPct;
    state.monitorAttached = false;
    expandedPart = null;
    monitorAttaching = false;

    el('hi-attach-overlay').classList.remove('hi-hidden');
    el('hi-attach-btn').disabled = false;
    el('hi-attach-btn').textContent = '';
    el('hi-attach-btn').innerHTML = `
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M4 12h4l2-7 4 14 2-7h4"/></svg>
        Attacher le moniteur
    `;

    el('hi-root').classList.remove('hi-hidden');
    renderAll();
    initDroppables();
    startPolling();
}

function closeUI() {
    state.open = false;
    el('hi-root').classList.add('hi-hidden');
    stopPolling();
}

el('hi-close').addEventListener('click', () => { fetchNui('hi:close', {}); closeUI(); });

el('hi-attach-btn').addEventListener('click', async () => {
    if (monitorAttaching || state.monitorAttached) return;
    monitorAttaching = true;
    const btn = el('hi-attach-btn');
    btn.disabled = true;
    btn.innerHTML = 'Branchement en cours...';
    await fetchNui('hi:attachMonitor', {});
    monitorAttaching = false;
    state.monitorAttached = true;
    el('hi-attach-overlay').classList.add('hi-hidden');
    renderHeart();
});

document.addEventListener('click', (e) => {
    const arrow = e.target.closest('.hi-part-arrow');
    if (!arrow) return;
    const partEl = arrow.closest('.hi-part');
    const part = partEl.dataset.part;
    expandedPart = (expandedPart === part) ? null : part;
    renderParts();
});

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && state.open) {
        fetchNui('hi:close', {});
        closeUI();
    }
});

window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data || !data.action) return;
    if (data.action === 'hi:open') openUI(data.data || {});
    else if (data.action === 'hi:hide') closeUI();
    else if (data.action === 'hi:useItemResult') onUseItemResult(data.data);
});
