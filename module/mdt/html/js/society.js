/* Onglet MDT « Entreprise » : trésorerie du job, factures, émission de facture.
   Helpers globaux : esc, setContent, emptyState, fetchNui, fmtDate, openModal, closeModal, toast, confirmAction. */
window.MDT_RENDERERS = window.MDT_RENDERERS || {};

(function () {
    const money = (n) => (Number(n) || 0).toLocaleString('fr-FR') + ' $';
    const OUT = ['Retrait', 'Achat', 'Virement sortant', 'Livret', 'Agios', 'Cotisation'];
    const sign = (t) => (OUT.indexOf(t.type) !== -1 ? -1 : 1) * Math.abs(Number(t.amount) || 0);
    const statusBadge = (s) => s === 'paid' ? '<span class="mdt-badge mdt-badge-green">Réglée</span>'
        : s === 'cancelled' ? '<span class="mdt-badge mdt-badge-gray">Annulée</span>'
        : '<span class="mdt-badge mdt-badge-blue">En attente</span>';

    async function openInvoiceForm() {
        const nearby = await fetchNui('mdtsociety:getNearby', {});
        const list = Array.isArray(nearby) ? nearby : [];
        openModal('Émettre une facture', `
            <div class="mdt-form-row"><label>Client (à moins de 6 m)</label>
                <select class="mdt-select" id="soc-inv-target">
                    ${list.length ? list.map((p) => `<option value="${p.src}">${esc(p.name)}</option>`).join('') : '<option value="">Aucun joueur à proximité</option>'}
                </select></div>
            <div class="mdt-form-row"><label>Montant ($)</label><input class="mdt-input" type="number" min="1" id="soc-inv-amount"></div>
            <div class="mdt-form-row"><label>Motif</label><input class="mdt-input" type="text" maxlength="120" id="soc-inv-reason" placeholder="Prestation, réparation, fourniture…"></div>
            <div class="mdt-form-row" style="font-size:12px;color:#666;">Le terminal de paiement s'ouvre immédiatement chez le client. Si le paiement échoue, la facture reste en attente et peut être représentée depuis cette liste.</div>
        `, `<button class="mdt-btn" onclick="window.__mdtCloseModal()">Annuler</button>
            <button class="mdt-btn mdt-btn-primary" id="soc-inv-send">Émettre</button>`);
        document.getElementById('soc-inv-send').addEventListener('click', async () => {
            const targetSrc = Number(document.getElementById('soc-inv-target').value);
            const amount = Number(document.getElementById('soc-inv-amount').value);
            const reason = document.getElementById('soc-inv-reason').value.trim();
            if (!targetSrc || !amount || amount <= 0 || !reason) { toast('Client, montant et motif requis.', false); return; }
            await fetchNui('mdtsociety:invoiceNearby', { targetSrc, amount, reason });
            closeModal();
            setTimeout(() => window.MDT_RENDERERS.entreprise(), 800);
        });
    }

    async function cancelInvoice(id) {
        confirmAction(`Annuler la facture #${id} ?`, async () => {
            const r = await fetchNui('mdtsociety:cancelInvoice', { id });
            toast(r && r.ok ? 'Facture annulée.' : (r && r.message) || 'Échec.', !!(r && r.ok));
            window.MDT_RENDERERS.entreprise();
        });
    }
    window.__socCancelInvoice = cancelInvoice;
    window.__socCollectInvoice = async function (id) {
        await fetchNui('mdtsociety:collectInvoice', { id });
        toast('Terminal présenté au client.', true);
        setTimeout(() => window.MDT_RENDERERS.entreprise(), 1500);
    };

    window.MDT_RENDERERS.entreprise = async function renderEntreprise() {
        setContent(`<div class="mdt-page-title">Entreprise</div>${emptyState('⏳', 'Chargement…')}`);
        const d = await fetchNui('mdtsociety:getOverview', {});
        if (!d) { setContent(emptyState('🚫', 'Données indisponibles.')); return; }
        const st = d.stats || {};
        const invoices = Array.isArray(d.invoices) ? d.invoices : [];
        const tx = Array.isArray(d.transactions) ? d.transactions : [];

        setContent(`
            <div class="mdt-page-title">Entreprise — ${esc(d.label)}</div>
            <div class="mdt-page-sub">Trésorerie, factures et opérations du compte entreprise.${d.isBoss ? ' Vous êtes chef : gestion du compte et de la carte à la banque.' : ''}</div>
            ${!d.hasAccount ? emptyState('🏦', 'Aucun compte entreprise. Le chef doit l\'ouvrir au guichet de la banque (onglet Entreprise).') : `
            <div class="mdt-stats-row">
                <div class="mdt-stat"><div class="mdt-stat-val">${money(d.balance)}</div><div class="mdt-stat-lbl">Solde</div></div>
                <div class="mdt-stat"><div class="mdt-stat-val">${money(st.paid_week)}</div><div class="mdt-stat-lbl">Encaissé 7 j</div></div>
                <div class="mdt-stat"><div class="mdt-stat-val">${money(st.paid_month)}</div><div class="mdt-stat-lbl">Encaissé 30 j</div></div>
                <div class="mdt-stat"><div class="mdt-stat-val">${money(st.pending_total)}</div><div class="mdt-stat-lbl">${Number(st.pending_count) || 0} facture(s) en attente</div></div>
            </div>
            <div class="mdt-card">
                <div class="mdt-card-title">Compte</div>
                <div>IBAN <b>${esc(d.iban)}</b> · Carte entreprise : ${d.hasCard ? (d.cardBlocked ? '<span class="mdt-badge mdt-badge-red">bloquée</span>' : '<span class="mdt-badge mdt-badge-green">active</span>') : '<span class="mdt-badge mdt-badge-gray">aucune</span>'}</div>
            </div>
            <div class="mdt-card">
                <div class="mdt-card-title" style="display:flex;justify-content:space-between;align-items:center;">Factures <button class="mdt-btn mdt-btn-primary mdt-btn-sm" id="soc-new-invoice">+ Émettre une facture</button></div>
                ${invoices.length ? `<table class="mdt-table"><thead><tr><th>#</th><th>Date</th><th>Client</th><th>Motif</th><th>Montant</th><th>Auteur</th><th>État</th><th></th></tr></thead><tbody>
                    ${invoices.map((i) => `<tr><td>${i.id}</td><td>${fmtDate(i.created_at)}</td><td>${esc(i.target_name || '—')}</td><td>${esc(i.reason || '')}</td><td><b>${money(i.amount)}</b></td><td>${esc(i.author_name || '—')}</td><td>${statusBadge(i.status)}</td>
                        <td>${i.status === 'pending' ? `<button class="mdt-btn mdt-btn-primary mdt-btn-sm" onclick="window.__socCollectInvoice(${i.id})">Faire régler</button> <button class="mdt-btn mdt-btn-danger mdt-btn-sm" onclick="window.__socCancelInvoice(${i.id})">Annuler</button>` : ''}</td></tr>`).join('')}
                </tbody></table>` : emptyState('🧾', 'Aucune facture émise.')}
            </div>
            <div class="mdt-card">
                <div class="mdt-card-title">Dernières opérations</div>
                ${tx.length ? `<table class="mdt-table"><thead><tr><th>Date</th><th>Type</th><th>Libellé</th><th>Montant</th></tr></thead><tbody>
                    ${tx.map((t) => `<tr><td>${esc(t.date)}</td><td>${esc(t.type || '')}</td><td>${esc(t.message || '')}</td><td style="color:${sign(t) >= 0 ? '#1f9d55' : '#c0392b'}"><b>${sign(t) >= 0 ? '+' : ''}${money(sign(t))}</b></td></tr>`).join('')}
                </tbody></table>` : emptyState('📭', 'Aucune opération.')}
            </div>`}
        `);
        const btn = document.getElementById('soc-new-invoice');
        if (btn) btn.addEventListener('click', openInvoiceForm);
    };
})();
