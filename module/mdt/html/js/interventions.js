/* ════════════════════════════════════════════════════════════════
   MDT POLICE — Onglet « Interventions » (missions PNJ / appels 17)
   ────────────────────────────────────────────────────────────────
   Chargé APRÈS mdt.js, dont il ne modifie rien : il s'enregistre
   dans le point d'extension window.MDT_RENDERERS et réutilise les
   helpers globaux (esc, setContent, emptyState, fetchNui, fmtDate).

   Toutes les lectures passent par le pont dédié `mdtco:*`, servi par
   module/police/server/callouts.lua.
   ════════════════════════════════════════════════════════════════ */

/* Message d'erreur simple. Le MDT expose openModal ; on s'en sert
   plutôt que d'un alert() natif, bloqué dans une NUI. */
function alertBox(msg) {
    openModal('Opération impossible', `<p>${esc(msg)}</p>`,
        `<button class="mdt-btn" onclick="window.__mdtCloseModal()">Fermer</button>`);
}

const coState = {
    page: 1,
    open: {},   // { [calloutId]: true } — lignes dépliées
};

/* ── Libellés ──────────────────────────────────────────────────── */

const CO_STATUS = {
    success:   { label: 'Réussite',          cls: 'mdt-badge-green' },
    failed:    { label: 'Échec',             cls: 'mdt-badge-red' },
    cancelled: { label: 'Classé sans suite', cls: 'mdt-badge-gray' },
};

/* Trois informations peuvent cohabiter sur un dossier :
     · le résultat de l'intervention (réussite, échec, sans suite) ;
     · une saisine IGPN, qui prime sur le résultat ;
     · le classement par le commissaire, qui remplace le résultat.

   Une affaire classée reste signalée IGPN si une bavure a été commise :
   le classement clôt la procédure, il n'efface pas la faute. */
function coStatus(s, misconducts, closed) {
    const bav = parseInt(misconducts, 10) || 0;
    const igpn = bav > 0
        ? `<span class="mdt-badge mdt-badge-red" title="${esc(
              bav > 1 ? `${bav} bavures constatées` : 'Bavure constatée')}">IGPN</span>`
        : '';

    const filed = '<span class="mdt-badge mdt-badge-blue">Affaire classée</span>';

    /* Une saisine IGPN interdit de qualifier l'intervention de réussite :
       le résultat n'est JAMAIS affiché à côté. Seul le classement peut
       l'accompagner, pour indiquer que la procédure est instruite. */
    if (igpn) {
        return (Number(closed) === 1) ? `${filed}${igpn}` : igpn;
    }

    const m = CO_STATUS[s] || { label: s || '?', cls: 'mdt-badge-gray' };
    const result = `<span class="mdt-badge ${m.cls}">${esc(m.label)}</span>`;

    return (Number(closed) === 1) ? `${result}${filed}` : result;
}

function coDuration(sec) {
    const n = parseInt(sec, 10);
    if (!n || n < 0) return '—';
    if (n < 60) return `${n} s`;
    return `${Math.floor(n / 60)} min ${n % 60} s`;
}

/* Un individu enfui ou non contrôlé n'a jamais d'identité. */
function coPersonName(p) {
    if (p && p.firstname && p.lastname) return `${p.firstname} ${p.lastname}`;
    return (p && p.label) || 'Individu non identifié';
}

/* Le libellé dépend du rôle : « présenté au poste » n'a aucun sens pour
   une personne assistée ou pour un défunt. */
const CO_OUTCOME = {
    delivered: { label: 'Interpellé(e)',     cls: 'mdt-badge-green' },
    dispersed: { label: 'Laissé(e) libre',   cls: 'mdt-badge-blue' },
    dead:      { label: 'Neutralisé',        cls: 'mdt-badge-red' },
    escaped:   { label: 'En fuite',          cls: 'mdt-badge-orange' },
    morgue:    { label: 'Corps à la morgue', cls: 'mdt-badge-gray' },
    cuffed:    { label: 'Menotté(e)',        cls: 'mdt-badge-orange' },
    // Individu jamais engagé individuellement (ex. fêtards d'un tapage,
    // résolu par la coupure de la sono et non par leur propre état).
    idle:      { label: 'N/C',               cls: 'mdt-badge-gray' },
};

