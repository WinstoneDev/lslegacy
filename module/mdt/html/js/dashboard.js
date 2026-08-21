/* ════════════════════════════════════════════════════════════════
   MDT — Tableau de bord des forces de l'ordre (police, gendarmerie)
   ────────────────────────────────────────────────────────────────
   Chargé APRÈS mdt.js et medical.js, dont il ne modifie rien : il
   s'enregistre dans window.MDT_RENDERERS et réutilise les helpers
   globaux (esc, setContent, emptyState, fetchNui, fmtDate, b, has,
   selectTab, depBadge).

   L'onglet `dashboard` est partagé avec le MDT médical, qui a sa
   propre vue. On conserve donc le rendu déjà enregistré par
   medical.js et on ne prend la main que pour les autres départements
   — voir l'enregistrement en bas de fichier.
   ════════════════════════════════════════════════════════════════ */

/* Rendu d'un agent de la liste « en service ». */
function dashDutyRow(a) {
    return `
        <div class="dash-duty-row">
            <span class="dash-dot"></span>
            <span class="dash-duty-name">${esc(a.name || '—')}</span>
            <span class="dash-duty-grade">${esc(a.gradeLabel || '')}</span>
        </div>`;
}

/* Niveau de danger d'un avis de recherche. Les libellés viennent du
   serveur (Config.MDT.DangerLevels), on retombe sur le niveau brut si
   le payload n'a pas encore été reçu. */
function dashDanger(level) {
    const lv = parseInt(level, 10) || 1;
    const cfg = (state.payload && state.payload.dangerLevels) || {};
    const d = cfg[lv] || cfg[String(lv)];
    const label = d ? d.label : ('Niveau ' + lv);
    const cls = lv >= 3 ? 'mdt-badge-red' : (lv === 2 ? 'mdt-badge-orange' : 'mdt-badge-green');
    return `<span class="mdt-badge ${cls}">${esc(label)}</span>`;
}

/* Temps restant d'une garde à vue. La date arrive en heure serveur ;
   un écart négatif signifie que la mesure vient d'expirer. */
function dashRemaining(endsAt) {
    if (!endsAt) return '—';
    const end = (typeof endsAt === 'number') ? new Date(endsAt)
        : new Date(String(endsAt).replace(' ', 'T'));
    if (isNaN(end.getTime())) return '—';
    const min = Math.round((end.getTime() - Date.now()) / 60000);
    if (min <= 0) return 'Terminée';
    if (min < 60) return `${min} min`;
    return `${Math.floor(min / 60)} h ${String(min % 60).padStart(2, '0')}`;
}

function dashTypeLabel(id) {
    const types = asArray(state.payload && state.payload.reportTypes);
    const t = types.find((x) => x.id === id);
    return t ? t.label : (id || '—');
}

