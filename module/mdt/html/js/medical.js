/* ════════════════════════════════════════════════════════════════
   MDT MÉDICAL (SAMU) — Vues NUI
   ────────────────────────────────────────────────────────────────
   Ce fichier est chargé APRÈS mdt.js et n'en modifie rien : il
   s'enregistre dans les deux points d'extension exposés par mdt.js
     • window.MDT_RENDERERS  → un rendu par onglet
     • window.MDT_EXT_REFRESH → rafraîchissement après écriture
   Il réutilise les helpers globaux de mdt.js (esc, setContent,
   emptyState, fetchNui, openModal, confirmAction, fmtDate, b, has).

   Toutes les lectures passent par `mdtmed:*` (pont dédié SAMU), donc
   aucun handler du MDT police n'est appelé ici.
   ════════════════════════════════════════════════════════════════ */

/* ── État local du module médical ─────────────────────────────── */
const medState = {
    cfg: null,            // catalogues (mis en cache après le 1er fetch)
    currentPatient: null, // character_id du dossier ouvert
    treatmentStatus: 'actif',
    docCategory: '',
    dispatchTimer: null,  // setInterval du rafraîchissement de la carte
};

/* Catalogues : un seul aller-retour, mémorisé ensuite. */
async function medConfig() {
    if (medState.cfg) return medState.cfg;
    const cfg = await fetchNui('mdtmed:getMedConfig', {});
    medState.cfg = cfg || {
        bloodGroups: [], entryTypes: [], treatments: [],
        treatmentStatuses: [], docCategories: [],
        dispatch: { bounds: { minX: -4000, maxX: 4500, minY: -4000, maxY: 8000 }, refreshInterval: 2000 },
    };
    return medState.cfg;
}

/* Arrête le rafraîchissement de la carte dès qu'on quitte le dispatch
   (sinon le timer continuerait à interroger le serveur en fond). */
function medStopDispatchTimer() {
    if (medState.dispatchTimer) {
        clearInterval(medState.dispatchTimer);
        medState.dispatchTimer = null;
    }
}

/* Petit helper : <select> construit depuis une liste ------------- */
function medSelect(id, items, selected, keyField, labelField) {
    const opts = (items || []).map((it) => {
        const v = keyField ? it[keyField] : it;
        const l = labelField ? it[labelField] : it;
        return `<option value="${esc(v)}"${String(v) === String(selected) ? ' selected' : ''}>${esc(l)}</option>`;
    }).join('');
    return `<select class="mdt-input" id="${id}">${opts}</select>`;
}

function medLabelOf(list, value, keyField, labelField) {
    for (const it of (list || [])) {
        if (String(keyField ? it[keyField] : it) === String(value)) {
            return labelField ? it[labelField] : it;
        }
    }
    return value || '—';
}

/* ════════════════════════════════════════════════════════════════
   1. DASHBOARD
   Une tuile arrondie par module : effectif en service, dernier
   appel, accès au dossier médical, mot des cheffes d'équipe.
   ════════════════════════════════════════════════════════════════ */
