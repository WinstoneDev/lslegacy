/* ════════════════════════════════════════════════════════════════
   MDT — Logique de l'interface (NUI)
   Le serveur pilote l'ouverture (permissions, onglets, services).
   Lectures  → fetch POST (callback serveur).
   Écritures → fetch POST (event serveur tokenisé) ; le serveur répond
               via 'mdt:result' → refresh ciblé.
   ════════════════════════════════════════════════════════════════ */

const RES = 'lslegacy';

const state = {
    payload: null,
    perms: {},
    tabs: [],
    currentTab: null,
    currentCitizen: null,   // identifier de la fiche ouverte
    currentWarrantStatus: 'active',
};

/* ── Helpers DOM / util ──────────────────────────────────────── */
const $ = (sel) => document.querySelector(sel);
const el = (id) => document.getElementById(id);

function esc(v) {
    if (v === null || v === undefined) return '';
    return String(v)
        .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

function asArray(x) { return Array.isArray(x) ? x : []; }

function fmtDate(v) {
    if (!v) return '—';
    let d;
    if (typeof v === 'number') d = new Date(v);
    else d = new Date(String(v).replace(' ', 'T'));
    if (isNaN(d.getTime())) return esc(v);
    const p = (n) => String(n).padStart(2, '0');
    return `${p(d.getDate())}/${p(d.getMonth() + 1)}/${d.getFullYear()} ${p(d.getHours())}:${p(d.getMinutes())}`;
}

function has(perm) { return !!state.perms[perm] || !!state.perms.admin_mdt; }

/* Estampille d'origine d'une pièce du dossier commun aux forces de
   l'ordre : « Police » ou « Gendarmerie » selon le pôle qui l'a saisie.

   Rien n'est affiché quand le département est seul dans sa sphère de
   données : le badge n'apprendrait rien et alourdirait les tableaux du
   SAMU ou des pompiers, qui ne partagent leur base avec personne. */
function depBadge(dep) {
    if (!dep || !state.depMulti) return '';
    const d = state.depLabels[dep];
    if (!d) return '';
    /* La couleur vient de la config du département (serveur), pas du
       client : elle peut être injectée telle quelle dans le style. */
    const style = d.color ? ` style="background:${esc(d.color)}"` : '';
    return `<span class="mdt-dep-badge"${style} title="Saisi par : ${esc(d.label || dep)}">${esc(d.short || d.label || dep)}</span>`;
}

// Date au format FR JJ/MM/AAAA. Gère : nombre (epoch ms, retour oxmysql),
// string ISO "YYYY-MM-DD[...]" ou datetime "YYYY-MM-DD HH:MM:SS".
function fmtDateFR(v) {
    if (!v && v !== 0) return '—';
    if (typeof v === 'number') {
        const d = new Date(v);
        if (isNaN(d.getTime())) return '—';
        const p = (n) => String(n).padStart(2, '0');
        return `${p(d.getDate())}/${p(d.getMonth() + 1)}/${d.getFullYear()}`;
    }
    const m = String(v).match(/^(\d{4})-(\d{2})-(\d{2})/);
    if (m) return `${m[3]}/${m[2]}/${m[1]}`;
    const d = new Date(String(v).replace(' ', 'T'));
    if (!isNaN(d.getTime())) {
        const p = (n) => String(n).padStart(2, '0');
        return `${p(d.getDate())}/${p(d.getMonth() + 1)}/${d.getFullYear()}`;
    }
    return esc(v);
}

// Convertit une date (nombre epoch ou string) en ISO YYYY-MM-DD (pour <input type=date>)
function toISODate(v) {
    if (!v && v !== 0) return '';
    const m = String(v).match(/^(\d{4})-(\d{2})-(\d{2})/);
    if (m) return m[0];
    const d = (typeof v === 'number') ? new Date(v) : new Date(String(v).replace(' ', 'T'));
    if (isNaN(d.getTime())) return '';
    const p = (n) => String(n).padStart(2, '0');
    return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
}

// Attache un listener click si l'élément existe (helper global)
function b(id, fn) { const e = el(id); if (e) e.addEventListener('click', fn); }

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

/* ── Toasts ──────────────────────────────────────────────────── */
function toast(message, ok) {
    const t = document.createElement('div');
    t.className = 'mdt-toast ' + (ok ? 'ok' : 'err');
    t.textContent = message;
    el('mdt-toasts').appendChild(t);
    setTimeout(() => t.remove(), 3500);
}

// Copie dans le presse-papier (méthode execCommand, compatible NUI/CEF)
function copyText(text) {
    const v = String(text == null ? '' : text);
    if (!v) return;
    let ok = false;
    try {
        const ta = document.createElement('textarea');
        ta.value = v;
        ta.style.position = 'fixed';
        ta.style.opacity = '0';
        document.body.appendChild(ta);
        ta.focus(); ta.select();
        ok = document.execCommand('copy');
        document.body.removeChild(ta);
    } catch (e) { ok = false; }
    toast(ok ? ('Référence copiée : ' + v) : 'Copie impossible.', ok);
}

/* ── Modale ──────────────────────────────────────────────────── */
function openModal(title, bodyHtml, footerHtml) {
    el('mdt-modal-title').textContent = title;
    el('mdt-modal-body').innerHTML = bodyHtml;
    el('mdt-modal-footer').innerHTML = footerHtml || '';
    el('mdt-modal-overlay').classList.remove('mdt-hidden');
}
function closeModal() { el('mdt-modal-overlay').classList.add('mdt-hidden'); }

// Modale de confirmation réutilisable (action sensible)
function confirmAction(message, onConfirm) {
    openModal('Confirmation', `<p style="font-size:14px;line-height:1.5">${esc(message)}</p>`,
        `<button class="mdt-btn" onclick="window.__mdtCloseModal()">Annuler</button>
         <button class="mdt-btn mdt-btn-danger" id="mdt-confirm-btn">Confirmer</button>`);
    el('mdt-confirm-btn').addEventListener('click', () => { closeModal(); onConfirm(); });
}

/* ════════════════════════════════════════════════════════════════
   Ouverture / message bridge
   ════════════════════════════════════════════════════════════════ */
window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data || !data.action) return;
    if (data.action === 'mdt:open') openMDT(data.data);
    else if (data.action === 'mdt:hide') hideMDT();
    else if (data.action === 'mdt:refresh') handleRefresh(data.refresh);
});

function openMDT(payload) {
    if (!payload) return;
    state.payload = payload;
    state.perms = payload.permissions || {};
    state.tabs = asArray(payload.tabs);
    /* Sphère de données : au-delà d'un département, chaque pièce du dossier
       est estampillée du pôle qui l'a saisie (voir depBadge). */
    state.depLabels = payload.departmentLabels || {};
    state.depMulti = asArray(payload.dataGroup).length > 1;
    el('mdt-dep-label').textContent = payload.departmentLabel || 'MDT';
    el('mdt-officer-name').textContent = payload.officerName || '—';
    el('mdt-officer-grade').textContent = payload.gradeLabel || '—';
    if (payload.departmentColor) {
        document.documentElement.style.setProperty('--mdt-blue-dk', payload.departmentColor);
    }
    renderSidebar();
    if (state.tabs.length) selectTab(state.tabs[0].id);
    el('mdt').classList.remove('mdt-hidden');
}

function hideMDT() {
    el('mdt').classList.add('mdt-hidden');
    closeModal();
}

function closeMDT() { fetchNui('mdt:close', {}); hideMDT(); }

/* ── Sidebar / navigation ────────────────────────────────────── */
function renderSidebar() {
    const nav = el('mdt-sidebar');
    nav.innerHTML = '';
    state.tabs.forEach((tab) => {
        const d = document.createElement('div');
        d.className = 'mdt-tab';
        d.dataset.tab = tab.id;
        d.innerHTML = `<span class="mdt-tab-icon">${esc(tab.icon || '•')}</span><span>${esc(tab.label)}</span>`;
        d.addEventListener('click', () => selectTab(tab.id));
        nav.appendChild(d);
    });
}

function selectTab(id) {
    state.currentTab = id;
    document.querySelectorAll('.mdt-tab').forEach((t) => t.classList.toggle('active', t.dataset.tab === id));
    // Registre extensible : les modules métier (ex. MDT médical SAMU,
    // js/medical.js) ajoutent leurs onglets via window.MDT_RENDERERS
    // plutôt qu'en éditant cette liste.
    const renderers = Object.assign({
        citizens: renderCitizens,
        vehicles: renderVehicles,
        weapons: renderWeapons,
        int_reports: renderInterventionReports,
        dossiers: renderDossiers,
        warrants: renderWarrants,
        custody: renderCustody,
        investigation: renderInvestigation,
        laws: renderLaws,
        effectifs: renderEffectifs,
        trainings: renderTrainings,
        organisation: renderOrganisation,
    }, window.MDT_RENDERERS || {});
    (renderers[id] || renderUnknown)();
}

function renderUnknown() { el('mdt-content').innerHTML = `<div class="mdt-empty">Section indisponible.</div>`; }
function setContent(html) { el('mdt-content').innerHTML = html; }
function emptyState(ico, msg) { return `<div class="mdt-empty"><span class="mdt-empty-ico">${ico}</span>${esc(msg)}</div>`; }

/* ════════════════════════════════════════════════════════════════
   ONGLET — CITOYENS
   ════════════════════════════════════════════════════════════════ */
function renderCitizens() {
    state.currentCitizen = null;
    setContent(`
        <div class="mdt-page-title">Gestion des citoyens</div>
        <div class="mdt-page-sub">Recherche d'identité, casier judiciaire, amendes, gardes à vue.</div>
        <div class="mdt-searchbar">
            <input class="mdt-input" id="cz-search" placeholder="Nom ou prénom du citoyen…" autocomplete="off">
            <button class="mdt-btn mdt-btn-primary" id="cz-search-btn">🔍 Rechercher</button>
        </div>
        <div id="cz-results"></div>
    `);
    const run = async () => {
        const q = el('cz-search').value.trim();
        if (q.length < 2) { el('cz-results').innerHTML = emptyState('🔎', 'Saisissez au moins 2 caractères.'); return; }
        el('cz-results').innerHTML = emptyState('⏳', 'Recherche…');
        const rows = asArray(await fetchNui('mdt:searchCitizens', { query: q }));
        if (!el('cz-results')) return;
        if (!rows.length) { el('cz-results').innerHTML = emptyState('🚫', 'Aucun citoyen trouvé.'); return; }
        el('cz-results').innerHTML = `<div class="mdt-list">` + rows.map((r) => `
            <div class="mdt-list-item" data-id="${esc(r.identifier)}">
                <div class="mdt-li-main">
                    <div class="mdt-li-name">${esc(r.name)} ${r.wanted ? '<span class="mdt-wanted-flag">Recherché</span>' : ''}</div>
                    <div class="mdt-li-sub">${esc(r.sexe || '?')} · Né(e) le ${esc(r.ddn || '?')}</div>
                </div>
                <span class="mdt-badge mdt-badge-blue">Ouvrir →</span>
            </div>`).join('') + `</div>`;
        document.querySelectorAll('#cz-results .mdt-list-item').forEach((it) => {
            it.addEventListener('click', () => openCitizenFile(it.dataset.id));
        });
    };
    el('cz-search-btn').addEventListener('click', run);
    el('cz-search').addEventListener('keydown', (e) => { if (e.key === 'Enter') run(); });
    el('cz-search').focus();
}