async function renderLeoDashboard() {
    setContent(`
        <div class="mdt-page-title">Tableau de bord</div>
        <div class="mdt-page-sub">${esc((state.payload && state.payload.departmentLabel) || '')} — vue d'ensemble du service.</div>
        <div id="dash-body">${emptyState('⏳', 'Chargement…')}</div>
    `);

    const d = await fetchNui('mdt:getDashboard', {});
    if (!el('dash-body')) return;                       // onglet changé entre-temps
    if (!d || d === true) { el('dash-body').innerHTML = emptyState('🚫', 'Données indisponibles.'); return; }

    const onDuty   = asArray(d.onDuty);
    const warrants = asArray(d.warrants);
    const reports  = asArray(d.reports);
    const custody  = asArray(d.custody);
    const st       = d.stats || {};

    const dutyList = onDuty.length
        ? onDuty.map(dashDutyRow).join('')
        : `<div class="dash-muted">Aucun agent en service.</div>`;

    const warrantList = warrants.length
        ? warrants.map((w) => `
            <div class="dash-item" data-warrant="${esc(w.identifier || '')}">
                <div class="dash-item-main">
                    <div class="dash-item-name">${esc(w.citizen_name || 'Individu non identifié')}</div>
                    <div class="dash-item-sub">${esc(w.reason || 'Motif non précisé')}</div>
                    <div class="dash-item-meta">Émis par ${esc(w.author_name || '—')}${depBadge(w.department)} · ${fmtDate(w.created_at)}</div>
                </div>
                ${dashDanger(w.danger_level)}
            </div>`).join('')
        : `<div class="dash-muted">Aucun avis de recherche actif.</div>`;

    const reportList = reports.length
        ? reports.map((r) => `
            <div class="dash-item" data-report="${esc(r.id)}">
                <div class="dash-item-main">
                    <div class="dash-item-name">${esc(r.title || 'Sans titre')}</div>
                    <div class="dash-item-meta">
                        <span class="mdt-badge mdt-badge-gray">${esc(dashTypeLabel(r.type))}</span>
                        ${esc(r.author_name || '—')}${depBadge(r.department)} · ${fmtDate(r.updated_at)}
                    </div>
                </div>
                <span class="mdt-badge mdt-badge-blue">Ouvrir →</span>
            </div>`).join('')
        : `<div class="dash-muted">Aucun dossier récent.</div>`;

    const custodyList = custody.length
        ? custody.map((c) => `
            <div class="dash-item">
                <div class="dash-item-main">
                    <div class="dash-item-name">${esc(c.citizen_name || '—')}</div>
                    <div class="dash-item-sub">${esc(c.reason || 'Motif non précisé')}</div>
                    <div class="dash-item-meta">${esc(c.officer_name || '—')}${depBadge(c.department)}</div>
                </div>
                <span class="mdt-badge mdt-badge-orange">${esc(dashRemaining(c.ends_at))}</span>
            </div>`).join('')
        : `<div class="dash-muted">Aucune garde à vue en cours.</div>`;

    /* Les compteurs absents (permission manquante) ne sont pas affichés :
       une tuile à « 0 » laisserait croire qu'il n'y a rien, alors que
       l'agent n'a simplement pas accès à l'information. */
    const tiles = [];
    if (st.warrantsActive !== undefined) tiles.push({ n: st.warrantsActive, l: 'Avis de recherche actifs' });
    if (st.custodyActive !== undefined)  tiles.push({ n: st.custodyActive,  l: 'Gardes à vue en cours' });
    if (st.reportsToday !== undefined)   tiles.push({ n: st.reportsToday,   l: "Dossiers rédigés aujourd'hui" });
    if (st.finesUnpaid !== undefined)    tiles.push({ n: st.finesUnpaid,    l: 'Amendes impayées' });
    tiles.push({ n: onDuty.length, l: 'Agents en service' });

    el('dash-body').innerHTML = `
        <div class="dash-stats">
            ${tiles.map((t) => `
                <div class="dash-stat">
                    <span class="dash-stat-n">${esc(t.n)}</span>
                    <span class="dash-stat-l">${esc(t.l)}</span>
                </div>`).join('')}
        </div>

        <div class="dash-grid">

            <div class="dash-card">
                <div class="dash-card-head">
                    <span class="dash-card-ico">👮</span>
                    <span class="dash-card-title">Effectif en service</span>
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
                    <span class="dash-card-ico">🔎</span>
                    <span class="dash-card-title">Recherche rapide</span>
                </div>
                <div class="dash-card-body">
                    ${has('view_citizens') ? `
                    <label class="dash-label">Citoyen</label>
                    <div class="dash-inline">
                        <input class="mdt-input" id="dash-cz" placeholder="Nom ou prénom…" autocomplete="off">
                        <button class="mdt-btn mdt-btn-primary" id="dash-cz-go">→</button>
                    </div>` : ''}
                    ${has('view_vehicles') ? `
                    <label class="dash-label">Véhicule</label>
                    <div class="dash-inline">
                        <input class="mdt-input" id="dash-vh" placeholder="Plaque d'immatriculation…" autocomplete="off">
                        <button class="mdt-btn mdt-btn-primary" id="dash-vh-go">→</button>
                    </div>` : ''}
                    <div class="dash-quick">
                        ${has('view_warrants') ? `<button class="dash-quick-btn" data-tab="warrants">🚨 Avis de recherche</button>` : ''}
                        ${has('view_reports') ? `<button class="dash-quick-btn" data-tab="dossiers">📁 Dossiers</button>` : ''}
                        ${has('manage_custody') ? `<button class="dash-quick-btn" data-tab="custody">🔒 Garde à vue</button>` : ''}
                        ${has('view_callouts') ? `<button class="dash-quick-btn" data-tab="interventions">📞 Interventions</button>` : ''}
                        ${has('view_laws') ? `<button class="dash-quick-btn" data-tab="laws">⚖️ Code juridique</button>` : ''}
                        <button class="dash-quick-btn" data-tab="effectifs">👥 Effectifs</button>
                    </div>
                </div>
            </div>

            ${has('view_warrants') ? `
            <div class="dash-card dash-card-wide">
                <div class="dash-card-head">
                    <span class="dash-card-ico">🚨</span>
                    <span class="dash-card-title">Avis de recherche actifs</span>
                    ${st.warrantsActive > warrants.length ? `<span class="dash-card-count">${esc(st.warrantsActive)}</span>` : ''}
                </div>
                <div class="dash-card-body dash-scroll">${warrantList}</div>
            </div>` : ''}

            ${has('view_reports') ? `
            <div class="dash-card dash-card-wide">
                <div class="dash-card-head">
                    <span class="dash-card-ico">📁</span>
                    <span class="dash-card-title">Derniers dossiers</span>
                </div>
                <div class="dash-card-body dash-scroll">${reportList}</div>
            </div>` : ''}

            ${has('manage_custody') ? `
            <div class="dash-card dash-card-wide">
                <div class="dash-card-head">
                    <span class="dash-card-ico">🔒</span>
                    <span class="dash-card-title">Gardes à vue en cours</span>
                </div>
                <div class="dash-card-body dash-scroll">${custodyList}</div>
            </div>` : ''}

        </div>
    `;

    /* Prise / fin de service. Le client répond aussitôt, mais le serveur
       enregistre la bascule juste après : on laisse passer un court délai
       avant de recharger, sinon la liste afficherait l'état précédent. */
    b('dash-duty-toggle', async () => {
        const btn = el('dash-duty-toggle');
        if (btn) { btn.disabled = true; btn.textContent = '…'; }
        const res = await fetchNui('mdt:toggleDuty', {});
        if (!res || res.ok !== true) {
            toast('Prise de service indisponible.', false);
        }
        setTimeout(() => {
            if (state.currentTab === 'dashboard') renderLeoDashboard();
        }, 400);
    });

    /* Raccourcis vers les autres onglets */
    document.querySelectorAll('.dash-quick-btn').forEach((btn) =>
        btn.addEventListener('click', () => selectTab(btn.dataset.tab)));

    /* Recherche citoyen : on bascule sur l'onglet puis on rejoue la
       recherche avec le terme saisi ici. */
    const goCitizen = () => {
        const q = ((el('dash-cz') || {}).value || '').trim();
        selectTab('citizens');
        if (q && el('cz-search')) {
            el('cz-search').value = q;
            const btn = el('cz-search-btn');
            if (btn) btn.click();
        }
    };
    b('dash-cz-go', goCitizen);
    const czInput = el('dash-cz');
    if (czInput) czInput.addEventListener('keydown', (e) => { if (e.key === 'Enter') goCitizen(); });

    const goVehicle = () => {
        const q = ((el('dash-vh') || {}).value || '').trim();
        selectTab('vehicles');
        if (q && el('vh-search')) {
            el('vh-search').value = q;
            const btn = el('vh-search-btn');
            if (btn) btn.click();
        }
    };
    b('dash-vh-go', goVehicle);
    const vhInput = el('dash-vh');
    if (vhInput) vhInput.addEventListener('keydown', (e) => { if (e.key === 'Enter') goVehicle(); });

    /* Accès direct depuis les listes */
    document.querySelectorAll('#dash-body [data-report]').forEach((it) =>
        it.addEventListener('click', () => openReport(it.dataset.report)));
    document.querySelectorAll('#dash-body [data-warrant]').forEach((it) =>
        it.addEventListener('click', () => {
            const id = it.dataset.warrant;
            if (id) openCitizenFile(id);          // avis nominatif → fiche du citoyen
            else selectTab('warrants');
        }));
}

/* ════════════════════════════════════════════════════════════════
   Enregistrement dans le point d'extension de mdt.js

   medical.js (chargé avant) a déjà posé son propre dashboard SAMU sur
   le même id d'onglet. On le mémorise et on le rappelle pour les
   départements médicaux : chaque métier garde ainsi sa vue sans que
   l'ordre de chargement des fichiers ne décide du gagnant.
   ════════════════════════════════════════════════════════════════ */
(function registerDashboard() {
    const previous = (window.MDT_RENDERERS || {}).dashboard;
    window.MDT_RENDERERS = Object.assign(window.MDT_RENDERERS || {}, {
        dashboard: function () {
            const dep = state.payload && state.payload.department;
            if (dep === 'samu' && typeof previous === 'function') return previous();
            return renderLeoDashboard();
        },
    });
})();