async function renderMedDashboard() {
    medStopDispatchTimer();
    setContent(`
        <div class="mdt-page-title">Tableau de bord</div>
        <div class="mdt-page-sub">Service d'aide médicale urgente — vue d'ensemble.</div>
        <div id="med-dash">${emptyState('⏳', 'Chargement…')}</div>
    `);

    const d = await fetchNui('mdtmed:getDashboard', {});
    if (!el('med-dash')) return; // onglet changé pendant le chargement
    if (!d) { el('med-dash').innerHTML = emptyState('🚫', 'Données indisponibles.'); return; }

    const onDuty = asArray(d.onDuty);
    const recent = asArray(d.recentCalls);
    const board  = asArray(d.board);
    const st     = d.stats || {};

    const dutyRows = onDuty.length
        ? onDuty.map((a) => `
            <div class="med-duty-row">
                <span class="med-dot"></span>
                <span class="med-duty-name">${esc(a.name)}</span>
                <span class="med-duty-grade">${esc(a.gradeLabel)}</span>
            </div>`).join('')
        : `<div class="med-muted">Aucun agent en service.</div>`;

    const callsBlock = recent.length ? recent.map((c) => `
        <div class="med-recent-call">
            <div class="med-recent-head">
                <b>${esc(c.callerName || 'Inconnu')}</b>
                ${medCallStatusBadge(c.status)}
            </div>
            <div class="med-recent-sub">${esc(c.reason || 'Appel patient')} · ${fmtDate(c.created_at)}</div>
            <div class="med-recent-zone">
                📍 ${esc(c.zone || 'Secteur inconnu')}
                <button class="med-recent-gps" data-x="${esc(c.x)}" data-y="${esc(c.y)}" title="Marquer sur le GPS">GPS</button>
            </div>
        </div>`).join('')
        : `<div class="med-muted">Aucun appel enregistré.</div>`;

    const boardBlock = board.length
        ? board.map((m) => `
            <div class="med-board-msg">
                <div class="med-board-head">
                    <b>${esc(m.author_name || '?')}</b>
                    <span class="med-board-grade">${esc(m.author_grade || '')}</span>
                    <span class="med-board-date">${fmtDate(m.created_at)}</span>
                    ${d.canPostBoard ? `<button class="med-board-del" data-id="${esc(m.id)}" title="Retirer">✕</button>` : ''}
                </div>
                <div class="med-board-body">${esc(m.message)}</div>
            </div>`).join('')
        : `<div class="med-muted">Aucun message pour le moment.</div>`;

    el('med-dash').innerHTML = `
        <div class="med-dash-grid">

            <div class="med-card med-card-board">
                <div class="med-card-head">
                    <span class="med-card-ico">📌</span>
                    <span class="med-card-title">Mot des cheffes d'équipe</span>
                    ${d.canPostBoard ? `<button class="mdt-btn mdt-btn-primary med-card-head-btn" id="med-board-new">＋ Publier</button>` : ''}
                </div>
                <div class="med-card-body med-scroll">${boardBlock}</div>
            </div>

            <div class="med-cards">
                <div class="med-card">
                    <div class="med-card-head">
                        <span class="med-card-ico">👥</span>
                        <span class="med-card-title">Effectif en service</span>
                        <span class="med-card-count">${onDuty.length}</span>
                    </div>
                    <div class="med-card-body">
                        <button class="mdt-btn med-duty-btn ${d.meOnDuty ? 'med-duty-on' : 'mdt-btn-primary'}" id="med-duty-toggle">
                            ${d.meOnDuty ? '⏹ Quitter le service' : '▶ Se mettre en service'}
                        </button>
                        <div class="med-duty-list">${dutyRows}</div>
                    </div>
                </div>

                <div class="med-card">
                    <div class="med-card-head">
                        <span class="med-card-ico">📞</span>
                        <span class="med-card-title">Derniers appels</span>
                        ${d.pendingCalls > 0 ? `<span class="med-card-count med-count-alert">${d.pendingCalls} en attente</span>` : ''}
                    </div>
                    <div class="med-card-body med-scroll">${callsBlock}</div>
                </div>

                <div class="med-card">
                    <div class="med-card-head">
                        <span class="med-card-ico">🩺</span>
                        <span class="med-card-title">Dossier médical</span>
                    </div>
                    <div class="med-card-body">
                        <div class="med-muted">Rechercher un patient et ouvrir son dossier.</div>
                        <input class="mdt-input med-card-input" id="med-dash-search" placeholder="Nom ou prénom…" autocomplete="off">
                        <button class="mdt-btn mdt-btn-primary med-card-btn" id="med-dash-open">🔍 Consulter un dossier</button>
                        <div class="med-quick">
                            <button class="med-quick-btn" data-tab="med_treatments">💊 Traitements</button>
                            <button class="med-quick-btn" data-tab="med_dispatch">🚑 Dispatch</button>
                            <button class="med-quick-btn" data-tab="med_docs">📄 Documents</button>
                            <button class="med-quick-btn" data-tab="effectifs">👮 Effectifs</button>
                        </div>
                    </div>
                </div>
            </div>

            <div class="med-stats">
                <div class="med-stat"><span class="med-stat-n">${st.patients || 0}</span><span class="med-stat-l">Dossiers patients</span></div>
                <div class="med-stat"><span class="med-stat-n">${st.treatments || 0}</span><span class="med-stat-l">Traitements en cours</span></div>
                <div class="med-stat"><span class="med-stat-n">${st.callsToday || 0}</span><span class="med-stat-l">Appels aujourd'hui</span></div>
                <div class="med-stat"><span class="med-stat-n">${st.entriesToday || 0}</span><span class="med-stat-l">Actes aujourd'hui</span></div>
                <div class="med-stat"><span class="med-stat-n">${st.docs || 0}</span><span class="med-stat-l">Documents internes</span></div>
            </div>

        </div>
    `;

    /* Raccourcis vers les autres onglets */
    document.querySelectorAll('.med-quick-btn').forEach((btn) =>
        btn.addEventListener('click', () => selectTab(btn.dataset.tab)));

    /* GPS depuis la liste des derniers appels */
    document.querySelectorAll('.med-recent-gps').forEach((btn) =>
        btn.addEventListener('click', () => {
            fetchNui('mdtmed:setWaypoint', { x: btn.dataset.x, y: btn.dataset.y });
            toast('Point de rendez-vous marqué sur le GPS.', true);
        }));

    /* Prise / fin de service. Le retour du client dit si la bascule a
       abouti (elle peut être refusée, ex. en tenue au moment de quitter),
       et on ne rafraîchit qu'après un court délai, le temps que le serveur
       ait enregistré le changement. */
    b('med-duty-toggle', async () => {
        const btn = el('med-duty-toggle');
        if (btn) { btn.disabled = true; btn.textContent = '…'; }
        const res = await fetchNui('mdtmed:toggleDuty', {});
        if (!res || res.ok !== true) {
            toast('Prise de service indisponible.', false);
        }
        setTimeout(() => {
            if (state.currentTab === 'dashboard') renderMedDashboard();
        }, 400);
    });

    /* Accès direct au dossier médical depuis le dashboard */
    const goToRecords = () => {
        const q = (el('med-dash-search') && el('med-dash-search').value || '').trim();
        selectTab('med_records');
        // La vue est rendue de façon synchrone : on peut préremplir juste après.
        if (q && el('med-rec-search')) {
            el('med-rec-search').value = q;
            const btn = el('med-rec-search-btn');
            if (btn) btn.click();
        }
    };
    b('med-dash-open', goToRecords);
    const dashSearch = el('med-dash-search');
    if (dashSearch) {
        dashSearch.addEventListener('keydown', (e) => { if (e.key === 'Enter') goToRecords(); });
    }

    /* Publication / retrait d'un mot (chef de service) */
    if (d.canPostBoard) {
        b('med-board-new', () => {
            openModal('Publier un message',
                `<label class="mdt-label">Message</label>
                 <textarea class="mdt-textarea" id="med-board-msg" rows="5" placeholder="Message à l'équipe…"></textarea>`,
                `<button class="mdt-btn" onclick="window.__mdtCloseModal()">Annuler</button>
                 <button class="mdt-btn mdt-btn-primary" id="med-board-save">Publier</button>`);
            b('med-board-save', () => {
                const msg = (el('med-board-msg').value || '').trim();
                if (!msg) { toast('Le message est vide.', false); return; }
                fetchNui('mdtmed:postBoard', { message: msg });
                closeModal();
            });
        });
        document.querySelectorAll('.med-board-del').forEach((btn) => {
            btn.addEventListener('click', () => {
                confirmAction('Retirer ce message du tableau de bord ?', () => {
                    fetchNui('mdtmed:removeBoard', { id: btn.dataset.id });
                });
            });
        });
    }
}