async function openCitizenFile(identifier) {
    state.currentCitizen = identifier;
    setContent(emptyState('⏳', 'Chargement de la fiche…'));
    const data = await fetchNui('mdt:getCitizen', { identifier });
    if (!data || !data.identity) { setContent(emptyState('🚫', 'Fiche introuvable ou accès refusé.')); return; }
    const id = data.identity;
    const records = asArray(data.records), fines = asArray(data.fines), warrants = asArray(data.warrants), custody = asArray(data.custody);
    const totalFines = fines.reduce((s, f) => s + (f.paid ? 0 : (parseInt(f.amount) || 0)), 0);
    const isWanted = warrants.some((w) => w.status === 'active');

    setContent(`
        <div class="mdt-back" id="cz-back">← Retour à la recherche</div>
        <div class="mdt-page-title">${esc(id.name)}${isWanted ? ' <span class="mdt-wanted-flag">RECHERCHE</span>' : ''}</div>
        <div class="mdt-page-sub">${esc(id.sexe || '?')} · Né(e) le ${esc(id.ddn || '?')} à ${esc(id.ldn || '?')}</div>

        <div class="mdt-grid-2">
            <div class="mdt-card">
                <div class="mdt-card-title">Identité</div>
                <dl class="mdt-kv">
                    <dt>Nom</dt><dd>${esc(id.nom || '?')}</dd>
                    <dt>Prénom</dt><dd>${esc(id.prenom || '?')}</dd>
                    <dt>Sexe</dt><dd>${esc(id.sexe || '?')}</dd>
                    <dt>Naissance</dt><dd>${esc(id.ddn || '?')}</dd>
                    <dt>Lieu</dt><dd>${esc(id.ldn || '?')}</dd>
                    <dt>Taille</dt><dd>${esc(id.taille || '?')} cm</dd>
                </dl>
            </div>
            <div class="mdt-card">
                <div class="mdt-card-title">Synthèse</div>
                <dl class="mdt-kv">
                    <dt>Permis</dt><dd>${(asArray(id.licenses).length ? asArray(id.licenses).map(esc).join(', ') : 'Aucun')}</dd>
                    <dt>Casier</dt><dd>${records.length} entrée(s)</dd>
                    <dt>Amendes</dt><dd>${fines.length} · <b style="color:var(--mdt-orange)">${totalFines}$ impayé(s)</b></dd>
                    <dt>Avis</dt><dd>${warrants.filter((w) => w.status === 'active').length} actif(s)</dd>
                    <dt>Gardes à vue</dt><dd>${custody.length}</dd>
                </dl>
            </div>
        </div>

        <div class="mdt-card">
            <div class="mdt-card-title">Casier judiciaire
                ${has('manage_records') ? `<button class="mdt-btn mdt-btn-sm mdt-btn-primary" id="cz-add-record">+ Ajouter</button>` : ''}
            </div>
            ${records.length ? `<table class="mdt-table"><thead><tr><th>Date</th><th>Chef d'accusation</th><th>Description</th><th>Agent</th><th></th></tr></thead><tbody>` +
            records.map((r) => `<tr>
                    <td>${fmtDate(r.created_at)}</td>
                    <td><b>${esc(r.charge)}</b></td>
                    <td>${esc(r.description || '—')}</td>
                    <td>${esc(r.officer_name)}${depBadge(r.department)}</td>
                    <td>${has('delete_records') ? `<button class="mdt-btn mdt-btn-sm mdt-btn-danger" data-del-record="${esc(r.id)}">🗑</button>` : ''}</td>
                </tr>`).join('') + `</tbody></table>` : emptyState('📋', 'Casier vierge.')}
        </div>

        <div class="mdt-card">
            <div class="mdt-card-title">Amendes
                ${has('create_fine') ? `<button class="mdt-btn mdt-btn-sm mdt-btn-primary" id="cz-add-fine">+ Verbaliser</button>` : ''}
            </div>
            ${fines.length ? `<table class="mdt-table"><thead><tr><th>Date</th><th>Motif</th><th>Montant</th><th>Plaque</th><th>Statut</th><th>Agent</th><th></th></tr></thead><tbody>` +
            fines.map((f) => `<tr>
                    <td>${fmtDate(f.created_at)}</td>
                    <td>${esc(f.reason)}</td>
                    <td><b>${esc(f.amount)}$</b></td>
                    <td>${esc(f.plate || '—')}</td>
                    <td>${f.paid ? '<span class="mdt-badge mdt-badge-green">Payée</span>' : '<span class="mdt-badge mdt-badge-orange">Impayée</span>'}</td>
                    <td>${esc(f.officer_name)}${depBadge(f.department)}</td>
                    <td>
                        ${has('create_fine') ? `<button class="mdt-btn mdt-btn-sm" data-toggle-fine="${esc(f.id)}" data-paid="${f.paid ? 1 : 0}">${f.paid ? '↩' : '✔'}</button>` : ''}
                        ${has('delete_records') ? `<button class="mdt-btn mdt-btn-sm mdt-btn-danger" data-del-fine="${esc(f.id)}">🗑</button>` : ''}
                    </td>
                </tr>`).join('') + `</tbody></table>` : emptyState('💸', 'Aucune amende.')}
        </div>

        <div class="mdt-card">
            <div class="mdt-card-title">Gardes à vue
                ${has('manage_custody') ? `<button class="mdt-btn mdt-btn-sm mdt-btn-primary" id="cz-add-custody">+ Enregistrer</button>` : ''}
            </div>
            ${custody.length ? `<table class="mdt-table"><thead><tr><th>Début</th><th>Motif</th><th>Durée</th><th>Agent</th><th>PV</th><th></th></tr></thead><tbody>` +
            custody.map((c) => `<tr>
                    <td>${fmtDate(c.started_at)}</td>
                    <td>${esc(c.reason || '—')}</td>
                    <td>${esc(c.duration)} min</td>
                    <td>${esc(c.officer_name)}${depBadge(c.department)}</td>
                    <td>${c.pv ? `<button class="mdt-btn mdt-btn-sm" data-pv="${esc(c.id)}">📄 Voir</button>` : '—'}</td>
                    <td>${has('delete_custody') ? `<button class="mdt-btn mdt-btn-sm mdt-btn-danger" data-del-custody="${esc(c.id)}">🗑</button>` : ''}</td>
                </tr>`).join('') + `</tbody></table>` : emptyState('🔒', 'Aucune garde à vue.')}
        </div>

        <div class="mdt-card">
            <div class="mdt-card-title">Armes associées
                ${has('manage_weapons') ? `<button class="mdt-btn mdt-btn-sm mdt-btn-primary" id="cz-add-weapon">+ Lier une arme</button>` : ''}
            </div>
            <div id="cz-weapons-list">${emptyState('⏳', 'Chargement…')}</div>
        </div>
    `);

    el('cz-back').addEventListener('click', renderCitizens);
    { const awb = el('cz-add-weapon'); if (awb) awb.addEventListener('click', () => formLinkCitizenWeapon(identifier)); }
    const b = (id, fn) => { const e = el(id); if (e) e.addEventListener('click', fn); };
    b('cz-add-record', () => formCriminalRecord(identifier));
    b('cz-add-fine', () => formFine(identifier));
    b('cz-add-custody', () => formCustody(identifier));
    document.querySelectorAll('[data-del-record]').forEach((x) => x.addEventListener('click', () => {
        fetchNui('mdt:deleteCriminalRecord', { id: x.dataset.delRecord, identifier });
    }));
    document.querySelectorAll('[data-del-fine]').forEach((x) => x.addEventListener('click', () => {
        fetchNui('mdt:deleteFine', { id: x.dataset.delFine, identifier });
    }));
    document.querySelectorAll('[data-toggle-fine]').forEach((x) => x.addEventListener('click', () => {
        fetchNui('mdt:toggleFinePaid', { id: x.dataset.toggleFine, paid: x.dataset.paid !== '1', identifier });
    }));
    document.querySelectorAll('[data-pv]').forEach((x) => x.addEventListener('click', () => {
        const c = custody.find((cc) => String(cc.id) === x.dataset.pv);
        openModal('Procès-verbal de garde à vue', `<pre style="white-space:pre-wrap;font-family:var(--mdt-font);font-size:14px;line-height:1.5">${esc(c && c.pv || '')}</pre>`, `<button class="mdt-btn" onclick="window.__mdtCloseModal()">Fermer</button>`);
    }));
    document.querySelectorAll('[data-del-custody]').forEach((x) => x.addEventListener('click', () => {
        confirmAction('Supprimer définitivement cette garde à vue du casier ?', () => {
            fetchNui('mdt:deleteCustody', { id: x.dataset.delCustody, identifier });
        });
    }));

    // Armes associées (chargées séparément)
    if (has('view_weapons')) {
        const weapons = asArray(await fetchNui('mdt:getPersonWeapons', { identifier }));
        const wl = el('cz-weapons-list');
        if (wl) {
            wl.innerHTML = weapons.length ? `<table class="mdt-table"><thead><tr><th>Désignation</th><th>Catégorie</th><th>N° série</th><th>Relation</th><th>Statut</th></tr></thead><tbody>` +
                weapons.map((w) => `<tr class="mdt-row-clickable" data-weapon="${esc(w.id)}" style="cursor:pointer">
                    <td><b>${esc(w.model || 'Arme')}</b></td>
                    <td>${weaponCatLabel(w.category)}</td>
                    <td>${w.serial_number ? esc(w.serial_number) : '—'}</td>
                    <td><span class="mdt-badge mdt-badge-gray">${esc(w.relation)}</span></td>
                    <td>${w.seized ? '<span class="mdt-badge mdt-badge-red">Scellés</span>' : '<span class="mdt-badge mdt-badge-green">—</span>'}</td>
                </tr>`).join('') + `</tbody></table>` : emptyState('🔫', 'Aucune arme associée.');
            wl.querySelectorAll('[data-weapon]').forEach((x) => x.addEventListener('click', () => {
                state.currentTab = 'weapons';
                document.querySelectorAll('.mdt-tab').forEach((t) => t.classList.toggle('active', t.dataset.tab === 'weapons'));
                openWeaponFile(x.dataset.weapon);
            }));
        }
    } else {
        const wl = el('cz-weapons-list'); if (wl) wl.closest('.mdt-card').style.display = 'none';
    }
}

/* ── Formulaires citoyen (modales) ───────────────────────────── */
function formFine(identifier) {
    openModal('Verbaliser un citoyen', `
        <div class="mdt-form-row"><label>Motif</label><input class="mdt-input" id="f-reason" placeholder="Excès de vitesse…"></div>
        <div class="mdt-form-row"><label>Montant ($)</label><input class="mdt-input" id="f-amount" type="number" min="1" placeholder="250"></div>
        <div class="mdt-form-row"><label>Plaque liée (optionnel)</label><input class="mdt-input" id="f-plate" placeholder="ABC123"></div>
    `, `<button class="mdt-btn" onclick="window.__mdtCloseModal()">Annuler</button>
        <button class="mdt-btn mdt-btn-primary" id="f-submit">Verbaliser</button>`);
    el('f-submit').addEventListener('click', () => {
        const reason = el('f-reason').value.trim();
        const amount = parseInt(el('f-amount').value);
        if (!reason || !amount || amount <= 0) { toast('Motif et montant requis.', false); return; }
        fetchNui('mdt:createFine', { identifier, reason, amount, plate: el('f-plate').value.trim() });
        closeModal();
    });
}

function formCriminalRecord(identifier) {
    openModal('Ajouter au casier judiciaire', `
        <div class="mdt-form-row"><label>Chef d'accusation</label><input class="mdt-input" id="r-charge" placeholder="Vol aggravé…"></div>
        <div class="mdt-form-row"><label>Description</label><textarea class="mdt-textarea" id="r-desc" placeholder="Circonstances, détails…"></textarea></div>
    `, `<button class="mdt-btn" onclick="window.__mdtCloseModal()">Annuler</button>
        <button class="mdt-btn mdt-btn-primary" id="r-submit">Ajouter</button>`);
    el('r-submit').addEventListener('click', () => {
        const charge = el('r-charge').value.trim();
        if (!charge) { toast("Chef d'accusation requis.", false); return; }
        fetchNui('mdt:addCriminalRecord', { identifier, charge, description: el('r-desc').value.trim() });
        closeModal();
    });
}

function formCustody(identifier) {
    openModal('Enregistrer une garde à vue', `
        <div class="mdt-soon">⚠️ La mise en cellule (motif/durée/horodatage physique) sera gérée en jeu. Ici : enregistrement et procès-verbal.</div>
        <div class="mdt-form-row"><label>Motif</label><input class="mdt-input" id="c-reason" placeholder="Flagrant délit…"></div>
        <div class="mdt-form-row"><label>Durée (minutes)</label><input class="mdt-input" id="c-duration" type="number" min="0" max="1440" placeholder="120"></div>
        <div class="mdt-form-row"><label>Procès-verbal</label><textarea class="mdt-textarea" id="c-pv" placeholder="Déroulé de la garde à vue…"></textarea></div>
    `, `<button class="mdt-btn" onclick="window.__mdtCloseModal()">Annuler</button>
        <button class="mdt-btn mdt-btn-primary" id="c-submit">Enregistrer</button>`);
    el('c-submit').addEventListener('click', () => {
        const reason = el('c-reason').value.trim();
        if (!reason) { toast('Motif requis.', false); return; }
        fetchNui('mdt:createCustody', { identifier, reason, duration: parseInt(el('c-duration').value) || 0, pv: el('c-pv').value.trim() });
        closeModal();
    });
}

// Lier une arme (par n° de série) au citoyen depuis sa fiche
function formLinkCitizenWeapon(identifier) {
    let relation = 'proprietaire';
    const pill = (v, label) => `<div class="mdt-pill ${v === relation ? 'active' : ''}" data-v="${v}">${label}</div>`;
    openModal('Lier une arme au citoyen', `
        <div class="mdt-form-row"><label>Numéro de série de l'arme</label><input class="mdt-input" id="cw-serial" placeholder="Ex : AB1234567"></div>
        <div class="mdt-form-row"><label>Relation</label>
            <div class="mdt-pills" id="cw-rel">${pill('proprietaire', 'Propriétaire')}${pill('detenteur', 'Détenteur')}${pill('suspect', 'Suspect')}${pill('temoin', 'Témoin')}${pill('lie', 'Lié')}</div>
        </div>
    `, `<button class="mdt-btn" onclick="window.__mdtCloseModal()">Annuler</button>
        <button class="mdt-btn mdt-btn-primary" id="cw-submit">Lier</button>`);
    document.querySelectorAll('#cw-rel .mdt-pill').forEach((p) => p.addEventListener('click', () => {
        relation = p.dataset.v;
        document.querySelectorAll('#cw-rel .mdt-pill').forEach((x) => x.classList.toggle('active', x === p));
    }));
    el('cw-submit').addEventListener('click', () => {
        const serial = el('cw-serial').value.trim();
        if (!serial) { toast('Numéro de série requis.', false); return; }
        fetchNui('mdt:linkPersonWeapon', { identifier, serial, relation });
        closeModal();
    });
}

/* ════════════════════════════════════════════════════════════════
   ONGLET — VÉHICULES
   ════════════════════════════════════════════════════════════════ */
function vehLocation(loc) {
    const m = {
        circulation: { label: 'En circulation', cls: 'mdt-badge-green' },
        concessionnaire: { label: 'Concessionnaire', cls: 'mdt-badge-gray' },
        fourriere: { label: 'Fourrière', cls: 'mdt-badge-blue' },
        saisie: { label: 'Saisie', cls: 'mdt-badge-orange' },
        detruit: { label: 'Détruit', cls: 'mdt-badge-red' },
    };
    return m[loc] || m.circulation;
}

function vtypeLabel(t) {
    const m = {
        car: 'Voiture', automobile: 'Voiture', moto: 'Moto', motorcycle: 'Moto', truck: 'Camion',
        boat: 'Bateau', heli: 'Hélicoptère', helicopter: 'Hélicoptère', plane: 'Avion', bike: 'Vélo', quad: 'Quad'
    };
    return m[String(t || '').toLowerCase()] || (t ? esc(t) : 'Véhicule');
}

function renderVehicles() {
    setContent(`
        <div class="mdt-page-title">Fichier des véhicules</div>
        <div class="mdt-page-sub">Recherche par plaque, propriétaire et historique d'infractions.</div>
        <div class="mdt-searchbar">
            <input class="mdt-input" id="vh-search" placeholder="Plaque d'immatriculation…" autocomplete="off">
            <button class="mdt-btn mdt-btn-primary" id="vh-search-btn">🔍 Rechercher</button>
        </div>
        <div id="vh-results"></div>
    `);
    const run = async () => {
        const q = el('vh-search').value.trim();
        if (q.length < 2) { el('vh-results').innerHTML = emptyState('🔎', 'Saisissez au moins 2 caractères.'); return; }
        el('vh-results').innerHTML = emptyState('⏳', 'Recherche…');
        const rows = asArray(await fetchNui('mdt:searchVehicles', { query: q }));
        if (!el('vh-results')) return;
        if (!rows.length) { el('vh-results').innerHTML = emptyState('🚫', 'Aucun véhicule trouvé.'); return; }
        el('vh-results').innerHTML = `<div class="mdt-list">` + rows.map((r) => `
            <div class="mdt-list-item" data-plate="${esc(r.plate)}">
                <div class="mdt-li-main">
                    <div class="mdt-li-name">${esc(r.plate)} <span class="mdt-badge mdt-badge-gray">${esc(r.model_name || vtypeLabel(r.vtype))}</span></div>
                    <div class="mdt-li-sub">${r.owner_name ? '👤 ' + esc(r.owner_name) : 'Propriétaire inconnu'}${r.color ? ' · 🎨 ' + esc(r.color) : ''}</div>
                </div>
                <span class="mdt-badge ${r.wanted ? 'mdt-badge-red' : 'mdt-badge-green'}">${r.wanted ? '🚨 Recherché' : 'En règle'}</span>
            </div>`).join('') + `</div>`;
        document.querySelectorAll('#vh-results .mdt-list-item').forEach((it) => {
            it.addEventListener('click', () => openVehicleFile(it.dataset.plate));
        });
    };
    el('vh-search-btn').addEventListener('click', run);
    el('vh-search').addEventListener('keydown', (e) => { if (e.key === 'Enter') run(); });
    el('vh-search').focus();
}

async function openVehicleFile(plate) {
    state.currentVehicle = plate;
    setContent(emptyState('⏳', 'Chargement…'));
    const data = await fetchNui('mdt:getVehicle', { plate });
    if (!data || !data.vehicle) { setContent(emptyState('🚫', 'Véhicule introuvable.')); return; }
    const v = data.vehicle, fines = asArray(data.fines), owner = data.owner;
    const canFlag = has('manage_warrants');
    const loc = vehLocation(v.location);
    // 'concessionnaire' (en vente) et 'fourriere' sont gérés automatiquement → non proposés manuellement.
    const autoManaged = v.location === 'concessionnaire' || v.location === 'fourriere';
    const autoNote = v.location === 'fourriere'
        ? '🚧 Véhicule en fourrière (géré par la fourrière).'
        : '🏷️ En vente au concessionnaire (automatique).';
    const locs = [['circulation', 'En circulation'], ['saisie', 'Saisie'], ['detruit', 'Détruit']];
    setContent(`
        <div class="mdt-back" id="vh-back">← Retour à la recherche</div>
        <div class="mdt-page-title">Véhicule ${esc(v.plate)}</div>
        <div class="mdt-grid-2">
            <div class="mdt-card">
                <div class="mdt-card-title">Informations</div>
                <dl class="mdt-kv">
                    <dt>Plaque</dt><dd>${esc(v.plate)}</dd>
                    <dt>Véhicule</dt><dd>${esc(v.model_name || vtypeLabel(v.vtype))}</dd>
                    <dt>Couleur</dt><dd>${v.color ? esc(v.color) : '<span style="color:var(--mdt-text-dim)">Inconnue</span>'}</dd>
                    <dt>Date d'achat</dt><dd>${fmtDateFR(v.bought_at)}</dd>
                    <dt>Localisation</dt><dd><span class="mdt-badge ${loc.cls}">${loc.label}</span></dd>
                </dl>
            </div>
            <div class="mdt-card">
                <div class="mdt-card-title">Statut administratif</div>
                <div style="margin-bottom:10px">${v.wanted
            ? `<span class="mdt-badge mdt-badge-red" style="font-size:14px">🚨 Recherché par les autorités</span>${v.wanted_reason ? `<div style="margin-top:8px;color:var(--mdt-text-dim);font-size:13px">Motif : ${esc(v.wanted_reason)}</div>` : ''}`
            : `<span class="mdt-badge mdt-badge-green" style="font-size:14px">✓ En règle</span>`}</div>
                ${canFlag ? (v.wanted
            ? `<button class="mdt-btn mdt-btn-sm" id="vh-unflag">Lever la recherche</button>`
            : `<button class="mdt-btn mdt-btn-sm mdt-btn-danger" id="vh-flag">🚨 Signaler recherché</button>`) : ''}
                ${canFlag ? `<div style="margin-top:14px;padding-top:12px;border-top:1px solid var(--mdt-border)">
                    <div style="font-size:12px;color:var(--mdt-text-dim);margin-bottom:6px">Localisation</div>
                    ${autoManaged
                ? `<div style="color:var(--mdt-text-dim);font-size:13px">${autoNote}</div>`
                : `<div class="mdt-pills">${locs.map(([id, lbl]) =>
                    `<div class="mdt-pill ${v.location === id ? 'active' : ''}" data-loc="${id}">${lbl}</div>`).join('')}</div>`}
                </div>` : ''}
                <div style="margin-top:14px;padding-top:12px;border-top:1px solid var(--mdt-border)">
                    <div style="font-size:12px;color:var(--mdt-text-dim);margin-bottom:6px">Propriétaire</div>
                    ${owner && owner.name ? `<b>${esc(owner.name)}</b>
                        ${owner.identifier ? `<button class="mdt-btn mdt-btn-sm mdt-btn-primary" id="vh-owner" style="margin-left:8px">👤 Fiche citoyen</button>` : ''}`
            : `<span style="color:var(--mdt-text-dim);font-size:13px">Aucun propriétaire enregistré.</span>`}
                </div>
            </div>
        </div>
        <div class="mdt-card">
            <div class="mdt-card-title">Historique d'infractions liées à la plaque</div>
            ${fines.length ? `<table class="mdt-table"><thead><tr><th>Date</th><th>Motif</th><th>Montant</th><th>Statut</th><th>Agent</th></tr></thead><tbody>` +
            fines.map((f) => `<tr><td>${fmtDate(f.created_at)}</td><td>${esc(f.reason)}</td><td>${esc(f.amount)}$</td>
            <td>${f.paid ? '<span class="mdt-badge mdt-badge-green">Payée</span>' : '<span class="mdt-badge mdt-badge-orange">Impayée</span>'}</td>
            <td>${esc(f.officer_name)}</td></tr>`).join('') + `</tbody></table>` : emptyState('✅', 'Aucune infraction enregistrée.')}
        </div>
    `);
    el('vh-back').addEventListener('click', renderVehicles);
    if (owner && owner.identifier) {
        b('vh-owner', () => {
            state.currentTab = 'citizens';
            document.querySelectorAll('.mdt-tab').forEach((t) => t.classList.toggle('active', t.dataset.tab === 'citizens'));
            openCitizenFile(owner.identifier);
        });
    }
    b('vh-flag', () => {
        openModal('Signaler le véhicule recherché', `
            <div class="mdt-form-row"><label>Motif de la recherche</label>
                <input class="mdt-input" id="vf-reason" placeholder="Ex. véhicule impliqué dans un braquage…"></div>
        `, `<button class="mdt-btn" onclick="window.__mdtCloseModal()">Annuler</button>
            <button class="mdt-btn mdt-btn-danger" id="vf-submit">🚨 Signaler recherché</button>`);
        b('vf-submit', () => {
            fetchNui('mdt:setVehicleWanted', { plate: v.plate, wanted: true, reason: el('vf-reason').value.trim() });
            closeModal();
        });
    });
    b('vh-unflag', () => confirmAction('Lever la recherche sur ce véhicule ?',
        () => fetchNui('mdt:setVehicleWanted', { plate: v.plate, wanted: false })));
    document.querySelectorAll('[data-loc]').forEach((p) => p.addEventListener('click', () => {
        if (p.dataset.loc === v.location) return;
        fetchNui('mdt:setVehicleLocation', { plate: v.plate, location: p.dataset.loc });
    }));
}

/* ════════════════════════════════════════════════════════════════
   ONGLET — ARMES
   ════════════════════════════════════════════════════════════════ */
function weaponCatLabel(c) { return c === 'melee' ? '🔪 Arme de mêlée' : '🔫 Arme à feu'; }

async function renderWeapons() {
    state.weaponSeized = state.weaponSeized || false;
    state.currentWeapon = null;
    setContent(`
        <div class="mdt-page-title">Registre des armes</div>
        <div class="mdt-page-sub">Recherche par numéro de série ou désignation. Les armes à feu possèdent un n° de série unique.</div>
        <div style="display:flex;justify-content:space-between;align-items:center;gap:12px;flex-wrap:wrap">
            <div class="mdt-searchbar" style="flex:1;margin-bottom:0">
                <input class="mdt-input" id="wp-search" placeholder="Numéro de série ou désignation…" autocomplete="off">
                <button class="mdt-btn mdt-btn-primary" id="wp-search-btn">🔍 Rechercher</button>
            </div>
            ${has('manage_weapons') ? `<button class="mdt-btn mdt-btn-primary" id="wp-new">+ Enregistrer une arme</button>` : ''}
        </div>
        <div class="mdt-pills" id="wp-pills" style="margin-top:16px">
            <div class="mdt-pill ${!state.weaponSeized ? 'active' : ''}" data-s="all">Toutes</div>
            <div class="mdt-pill ${state.weaponSeized ? 'active' : ''}" data-s="seized">Sous scellés</div>
        </div>
        <div id="wp-results"></div>
    `);
    const run = async () => {
        el('wp-results').innerHTML = emptyState('⏳', 'Recherche…');
        const rows = asArray(await fetchNui('mdt:searchWeapons', { query: el('wp-search').value.trim(), seized: state.weaponSeized }));
        if (!el('wp-results')) return;
        if (!rows.length) { el('wp-results').innerHTML = emptyState('🔫', 'Aucune arme trouvée.'); return; }
        el('wp-results').innerHTML = `<div class="mdt-list">` + rows.map((w) => `
            <div class="mdt-list-item" data-id="${esc(w.id)}">
                <div class="mdt-li-main">
                    <div class="mdt-li-name">${esc(w.model || 'Arme')} ${w.seized ? '<span class="mdt-wanted-flag">Sous scellés</span>' : ''}</div>
                    <div class="mdt-li-sub">${weaponCatLabel(w.category)} · ${w.serial_number ? 'N° ' + esc(w.serial_number) : 'Sans numéro de série'}</div>
                </div>
                <span class="mdt-badge mdt-badge-blue">Ouvrir →</span>
            </div>`).join('') + `</div>`;
        document.querySelectorAll('#wp-results .mdt-list-item').forEach((it) => it.addEventListener('click', () => openWeaponFile(it.dataset.id)));
    };
    el('wp-search-btn').addEventListener('click', run);
    el('wp-search').addEventListener('keydown', (e) => { if (e.key === 'Enter') run(); });
    document.querySelectorAll('#wp-pills .mdt-pill').forEach((p) => p.addEventListener('click', () => {
        state.weaponSeized = p.dataset.s === 'seized'; renderWeapons();
    }));
    const nb = el('wp-new'); if (nb) nb.addEventListener('click', () => formRegisterWeapon(null));
    run();
}

async function openWeaponFile(id) {
    setContent(emptyState('⏳', 'Chargement…'));
    const data = await fetchNui('mdt:getWeapon', { id });
    if (!data || !data.weapon) { setContent(emptyState('🚫', 'Arme introuvable.')); return; }
    const w = data.weapon, persons = asArray(data.persons), reports = asArray(data.reports);
    state.currentWeapon = id;
    setContent(`
        <div class="mdt-back" id="wp-back">← Retour au registre</div>
        <div style="display:flex;justify-content:space-between;align-items:flex-start;gap:12px">
            <div>
                <div class="mdt-page-title">${esc(w.model || 'Arme')} ${w.seized ? '<span class="mdt-wanted-flag">Sous scellés</span>' : ''}</div>
                <div class="mdt-page-sub">${weaponCatLabel(w.category)}</div>
            </div>
            ${has('manage_weapons') ? `<div style="display:flex;gap:8px">
                <button class="mdt-btn mdt-btn-sm" id="wp-edit">✏️ Modifier</button>
                <button class="mdt-btn mdt-btn-sm ${w.seized ? '' : 'mdt-btn-primary'}" id="wp-seize">${w.seized ? '🔓 Retirer des scellés' : '🔒 Placer sous scellés'}</button>
                <button class="mdt-btn mdt-btn-sm mdt-btn-danger" id="wp-del">🗑</button>
            </div>` : ''}
        </div>
        <div class="mdt-grid-2">
            <div class="mdt-card">
                <div class="mdt-card-title">Informations</div>
                <dl class="mdt-kv">
                    <dt>Désignation</dt><dd>${esc(w.model || '—')}</dd>
                    <dt>Catégorie</dt><dd>${weaponCatLabel(w.category)}</dd>
                    <dt>N° de série</dt><dd>${w.serial_number ? '<b>' + esc(w.serial_number) + '</b>' : '<span style="color:var(--mdt-text-dim)">Aucun (arme de mêlée)</span>'}</dd>
                    <dt>Statut</dt><dd>${w.seized ? '<span class="mdt-badge mdt-badge-red">Sous scellés</span>' : '<span class="mdt-badge mdt-badge-green">Enregistrée</span>'}</dd>
                    <dt>Enregistrée par</dt><dd>${esc(w.registered_by_name || '—')}${depBadge(w.department)}</dd>
                    <dt>Date</dt><dd>${fmtDate(w.created_at)}</dd>
                </dl>
            </div>
            <div class="mdt-card">
                <div class="mdt-card-title">Notes</div>
                <p style="font-size:14px;white-space:pre-wrap;line-height:1.5">${esc(w.notes || '—')}</p>
                ${w.seized ? `<div style="margin-top:10px;font-size:12px;color:var(--mdt-text-dim)">Saisie par ${esc(w.seized_by_name || '?')} le ${fmtDate(w.seized_at)}${w.seized_case_id ? ' · Enquête #' + esc(w.seized_case_id) : ''}</div>` : ''}
            </div>
        </div>
        <div class="mdt-card">
            <div class="mdt-card-title">Personnes liées
                ${has('manage_weapons') ? `<button class="mdt-btn mdt-btn-sm mdt-btn-primary" id="wp-add-person">+ Lier une personne</button>` : ''}
            </div>
            ${persons.length ? `<table class="mdt-table"><thead><tr><th>Personne</th><th>Relation</th><th>Date</th><th></th></tr></thead><tbody>` +
            persons.map((p) => `<tr>
                    <td><b>${esc(p.citizen_name)}</b></td>
                    <td><span class="mdt-badge mdt-badge-gray">${esc(p.relation)}</span></td>
                    <td>${fmtDate(p.created_at)}</td>
                    <td>${has('manage_weapons') ? `<button class="mdt-btn mdt-btn-sm mdt-btn-danger" data-unlink-person="${esc(p.id)}">🗑</button>` : ''}</td>
                </tr>`).join('') + `</tbody></table>` : emptyState('👤', 'Aucune personne liée.')}
        </div>
        <div class="mdt-card">
            <div class="mdt-card-title">Enquêtes liées</div>
            ${reports.length ? `<div class="mdt-list">` + reports.map((r) => `
                <div class="mdt-list-item" data-report="${esc(r.report_id)}">
                    <div class="mdt-li-main"><div class="mdt-li-name">${esc(r.title)}</div><div class="mdt-li-sub">${fmtDate(r.created_at)}</div></div>
                    <span class="mdt-badge mdt-badge-blue">Ouvrir →</span>
                </div>`).join('') + `</div>` : emptyState('🕵️', 'Aucune enquête liée.')}
        </div>
    `);
    el('wp-back').addEventListener('click', renderWeapons);
    const bind = (eid, fn) => { const e = el(eid); if (e) e.addEventListener('click', fn); };
    bind('wp-edit', () => formRegisterWeapon(w));
    bind('wp-del', () => fetchNui('mdt:deleteWeapon', { id: w.id }));
    bind('wp-seize', () => {
        if (w.seized) fetchNui('mdt:seizeWeapon', { id: w.id, seized: false });
        else formSeizeWeapon(w.id);
    });
    bind('wp-add-person', () => formLinkWeaponPerson(w.id));
    document.querySelectorAll('[data-unlink-person]').forEach((x) => x.addEventListener('click', () => {
        fetchNui('mdt:unlinkWeaponPerson', { linkId: x.dataset.unlinkPerson, weaponId: w.id });
    }));
    document.querySelectorAll('#wp-results, #mdt-content [data-report]').forEach(() => { });
    document.querySelectorAll('[data-report]').forEach((x) => x.addEventListener('click', () => {
        state.currentTab = 'dossiers';
        document.querySelectorAll('.mdt-tab').forEach((t) => t.classList.toggle('active', t.dataset.tab === 'dossiers'));
        openReport(x.dataset.report);
    }));
}

function formRegisterWeapon(existing) {
    let category = existing ? existing.category : 'firearm';
    const pill = (v, label, cur) => `<div class="mdt-pill ${cur === v ? 'active' : ''}" data-v="${v}">${label}</div>`;
    openModal(existing ? "Modifier l'arme" : 'Enregistrer une arme', `
        ${existing ? '' : `<div class="mdt-form-row"><label>Catégorie</label>
            <div class="mdt-pills" id="wpf-cat">${pill('firearm', 'Arme à feu', category)}${pill('melee', 'Arme de mêlée', category)}</div></div>`}
        <div class="mdt-form-row"><label>Désignation / modèle</label><input class="mdt-input" id="wpf-model" value="${esc(existing ? existing.model : '')}" placeholder="Glock 17, Couteau de combat…"></div>
        ${existing ? '' : `<div class="mdt-form-row" id="wpf-serial-row"><label>Numéro de série (optionnel — généré automatiquement si vide)</label><input class="mdt-input" id="wpf-serial" placeholder="Laisser vide pour génération automatique"></div>`}
        <div class="mdt-form-row"><label>Notes</label><textarea class="mdt-textarea" id="wpf-notes">${esc(existing ? existing.notes : '')}</textarea></div>
    `, `<button class="mdt-btn" onclick="window.__mdtCloseModal()">Annuler</button>
        <button class="mdt-btn mdt-btn-primary" id="wpf-submit">Enregistrer</button>`);
    if (!existing) {
        const updateSerialRow = () => { const r = el('wpf-serial-row'); if (r) r.style.display = category === 'firearm' ? '' : 'none'; };
        document.querySelectorAll('#wpf-cat .mdt-pill').forEach((p) => p.addEventListener('click', () => {
            category = p.dataset.v;
            document.querySelectorAll('#wpf-cat .mdt-pill').forEach((x) => x.classList.toggle('active', x === p));
            updateSerialRow();
        }));
        updateSerialRow();
    }
    el('wpf-submit').addEventListener('click', () => {
        const model = el('wpf-model').value.trim();
        if (!model) { toast('Désignation requise.', false); return; }
        if (existing) {
            fetchNui('mdt:updateWeapon', { id: existing.id, model, notes: el('wpf-notes').value.trim() });
        } else {
            fetchNui('mdt:registerWeapon', { category, model, serial: el('wpf-serial') ? el('wpf-serial').value.trim() : '', notes: el('wpf-notes').value.trim() });
        }
        closeModal();
    });
}

function formSeizeWeapon(weaponId) {
    openModal('Placer sous scellés', `
        <div class="mdt-soon">🔒 L'arme sera ajoutée à la liste des pièces à conviction.</div>
        <div class="mdt-form-row"><label>Enquête de rattachement (n° — optionnel)</label><input class="mdt-input" id="wsz-case" type="number" placeholder="ID de l'enquête"></div>
    `, `<button class="mdt-btn" onclick="window.__mdtCloseModal()">Annuler</button>
        <button class="mdt-btn mdt-btn-primary" id="wsz-submit">Placer sous scellés</button>`);
    el('wsz-submit').addEventListener('click', () => {
        fetchNui('mdt:seizeWeapon', { id: weaponId, seized: true, caseId: parseInt(el('wsz-case').value) || null });
        closeModal();
    });
}

function formLinkWeaponPerson(weaponId) {
    let selId = null, selName = '', relation = 'lie';
    const pill = (v, label) => `<div class="mdt-pill ${v === relation ? 'active' : ''}" data-v="${v}">${label}</div>`;
    openModal('Lier une personne', `
        <div class="mdt-form-row"><label>Personne</label>
            <div class="mdt-autocomplete">
                <input class="mdt-input" id="wlp-search" placeholder="Rechercher un citoyen…" autocomplete="off">
                <div class="mdt-ac-results mdt-hidden" id="wlp-results"></div>
            </div>
            <div class="mdt-ac-selected" id="wlp-selected">Sélectionnez un citoyen.</div>
        </div>
        <div class="mdt-form-row"><label>Relation</label>
            <div class="mdt-pills" id="wlp-rel">${pill('proprietaire', 'Propriétaire')}${pill('detenteur', 'Détenteur')}${pill('suspect', 'Suspect')}${pill('temoin', 'Témoin')}${pill('lie', 'Lié')}</div>
        </div>
    `, `<button class="mdt-btn" onclick="window.__mdtCloseModal()">Annuler</button>
        <button class="mdt-btn mdt-btn-primary" id="wlp-submit">Lier</button>`);
    let t; const box = el('wlp-results');
    el('wlp-search').addEventListener('input', () => {
        selId = null; el('wlp-selected').classList.remove('ok'); el('wlp-selected').textContent = 'Sélectionnez un citoyen.';
        const q = el('wlp-search').value.trim(); clearTimeout(t);
        if (q.length < 2) { box.classList.add('mdt-hidden'); return; }
        t = setTimeout(async () => {
            const rows = asArray(await fetchNui('mdt:searchCitizens', { query: q }));
            if (!el('wlp-results')) return;
            box.innerHTML = rows.length ? rows.map((r) => `<div class="mdt-ac-item" data-id="${esc(r.identifier)}" data-name="${esc(r.name)}"><span>${esc(r.name)}</span><span class="mdt-ac-ddn">${esc(r.ddn || '?')}</span></div>`).join('') : '<div class="mdt-ac-item mdt-ac-empty">Aucun résultat</div>';
            box.classList.remove('mdt-hidden');
            box.querySelectorAll('.mdt-ac-item[data-id]').forEach((it) => it.addEventListener('click', () => {
                selId = it.dataset.id; selName = it.dataset.name; el('wlp-search').value = selName;
                const s = el('wlp-selected'); s.classList.add('ok'); s.textContent = '✓ ' + selName; box.classList.add('mdt-hidden');
            }));
        }, 250);
    });
    document.querySelectorAll('#wlp-rel .mdt-pill').forEach((p) => p.addEventListener('click', () => {
        relation = p.dataset.v;
        document.querySelectorAll('#wlp-rel .mdt-pill').forEach((x) => x.classList.toggle('active', x === p));
    }));
    el('wlp-submit').addEventListener('click', () => {
        if (!selId) { toast('Sélectionnez un citoyen.', false); return; }
        fetchNui('mdt:linkWeaponPerson', { weaponId, identifier: selId, relation });
        closeModal();
    });
}

/* ════════════════════════════════════════════════════════════════
   ONGLET — DOSSIERS
   ════════════════════════════════════════════════════════════════ */
/* ════════════════════════════════════════════════════════════════
   ONGLET — RAPPORTS D'INTERVENTION

   Le compte rendu qu'un agent rédige après une intervention. Il vit sa
   propre vie : une enquête peut en agréger plusieurs (onglet Enquête),
   mais un rapport existe très bien seul.
   ════════════════════════════════════════════════════════════════ */

function reportTypeLabel(id) {
    const t = asArray(state.payload.reportTypes).find((x) => x.id === id);
    return t ? t.label : (id || '—');
}

/* Aperçu d'un compte rendu dans la liste : première ligne utile, tronquée. */
function reportExcerpt(content) {
    const txt = String(content || '').replace(/\s+/g, ' ').trim();
    if (!txt) return 'Aucun compte rendu.';
    return txt.length > 140 ? txt.slice(0, 140) + '…' : txt;
}

const JOINT_BADGE = '<span class="mdt-badge mdt-badge-orange" title="Intervention menée conjointement par la police et la gendarmerie">Conjointe</span>';

async function renderInterventionReports() {
    setContent(`
        <div class="mdt-page-title">Rapports d'intervention</div>
        <div class="mdt-page-sub">Comptes rendus rédigés par les agents à l'issue d'une intervention.</div>
        <div style="display:flex;justify-content:space-between;align-items:center;gap:12px;flex-wrap:wrap;margin-bottom:12px">
            <div class="mdt-stat-card" style="min-width:220px">
                <div class="stat-label">Rapports — 30 derniers jours</div>
                <div class="stat-value" id="ir-last30">—</div>
            </div>
            ${has('create_report') ? `<button class="mdt-btn mdt-btn-primary" id="ir-new">+ Créer une intervention</button>` : ''}
        </div>
        <div id="ir-list">${emptyState('⏳', 'Chargement…')}</div>
    `);
    const nb = el('ir-new'); if (nb) nb.addEventListener('click', () => formInterventionReport(null));

    const res = await fetchNui('mdt:getInterventionReports', {});
    if (!el('ir-list')) return;
    const payload = (res && typeof res === 'object' && !Array.isArray(res)) ? res : {};
    const rows = asArray(payload.rows);
    if (el('ir-last30')) el('ir-last30').textContent = parseInt(payload.last30, 10) || 0;

    if (!rows.length) { el('ir-list').innerHTML = emptyState('📝', 'Aucun rapport d\'intervention.'); return; }
    el('ir-list').innerHTML = `<div class="mdt-list">` + rows.map((r) => `
        <div class="mdt-list-item" data-id="${esc(r.id)}">
            <div class="mdt-li-main">
                <div class="mdt-li-name">
                    <span class="mdt-badge mdt-badge-gray">${esc(reportTypeLabel(r.type))}</span>
                    ${Number(r.joint) === 1 ? JOINT_BADGE : ''}
                </div>
                <div class="mdt-li-sub">${esc(reportExcerpt(r.content))}</div>
                <div class="mdt-li-sub">${esc(r.author_name)}${depBadge(r.department)} · ${fmtDate(r.created_at)}</div>
            </div>
            <span class="mdt-badge mdt-badge-blue">Ouvrir →</span>
        </div>`).join('') + `</div>`;
    document.querySelectorAll('#ir-list .mdt-list-item').forEach((it) =>
        it.addEventListener('click', () => openInterventionReport(it.dataset.id)));
}

async function openInterventionReport(id) {
    setContent(emptyState('⏳', 'Chargement…'));
    const r = await fetchNui('mdt:getInterventionReport', { id });
    if (!r || !r.id) { setContent(emptyState('🚫', 'Rapport introuvable.')); return; }
    let agents = [], involved = [];
    try { agents = JSON.parse(r.agents || '[]') || []; } catch (e) { agents = []; }
    try { involved = JSON.parse(r.involved || '[]') || []; } catch (e) { involved = []; }

    setContent(`
        <div class="mdt-back" id="ir-back">← Retour aux rapports</div>
        <div style="display:flex;justify-content:space-between;align-items:flex-start;gap:12px">
            <div>
                <div class="mdt-page-title">${esc(reportTypeLabel(r.type))} ${Number(r.joint) === 1 ? JOINT_BADGE : ''}</div>
                <div class="mdt-page-sub">${esc(r.author_name)}${depBadge(r.department)} · ${fmtDate(r.created_at)}</div>
            </div>
            <div style="display:flex;gap:8px">
                ${r.canEdit ? `<button class="mdt-btn mdt-btn-sm" id="ir-edit">✏️ Modifier</button>` : ''}
                ${has('delete_records') ? `<button class="mdt-btn mdt-btn-sm mdt-btn-danger" id="ir-del">🗑 Supprimer</button>` : ''}
            </div>
        </div>
        <div class="mdt-card"><div class="mdt-card-title">Compte rendu</div>
            <pre style="white-space:pre-wrap;font-family:var(--mdt-font);font-size:14px;line-height:1.6">${esc(r.content || '—')}</pre>
        </div>
        <div class="mdt-grid-2">
            <div class="mdt-card"><div class="mdt-card-title">Agents impliqués</div>
                ${agents.length ? `<ul class="mdt-plain-list">${agents.map((a) => `<li>${esc(a)}</li>`).join('')}</ul>`
            : emptyState('👮', 'Aucun agent renseigné.')}
            </div>
            <div class="mdt-card"><div class="mdt-card-title">Personnes impliquées</div>
                ${involved.length ? `<table class="mdt-table"><tbody>${involved.map((p) =>
                `<tr><td><b>${esc(p.name || '?')}</b></td><td>${esc(p.role || '—')}</td></tr>`).join('')}</tbody></table>`
            : emptyState('👤', 'Aucune personne renseignée.')}
            </div>
        </div>
        <div id="ir-links">${emptyState('⏳', 'Chargement des éléments associés…')}</div>
    `);
    el('ir-back').addEventListener('click', renderInterventionReports);
    const eb = el('ir-edit'); if (eb) eb.addEventListener('click', () => formInterventionReport(r));
    const db = el('ir-del'); if (db) db.addEventListener('click', () => confirmAction(
        'Supprimer définitivement ce rapport ? Il sera également retiré des enquêtes qui le référencent.',
        () => fetchNui('mdt:deleteInterventionReport', { id: r.id })));

    renderReportLinks(r.id, has('create_report'));
}

/* Armes et véhicules associés au rapport — chargés à part, comme les
   éléments rattachés d'une enquête (voir renderCaseLinks). */
async function renderReportLinks(reportId, canLink) {
    const box = el('ir-links');
    if (!box) return;
    const d = await fetchNui('mdt:getReportLinks', { reportId });
    if (!el('ir-links')) return;
    const data = (d && typeof d === 'object' && !Array.isArray(d)) ? d : {};
    const weapons = asArray(data.weapons), vehicles = asArray(data.vehicles);

    const unlinkBtn = (id) => canLink
        ? `<td><button class="mdt-btn mdt-btn-sm mdt-btn-danger" data-unlink-report-item="${esc(id)}">🗑</button></td>` : '';

    const weaponsBody = weapons.length
        ? `<table class="mdt-table"><thead><tr><th>Désignation</th><th>Catégorie</th><th>N° série</th><th>Statut</th>${canLink ? '<th></th>' : ''}</tr></thead><tbody>` +
        weapons.map((w) => `<tr>
            <td class="ir-w-open" data-weapon="${esc(w.weapon_id)}" style="cursor:pointer"><b>${esc(w.model || 'Arme')}</b></td>
            <td>${weaponCatLabel(w.category)}</td>
            <td>${w.serial_number ? esc(w.serial_number) : '—'}</td>
            <td>${w.seized ? '<span class="mdt-badge mdt-badge-red">Scellés</span>' : '—'}</td>
            ${unlinkBtn(w.id)}
          </tr>`).join('') + `</tbody></table>`
        : emptyState('🔫', 'Aucune arme associée.');

    const vehiclesBody = vehicles.length
        ? `<table class="mdt-table"><thead><tr><th>Plaque</th><th>Modèle</th><th>Propriétaire</th>${canLink ? '<th></th>' : ''}</tr></thead><tbody>` +
        vehicles.map((v) => `<tr>
            <td class="ir-v-open" data-plate="${esc(v.plate)}" style="cursor:pointer;font-family:monospace"><b>${esc(v.plate)}</b></td>
            <td>${esc(v.model_name || 'Inconnu')}</td>
            <td>${esc(v.owner_name || '—')}</td>
            ${unlinkBtn(v.id)}
          </tr>`).join('') + `</tbody></table>`
        : emptyState('🚓', 'Aucun véhicule associé.');

    box.innerHTML =
        caseCard('🔫', 'Armes', weapons.length, 'ir-add-weapon', 'Associer une arme', canLink, weaponsBody) +
        caseCard('🚓', 'Véhicules', vehicles.length, 'ir-add-vehicle', 'Associer un véhicule', canLink, vehiclesBody);

    b('ir-add-weapon', () => formLinkWeaponToIntReport(reportId));
    b('ir-add-vehicle', () => formLinkVehicleToIntReport(reportId));

    box.querySelectorAll('[data-unlink-report-item]').forEach((x) => x.addEventListener('click', () =>
        fetchNui('mdt:unlinkReportItem', { id: x.dataset.unlinkReportItem, reportId })));

    box.querySelectorAll('.ir-w-open').forEach((x) => x.addEventListener('click', () => {
        if (!has('view_weapons')) return;
        selectTabSilently('weapons');
        openWeaponFile(x.dataset.weapon);
    }));
    box.querySelectorAll('.ir-v-open').forEach((x) => x.addEventListener('click', () => {
        if (!has('view_vehicles')) return;
        selectTabSilently('vehicles');
        openVehicleFile(x.dataset.plate);
    }));
}

function formLinkWeaponToIntReport(reportId) {
    openModal('Associer une arme au rapport', `
        <div class="mdt-form-row"><label>Numéro de série de l'arme</label><input class="mdt-input" id="irw-serial" placeholder="Ex : AB1234567"></div>
    `, `<button class="mdt-btn" onclick="window.__mdtCloseModal()">Annuler</button>
        <button class="mdt-btn mdt-btn-primary" id="irw-submit">Associer</button>`);
    el('irw-submit').addEventListener('click', () => {
        const serial = el('irw-serial').value.trim();
        if (!serial) { toast('Numéro de série requis.', false); return; }
        fetchNui('mdt:linkReportItem', { reportId, kind: 'weapon', ref: serial });
        closeModal();
    });
}

function formLinkVehicleToIntReport(reportId) {
    openModal('Associer un véhicule au rapport', `
        <div class="mdt-form-row"><label>Plaque d'immatriculation</label><input class="mdt-input" id="irv-plate" placeholder="Ex : 12ABC34" autocomplete="off"></div>
    `, `<button class="mdt-btn" onclick="window.__mdtCloseModal()">Annuler</button>
        <button class="mdt-btn mdt-btn-primary" id="irv-submit">Associer</button>`);
    el('irv-submit').addEventListener('click', () => {
        const plate = el('irv-plate').value.trim();
        if (!plate) { toast('Plaque requise.', false); return; }
        fetchNui('mdt:linkReportItem', { reportId, kind: 'vehicle', ref: plate });
        closeModal();
    });
}

function formInterventionReport(existing) {
    const types = asArray(state.payload.reportTypes);
    let agents = [], involved = [];
    if (existing) {
        try { agents = JSON.parse(existing.agents || '[]') || []; } catch (e) { }
        try { involved = JSON.parse(existing.involved || '[]') || []; } catch (e) { }
    } else {
        // Le rédacteur est presque toujours sur l'intervention : on le
        // pré-remplit, quitte à ce qu'il se retire.
        agents = [state.payload.officerName].filter(Boolean);
    }
    const typeVal = existing ? existing.type : (types[0] && types[0].id);

    openModal(existing ? "Modifier le rapport d'intervention" : "Nouveau rapport d'intervention", `
        <div class="mdt-form-row"><label>Type d'intervention</label>
            <select class="mdt-input" id="ir-type">
                ${types.map((t) => `<option value="${esc(t.id)}"${t.id === typeVal ? ' selected' : ''}>${esc(t.label)}</option>`).join('')}
            </select>
        </div>
        <div class="mdt-form-row"><label>Compte rendu</label>
            <textarea class="mdt-textarea" id="ir-content" style="min-height:170px"
                placeholder="Déroulé des faits, constatations, suites données…">${esc(existing ? existing.content : '')}</textarea></div>
        <div class="mdt-form-row"><label>Agents impliqués (un par ligne)</label>
            <textarea class="mdt-textarea" id="ir-agents" placeholder="Jean Martin">${esc(agents.join('\n'))}</textarea></div>
        <div class="mdt-form-row"><label>Personnes impliquées (une par ligne : Nom | Rôle)</label>
            <textarea class="mdt-textarea" id="ir-involved" placeholder="Jean Dupont | Mis en cause">${esc(involved.map((p) => `${p.name || ''} | ${p.role || ''}`).join('\n'))}</textarea></div>
        <div class="mdt-form-row mdt-check-row">
            <input type="checkbox" id="ir-joint" ${existing && Number(existing.joint) === 1 ? 'checked' : ''}>
            <label for="ir-joint">Intervention conjointe Police / Gendarmerie</label>
        </div>
    `, `<button class="mdt-btn" onclick="window.__mdtCloseModal()">Annuler</button>
        <button class="mdt-btn mdt-btn-primary" id="ir-submit">${existing ? 'Enregistrer' : 'Créer'}</button>`);

    el('ir-submit').addEventListener('click', () => {
        const content = el('ir-content').value.trim();
        if (!content) { toast('Compte rendu requis.', false); return; }
        const payload = {
            type: el('ir-type').value,
            content,
            agents: el('ir-agents').value.split('\n').map((l) => l.trim()).filter(Boolean),
            involved: el('ir-involved').value.split('\n').map((l) => {
                const parts = l.split('|');
                return parts[0].trim() ? { name: parts[0].trim(), role: (parts[1] || '').trim() } : null;
            }).filter(Boolean),
            joint: el('ir-joint').checked,
        };
        if (existing) { payload.id = existing.id; fetchNui('mdt:updateInterventionReport', payload); }
        else { fetchNui('mdt:createInterventionReport', payload); }
        closeModal();
    });
}

/* ════════════════════════════════════════════════════════════════
   ONGLET — ENQUÊTE

   Une enquête s'ouvre avec un titre et une description, rien de plus.
   Tout le reste — rapports d'intervention, preuves, armes, véhicules,
   personnes — s'y rattache ensuite, au fil de l'instruction. Rien n'est
   recopié : l'enquête ne stocke que des références.
   ════════════════════════════════════════════════════════════════ */

async function renderDossiers() {
    setContent(`
        <div class="mdt-page-title">Enquêtes</div>
        <div class="mdt-page-sub">Dossiers d'instruction : rapports, preuves, armes, véhicules et personnes rattachés.</div>
        <div style="display:flex;justify-content:flex-end;margin-bottom:12px">
            ${has('create_report') ? `<button class="mdt-btn mdt-btn-primary" id="dz-new">+ Ouvrir une enquête</button>` : ''}
        </div>
        <div id="dz-list"></div>
    `);
    const nb = el('dz-new'); if (nb) nb.addEventListener('click', () => formReport(null));
    el('dz-list').innerHTML = emptyState('⏳', 'Chargement…');
    const rows = asArray(await fetchNui('mdt:getReports', { type: 'all' }));
    if (!el('dz-list')) return;
    if (!rows.length) { el('dz-list').innerHTML = emptyState('🕵️', 'Aucune enquête ouverte.'); return; }
    el('dz-list').innerHTML = `<div class="mdt-list">` + rows.map((r) => `
        <div class="mdt-list-item" data-id="${esc(r.id)}">
            <div class="mdt-li-main">
                <div class="mdt-li-name">${esc(r.title)}</div>
                <div class="mdt-li-sub">${esc(r.author_name)}${depBadge(r.department)} · ${fmtDate(r.updated_at)}</div>
            </div>
            <span class="mdt-badge mdt-badge-blue">Ouvrir →</span>
        </div>`).join('') + `</div>`;
    document.querySelectorAll('#dz-list .mdt-list-item').forEach((it) => it.addEventListener('click', () => openReport(it.dataset.id)));
}

/* Carte d'une catégorie d'éléments rattachés. Le bouton d'ajout n'apparaît
   que si l'agent a le droit correspondant. */
function caseCard(icon, title, count, addId, addLabel, canAdd, bodyHtml) {
    return `
        <div class="mdt-card">
            <div class="mdt-card-title">${icon} ${esc(title)}${count !== null ? ` (${count})` : ''}
                ${canAdd ? `<button class="mdt-btn mdt-btn-sm mdt-btn-primary" id="${addId}">+ ${esc(addLabel)}</button>` : ''}
            </div>
            ${bodyHtml}
        </div>`;
}

async function openReport(id) {
    setContent(emptyState('⏳', 'Chargement…'));
    const r = await fetchNui('mdt:getReport', { id });
    if (!r || !r.id) { setContent(emptyState('🚫', 'Enquête introuvable.')); return; }

    // Personnes saisies en texte libre avant la refonte : on les conserve
    // à l'affichage plutôt que de les perdre silencieusement.
    let legacyInvolved = [];
    try { legacyInvolved = JSON.parse(r.involved || '[]') || []; } catch (e) { legacyInvolved = []; }

    const evidence = asArray(r.evidence);
    const canLink = has('create_report');

    setContent(`
        <div class="mdt-back" id="dz-back">← Retour aux enquêtes</div>
        <div style="display:flex;justify-content:space-between;align-items:flex-start;gap:12px">
            <div>
                <div class="mdt-page-title">${esc(r.title)}</div>
                <div class="mdt-page-sub">${esc(r.author_name)}${depBadge(r.department)} · ${fmtDate(r.created_at)}</div>
            </div>
            <div style="display:flex;gap:8px">
                ${r.canEdit ? `<button class="mdt-btn mdt-btn-sm" id="dz-edit">✏️ Modifier</button>` : ''}
                ${has('delete_records') ? `<button class="mdt-btn mdt-btn-sm mdt-btn-danger" id="dz-del">🗑 Supprimer</button>` : ''}
            </div>
        </div>

        <div class="mdt-card"><div class="mdt-card-title">Description</div>
            <pre style="white-space:pre-wrap;font-family:var(--mdt-font);font-size:14px;line-height:1.6">${esc(r.content || '—')}</pre>
        </div>

        ${legacyInvolved.length ? `<div class="mdt-card">
            <div class="mdt-card-title">Personnes citées (saisie libre)</div>
            <table class="mdt-table"><tbody>${legacyInvolved.map((p) =>
        `<tr><td><b>${esc(p.name || '?')}</b></td><td>${esc(p.role || '—')}</td></tr>`).join('')}</tbody></table>
        </div>` : ''}

        <div id="dz-links">${emptyState('⏳', 'Chargement des éléments rattachés…')}</div>

        ${has('view_evidence') ? caseCard('🔬', 'Preuves liées', evidence.length, 'dz-add-evidence',
            'Lier une preuve', has('manage_evidence'),
            evidence.length ? `<table class="mdt-table"><thead><tr><th>Type</th><th>Référence</th><th>Libellé</th><th>Date</th>${has('manage_evidence') ? '<th></th>' : ''}</tr></thead><tbody>` +
                evidence.map((e) => `<tr><td><span class="mdt-badge mdt-badge-blue">${esc(e.ev_type)}</span></td><td style="font-family:monospace;font-size:12px">${esc(e.ev_ref)}</td><td>${esc(e.label)}</td><td>${fmtDate(e.created_at)}</td>${has('manage_evidence') ? `<td><button class="mdt-btn mdt-btn-sm mdt-btn-danger" data-unlink-ev="${esc(e.id)}">🗑</button></td>` : ''}</tr>`).join('') + `</tbody></table>`
                : emptyState('🔬', 'Aucune preuve liée.')) : ''}

        ${has('view_weapons') ? caseCard('🔫', 'Armes liées', null, 'dz-add-weapon',
                    'Lier une arme (n° série)', has('manage_evidence'),
                    `<div id="dz-weapons-list">${emptyState('⏳', 'Chargement…')}</div>`) : ''}
    `);

    el('dz-back').addEventListener('click', renderDossiers);
    const eb = el('dz-edit'); if (eb) eb.addEventListener('click', () => formReport(r));
    const db = el('dz-del'); if (db) db.addEventListener('click', () => confirmAction(
        'Supprimer définitivement cette enquête ? Tous ses rattachements seront perdus.',
        () => fetchNui('mdt:deleteReport', { id: r.id })));
    const awb = el('dz-add-weapon'); if (awb) awb.addEventListener('click', () => formLinkWeaponToReport(r.id));
    const aeb = el('dz-add-evidence'); if (aeb) aeb.addEventListener('click', () => formLinkEvidenceToReport(r.id));
    document.querySelectorAll('[data-unlink-ev]').forEach((x) => x.addEventListener('click', () => {
        fetchNui('mdt:unlinkReportEvidence', { id: x.dataset.unlinkEv, reportId: r.id });
    }));

    renderCaseLinks(r.id, canLink);

    // Armes liées (chargées séparément)
    if (has('view_weapons')) {
        const weapons = asArray(await fetchNui('mdt:getReportWeapons', { reportId: r.id }));
        const wl = el('dz-weapons-list');
        if (wl) {
            wl.innerHTML = weapons.length ? `<table class="mdt-table"><thead><tr><th>Désignation</th><th>Catégorie</th><th>N° série</th><th>Statut</th><th></th></tr></thead><tbody>` +
                weapons.map((w) => `<tr>
                    <td class="dz-w-open" data-weapon="${esc(w.id)}" style="cursor:pointer"><b>${esc(w.model || 'Arme')}</b></td>
                    <td>${weaponCatLabel(w.category)}</td>
                    <td>${w.serial_number ? esc(w.serial_number) : '—'}</td>
                    <td>${w.seized ? '<span class="mdt-badge mdt-badge-red">Scellés</span>' : '—'}</td>
                    <td>${has('manage_evidence') ? `<button class="mdt-btn mdt-btn-sm mdt-btn-danger" data-unlink-weapon="${esc(w.id)}">🗑</button>` : ''}</td>
                </tr>`).join('') + `</tbody></table>` : emptyState('🔫', 'Aucune arme liée.');
            wl.querySelectorAll('.dz-w-open').forEach((x) => x.addEventListener('click', () => {
                state.currentTab = 'weapons';
                document.querySelectorAll('.mdt-tab').forEach((t) => t.classList.toggle('active', t.dataset.tab === 'weapons'));
                openWeaponFile(x.dataset.weapon);
            }));
            wl.querySelectorAll('[data-unlink-weapon]').forEach((x) => x.addEventListener('click', () => {
                fetchNui('mdt:unlinkWeaponReport', { weaponId: x.dataset.unlinkWeapon, reportId: r.id });
            }));
        }
    }
}

/* Rapports, véhicules et personnes rattachés — un seul aller-retour. */
async function renderCaseLinks(caseId, canLink) {
    const box = el('dz-links');
    if (!box) return;
    const d = await fetchNui('mdt:getCaseLinks', { caseId });
    if (!el('dz-links')) return;
    const data = (d && typeof d === 'object' && !Array.isArray(d)) ? d : {};
    const reports = asArray(data.reports), vehicles = asArray(data.vehicles), persons = asArray(data.persons);

    const unlinkBtn = (id) => canLink
        ? `<td><button class="mdt-btn mdt-btn-sm mdt-btn-danger" data-unlink-case="${esc(id)}">🗑</button></td>` : '';

    const reportsBody = reports.length
        ? `<table class="mdt-table"><thead><tr><th>Type</th><th>Compte rendu</th><th>Rédacteur</th><th>Date</th>${canLink ? '<th></th>' : ''}</tr></thead><tbody>` +
        reports.map((r) => `<tr>
            <td class="dz-r-open" data-report-id="${esc(r.ref)}" style="cursor:pointer">
                <span class="mdt-badge mdt-badge-gray">${esc(reportTypeLabel(r.type))}</span>
                ${Number(r.joint) === 1 ? JOINT_BADGE : ''}</td>
            <td>${esc(reportExcerpt(r.content))}</td>
            <td>${esc(r.author_name || '—')}${depBadge(r.department)}</td>
            <td>${fmtDate(r.report_at)}</td>
            ${unlinkBtn(r.id)}
          </tr>`).join('') + `</tbody></table>`
        : emptyState('📝', 'Aucun rapport rattaché.');

    const vehiclesBody = vehicles.length
        ? `<table class="mdt-table"><thead><tr><th>Plaque</th><th>Modèle</th><th>Propriétaire</th><th>Précision</th>${canLink ? '<th></th>' : ''}</tr></thead><tbody>` +
        vehicles.map((v) => `<tr>
            <td class="dz-v-open" data-plate="${esc(v.plate)}" style="cursor:pointer;font-family:monospace"><b>${esc(v.plate)}</b></td>
            <td>${esc(v.model_name || 'Inconnu')}</td>
            <td>${esc(v.owner_name || '—')}</td>
            <td>${esc(v.note || '—')}</td>
            ${unlinkBtn(v.id)}
          </tr>`).join('') + `</tbody></table>`
        : emptyState('🚓', 'Aucun véhicule rattaché.');

    const personsBody = persons.length
        ? `<table class="mdt-table"><thead><tr><th>Identité</th><th>Qualité</th><th>Rattaché par</th>${canLink ? '<th></th>' : ''}</tr></thead><tbody>` +
        persons.map((p) => `<tr>
            <td class="dz-p-open" data-identifier="${esc(p.identifier)}" style="cursor:pointer"><b>${esc(p.name)}</b></td>
            <td>${esc(p.note || '—')}</td>
            <td>${esc(p.linked_by_name || '—')}</td>
            ${unlinkBtn(p.id)}
          </tr>`).join('') + `</tbody></table>`
        : emptyState('👤', 'Aucune personne rattachée.');

    box.innerHTML =
        caseCard('📝', "Rapports d'intervention", reports.length, 'dz-add-report', 'Rattacher un rapport', canLink, reportsBody) +
        caseCard('🚓', 'Véhicules', vehicles.length, 'dz-add-vehicle', 'Rattacher un véhicule', canLink, vehiclesBody) +
        caseCard('👤', 'Personnes', persons.length, 'dz-add-person', 'Rattacher une personne', canLink, personsBody);

    b('dz-add-report', () => formLinkReportToCase(caseId));
    b('dz-add-vehicle', () => formLinkVehicleToCase(caseId));
    b('dz-add-person', () => formLinkPersonToCase(caseId));

    box.querySelectorAll('[data-unlink-case]').forEach((x) => x.addEventListener('click', () =>
        fetchNui('mdt:unlinkCaseItem', { id: x.dataset.unlinkCase, caseId })));

    // Navigation vers la pièce d'origine
    box.querySelectorAll('.dz-r-open').forEach((x) => x.addEventListener('click', () => {
        selectTabSilently('int_reports');
        openInterventionReport(x.dataset.reportId);
    }));
    box.querySelectorAll('.dz-v-open').forEach((x) => x.addEventListener('click', () => {
        if (!has('view_vehicles')) return;
        selectTabSilently('vehicles');
        openVehicleFile(x.dataset.plate);
    }));
    box.querySelectorAll('.dz-p-open').forEach((x) => x.addEventListener('click', () => {
        if (!has('view_citizens')) return;
        selectTabSilently('citizens');
        openCitizenFile(x.dataset.identifier);
    }));
}

/* Bascule l'onglet actif sans déclencher son rendu : l'appelant ouvre
   lui-même la fiche voulue juste après. */
function selectTabSilently(id) {
    state.currentTab = id;
    document.querySelectorAll('.mdt-tab').forEach((t) => t.classList.toggle('active', t.dataset.tab === id));
}

function formLinkReportToCase(caseId) {
    openModal("Rattacher un rapport d'intervention", `
        <div class="mdt-form-row"><label>Rapport</label>
            <select class="mdt-input" id="lcr-report"><option value="">Chargement…</option></select></div>
        <div class="mdt-form-row"><label>Précision (facultatif)</label>
            <input class="mdt-input" id="lcr-note" placeholder="Ex : première intervention sur les lieux"></div>
    `, `<button class="mdt-btn" onclick="window.__mdtCloseModal()">Annuler</button>
        <button class="mdt-btn mdt-btn-primary" id="lcr-submit">Rattacher</button>`);

    fetchNui('mdt:getInterventionReports', {}).then((res) => {
        const sel = el('lcr-report');
        if (!sel) return;
        const rows = asArray((res && res.rows) || []);
        sel.innerHTML = rows.length
            ? rows.map((r) => `<option value="${esc(r.id)}">${esc(reportTypeLabel(r.type))} · ${esc(r.author_name)} · ${esc(fmtDate(r.created_at))}</option>`).join('')
            : '<option value="">Aucun rapport disponible</option>';
    });

    el('lcr-submit').addEventListener('click', () => {
        const ref = el('lcr-report').value;
        if (!ref) { toast('Sélectionnez un rapport.', false); return; }
        fetchNui('mdt:linkCaseItem', { caseId, kind: 'report', ref, note: el('lcr-note').value.trim() });
        closeModal();
    });
}

function formLinkVehicleToCase(caseId) {
    openModal('Rattacher un véhicule', `
        <div class="mdt-form-row"><label>Plaque d'immatriculation</label>
            <input class="mdt-input" id="lcv-plate" placeholder="Ex : 12ABC34" autocomplete="off"></div>
        <div class="mdt-form-row"><label>Précision (facultatif)</label>
            <input class="mdt-input" id="lcv-note" placeholder="Ex : véhicule utilisé pour la fuite"></div>
    `, `<button class="mdt-btn" onclick="window.__mdtCloseModal()">Annuler</button>
        <button class="mdt-btn mdt-btn-primary" id="lcv-submit">Rattacher</button>`);
    el('lcv-submit').addEventListener('click', () => {
        const ref = el('lcv-plate').value.trim();
        if (!ref) { toast('Plaque requise.', false); return; }
        fetchNui('mdt:linkCaseItem', { caseId, kind: 'vehicle', ref, note: el('lcv-note').value.trim() });
        closeModal();
    });
}

function formLinkPersonToCase(caseId) {
    let selId = null;
    openModal('Rattacher une personne', `
        <div class="mdt-form-row"><label>Citoyen</label>
            <div class="mdt-ac-wrap">
                <input class="mdt-input" id="lcp-search" placeholder="Rechercher un citoyen (nom ou prénom)…" autocomplete="off">
                <div class="mdt-ac-results mdt-hidden" id="lcp-results"></div>
            </div>
            <div class="mdt-ac-selected" id="lcp-selected">Recherchez et sélectionnez un citoyen.</div>
        </div>
        <div class="mdt-form-row"><label>Qualité (facultatif)</label>
            <input class="mdt-input" id="lcp-note" placeholder="Ex : Mis en cause, Victime, Témoin"></div>
    `, `<button class="mdt-btn" onclick="window.__mdtCloseModal()">Annuler</button>
        <button class="mdt-btn mdt-btn-primary" id="lcp-submit">Rattacher</button>`);

    let acTimer;
    const acBox = el('lcp-results');
    el('lcp-search').addEventListener('input', () => {
        selId = null;
        const selBox = el('lcp-selected');
        selBox.classList.remove('ok');
        selBox.textContent = 'Recherchez et sélectionnez un citoyen.';
        const q = el('lcp-search').value.trim();
        clearTimeout(acTimer);
        if (q.length < 2) { acBox.classList.add('mdt-hidden'); return; }
        acTimer = setTimeout(async () => {
            const rows = asArray(await fetchNui('mdt:searchCitizens', { query: q }));
            if (!el('lcp-results')) return;
            acBox.innerHTML = rows.length
                ? rows.map((r) => `<div class="mdt-ac-item" data-id="${esc(r.identifier)}" data-name="${esc(r.name)}">
                    <span>${esc(r.name)}</span><span class="mdt-ac-ddn">${esc(r.sexe || '?')} · ${esc(r.ddn || '?')}</span></div>`).join('')
                : '<div class="mdt-ac-item mdt-ac-empty">Aucun citoyen trouvé</div>';
            acBox.classList.remove('mdt-hidden');
            acBox.querySelectorAll('.mdt-ac-item[data-id]').forEach((it) => it.addEventListener('click', () => {
                selId = it.dataset.id;
                el('lcp-search').value = it.dataset.name;
                const sel = el('lcp-selected'); sel.classList.add('ok'); sel.textContent = '✓ ' + it.dataset.name;
                acBox.classList.add('mdt-hidden');
            }));
        }, 250);
    });

    el('lcp-submit').addEventListener('click', () => {
        if (!selId) { toast('Sélectionnez un citoyen.', false); return; }
        fetchNui('mdt:linkCaseItem', { caseId, kind: 'person', ref: selId, note: el('lcp-note').value.trim() });
        closeModal();
    });
}

function formLinkWeaponToReport(reportId) {
    openModal("Lier une arme à l'enquête", `
        <div class="mdt-form-row"><label>Numéro de série de l'arme</label><input class="mdt-input" id="lwr-serial" placeholder="Ex : AB1234567"></div>
    `, `<button class="mdt-btn" onclick="window.__mdtCloseModal()">Annuler</button>
        <button class="mdt-btn mdt-btn-primary" id="lwr-submit">Lier</button>`);
    el('lwr-submit').addEventListener('click', () => {
        const serial = el('lwr-serial').value.trim();
        if (!serial) { toast('Numéro de série requis.', false); return; }
        fetchNui('mdt:linkWeaponReport', { reportId, serial });
        closeModal();
    });
}

function formLinkEvidenceToReport(reportId) {
    openModal("Lier une preuve à l'enquête", `
        <div class="mdt-form-row"><label>Référence de la preuve</label><input class="mdt-input" id="lev-ref" placeholder="Ex : FP-1234, DNA-5678…"></div>
    `, `<button class="mdt-btn" onclick="window.__mdtCloseModal()">Annuler</button>
        <button class="mdt-btn mdt-btn-primary" id="lev-submit">Lier</button>`);
    el('lev-submit').addEventListener('click', () => {
        const ref = el('lev-ref').value.trim();
        if (!ref) { toast('Référence requise.', false); return; }
        fetchNui('mdt:linkReportEvidence', { reportId, ref });
        closeModal();
    });
}

/* Ouverture / modification d'une enquête : titre et description, rien
   d'autre. Le reste se rattache depuis la fiche. */
function formReport(existing) {
    openModal(existing ? "Modifier l'enquête" : 'Ouvrir une enquête', `
        <div class="mdt-form-row"><label>Titre</label>
            <input class="mdt-input" id="d-title" value="${esc(existing ? existing.title : '')}"
                placeholder="Ex : Braquage de la bijouterie de Vinewood"></div>
        <div class="mdt-form-row"><label>Description</label>
            <textarea class="mdt-textarea" id="d-content" style="min-height:180px"
                placeholder="Contexte, faits établis, pistes…">${esc(existing ? existing.content : '')}</textarea></div>
    `, `<button class="mdt-btn" onclick="window.__mdtCloseModal()">Annuler</button>
        <button class="mdt-btn mdt-btn-primary" id="d-submit">${existing ? 'Enregistrer' : 'Ouvrir'}</button>`);
    el('d-submit').addEventListener('click', () => {
        const title = el('d-title').value.trim();
        if (!title) { toast('Titre requis.', false); return; }
        const payload = { title, content: el('d-content').value.trim() };
        if (existing) { payload.id = existing.id; fetchNui('mdt:updateReport', payload); }
        else { fetchNui('mdt:createReport', payload); }
        closeModal();
    });
}


/* ════════════════════════════════════════════════════════════════
   ONGLET — AVIS DE RECHERCHE
   ════════════════════════════════════════════════════════════════ */
function dangerBadge(level) {
    const map = { 1: ['green', 'Faible'], 2: ['orange', 'Modéré'], 3: ['red', 'Élevé'] };
    const d = map[level] || map[1];
    return `<span class="mdt-badge mdt-badge-${d[0]}">Danger ${d[1]}</span>`;
}

async function renderWarrants() {
    setContent(`
        <div class="mdt-page-title">Avis de recherche</div>
        <div class="mdt-page-sub">Création, niveau de danger et suivi des personnes recherchées.</div>
        <div style="display:flex;justify-content:space-between;align-items:center;gap:12px;flex-wrap:wrap">
            <div class="mdt-pills" id="wr-pills">
                <div class="mdt-pill ${state.currentWarrantStatus === 'active' ? 'active' : ''}" data-s="active">Actifs</div>
                <div class="mdt-pill ${state.currentWarrantStatus === 'closed' ? 'active' : ''}" data-s="closed">Clôturés</div>
            </div>
            ${has('manage_warrants') ? `<button class="mdt-btn mdt-btn-primary" id="wr-new">+ Nouvel avis</button>` : ''}
        </div>
        <div id="wr-list"></div>
    `);
    document.querySelectorAll('#wr-pills .mdt-pill').forEach((p) => p.addEventListener('click', () => {
        state.currentWarrantStatus = p.dataset.s; renderWarrants();
    }));
    const nb = el('wr-new'); if (nb) nb.addEventListener('click', () => formWarrant(null));
    el('wr-list').innerHTML = emptyState('⏳', 'Chargement…');
    const rows = asArray(await fetchNui('mdt:getWarrants', { status: state.currentWarrantStatus }));
    if (!el('wr-list')) return;
    if (!rows.length) { el('wr-list').innerHTML = emptyState('🚨', 'Aucun avis de recherche.'); return; }
    el('wr-list').innerHTML = rows.map((w) => `
        <div class="mdt-card">
            <div style="display:flex;justify-content:space-between;align-items:flex-start;gap:12px">
                <div>
                    <div style="font-size:16px;font-weight:700;margin-bottom:4px">${esc(w.citizen_name || 'Individu non identifié')} ${dangerBadge(parseInt(w.danger_level))}</div>
                    <div style="color:var(--mdt-text-dim);font-size:13px">Émis par ${esc(w.author_name)}${depBadge(w.department)} · ${fmtDate(w.created_at)}</div>
                </div>
                ${has('manage_warrants') ? `<div style="display:flex;gap:8px">
                    <button class="mdt-btn mdt-btn-sm" data-edit-wr="${esc(w.id)}">✏️</button>
                    <button class="mdt-btn mdt-btn-sm mdt-btn-danger" data-del-wr="${esc(w.id)}">🗑</button>
                </div>` : ''}
            </div>
            <p style="margin-top:12px;font-size:14px;line-height:1.5">${esc(w.reason || '')}</p>
        </div>`).join('');
    document.querySelectorAll('[data-edit-wr]').forEach((x) => x.addEventListener('click', () => {
        const w = rows.find((r) => String(r.id) === x.dataset.editWr); formWarrant(w);
    }));
    document.querySelectorAll('[data-del-wr]').forEach((x) => x.addEventListener('click', () => {
        fetchNui('mdt:deleteWarrant', { id: x.dataset.delWr });
    }));
}

function formWarrant(existing) {
    // Niveau de danger & statut via pills (les <select> natifs ne sont pas
    // fiables dans le NUI CEF de FiveM : le dropdown ne s'ouvre pas toujours).
    let dangerVal = existing ? (parseInt(existing.danger_level) || 1) : 1;
    let statusVal = existing ? (existing.status === 'closed' ? 'closed' : 'active') : 'active';
    // Individu sélectionné via la recherche (lie l'identifier réel du citoyen)
    let selId = existing ? (existing.identifier || null) : null;
    let selName = existing ? (existing.citizen_name || '') : '';
    const pill = (v, label, cur) => `<div class="mdt-pill ${String(cur) === String(v) ? 'active' : ''}" data-v="${v}">${label}</div>`;
    openModal(existing ? "Modifier l'avis" : 'Nouvel avis de recherche', `
        <div class="mdt-form-row"><label>Individu recherché</label>
            <div class="mdt-autocomplete">
                <input class="mdt-input" id="w-search" value="${esc(selName)}" placeholder="Rechercher un citoyen (nom ou prénom)…" autocomplete="off">
                <div class="mdt-ac-results mdt-hidden" id="w-results"></div>
            </div>
            <div class="mdt-ac-selected ${selId ? 'ok' : ''}" id="w-selected">${selId ? '✓ ' + esc(selName) : "Recherchez et sélectionnez un citoyen pour lier son identité."}</div>
        </div>
        <div class="mdt-form-row"><label>Niveau de danger</label>
            <div class="mdt-pills" id="w-danger">${pill(1, 'Faible', dangerVal)}${pill(2, 'Modéré', dangerVal)}${pill(3, 'Élevé', dangerVal)}</div>
        </div>
        <div class="mdt-form-row"><label>Motif / description</label><textarea class="mdt-textarea" id="w-reason" style="min-height:120px">${esc(existing ? existing.reason : '')}</textarea></div>
        ${existing ? `<div class="mdt-form-row"><label>Statut</label>
            <div class="mdt-pills" id="w-status">${pill('active', 'Actif', statusVal)}${pill('closed', 'Clôturé', statusVal)}</div></div>` : ''}
    `, `<button class="mdt-btn" onclick="window.__mdtCloseModal()">Annuler</button>
        <button class="mdt-btn mdt-btn-primary" id="w-submit">${existing ? 'Enregistrer' : 'Émettre'}</button>`);

    // ── Recherche d'individu (autocomplete avec date de naissance) ──
    let acTimer;
    const acBox = el('w-results');
    el('w-search').addEventListener('input', () => {
        selId = null;
        el('w-selected').classList.remove('ok');
        el('w-selected').textContent = "Recherchez et sélectionnez un citoyen pour lier son identité.";
        const q = el('w-search').value.trim();
        clearTimeout(acTimer);
        if (q.length < 2) { acBox.classList.add('mdt-hidden'); return; }
        acTimer = setTimeout(async () => {
            const rows = asArray(await fetchNui('mdt:searchCitizens', { query: q }));
            if (!el('w-results')) return;
            if (!rows.length) {
                acBox.innerHTML = '<div class="mdt-ac-item mdt-ac-empty">Aucun citoyen trouvé</div>';
            } else {
                acBox.innerHTML = rows.map((r) => `<div class="mdt-ac-item" data-id="${esc(r.identifier)}" data-name="${esc(r.name)}">
                    <span>${esc(r.name)} ${r.wanted ? '<span class="mdt-wanted-flag">Recherché</span>' : ''}</span>
                    <span class="mdt-ac-ddn">${esc(r.sexe || '?')} · ${esc(r.ddn || '?')}</span></div>`).join('');
            }
            acBox.classList.remove('mdt-hidden');
            acBox.querySelectorAll('.mdt-ac-item[data-id]').forEach((it) => it.addEventListener('click', () => {
                selId = it.dataset.id; selName = it.dataset.name;
                el('w-search').value = selName;
                const sel = el('w-selected'); sel.classList.add('ok'); sel.textContent = '✓ ' + selName;
                acBox.classList.add('mdt-hidden');
            }));
        }, 250);
    });

    document.querySelectorAll('#w-danger .mdt-pill').forEach((p) => p.addEventListener('click', () => {
        dangerVal = parseInt(p.dataset.v);
        document.querySelectorAll('#w-danger .mdt-pill').forEach((x) => x.classList.toggle('active', x === p));
    }));
    document.querySelectorAll('#w-status .mdt-pill').forEach((p) => p.addEventListener('click', () => {
        statusVal = p.dataset.v;
        document.querySelectorAll('#w-status .mdt-pill').forEach((x) => x.classList.toggle('active', x === p));
    }));
    el('w-submit').addEventListener('click', () => {
        const reason = el('w-reason').value.trim();
        if (!reason) { toast('Motif requis.', false); return; }
        if (!selId) { toast('Sélectionnez un citoyen dans la liste.', false); return; }
        const payload = { identifier: selId, citizen_name: selName, danger_level: dangerVal, reason };
        if (existing) { payload.id = existing.id; payload.status = statusVal; fetchNui('mdt:updateWarrant', payload); }
        else { fetchNui('mdt:createWarrant', payload); }
        closeModal();
    });
}

/* ════════════════════════════════════════════════════════════════
   ONGLET — GARDE À VUE (historique)
   ════════════════════════════════════════════════════════════════ */
async function renderCustody() {
    setContent(`
        <div class="mdt-page-title">Gardes à vue</div>
        <div class="mdt-page-sub">Historique et procès-verbaux. La mise en cellule s'effectue en jeu.</div>
        <div id="gv-list">${emptyState('⏳', 'Chargement…')}</div>
    `);
    const rows = asArray(await fetchNui('mdt:getCustodyHistory', {}));
    if (!el('gv-list')) return;
    if (!rows.length) { el('gv-list').innerHTML = emptyState('🔒', 'Aucune garde à vue enregistrée.'); return; }
    el('gv-list').innerHTML = `<div class="mdt-card"><table class="mdt-table">
        <thead><tr><th>Début</th><th>Citoyen</th><th>Motif</th><th>Durée</th><th>Agent</th><th>PV</th></tr></thead><tbody>` +
        rows.map((c) => `<tr>
            <td>${fmtDate(c.started_at)}</td>
            <td><b>${esc(c.citizen_name)}</b></td>
            <td>${esc(c.reason || '—')}</td>
            <td>${esc(c.duration)} min</td>
            <td>${esc(c.officer_name)}${depBadge(c.department)}</td>
            <td>${c.pv ? `<button class="mdt-btn mdt-btn-sm" data-pv="${esc(c.id)}">📄</button>` : '—'}</td>
        </tr>`).join('') + `</tbody></table></div>`;
    document.querySelectorAll('#gv-list [data-pv]').forEach((x) => x.addEventListener('click', () => {
        const c = rows.find((cc) => String(cc.id) === x.dataset.pv);
        openModal('Procès-verbal', `<pre style="white-space:pre-wrap;font-family:var(--mdt-font);font-size:14px;line-height:1.5">${esc(c && c.pv || '')}</pre>`, `<button class="mdt-btn" onclick="window.__mdtCloseModal()">Fermer</button>`);
    }));
}

/* ════════════════════════════════════════════════════════════════
   ONGLET — ENQUÊTES (preuves) — Investigation complète
   ════════════════════════════════════════════════════════════════ */
async function renderInvestigation() {
    const evTypeIcons = { fingerprint: '🖐️', dna: '🧬', blood: '🩸', scene: '🔫', douille: '🔫', object: '📦', other: '🔍' };
    const evTypeBadge = { fingerprint: 'mdt-badge-blue', dna: 'mdt-badge-green', blood: 'mdt-badge-red', scene: 'mdt-badge-orange', douille: 'mdt-badge-orange', object: 'mdt-badge-gray', other: 'mdt-badge-gray' };
    const evTypeLabel = { fingerprint: 'Empreinte', dna: 'ADN', blood: 'Sang', scene: 'Douille', douille: 'Douille', object: 'Objet', other: 'Autre' };

    setContent(`
        <div class="mdt-page-title">Labo</div>
        <div class="mdt-page-sub">Preuves collectées sur le terrain par les agents PTS. La collecte s'effectue en jeu (F8).</div>

        <!-- Statistiques rapides -->
        <div class="mdt-grid-4" id="ev-stats">
            ${['🖐️ Empreintes', '🧬 ADN', '🩸 Sang', '🔫 Douilles'].map((l) =>
        `<div class="mdt-stat-card"><div class="stat-label">${l}</div><div class="stat-value" id="stat-${l.split(' ')[1]}">—</div></div>`
    ).join('')}
        </div>

        <!-- Recherche / filtre -->
        <div class="mdt-card" style="padding:14px 16px">
            <div class="mdt-row-gap">
                <input type="text" id="ev-search" class="mdt-input" placeholder="Référence, description, scène, nom…" style="flex:1">
                <select id="ev-type-filter" class="mdt-input" style="width:170px">
                    <option value="">Tous les types</option>
                    <option value="fingerprint">🖐️ Empreintes</option>
                    <option value="dna">🧬 ADN</option>
                    <option value="blood">🩸 Sang</option>
                    <option value="douille">🔫 Douille</option>
                    <option value="unidentified">❓ Non identifiées</option>
                </select>
                <button class="mdt-btn mdt-btn-sm mdt-btn-primary" id="ev-filter-btn">Filtrer</button>
            </div>
        </div>

        <!-- Liste des preuves -->
        <div class="mdt-card">
            <div class="mdt-card-title" style="display:flex;align-items:center;justify-content:space-between">
                <span>Preuves enregistrées</span>
                <span class="mdt-badge mdt-badge-blue" id="ev-count">—</span>
            </div>
            <div id="ev-list">${emptyState('⏳', 'Chargement…')}</div>
        </div>

    `);

    // Charger les preuves
    let rows = asArray(await fetchNui('mdt:getEvidence', {}));
    if (!el('ev-list')) return;

    // Stats
    const counts = { fingerprint: 0, dna: 0, blood: 0, scene: 0, douille: 0 };
    rows.forEach(e => { if (counts[e.type] !== undefined) counts[e.type]++; });
    const statMap = { 'Empreintes': 'fingerprint', 'ADN': 'dna', 'Sang': 'blood', 'Douilles': 'douille' };
    Object.entries(statMap).forEach(([k, v]) => {
        const el2 = el('stat-' + k); if (el2) el2.textContent = (v === 'douille') ? (counts.douille + counts.scene) : counts[v];
    });
    if (el('ev-count')) el('ev-count').textContent = rows.length + ' preuve(s)';

    // Une preuve est "non identifiée" si elle n'est rattachée à aucun citoyen
    const isUnidentified = (e) => !e.identifier || e.identifier === '';

    function renderRows(data) {
        if (!data.length) { el('ev-list').innerHTML = emptyState('🔬', 'Aucune preuve correspondante.'); return; }
        el('ev-list').innerHTML = `<table class="mdt-table" style="table-layout:fixed;width:100%">
        <colgroup>
            <col style="width:13%"><col style="width:16%"><col style="width:31%">
            <col style="width:12%"><col style="width:16%"><col style="width:12%">
        </colgroup>
        <thead><tr>
            <th>Type</th><th>Référence</th><th>Description</th><th>Citoyen</th><th>Relevé par</th><th>Date</th>
        </tr></thead><tbody>` +
            data.map((e) => `<tr class="ev-row" data-ev-ref="${esc(e.ref || '')}" data-ev-type="${esc(e.type || '')}" style="cursor:pointer">
            <td><span class="mdt-badge ${evTypeBadge[e.type] || 'mdt-badge-gray'}">${evTypeIcons[e.type] || '🔍'} ${esc(evTypeLabel[e.type] || e.type)}</span></td>
            <td style="font-family:monospace;font-size:12px;word-break:break-all">${e.ref ? `${esc(e.ref)} <button class="mdt-btn mdt-btn-sm" data-copy-ref="${esc(e.ref)}" title="Copier la référence">📋</button>` : '—'}</td>
            <td style="word-break:break-word">${esc(e.description || e.label || '—')}${isUnidentified(e) ? ' <span class="mdt-badge mdt-badge-gray">Non identifiée</span>' : ''}</td>
            <td style="word-break:break-word">${e.citizen_name ? `<b>${esc(e.citizen_name)}</b>` : '<span class="mdt-badge mdt-badge-gray">Inconnu</span>'}</td>
            <td style="word-break:break-word">${esc(e.officer_name || '—')}</td>
            <td>${fmtDate(e.created_at)}</td>
        </tr>`).join('') + `</tbody></table>`;
        // Clic sur une preuve → détails + description
        el('ev-list').querySelectorAll('.ev-row').forEach((tr) => tr.addEventListener('click', () => {
            const e = data.find((x) => String(x.ref) === tr.dataset.evRef && String(x.type) === tr.dataset.evType);
            if (e) openEvidenceDetail(e);
        }));
        // Copier la référence (sans ouvrir le détail)
        el('ev-list').querySelectorAll('[data-copy-ref]').forEach((btn) => btn.addEventListener('click', (ev) => {
            ev.stopPropagation();
            copyText(btn.dataset.copyRef);
        }));
    }
    renderRows(rows);

    // Filtrage / recherche
    const applyFilter = () => {
        const search = (el('ev-search').value || '').toLowerCase();
        const type = el('ev-type-filter').value;
        const filtered = rows.filter((e) => {
            let typeOk = true;
            if (type === 'douille') typeOk = (e.type === 'douille' || e.type === 'scene');
            else if (type === 'unidentified') typeOk = isUnidentified(e);
            else if (type) typeOk = (e.type === type);
            const searchOk = !search
                || (e.ref || '').toLowerCase().includes(search)
                || (e.description || e.label || '').toLowerCase().includes(search)
                || (e.scene_id || '').toLowerCase().includes(search)
                || (e.citizen_name || '').toLowerCase().includes(search);
            return typeOk && searchOk;
        });
        renderRows(filtered);
        if (el('ev-count')) el('ev-count').textContent = filtered.length + ' preuve(s)';
    };
    b('ev-filter-btn', applyFilter);
    { const si = el('ev-search'); if (si) si.addEventListener('keydown', (e) => { if (e.key === 'Enter') applyFilter(); }); }
}

// Détail d'une preuve + description détaillée éditable
function openEvidenceDetail(e) {
    const typeLabelMap = { fingerprint: 'Empreinte', dna: 'ADN', blood: 'Sang', scene: 'Douille', douille: 'Douille' };
    const canEdit = has('manage_evidence');
    openModal(`Preuve ${e.ref || ''}`, `
        <dl class="mdt-kv">
            <dt>Type</dt><dd>${esc(typeLabelMap[e.type] || e.type)}</dd>
            <dt>Référence</dt><dd>${e.ref ? `<span style="font-family:monospace">${esc(e.ref)}</span> <button class="mdt-btn mdt-btn-sm" id="evd-copy-ref" data-copy-ref="${esc(e.ref)}" title="Copier la référence">📋 Copier</button>` : '—'}</dd>
            <dt>Citoyen</dt><dd>${e.citizen_name ? esc(e.citizen_name) : '<span style="color:var(--mdt-text-dim)">Non identifiée</span>'}</dd>
            <dt>Scène</dt><dd>${esc(e.scene_id || '—')}</dd>
            <dt>Relevé par</dt><dd>${esc(e.officer_name || '—')}</dd>
            <dt>Date</dt><dd>${fmtDate(e.created_at)}</dd>
        </dl>
        <div class="mdt-form-row" style="margin-top:14px"><label>Description détaillée</label>
            <textarea class="mdt-textarea" id="evd-desc" style="min-height:120px" ${canEdit ? '' : 'readonly'}>${esc(e.description || '')}</textarea>
        </div>
    `, `<button class="mdt-btn" onclick="window.__mdtCloseModal()">Fermer</button>
        ${canEdit ? `<button class="mdt-btn mdt-btn-primary" id="evd-save">Enregistrer la description</button>` : ''}`);
    const cb = el('evd-copy-ref');
    if (cb) cb.addEventListener('click', () => copyText(cb.dataset.copyRef));
    const sb = el('evd-save');
    if (sb) sb.addEventListener('click', () => {
        fetchNui('mdt:updateEvidence', { type: e.type, ref: e.ref, description: el('evd-desc').value.trim() });
        closeModal();
    });
}

/* ════════════════════════════════════════════════════════════════
   ONGLET — CODE JURIDIQUE (lois / infractions)
   ════════════════════════════════════════════════════════════════ */
async function renderLaws() {
    const cats = asArray(state.payload.lawCategories);
    if (state.lawCategory === undefined) state.lawCategory = 'all';
    setContent(`
        <div class="mdt-page-title">Code Juridique</div>
        <div class="mdt-page-sub">Lois et infractions — sanctions et catégories légales.</div>
        <div style="display:flex;justify-content:space-between;align-items:center;gap:12px;flex-wrap:wrap">
            <div class="mdt-searchbar" style="flex:1;margin-bottom:0">
                <input class="mdt-input" id="lw-search" placeholder="Article, infraction ou catégorie…" autocomplete="off">
                <button class="mdt-btn mdt-btn-primary" id="lw-search-btn">🔍 Rechercher</button>
            </div>
            ${has('manage_laws') ? `<button class="mdt-btn mdt-btn-primary" id="lw-new">+ Ajouter un article</button>` : ''}
        </div>
        <div class="mdt-pills" id="lw-pills" style="margin-top:16px">
            <div class="mdt-pill ${state.lawCategory === 'all' ? 'active' : ''}" data-c="all">Toutes</div>
            ${cats.map((c) => `<div class="mdt-pill ${state.lawCategory === c ? 'active' : ''}" data-c="${esc(c)}">${esc(c)}</div>`).join('')}
        </div>
        <div id="lw-list"></div>
    `);
    const run = async () => {
        el('lw-list').innerHTML = emptyState('⏳', 'Chargement…');
        const rows = asArray(await fetchNui('mdt:getLaws', { query: el('lw-search').value.trim(), category: state.lawCategory }));
        if (!el('lw-list')) return;
        if (!rows.length) { el('lw-list').innerHTML = emptyState('⚖️', 'Aucun article trouvé.'); return; }
        el('lw-list').innerHTML = `<div class="mdt-card" style="padding:0"><table class="mdt-table">
            <thead><tr><th>Article</th><th>Infraction</th><th>Catégorie</th><th>Amende</th><th>Prison</th>${has('manage_laws') ? '<th></th>' : ''}</tr></thead><tbody>` +
            rows.map((l) => `<tr class="lw-row" data-id="${esc(l.id)}" style="cursor:pointer">
                <td><b>${esc(l.article || '—')}</b></td>
                <td>${esc(l.name)}</td>
                <td><span class="mdt-badge mdt-badge-gray">${esc(l.category || '—')}</span></td>
                <td>${l.fine ? esc(l.fine) + ' $' : '—'}</td>
                <td>${esc(l.jail || '—')}</td>
                ${has('manage_laws') ? `<td>
                    <button class="mdt-btn mdt-btn-sm" data-edit-law="${esc(l.id)}">✏️</button>
                    <button class="mdt-btn mdt-btn-sm mdt-btn-danger" data-del-law="${esc(l.id)}">🗑</button>
                </td>` : ''}
            </tr>`).join('') + `</tbody></table></div>`;
        el('lw-list').querySelectorAll('.lw-row').forEach((tr) => tr.addEventListener('click', (e) => {
            if (e.target.closest('[data-edit-law]') || e.target.closest('[data-del-law]')) return;
            const l = rows.find((x) => String(x.id) === tr.dataset.id); if (l) showLawDetail(l);
        }));
        el('lw-list').querySelectorAll('[data-edit-law]').forEach((x) => x.addEventListener('click', () => {
            const l = rows.find((r) => String(r.id) === x.dataset.editLaw); formLaw(l);
        }));
        el('lw-list').querySelectorAll('[data-del-law]').forEach((x) => x.addEventListener('click', () => {
            fetchNui('mdt:deleteLaw', { id: x.dataset.delLaw });
        }));
    };
    el('lw-search-btn').addEventListener('click', run);
    el('lw-search').addEventListener('keydown', (e) => { if (e.key === 'Enter') run(); });
    document.querySelectorAll('#lw-pills .mdt-pill').forEach((p) => p.addEventListener('click', () => {
        state.lawCategory = p.dataset.c; renderLaws();
    }));
    const nb = el('lw-new'); if (nb) nb.addEventListener('click', () => formLaw(null));
    run();
}

function showLawDetail(l) {
    openModal(`${l.article ? '[' + l.article + '] ' : ''}${l.name}`, `
        <dl class="mdt-kv">
            <dt>Article</dt><dd>${esc(l.article || '—')}</dd>
            <dt>Infraction</dt><dd>${esc(l.name)}</dd>
            <dt>Catégorie</dt><dd>${esc(l.category || '—')}</dd>
            <dt>Amende</dt><dd>${l.fine ? esc(l.fine) + ' $' : '—'}</dd>
            <dt>Prison</dt><dd>${esc(l.jail || '—')}</dd>
        </dl>
        <div style="margin-top:14px"><div class="mdt-card-title">Description</div>
            <p style="white-space:pre-wrap;font-size:14px;line-height:1.5">${esc(l.description || '—')}</p></div>
    `, `<button class="mdt-btn" onclick="window.__mdtCloseModal()">Fermer</button>`);
}

function formLaw(existing) {
    const cats = asArray(state.payload.lawCategories);
    let category = existing ? existing.category : (cats[0] || '');
    const pill = (v) => `<div class="mdt-pill ${v === category ? 'active' : ''}" data-v="${esc(v)}">${esc(v)}</div>`;
    openModal(existing ? "Modifier l'article" : 'Nouvel article', `
        <div class="mdt-form-row"><label>Article / référence</label><input class="mdt-input" id="lwf-article" value="${esc(existing ? existing.article : '')}" placeholder="221-1"></div>
        <div class="mdt-form-row"><label>Infraction</label><input class="mdt-input" id="lwf-name" value="${esc(existing ? existing.name : '')}" placeholder="Homicide volontaire"></div>
        <div class="mdt-form-row"><label>Catégorie</label><div class="mdt-pills" id="lwf-cat">${cats.map(pill).join('')}</div></div>
        <div class="mdt-form-row"><label>Amende ($)</label><input class="mdt-input" id="lwf-fine" type="number" min="0" value="${existing ? esc(existing.fine) : ''}" placeholder="100000"></div>
        <div class="mdt-form-row"><label>Peine de prison</label><input class="mdt-input" id="lwf-jail" value="${esc(existing ? existing.jail : '')}" placeholder="Perpétuité, 5 ans…"></div>
        <div class="mdt-form-row"><label>Description</label><textarea class="mdt-textarea" id="lwf-desc" style="min-height:120px">${esc(existing ? existing.description : '')}</textarea></div>
    `, `<button class="mdt-btn" onclick="window.__mdtCloseModal()">Annuler</button>
        <button class="mdt-btn mdt-btn-primary" id="lwf-submit">${existing ? 'Enregistrer' : 'Ajouter'}</button>`);
    document.querySelectorAll('#lwf-cat .mdt-pill').forEach((p) => p.addEventListener('click', () => {
        category = p.dataset.v;
        document.querySelectorAll('#lwf-cat .mdt-pill').forEach((x) => x.classList.toggle('active', x === p));
    }));
    el('lwf-submit').addEventListener('click', () => {
        const name = el('lwf-name').value.trim();
        if (!name) { toast('Infraction requise.', false); return; }
        const payload = {
            article: el('lwf-article').value.trim(), name, category,
            fine: parseInt(el('lwf-fine').value) || 0, jail: el('lwf-jail').value.trim(),
            description: el('lwf-desc').value.trim(),
        };
        if (existing) { payload.id = existing.id; fetchNui('mdt:updateLaw', payload); }
        else fetchNui('mdt:createLaw', payload);
        closeModal();
    });
}

/* ════════════════════════════════════════════════════════════════
   ONGLET — EFFECTIFS (agents connectés + statut de service)
   ════════════════════════════════════════════════════════════════ */
function renderRosterList(agents) {
    const list = el('ef-list');
    if (!list) return;
    if (!agents.length) { list.innerHTML = emptyState('👮', 'Aucun agent connecté.'); return; }
    list.innerHTML = agents.map((a) => `
        <div class="mdt-roster-item" data-agent="${esc(a.character_id != null ? a.character_id : '')}" style="cursor:pointer">
            <span class="mdt-dot ${a.onDuty ? 'mdt-dot-on' : 'mdt-dot-off'}" title="${a.onDuty ? 'En service' : 'Hors service'}"></span>
            <div class="mdt-roster-main">
                <div class="mdt-roster-name">${esc(a.name || 'Agent')}</div>
                <div class="mdt-roster-grade">${esc(a.gradeLabel || '—')}</div>
            </div>
            <span class="mdt-badge ${a.onDuty ? 'mdt-badge-green' : 'mdt-badge-red'}">${a.onDuty ? 'En service' : 'Hors service'}</span>
        </div>`).join('');
    list.querySelectorAll('.mdt-roster-item[data-agent]').forEach((it) => it.addEventListener('click', () => {
        if (it.dataset.agent) openAgentFile(it.dataset.agent);
    }));
}

async function renderEffectifs() {
    if (state.rosterTimer) { clearInterval(state.rosterTimer); state.rosterTimer = null; }
    if (state.rosterExpanded === undefined) state.rosterExpanded = true;
    setContent(`
        <div class="mdt-page-title">Effectifs</div>
        <div class="mdt-page-sub">Agents connectés, triés par grade. Statut de service en temps réel.</div>
        <div class="mdt-card" style="padding:0">
            <div class="mdt-card-title" id="ef-toggle" style="cursor:pointer;padding:16px 18px;margin:0;display:flex;align-items:center;justify-content:space-between">
                <span>Effectifs en ligne — <span id="ef-count">…</span></span>
                <span id="ef-chevron">${state.rosterExpanded ? '▼' : '▶'}</span>
            </div>
            <div id="ef-list" class="${state.rosterExpanded ? '' : 'mdt-hidden'}">${emptyState('⏳', 'Chargement…')}</div>
        </div>
    `);

    const load = async () => {
        const agents = asArray(await fetchNui('mdt:getRoster', {}));
        if (state.currentTab !== 'effectifs' || !el('ef-list')) return;
        const onCount = agents.filter((a) => a.onDuty).length;
        const cnt = el('ef-count'); if (cnt) cnt.textContent = `${agents.length} agent(s) · ${onCount} en service`;
        renderRosterList(agents);
    };

    el('ef-toggle').addEventListener('click', () => {
        state.rosterExpanded = !state.rosterExpanded;
        const lst = el('ef-list'); const chev = el('ef-chevron');
        if (lst) lst.classList.toggle('mdt-hidden', !state.rosterExpanded);
        if (chev) chev.textContent = state.rosterExpanded ? '▼' : '▶';
    });

    await load();

    // Rafraîchissement temps réel (auto-nettoyé en quittant l'onglet / fermeture)
    state.rosterTimer = setInterval(() => {
        if (state.currentTab !== 'effectifs' || el('mdt').classList.contains('mdt-hidden')) {
            clearInterval(state.rosterTimer); state.rosterTimer = null; return;
        }
        load();
    }, 5000);
}

/* ── Fiche détaillée d'un agent (depuis l'onglet Effectifs) ───────── */
async function openAgentFile(characterId) {
    if (state.rosterTimer) { clearInterval(state.rosterTimer); state.rosterTimer = null; }
    state.currentAgent = characterId;
    setContent(emptyState('⏳', 'Chargement de la fiche…'));
    const d = await fetchNui('mdt:getAgentFile', { character_id: characterId });
    if (!d || !d.identity) { setContent(emptyState('🚫', 'Agent introuvable.')); return; }
    const id = d.identity, meta = d.meta || {}, career = d.career || {};
    const identifier = id.identifier;
    const assignments = asArray(d.assignments), comms = asArray(d.commendations), skills = asArray(d.skills);
    const grades = asArray(state.payload.grades);
    const canEdit = has('manage_personnel');

    // Statut de recyclage : calculé côté serveur (s.recycle_status), affiché tel quel.
    const skillStatus = (s) => {
        if (s.recycle_status === 'valid') return '<span class="mdt-badge mdt-badge-green">Validé</span>';
        if (s.recycle_status === 'expired') return '<span class="mdt-badge mdt-badge-red">À recycler</span>';
        return '<span style="color:var(--mdt-text-dim)">—</span>';
    };

    setContent(`
        <div class="mdt-back" id="ag-back">← Retour aux effectifs</div>
        <div class="mdt-page-title">${esc(id.name)} <span class="mdt-badge mdt-badge-blue">${esc(meta.matricule || '—')}</span></div>
        <div class="mdt-page-sub">${esc(id.gradeLabel || '—')}</div>

        <div class="mdt-card">
            <div class="mdt-card-title">Informations générales ${canEdit ? `<button class="mdt-btn mdt-btn-sm mdt-btn-primary" id="ag-save-meta">Enregistrer</button>` : ''}</div>
            <div class="mdt-grid-2">
                <dl class="mdt-kv">
                    <dt>Matricule</dt><dd>${esc(meta.matricule || '—')}</dd>
                    <dt>Nom</dt><dd>${esc(id.nom || '—')}</dd>
                    <dt>Prénom</dt><dd>${esc(id.prenom || '—')}</dd>
                    <dt>Naissance</dt><dd>${esc(id.ddn || '—')}</dd>
                </dl>
                <dl class="mdt-kv">
                    <dt>Entrée police</dt><dd>${canEdit ? `<input class="mdt-input" style="max-width:180px" type="date" id="ag-hire" value="${esc(meta.hire_date || '')}">` : fmtDateFR(meta.hire_date)}</dd>
                    <dt>Titularisation</dt><dd>${canEdit ? `<input class="mdt-input" style="max-width:180px" type="date" id="ag-tenure" value="${esc(meta.tenure_date || '')}">` : fmtDateFR(meta.tenure_date)}</dd>
                    <dt>Arme de service</dt><dd>${canEdit ? `<input class="mdt-input" style="max-width:180px" id="ag-weapon" value="${esc(meta.service_weapon || '')}" placeholder="N° de série">` : esc(meta.service_weapon || '—')}</dd>
                </dl>
            </div>
        </div>

        <div class="mdt-card">
            <div class="mdt-card-title">Historique de carrière ${canEdit ? `<button class="mdt-btn mdt-btn-sm mdt-btn-primary" id="ag-save-career">Enregistrer</button>` : ''}</div>
            <table class="mdt-table"><thead><tr><th>Grade</th><th>Date de début</th><th>Date de fin</th></tr></thead><tbody>
            ${grades.map((g) => {
        const c = career[String(g.grade)] || {};
        return `<tr>
                    <td><b>${esc(g.label)}</b></td>
                    <td>${canEdit ? `<input class="mdt-input" style="max-width:170px" type="date" data-car-start="${g.grade}" value="${esc(c.start_date || '')}">` : fmtDateFR(c.start_date)}</td>
                    <td>${canEdit ? `<input class="mdt-input" style="max-width:170px" type="date" data-car-end="${g.grade}" value="${esc(c.end_date || '')}">` : fmtDateFR(c.end_date)}</td>
                </tr>`;
    }).join('')}
            </tbody></table>
        </div>

        <div class="mdt-card">
            <div class="mdt-card-title">Affectations opérationnelles ${canEdit ? `<button class="mdt-btn mdt-btn-sm mdt-btn-primary" id="ag-add-assign">+ Ajouter</button>` : ''}</div>
            ${assignments.length ? `<table class="mdt-table"><thead><tr><th>Code Affectation</th><th>Date de début</th><th>Date de fin</th>${canEdit ? '<th></th>' : ''}</tr></thead><tbody>` +
            assignments.map((a) => `<tr>
                    <td><b>${esc(a.code)}</b></td><td>${fmtDateFR(a.start_date)}</td><td>${fmtDateFR(a.end_date)}</td>
                    ${canEdit ? `<td style="white-space:nowrap">
                        <button class="mdt-btn mdt-btn-sm" data-edit-assign="${esc(a.id)}">✏️</button>
                        <button class="mdt-btn mdt-btn-sm mdt-btn-danger" data-del-assign="${esc(a.id)}">🗑</button></td>` : ''}
                </tr>`).join('') + `</tbody></table>` : emptyState('📍', 'Aucune affectation.')}
        </div>

        <div class="mdt-card">
            <div class="mdt-card-title">Lettres de félicitations / sanctions ${canEdit ? `<button class="mdt-btn mdt-btn-sm mdt-btn-primary" id="ag-add-comm">+ Ajouter</button>` : ''}</div>
            ${comms.length ? `<table class="mdt-table"><thead><tr><th>Date d'obtention</th><th>Nature</th><th>Motif</th>${canEdit ? '<th></th>' : ''}</tr></thead><tbody>` +
            comms.map((c) => `<tr class="comm-row" data-comm="${esc(c.id)}" style="cursor:pointer">
                    <td>${fmtDateFR(c.obtained_date)}</td>
                    <td>${c.nature === 'sanction' ? '<span class="mdt-badge mdt-badge-red">Sanction</span>' : '<span class="mdt-badge mdt-badge-green">Félicitation</span>'}</td>
                    <td>${esc(c.reason)}</td>
                    ${canEdit ? `<td><button class="mdt-btn mdt-btn-sm mdt-btn-danger" data-del-comm="${esc(c.id)}">🗑</button></td>` : ''}
                </tr>`).join('') + `</tbody></table>` : emptyState('🎖️', 'Aucune entrée.')}
        </div>

        <div class="mdt-card">
            <div class="mdt-card-title">Compétences ${canEdit ? `<button class="mdt-btn mdt-btn-sm mdt-btn-primary" id="ag-add-skill">+ Ajouter</button>` : ''}</div>
            ${skills.length ? `<table class="mdt-table"><thead><tr><th>Compétence</th><th>Statut</th><th>Date d'obtention</th>${canEdit ? '<th></th>' : ''}</tr></thead><tbody>` +
            skills.map((s) => `<tr>
                    <td><b>${esc(s.skill)}</b>${s.code ? ` <span class="mdt-badge mdt-badge-gray">${esc(s.code)}</span>` : ''}</td>
                    <td>${skillStatus(s)}</td>
                    <td>${fmtDateFR(s.obtained_at)}</td>
                    ${canEdit ? `<td style="white-space:nowrap">
                        <button class="mdt-btn mdt-btn-sm" data-edit-skill-date="${esc(s.id)}" data-date="${esc(toISODate(s.obtained_at))}" title="Modifier la date">✏️</button>
                        <button class="mdt-btn mdt-btn-sm mdt-btn-danger" data-del-skill="${esc(s.id)}">🗑</button></td>` : ''}
                </tr>`).join('') + `</tbody></table>` : emptyState('🎓', 'Aucune compétence. Les formations validées apparaissent ici automatiquement.')}
        </div>
    `);

    b('ag-back', renderEffectifs);
    if (canEdit) {
        b('ag-save-meta', () => fetchNui('mdt:saveAgentMeta', {
            character_id: characterId, hire_date: el('ag-hire').value, tenure_date: el('ag-tenure').value, service_weapon: el('ag-weapon').value.trim(),
        }));
        b('ag-save-career', () => {
            const entries = [];
            document.querySelectorAll('[data-car-start]').forEach((inp) => {
                const g = inp.dataset.carStart;
                const endInp = document.querySelector('[data-car-end="' + g + '"]');
                entries.push({ grade: parseInt(g), start: inp.value, endDate: endInp ? endInp.value : '' });
            });
            fetchNui('mdt:saveCareer', { character_id: characterId, identifier, entries });
        });
        b('ag-add-assign', () => formAssignment(characterId, identifier, null));
        b('ag-add-comm', () => formCommendation(characterId, identifier));
        document.querySelectorAll('[data-edit-assign]').forEach((x) => x.addEventListener('click', (e) => {
            e.stopPropagation();
            const a = assignments.find((aa) => String(aa.id) === x.dataset.editAssign); formAssignment(characterId, identifier, a);
        }));
        document.querySelectorAll('[data-del-assign]').forEach((x) => x.addEventListener('click', () => {
            fetchNui('mdt:deleteAssignment', { id: x.dataset.delAssign, character_id: characterId });
        }));
        document.querySelectorAll('[data-del-comm]').forEach((x) => x.addEventListener('click', (e) => {
            e.stopPropagation();
            confirmAction('Supprimer cette entrée ?', () => fetchNui('mdt:deleteCommendation', { id: x.dataset.delComm, character_id: characterId }));
        }));
        b('ag-add-skill', () => formAddSkill(characterId, identifier));
        document.querySelectorAll('[data-del-skill]').forEach((x) => x.addEventListener('click', () => {
            confirmAction('Retirer cette compétence ?', () => fetchNui('mdt:deleteSkill', { id: x.dataset.delSkill, character_id: characterId }));
        }));
        document.querySelectorAll('[data-edit-skill-date]').forEach((x) => x.addEventListener('click', () => {
            formEditSkillDate(x.dataset.editSkillDate, x.dataset.date, characterId);
        }));
    }
    document.querySelectorAll('.comm-row').forEach((tr) => tr.addEventListener('click', (e) => {
        if (e.target.closest('[data-del-comm]')) return;
        const c = comms.find((cc) => String(cc.id) === tr.dataset.comm); if (c) showCommendationDetail(c);
    }));
}

function showCommendationDetail(c) {
    openModal(c.nature === 'sanction' ? 'Sanction' : 'Félicitation', `
        <dl class="mdt-kv">
            <dt>Nature</dt><dd>${c.nature === 'sanction' ? 'Sanction' : 'Félicitation'}</dd>
            <dt>Date</dt><dd>${fmtDateFR(c.obtained_date)}</dd>
            <dt>Motif</dt><dd>${esc(c.reason || '—')}</dd>
            <dt>Délivré par</dt><dd>${esc(c.author_name || '—')}</dd>
        </dl>
        <div style="margin-top:14px"><div class="mdt-card-title">Détails</div>
            <p style="white-space:pre-wrap;font-size:14px;line-height:1.5">${esc(c.details || '—')}</p></div>
    `, `<button class="mdt-btn" onclick="window.__mdtCloseModal()">Fermer</button>`);
}

function formAssignment(characterId, identifier, existing) {
    openModal(existing ? "Modifier l'affectation" : 'Nouvelle affectation', `
        <div class="mdt-form-row"><label>Code Affectation</label><input class="mdt-input" id="as-code" value="${esc(existing ? existing.code : '')}" placeholder="Ex : BAC-01"></div>
        <div class="mdt-form-row"><label>Date de début</label><input class="mdt-input" type="date" id="as-start" value="${esc(existing ? existing.start_date : '')}"></div>
        <div class="mdt-form-row"><label>Date de fin</label><input class="mdt-input" type="date" id="as-end" value="${esc(existing ? existing.end_date : '')}"></div>
    `, `<button class="mdt-btn" onclick="window.__mdtCloseModal()">Annuler</button>
        <button class="mdt-btn mdt-btn-primary" id="as-submit">${existing ? 'Enregistrer' : 'Ajouter'}</button>`);
    el('as-submit').addEventListener('click', () => {
        const code = el('as-code').value.trim();
        if (!code) { toast('Code requis.', false); return; }
        const payload = { character_id: characterId, identifier, code, start_date: el('as-start').value, end_date: el('as-end').value };
        if (existing) { payload.id = existing.id; fetchNui('mdt:updateAssignment', payload); }
        else fetchNui('mdt:addAssignment', payload);
        closeModal();
    });
}

function formCommendation(characterId, identifier) {
    let nature = 'felicitation';
    const pill = (v, label) => `<div class="mdt-pill ${v === nature ? 'active' : ''}" data-v="${v}">${label}</div>`;
    openModal('Ajouter une félicitation / sanction', `
        <div class="mdt-form-row"><label>Nature</label><div class="mdt-pills" id="cm-nature">${pill('felicitation', 'Félicitation')}${pill('sanction', 'Sanction')}</div></div>
        <div class="mdt-form-row"><label>Date d'obtention</label><input class="mdt-input" type="date" id="cm-date"></div>
        <div class="mdt-form-row"><label>Motif</label><input class="mdt-input" id="cm-reason" placeholder="Motif de la félicitation / sanction"></div>
        <div class="mdt-form-row"><label>Détails</label><textarea class="mdt-textarea" id="cm-details" placeholder="Circonstances détaillées…"></textarea></div>
    `, `<button class="mdt-btn" onclick="window.__mdtCloseModal()">Annuler</button>
        <button class="mdt-btn mdt-btn-primary" id="cm-submit">Ajouter</button>`);
    document.querySelectorAll('#cm-nature .mdt-pill').forEach((p) => p.addEventListener('click', () => {
        nature = p.dataset.v;
        document.querySelectorAll('#cm-nature .mdt-pill').forEach((x) => x.classList.toggle('active', x === p));
    }));
    el('cm-submit').addEventListener('click', () => {
        const reason = el('cm-reason').value.trim();
        if (!reason) { toast('Motif requis.', false); return; }
        fetchNui('mdt:addCommendation', { character_id: characterId, identifier, nature, obtained_date: el('cm-date').value, reason, details: el('cm-details').value.trim() });
        closeModal();
    });
}

// Ajout manuel d'une compétence (Commissaire / Commandant) via code formation
function formAddSkill(characterId, identifier) {
    const codes = asArray(state.payload.trainingCodes);
    let selCode = '', selName = '';
    openModal('Ajouter une compétence', `
        <div class="mdt-form-row"><label>Compétence (code formation)</label>
            <div class="mdt-autocomplete">
                <input class="mdt-input" id="sk-code" placeholder="Cliquer pour choisir…" autocomplete="off" readonly style="cursor:pointer">
                <div class="mdt-ac-results mdt-hidden" id="sk-code-list"></div>
            </div>
            <div class="mdt-ac-selected" id="sk-selected">Aucune compétence sélectionnée.</div>
        </div>
    `, `<button class="mdt-btn" onclick="window.__mdtCloseModal()">Annuler</button>
        <button class="mdt-btn mdt-btn-primary" id="sk-submit">Ajouter</button>`);
    const box = el('sk-code-list');
    box.innerHTML = codes.map((c) => `<div class="mdt-ac-item" data-code="${esc(c.code)}" data-name="${esc(c.name)}"><span><b>${esc(c.code)}</b></span><span class="mdt-ac-ddn">${esc(c.name)}</span></div>`).join('');
    el('sk-code').addEventListener('click', () => box.classList.toggle('mdt-hidden'));
    box.querySelectorAll('.mdt-ac-item').forEach((it) => it.addEventListener('click', () => {
        selCode = it.dataset.code; selName = it.dataset.name;
        el('sk-code').value = it.dataset.code + ' — ' + it.dataset.name;
        const s = el('sk-selected'); s.textContent = '✓ ' + selName; s.classList.add('ok');
        box.classList.add('mdt-hidden');
    }));
    el('sk-submit').addEventListener('click', () => {
        if (!selName) { toast('Sélectionnez une compétence.', false); return; }
        fetchNui('mdt:addSkill', { character_id: characterId, identifier, skill: selName, code: selCode });
        closeModal();
    });
}

function formEditSkillDate(id, current, characterId) {
    const iso = toISODate(current);
    openModal("Modifier la date d'obtention", `
        <div class="mdt-form-row"><label>Date d'obtention</label><input class="mdt-input" type="date" id="sd-date" value="${esc(iso)}"></div>
    `, `<button class="mdt-btn" onclick="window.__mdtCloseModal()">Annuler</button>
        <button class="mdt-btn mdt-btn-primary" id="sd-submit">Enregistrer</button>`);
    el('sd-submit').addEventListener('click', () => {
        if (!el('sd-date').value) { toast('Date requise.', false); return; }
        fetchNui('mdt:updateSkillDate', { id, obtained_date: el('sd-date').value, character_id: characterId });
        closeModal();
    });
}

/* ════════════════════════════════════════════════════════════════
   ONGLET — FORMATIONS / STAGES
   ════════════════════════════════════════════════════════════════ */
async function renderTrainings() {
    if (state.trainingTimer) { clearInterval(state.trainingTimer); state.trainingTimer = null; }
    const isManager = has('manage_trainings');
    setContent(`
        <div style="display:flex;justify-content:space-between;align-items:flex-start;gap:12px">
            <div>
                <div class="mdt-page-title">Formations / Stages</div>
                <div class="mdt-page-sub">Sessions de formation interne. Places mises à jour en temps réel.</div>
            </div>
            ${isManager ? `<button class="mdt-btn mdt-btn-primary" id="tr-new">+ Nouvelle formation</button>` : ''}
        </div>
        <div id="tr-list">${emptyState('⏳', 'Chargement…')}</div>
    `);
    const nb = el('tr-new'); if (nb) nb.addEventListener('click', () => formTraining(null));

    const load = async () => {
        const rows = asArray(await fetchNui('mdt:getTrainings', {}));
        if (state.currentTab !== 'trainings' || !el('tr-list')) return;
        if (!rows.length) { el('tr-list').innerHTML = emptyState('🎓', 'Aucune formation programmée.'); return; }
        el('tr-list').innerHTML = rows.map((t) => {
            const max = parseInt(t.max_slots) || 0;
            const signups = parseInt(t.signups) || 0;
            const remaining = max > 0 ? Math.max(0, max - signups) : null;
            const full = max > 0 && signups >= max;
            const mine = (parseInt(t.me) || 0) > 0;
            let actions = '';
            if (isManager) {
                actions = `
                    <button class="mdt-btn mdt-btn-sm" data-tr-signups="${esc(t.id)}">👥 Inscrits (${signups})</button>
                    <button class="mdt-btn mdt-btn-sm" data-tr-edit="${esc(t.id)}">✏️</button>
                    <button class="mdt-btn mdt-btn-sm mdt-btn-danger" data-tr-del="${esc(t.id)}">🗑 Annuler</button>`;
            } else if (mine) {
                actions = `<button class="mdt-btn mdt-btn-sm mdt-btn-danger" data-tr-unsign="${esc(t.id)}">Se désinscrire</button>`;
            } else if (full) {
                actions = `<button class="mdt-btn mdt-btn-sm" disabled>Formation complète</button>`;
            } else {
                actions = `<button class="mdt-btn mdt-btn-sm mdt-btn-primary" data-tr-sign="${esc(t.id)}">S'inscrire</button>`;
            }
            return `<div class="mdt-card">
                <div style="display:flex;justify-content:space-between;align-items:flex-start;gap:12px">
                    <div style="flex:1;min-width:0">
                        <div style="font-size:16px;font-weight:700">${esc(t.name)}${mine ? ' <span class="mdt-badge mdt-badge-green">Inscrit</span>' : ''}</div>
                        <div style="color:var(--mdt-text-dim);font-size:13px;margin-top:3px">📅 ${fmtDate(t.scheduled_at)} · 👥 ${signups}${max > 0 ? ' / ' + max : ''} inscrit(s)${remaining !== null ? ' · ' + remaining + ' place(s) restante(s)' : ''}</div>
                    </div>
                    <div style="display:flex;gap:8px;flex-shrink:0;flex-wrap:wrap;justify-content:flex-end">${actions}</div>
                </div>
                ${t.description ? `<p style="margin-top:12px;font-size:14px;line-height:1.5;white-space:pre-wrap">${esc(t.description)}</p>` : ''}
            </div>`;
        }).join('');
        const data = rows;
        el('tr-list').querySelectorAll('[data-tr-sign]').forEach((x) => x.addEventListener('click', () => fetchNui('mdt:signupTraining', { id: x.dataset.trSign })));
        el('tr-list').querySelectorAll('[data-tr-unsign]').forEach((x) => x.addEventListener('click', () => fetchNui('mdt:unsignupTraining', { id: x.dataset.trUnsign })));
        el('tr-list').querySelectorAll('[data-tr-del]').forEach((x) => x.addEventListener('click', () => fetchNui('mdt:deleteTraining', { id: x.dataset.trDel })));
        el('tr-list').querySelectorAll('[data-tr-edit]').forEach((x) => x.addEventListener('click', () => { const t = data.find((r) => String(r.id) === x.dataset.trEdit); formTraining(t); }));
        el('tr-list').querySelectorAll('[data-tr-signups]').forEach((x) => x.addEventListener('click', () => openTrainingSignups(x.dataset.trSignups)));
    };
    await load();

    state.trainingTimer = setInterval(() => {
        if (state.currentTab !== 'trainings' || el('mdt').classList.contains('mdt-hidden')) {
            clearInterval(state.trainingTimer); state.trainingTimer = null; return;
        }
        if (!el('mdt-modal-overlay').classList.contains('mdt-hidden')) return; // ne pas perturber une modale ouverte
        load();
    }, 8000);
}

