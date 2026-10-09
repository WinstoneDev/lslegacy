/* Onglet MDT « Commande de pièces » (atelier uniquement : Red's Tunershop,
   Benny's) : panier multi-références = UNE commande, débitée sur le compte
   entreprise, livrée directement dans le stock du dépôt (retrait à la touche
   ALT/ox_target, hors MDT). Helpers globaux : esc, setContent, emptyState,
   fetchNui, fmtDateFR, openModal, closeModal, toast, confirmAction. */
window.MDT_RENDERERS = window.MDT_RENDERERS || {};

(function () {
    function tabLabel() {
        const t = (state.tabs || []).find((x) => x.id === 'commande_pieces');
        return (t && t.label) || 'Commande de pièces';
    }

    const statusBadge = (s) =>
        s === 'recupere' ? '<span class="mdt-badge mdt-badge-green">Livrée au dépôt</span>'
        : s === 'pret'    ? '<span class="mdt-badge mdt-badge-blue">Prête</span>'
        : s === 'annule'  ? '<span class="mdt-badge mdt-badge-gray">Annulée</span>'
        : '<span class="mdt-badge mdt-badge-orange">En livraison</span>';

    const fmtRemaining = (sec) => {
        sec = Math.max(0, Math.round(sec));
        const m = Math.floor(sec / 60), s = sec % 60;
        return `${m}m ${String(s).padStart(2, '0')}s`;
    };

    // items_data : "item::quantity::price;;..."
    function parseItems(itemsData) {
        return String(itemsData || '').split(';;').filter(Boolean).map((s) => {
            const [item, quantity, price] = s.split('::');
            return { item, quantity: Number(quantity), price: Number(price) };
        });
    }

    // ── Panier de commande (modale) ──────────────────────────────
    function renderOrderModal(catalogue, cart) {
        const items = (catalogue && catalogue.items) || [];
        const maxQty = (catalogue && catalogue.maxQuantityPerOrder) || 50;
        const total = cart.reduce((sum, it) => sum + it.price, 0);
        openModal(`Nouvelle commande — ${esc(tabLabel())}`, `
            <div class="mdt-form-row"><label>Pièce</label>
                <select class="mdt-select" id="piece-item">
                    ${items.map((it) => `<option value="${esc(it.id)}">${esc(it.label)} — ${it.price} $/unité</option>`).join('')}
                </select></div>
            <div class="mdt-form-row"><label>Quantité</label><input class="mdt-input" type="number" min="1" max="${maxQty}" id="piece-qty" value="1"></div>
            <button class="mdt-btn" id="piece-add" style="width:100%;margin-bottom:10px;">+ Ajouter au panier</button>
            ${cart.length ? `
                <table class="mdt-table">
                    <thead><tr><th>Pièce</th><th>Quantité</th><th>Prix</th><th></th></tr></thead>
                    <tbody>
                        ${cart.map((it, i) => `<tr>
                            <td>${esc(it.label)}</td>
                            <td>${it.quantity}</td>
                            <td>${it.price} $</td>
                            <td><button class="mdt-btn mdt-btn-danger" data-remove="${i}">Retirer</button></td>
                        </tr>`).join('')}
                    </tbody>
                </table>
                <div class="mdt-form-row" style="font-weight:600;">Total : ${cart.length} référence(s) — ${total} $ (1 seule commande)</div>
            ` : `<div class="mdt-form-row" style="font-size:12px;color:#666;">Panier vide — ajoutez au moins une référence.</div>`}
            <div class="mdt-form-row" style="font-size:12px;color:#666;">
                Débité du compte entreprise. Livraison directe au stock du dépôt sous ${Math.round(((catalogue && catalogue.delaySeconds) || 0) / 60)} min.
            </div>
        `, `<button class="mdt-btn" onclick="window.__mdtCloseModal()">Annuler</button>
            <button class="mdt-btn mdt-btn-primary" id="piece-send" ${cart.length ? '' : 'disabled'}>Commander</button>`);

        document.getElementById('piece-add').addEventListener('click', () => {
            const sel = document.getElementById('piece-item');
            const item = sel.value;
            const it = items.find((x) => x.id === item);
            const qty = Math.floor(Number(document.getElementById('piece-qty').value));
            if (!it || !qty || qty < 1 || qty > maxQty) { toast('Pièce et quantité requises.', false); return; }
            cart.push({ item, label: it.label, quantity: qty, price: it.price * qty });
            renderOrderModal(catalogue, cart);
        });
        cart.forEach((_, i) => {
            const btn = document.querySelector(`[data-remove="${i}"]`);
            if (btn) btn.addEventListener('click', () => { cart.splice(i, 1); renderOrderModal(catalogue, cart); });
        });
        const sendBtn = document.getElementById('piece-send');
        if (sendBtn) sendBtn.addEventListener('click', async () => {
            if (!cart.length) { toast('Panier vide.', false); return; }
            await fetchNui('mdtparts:order', { items: cart.map((it) => ({ item: it.item, quantity: it.quantity })) });
            closeModal();
            setTimeout(() => window.MDT_RENDERERS.commande_pieces(), 800);
        });
    }

    function openOrderForm(catalogue) {
        renderOrderModal(catalogue, []);
    }

    window.__pieceCancel = function (batchId) {
        confirmAction(`Annuler cette commande et rembourser l'entreprise ?`, async () => {
            await fetchNui('mdtparts:cancel', { batchId });
            window.MDT_RENDERERS.commande_pieces();
        });
    };

    window.__pieceToggleItems = function (batchId) {
        const row = document.getElementById('piece-items-' + batchId);
        if (row) row.classList.toggle('mdt-hidden');
    };

    function tickCountdowns() {
        document.querySelectorAll('[data-piece-remaining]').forEach((el) => {
            const end = Number(el.dataset.pieceRemaining);
            const left = Math.round((end - Date.now()) / 1000);
            el.textContent = left > 0 ? fmtRemaining(left) : 'Prête';
        });
    }

    function renderOrdersTable(orders) {
        const now = Date.now();
        const tbody = el('piece-tbody');
        if (!tbody) return;
        if (!orders.length) {
            tbody.closest('table').outerHTML = emptyState('🔩', `Aucune commande ${esc(tabLabel())}.`);
            return;
        }
        tbody.innerHTML = orders.map((o) => {
            const endEpoch = now + (Number(o.remaining_seconds) || 0) * 1000;
            const showCountdown = o.status === 'en_attente' && Number(o.remaining_seconds) > 0;
            const items = parseItems(o.items_data);
            return `<tr>
                <td>${esc(fmtDateFR(o.created_at))}</td>
                <td><button class="mdt-btn" onclick="window.__pieceToggleItems('${esc(o.batch_id)}')">${o.item_count} référence(s)</button></td>
                <td>${esc(String(o.price))} $</td>
                <td>${esc(o.ordered_by_name)}</td>
                <td>${statusBadge(o.status)}</td>
                <td>${showCountdown ? `<span data-piece-remaining="${endEpoch}">${fmtRemaining(o.remaining_seconds)}</span>` : (o.status === 'en_attente' ? 'Prête' : '—')}</td>
                <td style="white-space:nowrap;">
                    ${(o.status === 'en_attente' || o.status === 'pret') ? `<button class="mdt-btn mdt-btn-danger" onclick="window.__pieceCancel('${esc(o.batch_id)}')">Annuler</button>` : ''}
                </td>
            </tr>
            <tr id="piece-items-${esc(o.batch_id)}" class="mdt-hidden">
                <td colspan="7" style="background:rgba(0,0,0,.03);">
                    ${items.map((it) => `<div>${esc(it.item)} × ${it.quantity} — ${it.price} $</div>`).join('')}
                </td>
            </tr>`;
        }).join('');
    }

    function applyFilters(allOrders) {
        const status = (el('piece-status-filter') && el('piece-status-filter').value) || '';
        return allOrders.filter((o) => !status || o.status === status);
    }

    window.MDT_RENDERERS.commande_pieces = async function renderParts() {
        if (state.pieceTimer) { clearInterval(state.pieceTimer); state.pieceTimer = null; }
        const label = tabLabel();
        setContent(`<div class="mdt-page-title">${esc(label)}</div>${emptyState('⏳', 'Chargement…')}`);
        const catalogue = await fetchNui('mdtparts:getCatalogue', {});
        const res = await fetchNui('mdtparts:getHistory', {});
        const allOrders = (res && Array.isArray(res.orders)) ? res.orders : [];
        const monthSpend = (res && res.monthSpend) || 0;

        setContent(`
            <div class="mdt-page-title">${esc(label)}
                <button class="mdt-btn mdt-btn-primary" id="piece-new" style="float:right;">+ Nouvelle commande</button>
            </div>
            <div class="mdt-page-sub">Réapprovisionnement du dépôt de pièces — retrait à la touche ALT une fois livrée.</div>
            <div class="mdt-page-sub">Dépense ce mois-ci : <strong>${esc(String(monthSpend))} $</strong></div>
            <div class="mdt-form-row" style="display:flex;gap:10px;">
                <select class="mdt-select" id="piece-status-filter" style="max-width:220px;">
                    <option value="">Tous les statuts</option>
                    <option value="en_attente">En livraison</option>
                    <option value="recupere">Livrée au dépôt</option>
                    <option value="annule">Annulée</option>
                </select>
            </div>
            ${allOrders.length ? `
                <table class="mdt-table">
                    <thead><tr><th>Date</th><th>Références</th><th>Prix</th><th>Commandé par</th><th>Statut</th><th>Livraison</th><th></th></tr></thead>
                    <tbody id="piece-tbody"></tbody>
                </table>
            ` : emptyState('🔩', `Aucune commande ${esc(label)}.`)}
        `);
        document.getElementById('piece-new').addEventListener('click', () => openOrderForm(catalogue));

        if (allOrders.length) {
            renderOrdersTable(applyFilters(allOrders));
            el('piece-status-filter').addEventListener('change', () => renderOrdersTable(applyFilters(allOrders)));
        }

        state.pieceTimer = setInterval(() => {
            if (state.currentTab !== 'commande_pieces' || el('mdt').classList.contains('mdt-hidden')) {
                clearInterval(state.pieceTimer); state.pieceTimer = null; return;
            }
            tickCountdowns();
        }, 1000);
    };
})();