/* ════════════════════════════════════════════════════════════════
   2. DOSSIER MÉDICAL
   ════════════════════════════════════════════════════════════════ */
function renderMedRecords() {
    medStopDispatchTimer();
    medState.currentPatient = null;
    setContent(`
        <div class="mdt-page-title">Dossiers médicaux</div>
        <div class="mdt-page-sub">Identité, antécédents, allergies, actes et traitements. Aucune donnée judiciaire.</div>
        <div class="mdt-searchbar">
            <input class="mdt-input" id="med-rec-search" placeholder="Nom ou prénom du patient…" autocomplete="off">
            <button class="mdt-btn mdt-btn-primary" id="med-rec-search-btn">🔍 Rechercher</button>
        </div>
        <div id="med-rec-results"></div>
    `);

    const run = async () => {
        const q = el('med-rec-search').value.trim();
        if (q.length < 2) {
            el('med-rec-results').innerHTML = emptyState('🔎', 'Saisissez au moins 2 caractères.');
            return;
        }
        el('med-rec-results').innerHTML = emptyState('⏳', 'Recherche…');
        const rows = asArray(await fetchNui('mdtmed:searchPatients', { query: q }));
        if (!el('med-rec-results')) return;
        if (!rows.length) { el('med-rec-results').innerHTML = emptyState('🚫', 'Aucun patient trouvé.'); return; }
        el('med-rec-results').innerHTML = `<div class="mdt-list">` + rows.map((r) => `
            <div class="mdt-list-item" data-id="${esc(r.character_id != null ? r.character_id : '')}">
                <div class="mdt-li-main">
                    <div class="mdt-li-name">
                        ${esc(r.name)}
                        ${r.hasRecord ? '<span class="med-badge med-badge-ok">Dossier</span>' : '<span class="med-badge med-badge-new">Nouveau</span>'}
                        ${r.activeTreatments > 0 ? `<span class="med-badge med-badge-warn">${r.activeTreatments} traitement(s)</span>` : ''}
                    </div>
                    <div class="mdt-li-sub">${esc(r.sexe || '?')} · Né(e) le ${esc(r.ddn || '?')}</div>
                </div>
                <span class="mdt-badge mdt-badge-blue">Ouvrir →</span>
            </div>`).join('') + `</div>`;
        document.querySelectorAll('#med-rec-results .mdt-list-item').forEach((it) => {
            it.addEventListener('click', () => openMedPatient(it.dataset.id));
        });
    };

    b('med-rec-search-btn', run);
    el('med-rec-search').addEventListener('keydown', (e) => { if (e.key === 'Enter') run(); });
    el('med-rec-search').focus();
}