async function openTrainingSignups(trainingId) {
    state.signupsTrainingId = trainingId;
    openModal('Agents inscrits', emptyState('⏳', 'Chargement…'), `<button class="mdt-btn" onclick="window.__mdtCloseModal()">Fermer</button>`);
    const rows = asArray(await fetchNui('mdt:getTrainingSignups', { trainingId }));
    const body = el('mdt-modal-body');
    if (!body) return;
    const statusBadge = (st) => st === 'validated'
        ? '<span class="mdt-badge mdt-badge-green">Validée</span>'
        : (st === 'refused' ? '<span class="mdt-badge mdt-badge-red">Refusée</span>' : '<span class="mdt-badge mdt-badge-orange">En attente</span>');
    body.innerHTML = `<div style="margin-bottom:10px;color:var(--mdt-text-dim);font-size:13px">${rows.length} inscrit(s)</div>` +
        (rows.length ? `<table class="mdt-table"><thead><tr><th>Nom et prénom</th><th>Grade</th><th>Date d'inscription</th><th>Statut</th><th></th></tr></thead><tbody>` +
            rows.map((s) => `<tr>
                <td><b>${esc(s.citizen_name)}</b></td>
                <td><span class="mdt-badge mdt-badge-gray">${esc(s.grade_label || '—')}</span></td>
                <td>${fmtDate(s.created_at)}</td>
                <td>${statusBadge(s.status)}</td>
                <td style="white-space:nowrap">
                    <button class="mdt-btn mdt-btn-sm mdt-btn-primary" data-validate-signup="${esc(s.id)}" title="Valider la formation">✔</button>
                    <button class="mdt-btn mdt-btn-sm" data-refuse-signup="${esc(s.id)}" title="Refuser la formation">✖</button>
                    <button class="mdt-btn mdt-btn-sm mdt-btn-danger" data-rm-signup="${esc(s.id)}" title="Retirer l'inscription">🗑</button>
                </td>
            </tr>`).join('') + `</tbody></table>` : emptyState('👤', 'Aucun inscrit.'));
    body.querySelectorAll('[data-rm-signup]').forEach((x) => x.addEventListener('click', () => {
        fetchNui('mdt:removeSignup', { signupId: x.dataset.rmSignup, trainingId });
    }));
    body.querySelectorAll('[data-validate-signup]').forEach((x) => x.addEventListener('click', () => {
        fetchNui('mdt:validateSignup', { signupId: x.dataset.validateSignup, valid: true, trainingId });
    }));
    body.querySelectorAll('[data-refuse-signup]').forEach((x) => x.addEventListener('click', () => {
        fetchNui('mdt:validateSignup', { signupId: x.dataset.refuseSignup, valid: false, trainingId });
    }));
}

