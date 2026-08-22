/* ════════════════════════════════════════════════════════════════
   Banque — Noyau NUI : état global, communication Lua, routeur de
   vues. Les fichiers js/views/*.js ne font que du rendu ; toute la
   logique métier (validations, calculs, BDD) vit côté serveur
   (module/bank/server/main.lua), comme le reste de ce module.
   ════════════════════════════════════════════════════════════════ */

const RES = 'lslegacy';

const BankState = {
    mode: 'branch',       // 'branch' | 'atm'
    theme: 'mazebank',
    displayName: 'Maze Bank',
    isAdmin: false,
    accounts: [],
    livrets: [],
    atmAccountId: null,
    adminRates: null,
    adminCardTiers: null,
    view: 'dashboard',
    viewCtx: null,
};

window.BankViews = window.BankViews || {};

let bankHandlers = {};
let bankHandlerSeq = 0;
function H(fn) { const id = 'h' + (bankHandlerSeq++); bankHandlers[id] = fn; return id; }
window.callH = function (id, val) { const fn = bankHandlers[id]; if (fn) fn(val); };

function el(id) { return document.getElementById(id); }

function esc(v) {
    if (v === null || v === undefined) return '';
    return String(v)
        .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

function fmtMoney(n) {
    n = Number(n) || 0;
    const sign = n < 0 ? '-' : '';
    const abs = Math.abs(Math.round(n * 100) / 100);
    return sign + abs.toLocaleString('fr-FR', { maximumFractionDigits: 2 }) + ' $';
}

function fmtDate(v) {
    if (!v) return '?';
    const s = String(v);
    const m = s.match(/^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2})/);
    if (m) return `${m[3]}/${m[2]}/${m[1]} ${m[4]}:${m[5]}`;
    return s;
}

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

function toast(message, type) {
    const t = document.createElement('div');
    t.className = 'bank-toast' + (type === 'error' ? ' err' : '');
    t.textContent = message;
    el('bankToasts').appendChild(t);
    setTimeout(() => t.remove(), 3800);
}

/* ── Comptes / helpers dérivés ───────────────────────────────── */

function getCourantAccount() {
    return BankState.accounts.find(a => a.courant) || BankState.accounts[0] || null;
}

function getAccountById(id) {
    return BankState.accounts.find(a => Number(a.id) === Number(id)) || null;
}

function tierLabel(tier) {
    if (tier === 'premier') return 'Premier';
    if (tier === 'platinum') return 'Platinum';
    return 'Standard';
}

// Les plafonds sont cumulatifs sur une période (pas une limite par
// transaction) : on affiche "consommé / plafond" avec le reste disponible.
function ceilingLine(label, spent, limit) {
    spent = Number(spent) || 0;
    limit = Number(limit) || 0;
    const remaining = Math.max(0, limit - spent);
    const pct = limit > 0 ? Math.min(100, Math.round((spent / limit) * 100)) : 0;
    return `
        <div style="margin-bottom:10px;">
            <div style="display:flex;justify-content:space-between;font-size:12px;color:var(--bank-text-dim);margin-bottom:4px;">
                <span>${esc(label)}</span>
                <span>${fmtMoney(spent)} / ${fmtMoney(limit)}</span>
            </div>
            <div style="height:6px;border-radius:4px;background:var(--bank-surface-2);overflow:hidden;">
                <div style="height:100%;width:${pct}%;background:var(--bank-accent);"></div>
            </div>
            <div style="font-size:11px;color:var(--bank-text-faint);margin-top:3px;">${fmtMoney(remaining)} restants sur la période en cours</div>
        </div>
    `;
}

function tierBadgeClass(tier) {
    if (tier === 'premier') return 'bank-badge-green';
    if (tier === 'platinum') return 'bank-badge-gold';
    return 'bank-badge-gray';
}

/* ── Routeur ─────────────────────────────────────────────────── */

function showView(view, ctx) {
    BankState.view = view;
    BankState.viewCtx = ctx || null;
    render();
}

function render() {
    bankHandlers = {};
    bankHandlerSeq = 0;

    const backBtn = el('bankBackBtn');
    if (BankState.mode === 'atm') {
        backBtn.classList.add('bank-hidden');
    } else if (BankState.view === 'dashboard') {
        backBtn.classList.add('bank-hidden');
    } else {
        backBtn.classList.remove('bank-hidden');
    }

    const content = el('bankContent');
    content.innerHTML = '';

    if (BankState.mode === 'atm') {
        window.BankViews.atm(content);
        return;
    }

    const renderer = window.BankViews[BankState.view] || window.BankViews.dashboard;
    renderer(content, BankState.viewCtx);
}

function refreshCurrentView() {
    render();
}

/* ── Ouverture / fermeture ──────────────────────────────────── */

function applyOpenPayload(data) {
    BankState.mode = data.mode || 'branch';
    BankState.theme = data.theme || 'mazebank';
    BankState.displayName = data.displayName || 'Maze Bank';
    BankState.isAdmin = !!data.isAdmin;
    BankState.accounts = data.accounts || [];
    BankState.livrets = data.livrets || [];
    if (data.adminRates) BankState.adminRates = data.adminRates;
    if (data.adminCardTiers) BankState.adminCardTiers = data.adminCardTiers;
    BankState.atmAccountId = data.atmAccountId || null;
    BankState.view = BankState.mode === 'atm' ? 'atm' : 'dashboard';
    BankState.viewCtx = null;

    const root = el('bank-root');
    root.dataset.theme = BankState.theme;
    el('bankLogoMark').textContent = BankState.displayName.charAt(0).toUpperCase();
    el('bankBrandName').textContent = BankState.displayName;

    const courant = getCourantAccount();
    el('bankBrandSub').textContent = courant ? ('IBAN ' + courant.iban) : 'Aucun compte courant';

    root.classList.remove('bank-hidden');
    render();
}

window.addEventListener('message', function (event) {
    const data = event.data;
    if (!data || !data.action) return;

    switch (data.action) {
        case 'bank:open':
            applyOpenPayload(data);
            break;
        case 'bank:hide':
            el('bank-root').classList.add('bank-hidden');
            break;
        case 'bank:accounts':
            BankState.accounts = data.accounts || [];
            if (!el('bank-root').classList.contains('bank-hidden')) {
                const courant = getCourantAccount();
                el('bankBrandSub').textContent = courant ? ('IBAN ' + courant.iban) : 'Aucun compte courant';
                refreshCurrentView();
            }
            break;
        case 'bank:livrets':
            BankState.livrets = data.livrets || [];
            if (!el('bank-root').classList.contains('bank-hidden')) refreshCurrentView();
            break;
        case 'bank:adminRates':
            BankState.adminRates = data.rates || null;
            if (!el('bank-root').classList.contains('bank-hidden')) refreshCurrentView();
            break;
        case 'bank:adminCardTiers':
            BankState.adminCardTiers = data.tiers || null;
            if (!el('bank-root').classList.contains('bank-hidden')) refreshCurrentView();
            break;
    }
});

el('bankCloseBtn').addEventListener('click', function () {
    fetchNui('bank:close', {});
    el('bank-root').classList.add('bank-hidden');
});

el('bankBackBtn').addEventListener('click', function () {
    showView('dashboard');
});

document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape' && !el('bank-root').classList.contains('bank-hidden')) {
        fetchNui('bank:close', {});
        el('bank-root').classList.add('bank-hidden');
    }
});