async function openMedPatient(characterId) {
    medState.currentPatient = characterId;
    setContent(emptyState('⏳', 'Chargement du dossier…'));
    const cfg = await medConfig();
    const data = await fetchNui('mdtmed:getPatient', { character_id: characterId });
    if (!data || !data.identity) { setContent(emptyState('🚫', 'Dossier introuvable ou accès refusé.')); return; }

    const id = data.identity;
    const identifier = id.identifier;
    const rec = data.record || null;
    const entries = asArray(data.entries);
    const treatments = asArray(data.treatments);
    const activeTr = treatments.filter((t) => t.status === 'actif');

    setContent(`
        <div class="mdt-back" id="med-back">← Retour à la recherche</div>
        <div class="mdt-page-title">
            ${esc(id.name)}
            ${rec && Number(rec.dnr) === 1 ? '<span class="med-flag-dnr">NE PAS RÉANIMER</span>' : ''}
        </div>
        <div class="mdt-page-sub">${esc(id.sexe || '?')} · Né(e) le ${esc(id.ddn || '?')} à ${esc(id.ldn || '?')}</div>

        <div class="mdt-grid-2">
            <div class="mdt-card">
                <div class="mdt-card-title">Identité</div>
                <dl class="mdt-kv">
                    <dt>Nom</dt><dd>${esc(id.nom || '?')}</dd>
                    <dt>Prénom</dt><dd>${esc(id.prenom || '?')}</dd>
                    <dt>Sexe</dt><dd>${esc(id.sexe || '?')}</dd>
                    <dt>Naissance</dt><dd>${esc(id.ddn || '?')}</dd>
                    <dt>Taille</dt><dd>${esc(id.taille || '?')} cm</dd>
                </dl>
            </div>
            <div class="mdt-card">
                <div class="mdt-card-title">
                    Fiche médicale
                    ${has('edit_med_records') ? `<button class="mdt-btn mdt-btn-primary med-inline-btn" id="med-edit-rec">✎ Modifier</button>` : ''}
                </div>
                ${rec ? `
                    <dl class="mdt-kv">
                        <dt>Groupe sanguin</dt><dd><b>${esc(rec.blood_group || '—')}</b></dd>
                        <dt>Allergies</dt><dd>${esc(rec.allergies || 'Aucune connue')}</dd>
                        <dt>Antécédents</dt><dd>${esc(rec.antecedents || '—')}</dd>
                        <dt>En cours</dt><dd>${esc(rec.ongoing || '—')}</dd>
                        <dt>Traitements actifs</dt><dd><b>${activeTr.length}</b></dd>
                        <dt>Mise à jour</dt><dd>${fmtDate(rec.updated_at)} · ${esc(rec.updated_by || '?')}</dd>
                    </dl>
                    ${rec.notes ? `<div class="med-notes"><b>Notes</b><p>${esc(rec.notes)}</p></div>` : ''}
                ` : `<div class="med-muted">Aucune fiche médicale. ${has('edit_med_records') ? 'Cliquez sur « Modifier » pour la créer.' : ''}</div>`}
            </div>
        </div>

        <div class="mdt-card">
            <div class="mdt-card-title">
                Traitements (${treatments.length})
                ${has('manage_treatments') ? `<button class="mdt-btn mdt-btn-primary med-inline-btn" id="med-add-tr">＋ Prescrire</button>` : ''}
            </div>
            <div id="med-patient-tr">${medTreatmentTable(treatments, cfg, false)}</div>
        </div>

        <div class="mdt-card">
            <div class="mdt-card-title">
                Historique médical (${entries.length})
                ${has('med_add_entry') ? `<button class="mdt-btn mdt-btn-primary med-inline-btn" id="med-add-entry">＋ Nouvelle entrée</button>` : ''}
            </div>
            ${entries.length ? `<div class="med-timeline">` + entries.map((e) => `
                <div class="med-tl-item">
                    <div class="med-tl-head">
                        <span class="med-badge med-badge-type">${esc(medLabelOf(cfg.entryTypes, e.type, 'id', 'label'))}</span>
                        <b>${esc(e.title)}</b>
                        <span class="med-tl-date">${fmtDate(e.created_at)}</span>
                        ${has('med_delete_entry') ? `<button class="med-tl-del" data-id="${esc(e.id)}" title="Supprimer">✕</button>` : ''}
                    </div>
                    ${e.content ? `<div class="med-tl-body">${esc(e.content)}</div>` : ''}
                    <div class="med-tl-author">Par ${esc(e.author_name || '?')}</div>
                </div>`).join('') + `</div>`
            : emptyState('📋', 'Aucune entrée dans ce dossier.')}
        </div>
    `);

    b('med-back', renderMedRecords);

    /* ── Modification de la fiche médicale ── */
    if (has('edit_med_records')) {
        b('med-edit-rec', () => {
            const r = rec || {};
            openModal('Fiche médicale',
                `<label class="mdt-label">Groupe sanguin</label>
                 <select class="mdt-input" id="med-f-bg">
                    <option value="">— Inconnu —</option>
                    ${(cfg.bloodGroups || []).map((g) => `<option value="${esc(g)}"${r.blood_group === g ? ' selected' : ''}>${esc(g)}</option>`).join('')}
                 </select>
                 <label class="mdt-label">Allergies</label>
                 <input class="mdt-input" id="med-f-al" value="${esc(r.allergies || '')}" placeholder="Pénicilline, arachides…">
                 <label class="mdt-label">Antécédents</label>
                 <textarea class="mdt-textarea" id="med-f-an" rows="3">${esc(r.antecedents || '')}</textarea>
                 <label class="mdt-label">Traitement(s) en cours</label>
                 <textarea class="mdt-textarea" id="med-f-on" rows="2">${esc(r.ongoing || '')}</textarea>
                 <label class="mdt-label">Notes</label>
                 <textarea class="mdt-textarea" id="med-f-no" rows="3">${esc(r.notes || '')}</textarea>
                 <label class="mdt-check">
                    <input type="checkbox" id="med-f-dnr"${Number(r.dnr) === 1 ? ' checked' : ''}>
                    Directive « ne pas réanimer »
                 </label>`,
                `<button class="mdt-btn" onclick="window.__mdtCloseModal()">Annuler</button>
                 <button class="mdt-btn mdt-btn-primary" id="med-f-save">Enregistrer</button>`);
            b('med-f-save', () => {
                fetchNui('mdtmed:saveRecord', {
                    identifier:  identifier,
                    blood_group: el('med-f-bg').value,
                    allergies:   el('med-f-al').value,
                    antecedents: el('med-f-an').value,
                    ongoing:     el('med-f-on').value,
                    notes:       el('med-f-no').value,
                    dnr:         el('med-f-dnr').checked,
                });
                closeModal();
            });
        });
    }

    /* ── Nouvelle entrée de dossier ── */
    if (has('med_add_entry')) {
        b('med-add-entry', () => {
            openModal('Nouvelle entrée',
                `<label class="mdt-label">Type</label>
                 ${medSelect('med-e-type', cfg.entryTypes, 'consultation', 'id', 'label')}
                 <label class="mdt-label">Titre</label>
                 <input class="mdt-input" id="med-e-title" placeholder="Motif de l'acte…">
                 <label class="mdt-label">Détail</label>
                 <textarea class="mdt-textarea" id="med-e-content" rows="6" placeholder="Observations, soins réalisés…"></textarea>`,
                `<button class="mdt-btn" onclick="window.__mdtCloseModal()">Annuler</button>
                 <button class="mdt-btn mdt-btn-primary" id="med-e-save">Enregistrer</button>`);
            b('med-e-save', () => {
                const title = (el('med-e-title').value || '').trim();
                if (!title) { toast('Le titre est obligatoire.', false); return; }
                fetchNui('mdtmed:addEntry', {
                    identifier: identifier,
                    type:       el('med-e-type').value,
                    title:      title,
                    content:    el('med-e-content').value,
                });
                closeModal();
            });
        });
    }

    /* ── Suppression d'une entrée ── */
    document.querySelectorAll('.med-tl-del').forEach((btn) => {
        btn.addEventListener('click', () => {
            confirmAction('Supprimer définitivement cette entrée du dossier ?', () => {
                fetchNui('mdtmed:deleteEntry', { id: btn.dataset.id });
            });
        });
    });

    /* ── Prescription depuis la fiche patient ── */
    if (has('manage_treatments')) {
        b('med-add-tr', () => medPrescribeModal(identifier, cfg));
    }
    medBindTreatmentActions();
}