function formTraining(existing) {
    const codes = asArray(state.payload.trainingCodes);
    let selCode = existing ? (existing.code || '') : '';
    openModal(existing ? 'Modifier la formation' : 'Nouvelle formation', `
        <div class="mdt-form-row"><label>Code formation</label>
            <div class="mdt-autocomplete">
                <input class="mdt-input" id="trf-code" value="${esc(selCode)}" placeholder="Cliquer pour choisir un code…" autocomplete="off" readonly style="cursor:pointer">
                <div class="mdt-ac-results mdt-hidden" id="trf-code-list"></div>
            </div>
        </div>
        <div class="mdt-form-row"><label>Nom de la formation</label><input class="mdt-input" id="trf-name" value="${esc(existing ? existing.name : '')}" placeholder="Sélectionnez un code ou saisissez un nom"></div>
        <div class="mdt-form-row"><label>Date et heure</label><input class="mdt-input" id="trf-date" type="datetime-local" value="${esc(existing ? existing.scheduled_at : '')}"></div>
        <div class="mdt-form-row"><label>Places maximum (0 = illimité)</label><input class="mdt-input" id="trf-max" type="number" min="0" value="${existing ? esc(existing.max_slots) : ''}" placeholder="10"></div>
        <div class="mdt-form-row"><label>Description / contenu</label><textarea class="mdt-textarea" id="trf-desc" style="min-height:120px">${esc(existing ? existing.description : '')}</textarea></div>
    `, `<button class="mdt-btn" onclick="window.__mdtCloseModal()">Annuler</button>
        <button class="mdt-btn mdt-btn-primary" id="trf-submit">${existing ? 'Enregistrer' : 'Créer'}</button>`);

    // Dropdown cliquable des codes formation → remplit le nom
    const box = el('trf-code-list');
    const renderCodeList = (filter) => {
        const f = (filter || '').toUpperCase();
        const list = codes.filter((c) => !f || c.code.toUpperCase().includes(f) || c.name.toUpperCase().includes(f));
        box.innerHTML = list.length ? list.map((c) => `<div class="mdt-ac-item" data-code="${esc(c.code)}" data-name="${esc(c.name)}">
            <span><b>${esc(c.code)}</b></span><span class="mdt-ac-ddn">${esc(c.name)}</span></div>`).join('')
            : '<div class="mdt-ac-item mdt-ac-empty">Aucun code</div>';
        box.querySelectorAll('.mdt-ac-item[data-code]').forEach((it) => it.addEventListener('click', () => {
            selCode = it.dataset.code;
            el('trf-code').value = it.dataset.code;
            el('trf-name').value = it.dataset.name;
            box.classList.add('mdt-hidden');
        }));
    };
    el('trf-code').addEventListener('click', () => {
        if (box.classList.contains('mdt-hidden')) { renderCodeList(''); box.classList.remove('mdt-hidden'); }
        else box.classList.add('mdt-hidden');
    });

    el('trf-submit').addEventListener('click', () => {
        const name = el('trf-name').value.trim();
        if (!name) { toast('Nom de la formation requis.', false); return; }
        const payload = { name, code: selCode, scheduled_at: el('trf-date').value, description: el('trf-desc').value.trim(), max_slots: parseInt(el('trf-max').value) || 0 };
        if (existing) { payload.id = existing.id; fetchNui('mdt:updateTraining', payload); }
        else fetchNui('mdt:createTraining', payload);
        closeModal();
    });
}

