/* ════════════════════════════════════════════════════════════════
   Menu Admin — Logique NUI
   Toute la logique métier (permissions, appels serveur) reste côté
   Lua (client/main.lua) ; ce fichier ne fait que du rendu + relais des
   clics vers 'admin:action' (voir fetchNui/act ci-dessous).
   ════════════════════════════════════════════════════════════════ */

const RES = 'lslegacy';

const state = {
    lvl: 0,
    duty: false,
    inSpec: false,
    tools: { godmode: false, invisible: false, showIds: false, showCoords: false, blips: false },
    players: {}, playersLoaded: false,
    selected: { id: null, name: null, data: null },
    bankInfo: null,
    warns: [],
    tickets: { open: [], taken: [], closed: [], avg: 'calcul...' },
    ticketSelected: { id: null, data: null },
    jobs: null, factions: null,
    pendingJobKey: null, pendingFactionKey: null,
    onlineStaff: [], staffLoaded: false,
    giveItems: [], giveWeapons: [],
    timePresets: [],
    timeFrozen: false,
};

let nav = [];               // pile d'écrans [{screen, ctx, label}]
let handlers = {};          // registre des callbacks de clic pour le rendu courant
let handlerSeq = 0;
let activePromptResolve = null;

/* ── Helpers DOM / util ──────────────────────────────────────── */
const $ = (sel) => document.querySelector(sel);
const el = (id) => document.getElementById(id);

function esc(v) {
    if (v === null || v === undefined) return '';
    return String(v)
        .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

function fmtDate(v) {
    if (!v) return '?';
    const s = String(v);
    const m = s.match(/^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2})/);
    if (m) return `${m[3]}/${m[2]}/${m[1]} ${m[4]}:${m[5]}`;
    const n = Number(v);
    if (!isNaN(n) && n > 0) {
        const d = new Date(n > 1e12 ? n : n * 1000);
        if (!isNaN(d.getTime())) {
            const p = (x) => String(x).padStart(2, '0');
            return `${p(d.getDate())}/${p(d.getMonth() + 1)}/${d.getFullYear()} ${p(d.getHours())}:${p(d.getMinutes())}`;
        }
    }
    return s;
}

function H(fn) { const id = 'h' + (handlerSeq++); handlers[id] = fn; return id; }
window.callH = function (id, val) { const fn = handlers[id]; if (fn) fn(val); };
window.filterList = function (q) {
    q = (q || '').toLowerCase().trim();
    document.querySelectorAll('#am-content .am-item[data-search]').forEach((e) => {
        e.style.display = !q || e.dataset.search.includes(q) ? '' : 'none';
    });
};