/* Modale de prescription, partagée entre la fiche patient et l'onglet
   Traitements (où le patient est déjà connu). */
function medPrescribeModal(identifier, cfg) {
    openModal('Prescrire un traitement',
        `<label class="mdt-label">Traitement du catalogue</label>
         <select class="mdt-input" id="med-t-code">
            <option value="">— Saisie libre —</option>
            ${(cfg.treatments || []).map((t) => `<option value="${esc(t.code)}" data-label="${esc(t.label)}" data-dosage="${esc(t.dosage || '')}">${esc(t.code)} · ${esc(t.label)}</option>`).join('')}
         </select>
         <label class="mdt-label">Libellé</label>
         <input class="mdt-input" id="med-t-label" placeholder="Nom du traitement">
         <label class="mdt-label">Dosage</label>
         <input class="mdt-input" id="med-t-dosage" placeholder="ex : 1 g / 6 h">
         <label class="mdt-label">Durée</label>
         <input class="mdt-input" id="med-t-duration" placeholder="ex : 7 jours">
         <label class="mdt-label">Notes</label>
         <textarea class="mdt-textarea" id="med-t-notes" rows="3"></textarea>`,
        `<button class="mdt-btn" onclick="window.__mdtCloseModal()">Annuler</button>
         <button class="mdt-btn mdt-btn-primary" id="med-t-save">Prescrire</button>`);

    /* Sélectionner un code remplit libellé + dosage (restent éditables). */
    el('med-t-code').addEventListener('change', (e) => {
        const opt = e.target.selectedOptions[0];
        if (opt && opt.value) {
            el('med-t-label').value = opt.dataset.label || '';
            el('med-t-dosage').value = opt.dataset.dosage || '';
        }
    });

    b('med-t-save', () => {
        const label = (el('med-t-label').value || '').trim();
        if (!label) { toast('Le libellé est obligatoire.', false); return; }
        fetchNui('mdtmed:addTreatment', {
            identifier: identifier,
            code:       el('med-t-code').value,
            label:      label,
            dosage:     el('med-t-dosage').value,
            duration:   el('med-t-duration').value,
            notes:      el('med-t-notes').value,
        });
        closeModal();
    });
}

/* ════════════════════════════════════════════════════════════════
   3. TRAITEMENTS (tous patients)
   ════════════════════════════════════════════════════════════════ */
function medTreatmentTable(rows, cfg, showPatient) {
    if (!rows.length) return emptyState('💊', 'Aucun traitement.');
    return `<table class="mdt-table med-table">
        <thead><tr>
            ${showPatient ? '<th>Patient</th>' : ''}
            <th>Traitement</th><th>Dosage</th><th>Durée</th>
            <th>Prescrit par</th><th>Le</th><th>Statut</th><th></th>
        </tr></thead>
        <tbody>${rows.map((t) => `
            <tr>
                ${showPatient ? `<td><b>${esc(t.patientName || '?')}</b></td>` : ''}
                <td>
                    <b>${esc(t.label)}</b>
                    ${t.code ? `<span class="med-code">${esc(t.code)}</span>` : ''}
                    ${t.notes ? `<div class="med-sub">${esc(t.notes)}</div>` : ''}
                </td>
                <td>${esc(t.dosage || '—')}</td>
                <td>${esc(t.duration || '—')}</td>
                <td>${esc(t.prescriber_name || '?')}</td>
                <td>${fmtDate(t.created_at)}</td>
                <td>${medTreatmentBadge(t.status, cfg)}</td>
                <td class="med-actions">
                    ${has('manage_treatments') && t.status === 'actif' ? `
                        <button class="mdt-btn mdt-btn-sm med-tr-done" data-id="${esc(t.id)}">Terminer</button>
                        <button class="mdt-btn mdt-btn-sm mdt-btn-danger med-tr-cancel" data-id="${esc(t.id)}">Annuler</button>
                    ` : ''}
                    ${has('manage_treatments') && t.status !== 'actif' ? `
                        <button class="mdt-btn mdt-btn-sm med-tr-reopen" data-id="${esc(t.id)}">Réactiver</button>
                    ` : ''}
                </td>
            </tr>`).join('')}</tbody>
    </table>`;
}