/* ════════════════════════════════════════════════════════════════
   ONGLET — ORGANISATION (services / unités / grades)
   ════════════════════════════════════════════════════════════════ */
function renderOrganisation() {
    const services = asArray(state.payload.services);
    const grades = asArray(state.payload.grades);
    setContent(`
        <div class="mdt-page-title">Organisation — ${esc(state.payload.departmentLabel)}</div>
        <div class="mdt-page-sub">Services, unités et grille des grades.</div>
        <div class="mdt-grid-2">
            <div>
                <div class="mdt-card-title">Services & unités</div>
                ${services.map((s) => `
                    <div class="mdt-service">
                        <div class="mdt-service-head">${esc(s.label)}</div>
                        ${asArray(s.units).map((u) => `<div class="mdt-unit"><div class="mdt-unit-name">${esc(u.label)}</div><div class="mdt-unit-desc">${esc(u.description || '')}</div></div>`).join('')}
                    </div>`).join('')}
            </div>
            <div>
                <div class="mdt-card-title">Grades</div>
                <div class="mdt-card" style="padding:0">
                    <table class="mdt-table"><thead><tr><th>Grade</th><th>Responsabilités</th></tr></thead><tbody>
                    ${grades.map((g) => `<tr class="mdt-grade-row">
                        <td>${esc(g.label)}</td>
                        <td>${esc(g.responsibilities || '')}</td>
                    </tr>`).join('')}
                    </tbody></table>
                </div>
            </div>
        </div>
    `);
}