const CO_OUTCOME_BY_ROLE = {
    wanderer: {
        delivered: { label: 'Présenté(e) à l\'hôpital', cls: 'mdt-badge-green' },
        dispersed: { label: 'Laissé(e) sur place',     cls: 'mdt-badge-blue' },
    },
    deceased: {
        morgue: { label: 'Corps à la morgue', cls: 'mdt-badge-gray' },
    },
    animal: {
        dead:   { label: 'Animal neutralisé',   cls: 'mdt-badge-red' },
        morgue: { label: 'Dépouille évacuée',   cls: 'mdt-badge-gray' },
    },
};

function coOutcome(o, role) {
    if (!o) return '';
    const byRole = (CO_OUTCOME_BY_ROLE[role] || {})[o];
    const m = byRole || CO_OUTCOME[o] || { label: o, cls: 'mdt-badge-gray' };
    return `<span class="mdt-badge ${m.cls}">${esc(m.label)}</span>`;
}

const CO_ROLE = {
    suspect:  'Mis en cause',
    caller:   'Requérant(e)',
    victim:   'Victime',
    deceased: 'Personne décédée',
    wanderer: 'Personne assistée',
    animal:   'Animal',
};

/* ── Détail dépliable d'une intervention ───────────────────────── */

/* Rapport d'intervention : affiché seulement s'il existe. */
function coReportBlock(row) {
    if (!row.report) return '';
    const sig = [row.report_by, row.report_at ? fmtDate(row.report_at) : null]
        .filter(Boolean).join(' · ');
    const closure = Number(row.closed) === 1
        ? `<div class="co-report-closure">Affaire classée par ${esc(row.closed_by || '—')}${
              row.closed_at ? ` le ${esc(fmtDate(row.closed_at))}` : ''}</div>`
        : '';
    return `
        <div class="co-report">
            <div class="co-report-head">Rapport d'intervention${
                sig ? ` <span class="co-report-sig">${esc(sig)}</span>` : ''}</div>
            <div class="co-report-body">${esc(row.report)}</div>
            ${closure}
        </div>`;
}

/* Boutons du dossier. Le classement n'apparaît que pour le commissaire,
   et seulement sur un dossier non classé disposant d'un rapport. */
function coActionBar(row, canManage) {
    const closed = Number(row.closed) === 1;
    const btns = [];

    if (!closed) {
        btns.push(`<button class="mdt-btn co-report-btn" data-report="${esc(row.id)}">${
            row.report ? 'Modifier le rapport' : 'Rédiger le rapport'}</button>`);
    }

    if (canManage && !closed) {
        btns.push(`<button class="mdt-btn mdt-btn-primary co-close-btn" data-close="${
            esc(row.id)}" ${row.report ? '' : 'disabled title="Aucun rapport rédigé"'}>${
            'Classer l\'affaire'}</button>`);
    }

    if (!btns.length) return '';
    return `<div class="co-actions">${btns.join('')}</div>`;
}