function medTreatmentBadge(status, cfg) {
    const label = esc(medLabelOf(cfg && cfg.treatmentStatuses, status, 'id', 'label'));
    const cls = status === 'actif' ? 'med-badge-ok' : (status === 'annule' ? 'med-badge-err' : 'med-badge-neutral');
    return `<span class="med-badge ${cls}">${label}</span>`;
}

/* Boutons de changement de statut (présents dans les deux vues). */
function medBindTreatmentActions() {
    const send = (id, status) => fetchNui('mdtmed:setTreatmentStatus', { id, status });
    document.querySelectorAll('.med-tr-done').forEach((btn) =>
        btn.addEventListener('click', () => send(btn.dataset.id, 'termine')));
    document.querySelectorAll('.med-tr-reopen').forEach((btn) =>
        btn.addEventListener('click', () => send(btn.dataset.id, 'actif')));
    document.querySelectorAll('.med-tr-cancel').forEach((btn) =>
        btn.addEventListener('click', () => {
            confirmAction('Annuler ce traitement ?', () => send(btn.dataset.id, 'annule'));
        }));
}

async function renderMedTreatments() {
    medStopDispatchTimer();
    const cfg = await medConfig();
    const statuses = asArray(cfg.treatmentStatuses);

    setContent(`
        <div class="mdt-page-title">Traitements</div>
        <div class="mdt-page-sub">Prescriptions en cours et historique, tous patients confondus.</div>
        <div class="mdt-pills" id="med-tr-filters">
            ${statuses.map((s) => `
                <button class="mdt-pill${s.id === medState.treatmentStatus ? ' active' : ''}" data-st="${esc(s.id)}">
                    ${esc(s.label)}
                </button>`).join('')}
        </div>
        <div id="med-tr-list">${emptyState('⏳', 'Chargement…')}</div>
    `);

    document.querySelectorAll('#med-tr-filters .mdt-pill').forEach((btn) => {
        btn.addEventListener('click', () => {
            medState.treatmentStatus = btn.dataset.st;
            renderMedTreatments();
        });
    });

    const rows = asArray(await fetchNui('mdtmed:getTreatments', { status: medState.treatmentStatus }));
    if (!el('med-tr-list')) return;
    el('med-tr-list').innerHTML = medTreatmentTable(rows, cfg, true);
    medBindTreatmentActions();
}

/* ════════════════════════════════════════════════════════════════
   4. DISPATCH — unités en service et appels
   ════════════════════════════════════════════════════════════════ */
function medCallStatusBadge(status) {
    if (status === 'pending')   return '<span class="med-badge med-badge-warn">En attente</span>';
    if (status === 'assigned')  return '<span class="med-badge med-badge-ok">Pris en charge</span>';
    if (status === 'cancelled') return '<span class="med-badge med-badge-err">Annulé</span>';
    return '<span class="med-badge med-badge-neutral">Clôturé</span>';
}

/* ── Vue Dispatch : unités en service + appels ───────────────────
   Pas de carte : le repérage se fait par nom de quartier (calculé
   serveur, cf. Config.Medical.Districts) et par statut. Une unité
   affectée à un appel ouvert est « en intervention », sinon elle est
   « en patrouille » — c'est le serveur qui tranche, à partir de la
   table des appels.                                                */

function medCallStatusBadge(status) {
    if (status === 'pending')   return '<span class="med-badge med-badge-warn">En attente</span>';
    if (status === 'assigned')  return '<span class="med-badge med-badge-ok">Pris en charge</span>';
    if (status === 'cancelled') return '<span class="med-badge med-badge-err">Annulé</span>';
    return '<span class="med-badge med-badge-neutral">Clôturé</span>';
}

function medUnitStatusBadge(u) {
    return u.status === 'inter'
        ? '<span class="med-badge med-badge-err">En intervention</span>'
        : '<span class="med-badge med-badge-ok">En patrouille</span>';
}

