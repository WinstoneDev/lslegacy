/* ════════════════════════════════════════════════════════════════
   MDT — Tableau de bord Kebab King
   ────────────────────────────────────────────────────────────────
   Chargé APRÈS dashboard.js, dont il récupère le rendu déjà enregistré
   (le dashboard "forces de l'ordre") pour laisser les autres
   départements inchangés — même mécanique que dashboard.js vis-à-vis
   de medical.js. Partagé avec Burger Shot (voir registerRestoDashboard
   plus bas) : même concept "resto", pas de raison de dupliquer le fichier.
   Réutilise les helpers globaux de mdt.js (esc,
   setContent, emptyState, fetchNui, el, b, selectTab) et les classes
   CSS déjà posées par dashboard.css (dash-stats, dash-card, dash-quick,
   mdt-badge…) : aucun style spécifique n'est nécessaire.

   Pas de concept policier ici (avis de recherche, garde à vue…) : juste
   l'effectif en service et l'état réel des stocks/coffre, lus dans les
   DataStores du restaurant (voir readHandlers.getRestoDashboard,
   module/mdt/server/main.lua).
   ════════════════════════════════════════════════════════════════ */

function kkDutyRow(a) {
    return `
        <div class="dash-duty-row">
            <span class="dash-dot"></span>
            <span class="dash-duty-name">${esc(a.name || '—')}</span>
            <span class="dash-duty-grade">${esc(a.gradeLabel || '')}</span>
        </div>`;
}

/* Couleur du badge selon le taux de remplissage d'un stockage. */
function kkStockBadgeClass(weight, maxWeight) {
    if (!maxWeight) return 'mdt-badge-gray';
    const ratio = weight / maxWeight;
    if (ratio >= 0.9) return 'mdt-badge-red';
    if (ratio >= 0.7) return 'mdt-badge-orange';
    return 'mdt-badge-green';
}

function kkMoney(n) {
    return (typeof n === 'number' ? n : 0).toLocaleString('fr-FR') + ' $';
}

async function renderRestoDashboard() {
    setContent(`
        <div class="mdt-page-title">Tableau de bord</div>
        <div class="mdt-page-sub">${esc((state.payload && state.payload.departmentLabel) || '')} — vue d'ensemble du restaurant.</div>
        <div id="dash-body">${emptyState('⏳', 'Chargement…')}</div>
    `);

    const d = await fetchNui('mdtresto:getDashboard', {});
    if (!el('dash-body')) return;                       // onglet changé entre-temps
    if (!d || d === true) { el('dash-body').innerHTML = emptyState('🚫', 'Données indisponibles.'); return; }

    const onDuty = asArray(d.onDuty);
    const stocks = asArray(d.stocks);

    const dutyList = onDuty.length
        ? onDuty.map(kkDutyRow).join('')
        : `<div class="dash-muted">Aucun employé en service.</div>`;

    const stockList = stocks.length
        ? stocks.map((s) => `
            <div class="dash-item">
                <div class="dash-item-main">
                    <div class="dash-item-name">${esc(s.label)}</div>
                    <div class="dash-item-sub">${esc(s.weight)} / ${esc(s.maxWeight)} kg</div>
                </div>
                <span class="mdt-badge ${kkStockBadgeClass(s.weight, s.maxWeight)}">
                    ${s.maxWeight ? Math.round((s.weight / s.maxWeight) * 100) : 0}%
                </span>
            </div>`).join('')
        : `<div class="dash-muted">Aucun stockage suivi.</div>`;

    const tiles = [{ n: onDuty.length, l: 'Employés en service' }];
    if (d.safeBalance !== undefined && d.safeBalance !== null) {
        tiles.push({ n: kkMoney(d.safeBalance), l: "Solde du coffre" });
    }
    stocks.forEach((s) => tiles.push({ n: `${esc(s.weight)}/${esc(s.maxWeight)}`, l: s.label + ' (kg)' }));

    el('dash-body').innerHTML = `
        <div class="dash-stats">
            ${tiles.map((t) => `
                <div class="dash-stat">
                    <span class="dash-stat-n">${t.n}</span>
                    <span class="dash-stat-l">${esc(t.l)}</span>
                </div>`).join('')}
        </div>

        <div class="dash-grid">

            <div class="dash-card">
                <div class="dash-card-head">
                    <span class="dash-card-ico">🧑‍🍳</span>
                    <span class="dash-card-title">Équipe en service</span>
                    <span class="dash-card-count">${onDuty.length}</span>
                </div>
                <div class="dash-card-body">
                    <button class="mdt-btn dash-duty-btn ${d.meOnDuty ? 'dash-duty-on' : 'mdt-btn-primary'}" id="dash-duty-toggle">
                        ${d.meOnDuty ? '⏹ Terminer le service' : '▶ Prendre le service'}
                    </button>
                    <div class="dash-scroll">${dutyList}</div>
                </div>
            </div>

            <div class="dash-card">
                <div class="dash-card-head">
                    <span class="dash-card-ico">📋</span>
                    <span class="dash-card-title">Accès rapide</span>
                </div>
                <div class="dash-card-body">
                    <div class="dash-quick">
                        <button class="dash-quick-btn" data-tab="effectifs">👥 Effectifs</button>
                        <button class="dash-quick-btn" data-tab="organisation">🏢 Organisation</button>
                        <button class="dash-quick-btn" data-tab="entreprise">💰 Entreprise</button>
                    </div>
                </div>
            </div>

            <div class="dash-card dash-card-wide">
                <div class="dash-card-head">
                    <span class="dash-card-ico">📦</span>
                    <span class="dash-card-title">Stocks</span>
                </div>
                <div class="dash-card-body dash-scroll">${stockList}</div>
            </div>

        </div>
    `;

    /* Prise / fin de service — même bascule que le dashboard générique. */
    b('dash-duty-toggle', async () => {
        const btn = el('dash-duty-toggle');
        if (btn) { btn.disabled = true; btn.textContent = '…'; }
        const res = await fetchNui('mdt:toggleDuty', {});
        if (!res || res.ok !== true) {
            toast('Prise de service indisponible.', false);
        }
        setTimeout(() => {
            if (state.currentTab === 'dashboard') renderRestoDashboard();
        }, 400);
    });

    document.querySelectorAll('.dash-quick-btn').forEach((btn) =>
        btn.addEventListener('click', () => selectTab(btn.dataset.tab)));
}

/* ════════════════════════════════════════════════════════════════
   Enregistrement dans le point d'extension de mdt.js

   dashboard.js (chargé avant) a déjà posé le dashboard "forces de
   l'ordre" sur le même id d'onglet. On le mémorise et on le rappelle
   pour tout département autre qu'un "resto" (kebabking, burgershot),
   pour ne rien changer aux autres métiers.
   ════════════════════════════════════════════════════════════════ */
const RESTO_DEPARTMENTS = ['kebabking', 'burgershot'];

(function registerRestoDashboard() {
    const previous = (window.MDT_RENDERERS || {}).dashboard;
    window.MDT_RENDERERS = Object.assign(window.MDT_RENDERERS || {}, {
        dashboard: function () {
            const dep = state.payload && state.payload.department;
            if (RESTO_DEPARTMENTS.includes(dep)) return renderRestoDashboard();
            return typeof previous === 'function' ? previous() : renderUnknown();
        },
    });
})();