/* ════════════════════════════════════════════════════════════════
   Refresh ciblé (après écriture serveur)
   ════════════════════════════════════════════════════════════════ */
function handleRefresh(refresh) {
    if (!refresh) return;
    // Les modules métier traitent d'abord leurs propres vues (ils
    // renvoient true si la demande les concernait).
    if (window.MDT_EXT_REFRESH && window.MDT_EXT_REFRESH(refresh)) return;
    const v = refresh.view;
    if (v === 'citizen') {
        if (state.currentTab === 'citizens' && state.currentCitizen && (!refresh.id || refresh.id === state.currentCitizen)) {
            openCitizenFile(state.currentCitizen);
        }
    } else if (v === 'vehicle' && state.currentTab === 'vehicles' && state.currentVehicle
        && (!refresh.id || String(refresh.id).toUpperCase() === String(state.currentVehicle).toUpperCase())) {
        openVehicleFile(state.currentVehicle);
    }
    else if (v === 'warrants' && state.currentTab === 'warrants') renderWarrants();
    else if (v === 'reports' && state.currentTab === 'dossiers') renderDossiers();
    else if (v === 'report' && state.currentTab === 'dossiers' && refresh.id) openReport(refresh.id);
    else if (v === 'int_reports' && state.currentTab === 'int_reports') renderInterventionReports();
    else if (v === 'int_report' && state.currentTab === 'int_reports' && refresh.id) openInterventionReport(refresh.id);
    else if (v === 'custody' && state.currentTab === 'custody') renderCustody();
    else if (v === 'evidence' && state.currentTab === 'investigation') renderInvestigation();
    else if (v === 'weapons' && state.currentTab === 'weapons') renderWeapons();
    else if (v === 'weapon' && state.currentTab === 'weapons' && refresh.id) openWeaponFile(refresh.id);
    else if (v === 'laws' && state.currentTab === 'laws') renderLaws();
    else if (v === 'agent' && state.currentTab === 'effectifs' && state.currentAgent
        && (!refresh.id || String(refresh.id) === String(state.currentAgent))) openAgentFile(state.currentAgent);
    else if (v === 'trainings' && state.currentTab === 'trainings') renderTrainings();
    else if (v === 'training' && state.signupsTrainingId && String(state.signupsTrainingId) === String(refresh.id)
        && !el('mdt-modal-overlay').classList.contains('mdt-hidden')) {
        openTrainingSignups(refresh.id); // rafraîchit la modale des inscrits
    }
}

/* ── Listeners globaux ───────────────────────────────────────── */
el('mdt-close').addEventListener('click', closeMDT);
el('mdt-modal-close').addEventListener('click', closeModal);
el('mdt-modal-overlay').addEventListener('click', (e) => { if (e.target === el('mdt-modal-overlay')) closeModal(); });
window.__mdtCloseModal = closeModal;

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        if (!el('mdt-modal-overlay').classList.contains('mdt-hidden')) closeModal();
        else if (!el('mdt').classList.contains('mdt-hidden')) closeMDT();
    }
});

/* Horloge */
setInterval(() => {
    const d = new Date();
    const p = (n) => String(n).padStart(2, '0');
    const c = el('mdt-clock'); if (c) c.textContent = `${p(d.getHours())}:${p(d.getMinutes())}`;
}, 1000);