async function renderMedDispatch() {
    medStopDispatchTimer();
    const cfg = await medConfig();
    const dcfg = cfg.dispatch || {};

    setContent(`
        <div class="mdt-page-title">Dispatch</div>
        <div class="mdt-page-sub">Ambulances en service et appels en cours.</div>

        <div class="med-dispatch">
            <div class="med-units-panel">
                <div class="mdt-card-title">Unités en service <span id="med-units-count"></span></div>
                <div id="med-units-list">${emptyState('⏳', 'Chargement…')}</div>
            </div>
            <div class="med-calls">
                <div class="mdt-card-title">Appels en cours</div>
                <div id="med-call-list">${emptyState('⏳', 'Chargement…')}</div>
            </div>
        </div>

        <div class="mdt-card">
            <div class="mdt-card-title">Historique des appels</div>
            <div id="med-call-history">${emptyState('⏳', 'Chargement…')}</div>
        </div>
    `);

    const paint = async () => {
        // La vue a changé : on coupe le timer et on ne touche plus au DOM.
        if (!el('med-units-list')) { medStopDispatchTimer(); return; }
        const d = await fetchNui('mdtmed:getDispatch', {});
        if (!el('med-units-list')) { medStopDispatchTimer(); return; }
        if (!d) return;

        const units = asArray(d.units);
        const calls = asArray(d.calls);

        const cnt = el('med-units-count');
        if (cnt) cnt.textContent = units.length ? `(${units.length})` : '';

        el('med-units-list').innerHTML = units.length ? units.map((u) => `
            <div class="med-unit ${u.status === 'inter' ? 'med-unit-inter' : ''}">
                <div class="med-unit-head">
                    <span class="med-dot"></span>
                    <b>${esc(u.name)}</b>
                    ${medUnitStatusBadge(u)}
                </div>
                <div class="med-unit-sub">${esc(u.gradeLabel)}</div>
                <div class="med-unit-zone">
                    📍 ${esc(u.zone || 'Secteur inconnu')}
                    ${u.inVehicle ? '<span class="med-unit-veh">🚑 en véhicule</span>' : ''}
                </div>
                ${u.status === 'inter' ? `
                    <div class="med-unit-call">
                        Intervention sur l'appel #${esc(u.callId)} — ${esc(u.callCaller || 'Inconnu')}
                        ${u.callZone ? ` · ${esc(u.callZone)}` : ''}
                    </div>` : ''}
            </div>`).join('') : emptyState('🚑', 'Aucune ambulance en service.');

        el('med-call-list').innerHTML = calls.length ? calls.map((c) => `
            <div class="med-call">
                <div class="med-call-head">
                    <b>${esc(c.callerName)}</b>
                    ${medCallStatusBadge(c.status)}
                </div>
                <div class="med-call-sub">${esc(c.reason || 'Appel patient')} · ${fmtDate(c.created_at)}</div>
                ${c.zone ? `<div class="med-call-zone">📍 ${esc(c.zone)}</div>` : ''}
                ${c.assigned_name ? `<div class="med-call-sub">Pris par ${esc(c.assigned_name)}</div>` : ''}
                <div class="med-call-actions">
                    <button class="mdt-btn mdt-btn-sm med-call-gps" data-x="${esc(c.x)}" data-y="${esc(c.y)}">📍 GPS</button>
                    ${has('manage_dispatch') && c.status === 'pending'
                        ? `<button class="mdt-btn mdt-btn-sm mdt-btn-primary med-call-take" data-id="${esc(c.id)}">Prendre</button>` : ''}
                    ${has('manage_dispatch') && (c.status === 'pending' || c.status === 'assigned')
                        ? `<button class="mdt-btn mdt-btn-sm med-call-done" data-id="${esc(c.id)}">Clôturer</button>
                           <button class="mdt-btn mdt-btn-sm mdt-btn-danger med-call-cancel" data-id="${esc(c.id)}">Annuler</button>` : ''}
                </div>
            </div>`).join('') : emptyState('📭', 'Aucun appel en cours.');

        document.querySelectorAll('.med-call-gps').forEach((btn) =>
            btn.addEventListener('click', () => {
                fetchNui('mdtmed:setWaypoint', { x: btn.dataset.x, y: btn.dataset.y });
                toast('Point de rendez-vous marqué sur le GPS.', true);
            }));
        document.querySelectorAll('.med-call-take').forEach((btn) =>
            btn.addEventListener('click', () => fetchNui('mdtmed:assignCall', { id: btn.dataset.id })));
        document.querySelectorAll('.med-call-done').forEach((btn) =>
            btn.addEventListener('click', () => fetchNui('mdtmed:closeCall', { id: btn.dataset.id, status: 'done' })));
        document.querySelectorAll('.med-call-cancel').forEach((btn) =>
            btn.addEventListener('click', () => {
                confirmAction('Annuler cet appel ?', () =>
                    fetchNui('mdtmed:closeCall', { id: btn.dataset.id, status: 'cancelled' }));
            }));
    };

    await paint();
    medState.dispatchTimer = setInterval(paint, dcfg.refreshInterval || 2000);

    const hist = asArray(await fetchNui('mdtmed:getCallHistory', {}));
    if (!el('med-call-history')) return;
    el('med-call-history').innerHTML = hist.length ? `<table class="mdt-table med-table">
        <thead><tr><th>Appelant</th><th>Motif</th><th>Reçu</th><th>Clos</th><th>Pris par</th><th>Statut</th></tr></thead>
        <tbody>${hist.map((c) => `
            <tr>
                <td>${esc(c.caller_name || 'Inconnu')}</td>
                <td>${esc(c.reason || 'Appel patient')}</td>
                <td>${fmtDate(c.created_at)}</td>
                <td>${fmtDate(c.closed_at)}</td>
                <td>${esc(c.assigned_name || '—')}</td>
                <td>${medCallStatusBadge(c.status)}</td>
            </tr>`).join('')}</tbody>
    </table>` : emptyState('📭', 'Aucun appel clos.');
}

/* ════════════════════════════════════════════════════════════════
   5. DOCUMENTS INTERNES
   ════════════════════════════════════════════════════════════════ */