async function fetchNui(name, data) {
    try {
        const resp = await fetch(`https://${RES}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data || {}),
        });
        return await resp.json();
    } catch (e) { return null; }
}

async function act(type, payload) {
    const r = await fetchNui('admin:action', Object.assign({ type }, payload || {}));
    if (r && r.error) toast(r.error, 'err');
    return r;
}

/* ── Toasts ──────────────────────────────────────────────────── */
function toast(message, type) {
    const t = document.createElement('div');
    t.className = 'am-toast ' + (type || 'ok');
    t.textContent = message;
    el('am-toasts').appendChild(t);
    setTimeout(() => t.remove(), 3500);
}

/* ── Modale / prompts ────────────────────────────────────────── */
function openModal(title, bodyHtml, footerHtml) {
    el('am-modal-title').textContent = title;
    el('am-modal-body').innerHTML = bodyHtml;
    el('am-modal-footer').innerHTML = footerHtml || '';
    el('am-modal-overlay').classList.remove('am-hidden');
}
function closeModal() { el('am-modal-overlay').classList.add('am-hidden'); }

function cancelActivePrompt() {
    if (!activePromptResolve) return;
    const r = activePromptResolve;
    activePromptResolve = null;
    closeModal();
    r(null);
}

function promptFields(title, fields) {
    return new Promise((resolve) => {
        activePromptResolve = resolve;
        const body = fields.map((f, i) => `
            <div class="am-form-row">
                <label>${esc(f.label)}</label>
                <input class="am-input" id="am-pf-${i}" type="${f.numeric ? 'number' : 'text'}" maxlength="${f.maxlength || 120}" autocomplete="off">
            </div>`).join('');
        openModal(title, body, `
            <button class="am-btn" id="am-pf-cancel">Annuler</button>
            <button class="am-btn am-btn-primary" id="am-pf-ok">Valider</button>
        `);
        const finish = (val) => { activePromptResolve = null; closeModal(); resolve(val); };
        el('am-pf-cancel').onclick = () => finish(null);
        el('am-pf-ok').onclick = () => {
            const out = {};
            for (let i = 0; i < fields.length; i++) {
                const v = el('am-pf-' + i).value;
                if (v === '' || v === null) { finish(null); return; }
                out[fields[i].key] = v;
            }
            finish(out);
        };
        fields.forEach((f, i) => {
            el('am-pf-' + i).addEventListener('keydown', (e) => { if (e.key === 'Enter') el('am-pf-ok').click(); });
        });
        const first = el('am-pf-0'); if (first) first.focus();
    });
}

async function promptText(title, label, opts) {
    opts = opts || {};
    const r = await promptFields(title, [{ key: 'value', label, numeric: opts.numeric, maxlength: opts.maxlength }]);
    return r ? r.value : null;
}

/* ── Rendu générique (items / séparateurs / checkboxes) ────────── */
function setContent(html) { el('am-content').innerHTML = html; }

function item(opts) {
    const { label, desc, enabled = true, badge, badgeType = 'gray', onClick, danger = false, search } = opts;
    const id = onClick && enabled ? H(onClick) : null;
    const cls = 'am-item' + (!enabled ? ' am-item-disabled' : '') + (!onClick ? ' am-item-static' : '');
    const click = id ? ` onclick="callH('${id}')"` : '';
    const searchAttr = search ? ` data-search="${esc(String(search).toLowerCase())}"` : '';
    return `<div class="${cls}"${click}${searchAttr}>
        <div class="am-item-main">
            <div class="am-item-label"${danger ? ' style="color:var(--am-red)"' : ''}>${esc(label)}</div>
            ${desc ? `<div class="am-item-desc">${esc(desc)}</div>` : ''}
        </div>
        ${badge ? `<span class="am-badge am-badge-${badgeType}">${esc(badge)}</span>` : ''}
    </div>`;
}
function list(items) { return `<div class="am-list">${items.join('')}</div>`; }
function sep(text, warn) { return `<div class="am-separator${warn ? ' warn' : ''}">${esc(text)}</div>`; }
function empty(msg) { return `<div class="am-empty">${esc(msg)}</div>`; }

function checkItem(opts) {
    const { label, desc, checked, enabled = true, onChange } = opts;
    const id = H((val) => onChange(val));
    return `<label class="am-check-item ${!enabled ? 'am-item-disabled' : ''}">
        <div class="am-check-main">
            <div class="am-check-label">${esc(label)}</div>
            ${desc ? `<div class="am-check-desc">${esc(desc)}</div>` : ''}
        </div>
        <span class="am-switch">
            <input type="checkbox" ${checked ? 'checked' : ''} ${!enabled ? 'disabled' : ''} onchange="callH('${id}', this.checked)">
            <span class="am-switch-track"></span>
        </span>
    </label>`;
}

/* ── Navigation ──────────────────────────────────────────────── */
function pushScreen(screen, label, ctx) { nav.push({ screen, ctx: ctx || {}, label }); render(); }
function backLink(label, fn) { const id = H(fn); return `<div class="am-back" onclick="callH('${id}')">← ${esc(label)}</div>`; }

function render() {
    handlers = {}; handlerSeq = 0;
    const top = nav[nav.length - 1];
    if (!top) { setContent(''); renderSidebar(); return; }
    let html = '';
    if (nav.length > 1) html += backLink(nav[nav.length - 2].label, () => { nav.pop(); render(); });
    const renderer = SCREENS[top.screen];
    html += renderer ? renderer(top.ctx || {}) : empty('Section indisponible.');
    setContent(html);
    renderSidebar();
}

/* ── Sidebar ─────────────────────────────────────────────────── */
const SIDEBAR = [
    { id: 'players',     label: 'Joueurs',            requires: { duty: true } },
    { id: 'tickets',      label: 'Tickets / Support',  requires: { duty: true, lvl: 1 } },
    { id: 'vehicles',     label: 'Véhicules',          requires: { duty: true, lvl: 3 } },
    { id: 'server',       label: 'Monde / Serveur',    requires: { duty: true, lvl: 2 } },
    { id: 'economy',      label: 'Économie',           requires: { duty: true, lvl: 4 } },
    { id: 'tools',        label: 'Outils Staff',       requires: { lvl: 1 } },
    { id: 'staffOnline',  label: 'Staff en ligne',     requires: { lvl: 1 } },
];

function tabAllowed(t) {
    const r = t.requires || {};
    if (r.duty && !state.duty) return false;
    if (r.lvl && state.lvl < r.lvl) return false;
    return true;
}

function renderSidebar() {
    const root = nav[0] && nav[0].screen;
    el('am-sidebar').innerHTML = SIDEBAR.map((t) => {
        const allowed = tabAllowed(t);
        const active = root === t.id;
        return `<div class="am-tab ${active ? 'active' : ''} ${allowed ? '' : 'disabled'}" ${allowed ? `onclick="openTab('${t.id}')"` : ''}>
            <span>${esc(t.label)}</span>
        </div>`;
    }).join('');
}

function onEnterTab(id) {
    if (id === 'players') act('enterPlayers', {});
    else if (id === 'tickets') act('enterTickets', {});
    else if (id === 'staffOnline') act('enterStaffOnline', {});
}

window.openTab = function (id) {
    const tab = SIDEBAR.find((t) => t.id === id);
    if (!tab || !tabAllowed(tab)) return;
    nav = [{ screen: id, ctx: {}, label: tab.label }];
    onEnterTab(id);
    render();
};

function renderHeader() {
    const flag = el('am-duty-flag');
    flag.textContent = state.duty ? 'En service' : 'Hors service';
    flag.classList.toggle('on', state.duty);
}

/* ════════════════════════════════════════════════════════════════
   ÉCRANS
   ════════════════════════════════════════════════════════════════ */
const SCREENS = {};

/* ── Joueurs ─────────────────────────────────────────────────── */
SCREENS.players = function () {
    let html = `<div class="am-page-title">Joueurs connectés</div>`;
    if (!state.duty) html += `<div class="am-separator warn">Vous n'êtes pas en service</div>`;
    html += `<div class="am-searchbar"><input class="am-input" placeholder="Filtrer un joueur..." oninput="filterList(this.value)"></div>`;
    if (!state.playersLoaded) { html += empty('Chargement...'); return html; }
    const players = Object.values(state.players || {}).filter((p) => p && p.source != null && p.characterInfos);
    if (!players.length) { html += empty('Aucun joueur.'); return html; }
    html += list(players.map((p) => {
        const name = `${p.characterInfos.Prenom} ${p.characterInfos.NDF}`;
        return item({ label: `(${p.source}) ${name}`, search: `(${p.source}) ${name}`, onClick: () => selectPlayer(p.source) });
    }));
    return html;
};

async function selectPlayer(source) {
    const r = await act('selectPlayer', { source });
    if (!r || !r.ok) return;
    if (r.selected) state.selected = r.selected;
    state.bankInfo = null;
    if (r.nav === 'economy') nav = [{ screen: 'economy', ctx: {}, label: 'Économie' }];
    else nav.push({ screen: 'playerActions', ctx: {}, label: 'Joueur' });
    render();
}

/* ── Fiche joueur ────────────────────────────────────────────── */
SCREENS.playerActions = function () {
    let html = '';
    if (state.selected.id != null) html += sep(`(${state.selected.id}) ${state.selected.name || ''}`);
    html += list([
        item({ label: 'Informations', badge: '›', onClick: () => pushScreen('playerInfo', 'Informations') }),
        item({ label: 'Véhicule joueur', enabled: state.lvl >= 3, badge: '›', onClick: () => pushScreen('playerVehicle', 'Véhicule joueur') }),
        item({ label: 'Sanctions', enabled: state.lvl >= 2, badge: '›', onClick: () => pushScreen('playerSanction', 'Sanctions') }),
    ]);
    return html;
};

SCREENS.playerInfo = function () {
    const d = state.selected.data;
    const ci = d && d.characterInfos;
    const sel = state.selected.id != null;
    let html = `<div class="am-page-title">Informations joueur</div>`;
    const rows = [item({ label: `ID serveur : ${state.selected.id != null ? state.selected.id : '?'}` })];
    if (ci) {
        rows.push(item({ label: `Prénom : ${ci.Prenom || '?'}` }));
        rows.push(item({ label: `Nom : ${ci.NDF || '?'}` }));
        if (ci.DDN) rows.push(item({ label: `Naissance : ${ci.DDN}` }));
    }
    if (d) {
        if (sel) {
            rows.push(item({ label: 'Envoyer identifiers (Discord)', enabled: state.lvl >= 3, onClick: () => act('logIdentifiers', {}) }));
        }
        rows.push(item({ label: `Job : ${d.jobLabel || d.job || 'N/A'}` }));
        rows.push(item({ label: `Grade job : ${d.jobGradeLabel || '?'}` }));
        rows.push(item({ label: `Faction : ${d.factionLabel || d.faction || 'N/A'}` }));
        rows.push(item({ label: `Grade faction : ${d.factionGradeLabel || '?'}` }));
        rows.push(item({ label: `Cash : ${d.cash || 0}$` }));
        if (state.bankInfo === null) {
            rows.push(item({ label: 'Compte courant : chargement...' }));
        } else if (state.bankInfo.hasAccount) {
            rows.push(item({ label: `Compte courant : ${state.bankInfo.balance}$` }));
        } else {
            rows.push(item({ label: 'Compte courant : aucun' }));
        }
        let c = d.coords;
        if (typeof c === 'string') { try { c = JSON.parse(c); } catch (e) { c = null; } }
        if (c) rows.push(item({ label: `Coords : ${(c.x || 0).toFixed(1)}, ${(c.y || 0).toFixed(1)}, ${(c.z || 0).toFixed(1)}` }));
    }
    rows.push(item({ label: `Warns : ${state.warns.length}` }));
    html += list(rows);
    html += sep('Actions');
    html += list([
        item({ label: "Voir l'inventaire", enabled: state.lvl >= 2 && sel, onClick: () => act('viewInventory', {}) }),
        item({ label: 'TP vers joueur', enabled: state.lvl >= 2 && sel, onClick: () => act('tpToPlayer', {}) }),
        item({ label: 'Téléporter joueur vers soi', enabled: state.lvl >= 2 && sel, onClick: () => act('bringPlayer', {}) }),
        item({ label: 'Freeze joueur', enabled: state.lvl >= 2 && sel, onClick: () => act('freezePlayer', { state: true }) }),
        item({ label: 'Unfreeze joueur', enabled: state.lvl >= 2 && sel, onClick: () => act('freezePlayer', { state: false }) }),
        item({ label: 'Spectate', enabled: state.lvl >= 1 && sel, onClick: () => act('spectatePlayer', {}) }),
        item({ label: 'Soigner (Heal)', enabled: state.lvl >= 2 && sel, onClick: () => act('healPlayer', {}) }),
        item({ label: 'Réanimer (Revive)', enabled: state.lvl >= 2 && sel, onClick: () => act('revivePlayer', {}) }),
        item({ label: 'Reset faim / soif', enabled: state.lvl >= 2 && sel, onClick: () => act('resetNeeds', {}) }),
        item({ label: 'Reset skin (création perso)', enabled: state.lvl >= 3 && sel, onClick: () => act('resetSkin', {}) }),
    ]);
    return html;
};

SCREENS.playerVehicle = function () {
    const sel = state.selected.id != null;
    return list([
        item({ label: 'Réparer le véhicule', enabled: state.lvl >= 3 && sel, onClick: () => act('repairVehicle', {}) }),
        item({ label: 'Supprimer le véhicule', enabled: state.lvl >= 3 && sel, danger: true, onClick: () => act('deletePlayerVehicle', {}) }),
        item({
            label: 'Spawn un véhicule (AP)', enabled: state.lvl >= 3 && sel, onClick: async () => {
                const model = await promptText('Spawn véhicule', 'Nom du modèle (ex: adder)', { maxlength: 50 });
                if (!model) return;
                await act('spawnVehicleForPlayer', { model });
            }
        }),
    ]);
};

SCREENS.playerSanction = function () {
    const sel = state.selected.id != null;
    let html = sep(`Warns : ${state.warns.length}`);
    html += list([
        item({
            label: 'Warn', enabled: state.lvl >= 2 && sel, onClick: async () => {
                const reason = await promptText('Avertissement', 'Raison du warn', { maxlength: 120 });
                if (!reason) return;
                await act('warnPlayer', { reason });
            }
        }),
        item({ label: `Gérer les warns (${state.warns.length})`, enabled: state.lvl >= 4 && sel && state.warns.length > 0, badge: '›', onClick: () => pushScreen('warnsList', 'Warns') }),
        item({
            label: 'Kick', enabled: state.lvl >= 2 && sel, onClick: async () => {
                const reason = await promptText('Kick', 'Raison du kick', { maxlength: 120 });
                if (!reason) return;
                await act('kickPlayer', { reason });
            }
        }),
        item({
            label: 'Tempban', enabled: state.lvl >= 3 && sel, onClick: async () => {
                const f = await promptFields('Tempban', [
                    { key: 'hours', label: 'Durée (heures)', numeric: true, maxlength: 5 },
                    { key: 'reason', label: 'Raison', maxlength: 120 },
                ]);
                if (!f) return;
                await act('tempbanPlayer', { hours: f.hours, reason: f.reason });
            }
        }),
        item({
            label: 'Ban permanent', enabled: state.lvl >= 4 && sel, danger: true, onClick: async () => {
                const reason = await promptText('Ban permanent', 'Raison du ban permanent', { maxlength: 120 });
                if (!reason) return;
                await act('permabanPlayer', { reason });
            }
        }),
        item({ label: 'Screenshot joueur', enabled: state.lvl >= 2 && sel, onClick: () => act('screenshotPlayer', {}) }),
    ]);
    return html;
};

SCREENS.warnsList = function () {
    if (!state.warns.length) return empty('Aucun warn enregistré');
    return list(state.warns.map((w) => item({
        label: `#${w.id} – ${w.reason || '?'}`,
        desc: `Par : ${w.staff_name || '?'} | ${fmtDate(w.created_at)}`,
        enabled: state.lvl >= 4,
        danger: true,
        onClick: () => act('deleteWarn', { warnId: w.id }),
    })));
};

/* ── Tickets ─────────────────────────────────────────────────── */
SCREENS.tickets = function () {
    let html = sep(`Moy. traitement (aujourd'hui) : ${state.tickets.avg || 'calcul...'}`);
    html += list([
        item({ label: `Tickets ouverts (${state.tickets.open.length})`, enabled: state.lvl >= 1, badge: '›', onClick: () => { act('openTickets', { status: 'open' }); pushScreen('ticketsOpen', 'Tickets ouverts'); } }),
        item({ label: `Tickets pris (${state.tickets.taken.length})`, enabled: state.lvl >= 1, badge: '›', onClick: () => { act('openTickets', { status: 'taken' }); pushScreen('ticketsTaken', 'Tickets pris'); } }),
        item({ label: `Historique (${state.tickets.closed.length})`, enabled: state.lvl >= 2, badge: '›', onClick: () => { act('openTickets', { status: 'closed' }); pushScreen('ticketsHistory', 'Historique'); } }),
        item({ label: 'Actions rapides', enabled: state.ticketSelected.id != null && state.lvl >= 1, badge: '›', onClick: () => pushScreen('ticketActions', 'Actions rapides') }),
    ]);
    return html;
};

function ticketRow(t, showClosed) {
    let desc = t.subject || '';
    if (showClosed) desc = `${t.subject || '?'} | Créé : ${fmtDate(t.created_at)}` + (t.closed_at ? ` | Fermé : ${fmtDate(t.closed_at)}` : '');
    else if (t.assigned_name) desc += ` [${t.assigned_name}]`;
    return item({
        label: `#${t.id} – ${t.player_name || '?'}`,
        desc,
        onClick: () => {
            state.ticketSelected = { id: t.id, data: t };
            if (!showClosed) toast(`Ticket #${t.id} sélectionné.`, 'ok');
        },
    });
}
SCREENS.ticketsOpen = function () {
    if (!state.tickets.open.length) return empty('Aucun ticket ouvert');
    return list(state.tickets.open.map((t) => ticketRow(t, false)));
};
SCREENS.ticketsTaken = function () {
    if (!state.tickets.taken.length) return empty('Aucun ticket pris');
    return list(state.tickets.taken.map((t) => ticketRow(t, false)));
};
SCREENS.ticketsHistory = function () {
    if (!state.tickets.closed.length) return empty('Aucun ticket fermé');
    return list(state.tickets.closed.map((t) => ticketRow(t, true)));
};
SCREENS.ticketActions = function () {
    const hasTicket = state.ticketSelected.id != null;
    const ticketId = state.ticketSelected.id;
    let html = hasTicket ? sep(`Ticket #${ticketId}`) : '';
    html += list([
        item({ label: 'TP vers joueur ticket', enabled: hasTicket && state.lvl >= 1, onClick: () => act('tpToTicket', { ticketId }) }),
        item({ label: 'Bring joueur ticket', enabled: hasTicket && state.lvl >= 1, onClick: () => act('bringTicketPlayer', { ticketId }) }),
        item({
            label: 'Message rapide', enabled: hasTicket && state.lvl >= 1 && !!(state.ticketSelected.data && state.ticketSelected.data.player_id), onClick: async () => {
                const msg = await promptText('Message rapide', 'Message au joueur', { maxlength: 120 });
                if (!msg) return;
                await act('messageTicketPlayer', { playerId: state.ticketSelected.data.player_id, msg });
            }
        }),
        item({ label: 'Prendre le ticket', enabled: hasTicket && state.lvl >= 1, onClick: () => act('takeTicket', { ticketId }) }),
        item({
            label: 'Fermer le ticket', enabled: hasTicket && state.lvl >= 1, danger: true, onClick: async () => {
                await act('closeTicket', { ticketId });
                state.ticketSelected = { id: null, data: null };
                render();
            }
        }),
    ]);
    return html;
};

/* ── Véhicules (admin) ───────────────────────────────────────── */
SCREENS.vehicles = function () {
    return list([
        item({
            label: 'Spawn un véhicule (AP)', enabled: state.lvl >= 3, onClick: async () => {
                const model = await promptText('Spawn véhicule', 'Nom du modèle (ex: adder)', { maxlength: 50 });
                if (!model) return;
                await act('spawnVehicle', { model });
            }
        }),
        item({ label: 'Supprimer véhicules zone (50m)', enabled: state.lvl >= 3, onClick: () => act('deleteVehiclesZone', { radius: 50.0 }) }),
        item({ label: 'Supprimer véhicules zone (150m)', enabled: state.lvl >= 4, danger: true, onClick: () => act('deleteVehiclesZone', { radius: 150.0 }) }),
    ]);
};

/* ── Monde / Serveur ─────────────────────────────────────────── */
// Réservé à l'heure : la météo est désormais gérée exclusivement par
// codem-dynamicweather (son propre panneau /weatherpanel).
SCREENS.server = function () {
    return list([
        item({ label: 'Heure', enabled: state.lvl >= 2, badge: '›', onClick: () => pushScreen('time', 'Heure') }),
    ]);
};
SCREENS.time = function () {
    let html = checkItem({
        label: 'Geler l\'horloge',
        desc: 'Indépendant de la météo dynamique : fige l\'heure in-game sur sa valeur actuelle.',
        checked: state.timeFrozen,
        enabled: state.lvl >= 2,
        onChange: (val) => act('toggleTimeFrozen', { state: val }),
    });
    const rows = (state.timePresets || []).map((p) => item({ label: p.label, enabled: state.lvl >= 2, onClick: () => act('setTime', { h: p.h, m: p.m }) }));
    rows.push(item({
        label: 'Heure personnalisée...', enabled: state.lvl >= 2, onClick: async () => {
            const f = await promptFields('Heure personnalisée', [
                { key: 'h', label: 'Heure (0-23)', numeric: true, maxlength: 2 },
                { key: 'm', label: 'Minutes (0-59)', numeric: true, maxlength: 2 },
            ]);
            if (!f) return;
            await act('setTime', { h: Number(f.h) || 0, m: Number(f.m) || 0 });
        }
    }));
    return html + sep('Réglage manuel') + list(rows);
};

/* ── Économie ────────────────────────────────────────────────── */
SCREENS.economy = function () {
    const target = state.selected.id != null ? `(${state.selected.id}) ${state.selected.name || ''}` : 'Aucune';
    let html = sep('Cible : ' + target);
    const hasTarget = state.selected.id != null && state.lvl >= 4;
    html += list([
        item({
            label: 'Choisir une cible → liste joueurs', onClick: async () => {
                await act('ecoSelectTarget', {});
                nav = [{ screen: 'players', ctx: {}, label: 'Joueurs' }];
                onEnterTab('players');
                render();
            }
        }),
        item({ label: 'Give argent (cash)', enabled: hasTarget, onClick: () => moneyPrompt(false, false) }),
        item({ label: 'Remove argent (cash)', enabled: hasTarget, danger: true, onClick: () => moneyPrompt(true, false) }),
        item({ label: 'Add compte courant bancaire', enabled: hasTarget, onClick: () => moneyPrompt(false, true) }),
        item({ label: 'Remove compte courant bancaire', enabled: hasTarget, danger: true, onClick: () => moneyPrompt(true, true) }),
        item({ label: 'Give item', enabled: hasTarget, badge: '›', onClick: () => pushScreen('giveItem', 'Give item') }),
        item({ label: 'Give arme', enabled: hasTarget, badge: '›', onClick: () => pushScreen('giveWeapon', 'Give arme') }),
        item({ label: 'Changer job', enabled: hasTarget, badge: '›', onClick: async () => { await act('loadJobsFactions', {}); pushScreen('changeJob', 'Changer job'); } }),
        item({ label: 'Changer faction', enabled: hasTarget, badge: '›', onClick: async () => { await act('loadJobsFactions', {}); pushScreen('changeFaction', 'Changer faction'); } }),
    ]);
    return html;
};
async function moneyPrompt(remove, bank) {
    const label = (remove ? 'Montant à retirer' : 'Montant') + (bank ? ' — compte courant ($)' : ' ($)');
    const title = bank ? (remove ? 'Remove compte courant' : 'Add compte courant') : (remove ? 'Remove argent' : 'Give argent');
    const amount = await promptText(title, label, { numeric: true, maxlength: 10 });
    if (!amount) return;
    await act(remove ? 'removeMoney' : 'giveMoney', { amount: Number(amount), bank });
}

SCREENS.giveItem = function () {
    const sel = state.selected.id != null;
    let html = sep('Cible : ' + (sel ? `(${state.selected.id}) ${state.selected.name || ''}` : 'Aucune'));
    html += `<div class="am-searchbar"><input class="am-input" placeholder="Filtrer..." oninput="filterList(this.value)"></div>`;
    html += list((state.giveItems || []).map((it) => item({
        label: it.label, search: it.label, enabled: sel,
        onClick: async () => {
            const qty = await promptText('Quantité', 'Quantité : ' + it.label, { numeric: true, maxlength: 5 });
            if (!qty || Number(qty) <= 0) return;
            await act('giveItem', { name: it.name, qty: Number(qty) });
        },
    })));
    return html;
};
SCREENS.giveWeapon = function () {
    const sel = state.selected.id != null;
    let html = sep('Cible : ' + (sel ? `(${state.selected.id}) ${state.selected.name || ''}` : 'Aucune'));
    html += `<div class="am-searchbar"><input class="am-input" placeholder="Filtrer..." oninput="filterList(this.value)"></div>`;
    html += list((state.giveWeapons || []).map((w) => item({
        label: w.label, desc: w.desc, search: w.label, enabled: sel,
        onClick: async () => {
            const ammo = await promptText('Munitions', 'Munitions : ' + w.label, { numeric: true, maxlength: 5 });
            await act('giveWeapon', { name: w.name, ammo: ammo ? Number(ammo) : 50 });
        },
    })));
    return html;
};

SCREENS.changeJob = function () {
    const sel = state.selected.id != null;
    let html = sep('Cible : ' + (sel ? `(${state.selected.id}) ${state.selected.name || ''}` : 'Aucune'));
    if (!state.jobs) return html + empty('Chargement...');
    const sorted = Object.keys(state.jobs).map((k) => ({ key: k, label: state.jobs[k].label })).sort((a, b) => a.label.localeCompare(b.label));
    html += `<div class="am-searchbar"><input class="am-input" placeholder="Filtrer..." oninput="filterList(this.value)"></div>`;
    html += list(sorted.map((j) => item({
        label: j.label, search: j.label, enabled: sel, badge: '›',
        onClick: () => { state.pendingJobKey = j.key; pushScreen('changeJobGrade', 'Grade'); },
    })));
    return html;
};
SCREENS.changeJobGrade = function () {
    const job = state.pendingJobKey && state.jobs && state.jobs[state.pendingJobKey];
    let html = sep('Job : ' + (job ? job.label : '?'));
    if (!job) return html;
    const grades = Object.keys(job.grades).map((g) => ({ key: Number(g), label: job.grades[g].label })).sort((a, b) => a.key - b.key);
    html += list(grades.map((g) => item({
        label: `${g.key} - ${g.label}`, enabled: state.selected.id != null,
        onClick: () => act('setPlayerJob', { jobKey: state.pendingJobKey, gradeKey: g.key }),
    })));
    return html;
};
SCREENS.changeFaction = function () {
    const sel = state.selected.id != null;
    let html = sep('Cible : ' + (sel ? `(${state.selected.id}) ${state.selected.name || ''}` : 'Aucune'));
    if (!state.factions) return html + empty('Chargement...');
    const sorted = Object.keys(state.factions).map((k) => ({ key: k, label: state.factions[k].label })).sort((a, b) => a.label.localeCompare(b.label));
    html += `<div class="am-searchbar"><input class="am-input" placeholder="Filtrer..." oninput="filterList(this.value)"></div>`;
    html += list(sorted.map((f) => item({
        label: f.label, search: f.label, enabled: sel, badge: '›',
        onClick: () => { state.pendingFactionKey = f.key; pushScreen('changeFactionGrade', 'Grade'); },
    })));
    return html;
};
SCREENS.changeFactionGrade = function () {
    const faction = state.pendingFactionKey && state.factions && state.factions[state.pendingFactionKey];
    let html = sep('Faction : ' + (faction ? faction.label : '?'));
    if (!faction) return html;
    const grades = Object.keys(faction.grades).map((g) => ({ key: Number(g), label: faction.grades[g].label })).sort((a, b) => a.key - b.key);
    html += list(grades.map((g) => item({
        label: `${g.key} - ${g.label}`, enabled: state.selected.id != null,
        onClick: () => act('setPlayerFaction', { factionKey: state.pendingFactionKey, gradeKey: g.key }),
    })));
    return html;
};

/* ── Outils Staff ────────────────────────────────────────────── */
SCREENS.tools = function () {
    const duty = state.duty;
    let html = checkItem({ label: 'Prise de service (Staff)', desc: 'Requis pour le NoClip et le ciblage rapide (ox_target) sur les joueurs.', checked: state.duty, enabled: state.lvl >= 1, onChange: (val) => act('toggleDuty', { state: val }) });
    html += checkItem({ label: 'NoClip / Spectate', checked: state.inSpec, enabled: duty && state.lvl >= 1, onChange: (val) => act('toggleNoclip', { state: val }) });
    html += checkItem({ label: 'Invisible', checked: state.tools.invisible, enabled: duty && state.lvl >= 2, onChange: (val) => act('toggleInvisible', { state: val }) });
    html += checkItem({ label: 'Godmode', checked: state.tools.godmode, enabled: duty && state.lvl >= 3, onChange: (val) => act('toggleGodmode', { state: val }) });
    html += checkItem({ label: 'Afficher IDs joueurs', checked: state.tools.showIds, enabled: duty && state.lvl >= 1, onChange: (val) => act('toggleShowIds', { state: val }) });
    html += checkItem({ label: 'Afficher les coords (HUD)', checked: state.tools.showCoords, enabled: duty && state.lvl >= 1, onChange: (val) => act('toggleShowCoords', { state: val }) });
    html += checkItem({ label: 'Blips joueurs', checked: state.tools.blips, enabled: duty && state.lvl >= 2, onChange: (val) => act('toggleBlips', { state: val }) });
    html += sep('Navigation');
    html += list([
        item({ label: 'TP au marqueur', enabled: duty && state.lvl >= 2, onClick: () => act('tpMarker', {}) }),
        item({ label: 'Afficher ma position', enabled: duty && state.lvl >= 1, onClick: () => act('showMyPos', {}) }),
    ]);
    html += sep('Multicharacter');
    html += list([
        item({ label: 'Retour à la sélection de personnage', enabled: state.lvl >= 1, onClick: () => act('returnToCharSelect', {}) }),
    ]);
    return html;
};

/* ── Staff en ligne ──────────────────────────────────────────── */
SCREENS.staffOnline = function () {
    if (!state.staffLoaded) return empty('Chargement...');
    if (!state.onlineStaff.length) return empty('Aucun staff connecté (hors vous).');
    return list(state.onlineStaff.map((s) => item({
        label: `${s.onDuty ? '● En service' : '○ Hors service'} — (${s.id}) ${s.rpName || s.steamName || ('ID ' + s.id)}`,
        desc: `Steam : ${s.steamName || '?'} • Grade : ${s.group || '?'}`,
    })));
};

/* ════════════════════════════════════════════════════════════════
   Ouverture / fermeture / bridge messages
   ════════════════════════════════════════════════════════════════ */
function openAdmin(payload) {
    state.lvl = payload.lvl || 0;
    state.duty = !!payload.duty;
    state.tools = payload.tools || state.tools;
    state.inSpec = !!payload.inSpec;
    state.giveItems = payload.giveItems || [];
    state.giveWeapons = payload.giveWeapons || [];
    state.timePresets = payload.timePresets || [];
    state.timeFrozen = !!payload.timeFrozen;
    if (payload.selected) state.selected = payload.selected;
    if (payload.openTo) state.bankInfo = null;

    el('admin').classList.remove('am-hidden');
    renderHeader();

    if (payload.openTo === 'playerActions') {
        nav = [{ screen: 'players', ctx: {}, label: 'Joueurs' }, { screen: 'playerActions', ctx: {}, label: 'Joueur' }];
        render();
        return;
    }
    const first = SIDEBAR.find((t) => tabAllowed(t));
    if (first) window.openTab(first.id); else render();
}

function hideAdmin() {
    el('admin').classList.add('am-hidden');
    cancelActivePrompt();
    closeModal();
}

function closeAdmin() {
    fetchNui('admin:close', {});
    hideAdmin();
}

const STATE_DEPS = {
    players: ['players'],
    selected: ['playerActions', 'playerInfo', 'playerVehicle', 'playerSanction', 'warnsList', 'economy', 'giveItem', 'giveWeapon', 'changeJob', 'changeJobGrade', 'changeFaction', 'changeFactionGrade'],
    warns: ['playerSanction', 'warnsList', 'playerInfo'],
    bankInfo: ['playerInfo'],
    tickets: ['tickets', 'ticketsOpen', 'ticketsTaken', 'ticketsHistory'],
    jobsFactions: ['changeJob', 'changeFaction'],
    onlineStaff: ['staffOnline'],
    tools: ['tools'],
    duty: ['tools'],
    inSpec: ['tools'],
    timeFrozen: ['time'],
};

function applyState(key, data) {
    switch (key) {
        case 'players': state.players = data || {}; state.playersLoaded = true; break;
        case 'selected': state.selected = data || { id: null, name: null, data: null }; break;
        case 'warns': state.warns = data || []; break;
        case 'bankInfo': state.bankInfo = data || { hasAccount: false, balance: 0 }; break;
        case 'tickets': state.tickets = data || { open: [], taken: [], closed: [], avg: state.tickets.avg }; break;
        case 'jobsFactions': state.jobs = (data && data.jobs) || {}; state.factions = (data && data.factions) || {}; break;
        case 'onlineStaff': state.onlineStaff = data || []; state.staffLoaded = true; break;
        case 'tools': state.tools = Object.assign({}, state.tools, data || {}); break;
        case 'duty': state.duty = !!data; break;
        case 'inSpec': state.inSpec = !!data; break;
        case 'timeFrozen': state.timeFrozen = !!data; break;
        default: return;
    }
    renderHeader();
    const top = nav[nav.length - 1];
    const deps = STATE_DEPS[key] || [];
    if (top && deps.includes(top.screen)) render();
    else renderSidebar();
}

window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data || !data.action) return;
    if (data.action === 'admin:open') openAdmin(data.data || {});
    else if (data.action === 'admin:hide') hideAdmin();
    else if (data.action === 'admin:state') applyState(data.key, data.data);
});

/* ── Listeners globaux ───────────────────────────────────────── */
el('am-close').addEventListener('click', closeAdmin);
el('am-modal-close').addEventListener('click', cancelActivePrompt);
el('am-modal-overlay').addEventListener('click', (e) => { if (e.target === el('am-modal-overlay')) cancelActivePrompt(); });

document.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape') return;
    if (!el('am-modal-overlay').classList.contains('am-hidden')) cancelActivePrompt();
    else if (!el('admin').classList.contains('am-hidden')) closeAdmin();
});