function coDetail(row, canManage) {
    let people = [];
    try { people = JSON.parse(row.suspects_json || '[]') || []; } catch (e) { people = []; }

    /* Les saisies sont déjà des désignations lisibles côté serveur :
       armes traduites via C.WeaponLabels, objets nommés par le scénario. */
    const seizedCell = (p) => {
        if (!Array.isArray(p.seized) || p.seized.length === 0) return '—';
        return p.seized.map((it) => esc(it)).join('<br>');
    };

    /* Avec plusieurs agents engagés, le dossier doit dire QUI a fait
       feu, et sur quel motif la bavure a été retenue. */
    const outcomeCell = (p) => {
        let html = coOutcome(p.outcome, p.role);
        if (p.killedBy) {
            html += `<div class="co-killed-by">par ${esc(p.killedBy)}</div>`;
        }
        if (p.releasedBy) {
            html += `<div class="co-killed-by">par ${esc(p.releasedBy)}</div>`;
        }
        if (p.killReason) {
            html += `<div class="co-kill-reason">${esc(p.killReason)}</div>`;
        }
        return html;
    };

    /* Déposition recueillie sur place auprès du mis en cause.
       L'attitude qualifie la valeur de la déclaration : un individu qui
       nie n'a pas dit la même chose qu'un individu qui avoue. */
    const STANCE = {
        nie:      'conteste les faits',
        justifie: 'reconnaît mais se justifie',
        provoque: 'attitude de défi',
        avoue:    'reconnaît les faits',
        silence:  'refuse de répondre',
    };

    const declarationRow = (p) => {
        if (!p.declaration) return '';
        const st = STANCE[p.stance];
        return `<tr class="co-declaration">
            <td colspan="5">« ${esc(p.declaration)} » — ${esc(coPersonName(p))}${
                st ? ` <span class="co-stance">(${esc(st)})</span>` : ''}</td>
        </tr>`;
    };

    const rows = people.map((p) => `
        <tr>
            <td>${esc(coPersonName(p))}</td>
            <td>${esc(CO_ROLE[p.role] || p.role || '—')}</td>
            <td>${p.weapon ? esc(p.weapon) : '—'}</td>
            <td>${seizedCell(p)}</td>
            <td>${outcomeCell(p)}</td>
        </tr>${declarationRow(p)}`).join('');

    const bav = parseInt(row.misconducts, 10) || 0;

    return `
        <div class="mdt-detail">
            ${bav > 0 ? `<div class="mdt-detail-row mdt-text-red"><b>Saisine IGPN :</b>
                ${bav > 1 ? `${bav} bavures constatées` : 'bavure constatée'}
                durant l'intervention.</div>` : ''}
            <div class="mdt-detail-row"><b>Agents engagés :</b> ${esc(row.agents || '—')}</div>
            <div class="mdt-detail-row"><b>Coordonnées :</b> ${esc(row.coords || '—')}</div>
            <div class="mdt-detail-row"><b>Temps de réponse :</b> ${coDuration(row.response_time)}</div>
            ${coReportBlock(row)}
            ${coActionBar(row, canManage)}
            ${people.length ? `
            <table class="mdt-table">
                <thead><tr><th>Individu</th><th>Qualité</th><th>Arme portée</th><th>Saisies</th><th>Suite</th></tr></thead>
                <tbody>${rows}</tbody>
            </table>` : `<div class="mdt-detail-row"><i>Aucun individu recensé.</i></div>`}
        </div>`;
}

/* ── Rendu principal ───────────────────────────────────────────── */

async function renderInterventions() {
    setContent(`
        <div class="mdt-page-title">Appel 17</div>
        <div class="mdt-page-sub">Historique des appels 17 et statistiques par agent.</div>
        <div id="co-summary"></div>
        <div class="mdt-searchbar">
            <button class="mdt-btn mdt-btn-primary" id="co-tab-history">📁 Historique</button>
            <button class="mdt-btn" id="co-tab-stats">📊 Statistiques</button>
        </div>
        <div id="co-body">${emptyState('⏳', 'Chargement…')}</div>
    `);

    /* Bandeau de synthèse — 30 derniers jours */
    const sum = await fetchNui('mdtco:getSummary', {});
    const s = (sum && typeof sum === 'object' && !Array.isArray(sum)) ? sum : {};
    const total = parseInt(s.total, 10) || 0;
    const succ = parseInt(s.successes, 10) || 0;
    const rate = total > 0 ? Math.round((succ / total) * 100) : 0;
    const avg = s.avg_response ? coDuration(Math.round(s.avg_response)) : '—';

    const sumEl = el('co-summary');
    if (sumEl) {
        sumEl.innerHTML = `
            <div class="mdt-stats-row">
                <div class="mdt-stat"><div class="mdt-stat-val">${total}</div>
                     <div class="mdt-stat-lbl">Interventions (30 j)</div></div>
                <div class="mdt-stat"><div class="mdt-stat-val">${rate} %</div>
                     <div class="mdt-stat-lbl">Taux de réussite</div></div>
                <div class="mdt-stat"><div class="mdt-stat-val">${avg}</div>
                     <div class="mdt-stat-lbl">Temps de réponse moyen</div></div>
            </div>`;
    }

    b('co-tab-history', () => {
        el('co-tab-history').className = 'mdt-btn mdt-btn-primary';
        el('co-tab-stats').className = 'mdt-btn';
        coRenderHistory();
    });
    b('co-tab-stats', () => {
        el('co-tab-stats').className = 'mdt-btn mdt-btn-primary';
        el('co-tab-history').className = 'mdt-btn';
        coRenderStats();
    });

    coRenderHistory();
}

/* ── Historique ────────────────────────────────────────────────── */

async function coRenderHistory() {
    const box = el('co-body');
    if (!box) return;
    box.innerHTML = emptyState('⏳', 'Chargement de l\'historique…');

    const res = await fetchNui('mdtco:getHistory', { page: coState.page });
    if (!el('co-body')) return;

    const payload = (res && typeof res === 'object' && !Array.isArray(res)) ? res : {};
    const rows = asArray(payload.rows);
    const hasMore = !!payload.hasMore;
    const canManage = !!payload.canManage;

    /* Page vide alors qu'on n'est pas à la première : on recule au lieu
       de laisser l'écran bloqué sans pagination. */
    if (!rows.length && coState.page > 1) {
        coState.page -= 1;
        return coRenderHistory();
    }

    const pager = `
        <div class="mdt-searchbar" style="margin-top:12px">
            <button class="mdt-btn" id="co-prev" ${coState.page <= 1 ? 'disabled' : ''}>← Précédent</button>
            <span class="mdt-page-ind">Page ${coState.page}</span>
            <button class="mdt-btn" id="co-next" ${hasMore ? '' : 'disabled'}>Suivant →</button>
            ${canManage ? `<button class="mdt-btn mdt-btn-danger" id="co-reset">🗑 Réinitialiser les compteurs</button>` : ''}
        </div>`;

    if (!rows.length) {
        el('co-body').innerHTML = emptyState('📭', 'Aucune intervention enregistrée.') + pager;
        coBindPager(hasMore, canManage);
        return;
    }

    const html = rows.map((r) => {
        const opened = !!coState.open[r.id];
        return `
        <div class="mdt-list-item co-row" data-id="${esc(r.id)}">
            <div class="mdt-li-main">
                <div class="mdt-li-name">
                    ${esc(r.label || r.scenario_id)}${depBadge(r.department)}
                    ${Number(r.false_alarm) === 1 ? '<span class="mdt-badge mdt-badge-gray">Fausse alerte</span>' : ''}
                </div>
                <div class="mdt-li-sub">
                    ${esc(fmtDate(r.started_at))} · ${esc(r.zone || '—')} ·
                    ${esc(r.suspects_delivered || 0)} interpellé(s),
                    ${esc(r.suspects_killed || 0)} neutralisé(s),
                    ${esc(r.suspects_escaped || 0)} en fuite
                </div>
            </div>
            ${coStatus(r.status, r.misconducts, r.closed)}
            ${canManage ? `<button class="mdt-btn mdt-btn-danger co-del" data-del="${esc(r.id)}" title="Supprimer">✕</button>` : ''}
        </div>
        <div class="co-detail-wrap" data-detail="${esc(r.id)}" ${opened ? '' : 'style="display:none"'}>
            ${coDetail(r, canManage)}
        </div>`;
    }).join('');

    el('co-body').innerHTML = `<div class="mdt-list">${html}</div>` + pager;

    document.querySelectorAll('#co-body .co-row').forEach((it) => {
        it.addEventListener('click', (ev) => {
            if (ev.target.closest('.co-del')) return;   // le ✕ ne déplie pas
            const id = it.dataset.id;
            const d = document.querySelector(`[data-detail="${id}"]`);
            if (!d) return;
            const show = d.style.display === 'none';
            d.style.display = show ? '' : 'none';
            coState.open[id] = show;
        });
    });

    document.querySelectorAll('#co-body .co-del').forEach((btn) => {
        btn.addEventListener('click', (ev) => {
            ev.stopPropagation();
            const id = btn.dataset.del;
            confirmAction(
                'Supprimer définitivement cette intervention ? Les statistiques des agents associées seront également retirées.',
                async () => {
                    await fetchNui('mdtco:deleteCallout', { id: Number(id) });
                    delete coState.open[id];
                    coRenderHistory();
                });
        });
    });

    /* Rédaction du rapport : ouvert à tout agent ayant accès à l'onglet.
       Le clic ne doit pas replier le dossier, d'où le stopPropagation. */
    document.querySelectorAll('#co-body .co-report-btn').forEach((btn) => {
        btn.addEventListener('click', (ev) => {
            ev.stopPropagation();
            const id  = btn.dataset.report;
            const row = rows.find((r) => String(r.id) === String(id)) || {};
            openModal('Rapport d\'intervention', `
                <div class="mdt-form-row">
                    <label>Compte rendu des faits, constatations et suites données</label>
                    <textarea id="co-report-text" class="mdt-textarea" rows="12"
                        placeholder="Rédigez le rapport…">${esc(row.report || '')}</textarea>
                </div>`,
                `<button class="mdt-btn" onclick="window.__mdtCloseModal()">Annuler</button>
                 <button class="mdt-btn mdt-btn-primary" id="co-report-save">Enregistrer</button>`);

            const save = el('co-report-save');
            if (!save) return;
            save.addEventListener('click', async () => {
                const text = (el('co-report-text') || {}).value || '';
                const res = await fetchNui('mdtco:saveReport',
                    { id: Number(id), text: text });
                if (res && res.ok === false) {
                    alertBox(res.reason || 'Enregistrement impossible.');
                    return;
                }
                window.__mdtCloseModal();
                coState.open[id] = true;   // le dossier reste déplié
                coRenderHistory();
            });
        });
    });

    /* Classement de l'affaire : commissaire uniquement, rapport exigé. */
    document.querySelectorAll('#co-body .co-close-btn').forEach((btn) => {
        btn.addEventListener('click', (ev) => {
            ev.stopPropagation();
            if (btn.hasAttribute('disabled')) return;
            const id = btn.dataset.close;
            confirmAction(
                'Classer définitivement cette affaire ? Le rapport ne pourra plus être modifié.',
                async () => {
                    const res = await fetchNui('mdtco:closeCase', { id: Number(id) });
                    if (res && res.ok === false) {
                        alertBox(res.reason || 'Classement impossible.');
                        return;
                    }
                    coState.open[id] = true;
                    coRenderHistory();
                });
        });
    });

    coBindPager(hasMore, canManage);
}

function coBindPager(hasMore, canManage) {
    b('co-prev', () => {
        if (coState.page > 1) { coState.page -= 1; coRenderHistory(); }
    });
    b('co-next', () => {
        if (hasMore) { coState.page += 1; coRenderHistory(); }
    });
    if (canManage) {
        b('co-reset', () => {
            confirmAction(
                'Réinitialiser tous les compteurs ? Tout l\'historique des interventions et toutes les statistiques par agent seront effacés. Action irréversible.',
                async () => {
                    await fetchNui('mdtco:resetStats', {});
                    coState.page = 1;
                    coState.open = {};
                    renderInterventions();
                });
        });
    }
}

/* ── Statistiques par agent ────────────────────────────────────── */

async function coRenderStats() {
    const box = el('co-body');
    if (!box) return;
    box.innerHTML = emptyState('⏳', 'Calcul des statistiques…');

    const rows = asArray(await fetchNui('mdtco:getStats', {}));
    if (!el('co-body')) return;
    if (!rows.length) {
        el('co-body').innerHTML = emptyState('📊', 'Aucune donnée pour le moment.');
        return;
    }

    const body = rows.map((r) => {
        const inter = parseInt(r.interventions, 10) || 0;
        const succ = parseInt(r.successes, 10) || 0;
        const rate = inter > 0 ? Math.round((succ / inter) * 100) : 0;
        const mis = parseInt(r.misconduct, 10) || 0;
        return `
        <tr>
            <td>${esc(r.name || '—')}${depBadge(r.department)}</td>
            <td>${inter}</td>
            <td>${esc(r.cuffed || 0)}</td>
            <td>${esc(r.delivered || 0)}</td>
            <td>${esc(r.killed || 0)}</td>
            <td>${mis > 0 ? `<span class="mdt-badge mdt-badge-red">${mis}</span>` : '0'}</td>
            <td>${rate} %</td>
        </tr>`;
    }).join('');

    el('co-body').innerHTML = `
        <table class="mdt-table">
            <thead>
                <tr>
                    <th>Agent</th><th>Interventions</th><th>Menottés</th>
                    <th>Présentés</th><th>Neutralisés</th><th>Bavures</th><th>Réussite</th>
                </tr>
            </thead>
            <tbody>${body}</tbody>
        </table>`;
}

/* ════════════════════════════════════════════════════════════════
   Enregistrement dans le point d'extension de mdt.js
   ════════════════════════════════════════════════════════════════ */
window.MDT_RENDERERS = Object.assign(window.MDT_RENDERERS || {}, {
    interventions: renderInterventions,
});