async function renderMedDocs() {
    medStopDispatchTimer();
    const cfg = await medConfig();
    const cats = asArray(cfg.docCategories);

    setContent(`
        <div class="mdt-page-title">Documents internes</div>
        <div class="mdt-page-sub">Protocoles, notes de service et comptes rendus.</div>
        <div class="mdt-searchbar">
            <div class="mdt-pills" id="med-doc-filters">
                <button class="mdt-pill${medState.docCategory === '' ? ' active' : ''}" data-cat="">Tous</button>
                ${cats.map((c) => `<button class="mdt-pill${medState.docCategory === c ? ' active' : ''}" data-cat="${esc(c)}">${esc(c)}</button>`).join('')}
            </div>
            ${has('manage_med_docs') ? `<button class="mdt-btn mdt-btn-primary" id="med-doc-new">＋ Nouveau document</button>` : ''}
        </div>
        <div id="med-doc-list">${emptyState('⏳', 'Chargement…')}</div>
    `);

    document.querySelectorAll('#med-doc-filters .mdt-pill').forEach((btn) => {
        btn.addEventListener('click', () => {
            medState.docCategory = btn.dataset.cat;
            renderMedDocs();
        });
    });

    if (has('manage_med_docs')) {
        b('med-doc-new', () => medDocModal(null, cfg));
    }

    const rows = asArray(await fetchNui('mdtmed:getDocs', { category: medState.docCategory }));
    if (!el('med-doc-list')) return;
    el('med-doc-list').innerHTML = rows.length ? `<div class="mdt-list">` + rows.map((d) => `
        <div class="mdt-list-item med-doc-item" data-id="${esc(d.id)}">
            <div class="mdt-li-main">
                <div class="mdt-li-name">
                    ${Number(d.pinned) === 1 ? '<span class="med-pin">📌</span>' : ''}
                    ${esc(d.title)}
                    <span class="med-badge med-badge-type">${esc(d.category)}</span>
                </div>
                <div class="mdt-li-sub">Par ${esc(d.author_name || '?')} · ${fmtDate(d.updated_at)}</div>
            </div>
            <span class="mdt-badge mdt-badge-blue">Lire →</span>
        </div>`).join('') + `</div>` : emptyState('📄', 'Aucun document.');

    document.querySelectorAll('.med-doc-item').forEach((it) => {
        it.addEventListener('click', () => {
            const doc = rows.find((r) => String(r.id) === String(it.dataset.id));
            if (doc) medDocView(doc, cfg);
        });
    });
}

function medDocView(doc, cfg) {
    openModal(doc.title,
        `<div class="med-doc-meta">
            <span class="med-badge med-badge-type">${esc(doc.category)}</span>
            Par ${esc(doc.author_name || '?')} · ${fmtDate(doc.updated_at)}
         </div>
         <div class="med-doc-content">${esc(doc.content || '')}</div>`,
        `${has('manage_med_docs') ? `
            <button class="mdt-btn mdt-btn-danger" id="med-doc-del">Supprimer</button>
            <button class="mdt-btn mdt-btn-primary" id="med-doc-edit">✎ Modifier</button>` : ''}
         <button class="mdt-btn" onclick="window.__mdtCloseModal()">Fermer</button>`);

    if (has('manage_med_docs')) {
        b('med-doc-edit', () => medDocModal(doc, cfg));
        b('med-doc-del', () => {
            confirmAction(`Supprimer définitivement « ${doc.title} » ?`, () => {
                fetchNui('mdtmed:deleteDoc', { id: doc.id });
                closeModal();
            });
        });
    }
}

function medDocModal(doc, cfg) {
    const d = doc || {};
    openModal(doc ? 'Modifier le document' : 'Nouveau document',
        `<label class="mdt-label">Catégorie</label>
         ${medSelect('med-d-cat', cfg.docCategories, d.category || 'Général')}
         <label class="mdt-label">Titre</label>
         <input class="mdt-input" id="med-d-title" value="${esc(d.title || '')}" placeholder="Titre du document">
         <label class="mdt-label">Contenu</label>
         <textarea class="mdt-textarea" id="med-d-content" rows="10">${esc(d.content || '')}</textarea>
         <label class="mdt-check">
            <input type="checkbox" id="med-d-pin"${Number(d.pinned) === 1 ? ' checked' : ''}>
            Épingler en haut de la liste
         </label>`,
        `<button class="mdt-btn" onclick="window.__mdtCloseModal()">Annuler</button>
         <button class="mdt-btn mdt-btn-primary" id="med-d-save">Enregistrer</button>`);

    b('med-d-save', () => {
        const title = (el('med-d-title').value || '').trim();
        if (!title) { toast('Le titre est obligatoire.', false); return; }
        fetchNui('mdtmed:saveDoc', {
            id:       d.id,
            category: el('med-d-cat').value,
            title:    title,
            content:  el('med-d-content').value,
            pinned:   el('med-d-pin').checked,
        });
        closeModal();
    });
}

/* ════════════════════════════════════════════════════════════════
   Enregistrement dans les points d'extension de mdt.js
   ════════════════════════════════════════════════════════════════ */
window.MDT_RENDERERS = Object.assign(window.MDT_RENDERERS || {}, {
    dashboard:      renderMedDashboard,
    med_records:    renderMedRecords,
    med_treatments: renderMedTreatments,
    med_dispatch:   renderMedDispatch,
    med_docs:       renderMedDocs,
});

/* Rafraîchissement après écriture. Renvoie true si on a traité la
   demande, ce qui évite à mdt.js de la reprendre. */
window.MDT_EXT_REFRESH = function (refresh) {
    const v = refresh && refresh.view;
    if (!v || String(v).indexOf('med_') !== 0) return false;

    if (v === 'med_dashboard') {
        if (state.currentTab === 'dashboard') renderMedDashboard();
    } else if (v === 'med_patient') {
        if (state.currentTab === 'med_records' && medState.currentPatient) {
            openMedPatient(medState.currentPatient);
        }
    } else if (v === 'med_treatments') {
        // La prescription peut venir de la fiche patient comme de l'onglet
        // Traitements : on rafraîchit la vue réellement affichée.
        if (state.currentTab === 'med_treatments') renderMedTreatments();
        else if (state.currentTab === 'med_records' && medState.currentPatient) {
            openMedPatient(medState.currentPatient);
        }
    } else if (v === 'med_dispatch') {
        // Le dispatch se rafraîchit déjà tout seul via son timer.
    } else if (v === 'med_docs') {
        if (state.currentTab === 'med_docs') renderMedDocs();
    }
    return true;
};
