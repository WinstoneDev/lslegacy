/* Onglet MDT « Boutique tenues » (générique, tout département avec un
   compte entreprise actif) : commande de tenues pour un collègue nommé
   (panier multi-articles = UNE commande), débitée sur le compte entreprise,
   livrée à un point de retrait après délai. Filtre + dépense mensuelle +
   recommande. Le libellé affiché ("UNIPOL" pour la police, "Boutique
   tenues" par défaut) suit celui envoyé par le serveur pour cet onglet.
   Helpers globaux : esc, setContent, emptyState, fetchNui, fmtDateFR, openModal, closeModal, toast, confirmAction. */
window.MDT_RENDERERS = window.MDT_RENDERERS || {};

(function () {
    function tabLabel() {
        const t = (state.tabs || []).find((x) => x.id === 'boutique_tenue');
        return (t && t.label) || 'Boutique tenues';
    }

    const statusBadge = (s) =>
        s === 'recupere' ? '<span class="mdt-badge mdt-badge-green">Récupérée</span>'
        : s === 'pret'    ? '<span class="mdt-badge mdt-badge-blue">Prête au retrait</span>'
        : s === 'annule'  ? '<span class="mdt-badge mdt-badge-gray">Annulée</span>'
        : '<span class="mdt-badge mdt-badge-orange">En livraison</span>';

    const fmtRemaining = (sec) => {
        sec = Math.max(0, Math.round(sec));
        const m = Math.floor(sec / 60), s = sec % 60;
        return `${m}m ${String(s).padStart(2, '0')}s`;
    };

    // items_data : "slot::drawable::texture::label::asOutfit;;..."
    function parseItems(itemsData) {
        return String(itemsData || '').split(';;').filter(Boolean).map((s) => {
            const [slot, drawable, texture, label, asOutfit] = s.split('::');
            return { slot, drawable: Number(drawable), texture: Number(texture), label, asOutfit: asOutfit === '1' };
        });
    }

    // ── Panier de commande (modale) ──────────────────────────────
    function renderOrderModal(catalogue, agents, cart, selectedTarget, presets) {
        const slots = (catalogue && catalogue.slots) || [];
        const price = (catalogue && catalogue.price) || 0;
        const maxItems = (catalogue && catalogue.maxItemsPerOrder) || 15;
        const total = price * cart.length;
        presets = presets || [];
        openModal(`Nouvelle commande — ${esc(tabLabel())}`, `
            <div class="mdt-form-row"><label>${esc(staffLabel(false))} destinataire</label>
                <select class="mdt-select" id="veti-target">
                    ${agents.length ? agents.map((a) => `<option value="${a.character_id}" ${String(a.character_id) === String(selectedTarget) ? 'selected' : ''}>${esc(a.name)} — ${esc(a.gradeLabel || '')}</option>`).join('') : `<option value="">Aucun ${esc(staffLabel(false).toLowerCase())}</option>`}
                </select></div>
            <div class="mdt-form-row"><label>Tenue pré-enregistrée</label>
                <div style="display:flex;gap:6px;">
                    <select class="mdt-select" id="veti-preset" style="flex:1;">
                        <option value="">— Composer manuellement —</option>
                        ${presets.map((p) => `<option value="${p.id}">${esc(p.name)} (${Object.keys(p.items).length} article(s))</option>`).join('')}
                    </select>
                    <button class="mdt-btn" id="veti-preset-load" ${presets.length ? '' : 'disabled'}>Charger</button>
                    <button class="mdt-btn mdt-btn-danger" id="veti-preset-delete" ${presets.length ? '' : 'disabled'}>Supprimer</button>
                </div>
            </div>
            <div class="mdt-form-row"><label>Article</label>
                <select class="mdt-select" id="veti-slot">
                    ${slots.map((s) => `<option value="${esc(s.id)}">${esc(s.label)}</option>`).join('')}
                </select></div>
            <div class="mdt-form-row"><label>Drawable (numéro)</label><input class="mdt-input" type="number" min="0" max="999" id="veti-drawable" value="0"></div>
            <div class="mdt-form-row"><label>Texture (numéro)</label><input class="mdt-input" type="number" min="0" max="99" id="veti-texture" value="0"></div>
            <div class="mdt-form-row"><label style="display:flex;align-items:center;gap:6px;font-weight:normal;">
                <input type="checkbox" id="veti-as-outfit"> Recevoir comme tenue (regroupe les articles cochés en un seul item)
            </label></div>
            <button class="mdt-btn" id="veti-add" style="width:100%;margin-bottom:10px;" ${cart.length >= maxItems ? 'disabled' : ''}>+ Ajouter au panier</button>
            ${cart.length ? `
                <button class="mdt-btn" id="veti-preset-save" style="width:100%;margin-bottom:10px;">💾 Enregistrer le panier comme tenue</button>` : ''}
            ${cart.length ? `
                <table class="mdt-table">
                    <thead><tr><th>Article</th><th>Tenue ?</th><th>Prix</th><th></th></tr></thead>
                    <tbody>
                        ${cart.map((it, i) => `<tr>
                            <td>${esc(it.label)} #${it.drawable}</td>
                            <td>${it.asOutfit ? '🧥 Oui' : '—'}</td>
                            <td>${price} $</td>
                            <td><button class="mdt-btn mdt-btn-danger" data-remove="${i}">Retirer</button></td>
                        </tr>`).join('')}
                    </tbody>
                </table>
                <div class="mdt-form-row" style="font-weight:600;">Total : ${cart.length}/${maxItems} article(s) — ${total} $ (1 seule commande)</div>
            ` : `<div class="mdt-form-row" style="font-size:12px;color:#666;">Panier vide — ajoutez au moins un article (max ${maxItems}).</div>`}
            <div class="mdt-form-row" style="font-size:12px;color:#666;">
                Pas d'aperçu pour l'instant (catalogue provisoire) — ${price} $/article, débité du compte entreprise. Livraison au point de retrait sous ${Math.round(((catalogue && catalogue.delaySeconds) || 0) / 60)} min.
            </div>
        `, `<button class="mdt-btn" onclick="window.__mdtCloseModal()">Annuler</button>
            <button class="mdt-btn mdt-btn-primary" id="veti-send" ${cart.length ? '' : 'disabled'}>Commander</button>`);

        document.getElementById('veti-add').addEventListener('click', () => {
            const target = document.getElementById('veti-target').value;
            const slotSel = document.getElementById('veti-slot');
            const slot = slotSel.value;
            const label = slotSel.options[slotSel.selectedIndex] ? slotSel.options[slotSel.selectedIndex].text : slot;
            const drawable = Number(document.getElementById('veti-drawable').value);
            const texture = Number(document.getElementById('veti-texture').value);
            const asOutfit = document.getElementById('veti-as-outfit').checked;
            if (!slot || isNaN(drawable) || isNaN(texture)) { toast('Article et numéros requis.', false); return; }
            cart.push({ slot, label, drawable, texture, asOutfit });
            renderOrderModal(catalogue, agents, cart, target, presets);
        });
        cart.forEach((_, i) => {
            const btn = document.querySelector(`[data-remove="${i}"]`);
            if (btn) btn.addEventListener('click', () => {
                const target = document.getElementById('veti-target').value;
                cart.splice(i, 1);
                renderOrderModal(catalogue, agents, cart, target, presets);
            });
        });
        const sendBtn = document.getElementById('veti-send');
        if (sendBtn) sendBtn.addEventListener('click', async () => {
            const targetCharacterId = Number(document.getElementById('veti-target').value);
            if (!targetCharacterId || !cart.length) { toast(`${staffLabel(false)} et panier requis.`, false); return; }
            await fetchNui('mdtboutique:order', { targetCharacterId, items: cart.map((it) => ({ slot: it.slot, drawable: it.drawable, texture: it.texture, asOutfit: it.asOutfit })) });
            closeModal();
            setTimeout(() => window.MDT_RENDERERS.boutique_tenue(), 800);
        });

        const presetLoadBtn = document.getElementById('veti-preset-load');
        if (presetLoadBtn) presetLoadBtn.addEventListener('click', () => {
            const target = document.getElementById('veti-target').value;
            const presetId = document.getElementById('veti-preset').value;
            const preset = presets.find((p) => String(p.id) === String(presetId));
            if (!preset) { toast('Choisissez une tenue à charger.', false); return; }
            const loaded = Object.keys(preset.items).map((slot) => {
                const s = slots.find((x) => x.id === slot);
                const vals = preset.items[slot];
                return { slot, label: (s && s.label) || slot, drawable: Number(vals[0]), texture: Number(vals[1]), asOutfit: true };
            }).slice(0, maxItems);
            renderOrderModal(catalogue, agents, loaded, target, presets);
        });

        const presetDeleteBtn = document.getElementById('veti-preset-delete');
        if (presetDeleteBtn) presetDeleteBtn.addEventListener('click', () => {
            const presetId = document.getElementById('veti-preset').value;
            const preset = presets.find((p) => String(p.id) === String(presetId));
            if (!preset) { toast('Choisissez une tenue à supprimer.', false); return; }
            confirmAction(`Supprimer définitivement la tenue "${preset.name}" ?`, async () => {
                await fetchNui('mdtboutique:presetDelete', { presetId: preset.id });
                const target = document.getElementById('veti-target').value;
                await new Promise((r) => setTimeout(r, 400));
                const res = await fetchNui('mdtboutique:getPresets', {});
                const freshPresets = (res && Array.isArray(res.presets)) ? res.presets : [];
                renderOrderModal(catalogue, agents, cart, target, freshPresets);
            });
        });

        const presetSaveBtn = document.getElementById('veti-preset-save');
        if (presetSaveBtn) presetSaveBtn.addEventListener('click', async () => {
            const name = (window.prompt('Nom de la tenue à enregistrer :') || '').trim();
            if (!name) return;
            const items = {};
            cart.forEach((it) => { items[it.slot] = [it.drawable, it.texture]; });
            await fetchNui('mdtboutique:presetSave', { name, items });
            const target = document.getElementById('veti-target').value;
            await new Promise((r) => setTimeout(r, 400));
            const res = await fetchNui('mdtboutique:getPresets', {});
            const freshPresets = (res && Array.isArray(res.presets)) ? res.presets : [];
            renderOrderModal(catalogue, agents, cart, target, freshPresets);
        });
    }

    async function openOrderForm(catalogue, prefillItems, prefillTarget) {
        const roster = await fetchNui('mdt:getRoster', {});
        const agents = Array.isArray(roster) ? roster : [];
        const res = await fetchNui('mdtboutique:getPresets', {});
        const presets = (res && Array.isArray(res.presets)) ? res.presets : [];
        renderOrderModal(catalogue, agents, prefillItems ? prefillItems.slice() : [], prefillTarget || null, presets);
    }

    window.__vetiCancel = function (batchId) {
        confirmAction(`Annuler cette commande et rembourser l'entreprise ?`, async () => {
            await fetchNui('mdtboutique:cancel', { batchId });
            window.MDT_RENDERERS.boutique_tenue();
        });
    };

    // ── Recommander : ré-ouvre la modale avec les mêmes articles/agent ──
    window.__vetiReorder = function (orderJson) {
        const o = JSON.parse(decodeURIComponent(orderJson));
        const items = parseItems(o.items_data);
        openOrderForm(window.__vetiCatalogue, items, o.target_character_id);
    };

    // ── Voir/masquer le détail des articles d'une commande ───────────
    window.__vetiToggleItems = function (batchId) {
        const row = document.getElementById('veti-items-' + batchId);
        if (row) row.classList.toggle('mdt-hidden');
    };

    // ── Liste / historique : filtre + compte à rebours en direct ────
    function tickCountdowns() {
        document.querySelectorAll('[data-veti-remaining]').forEach((el) => {
            const end = Number(el.dataset.vetiRemaining);
            const left = Math.round((end - Date.now()) / 1000);
            el.textContent = left > 0 ? fmtRemaining(left) : 'Prêt';
        });
    }

    function renderOrdersTable(orders) {
        const now = Date.now();
        const tbody = el('veti-tbody');
        if (!tbody) return;
        if (!orders.length) {
            tbody.closest('table').outerHTML = emptyState('🧥', `Aucune commande ${esc(tabLabel())}.`);
            return;
        }
        tbody.innerHTML = orders.map((o) => {
            const endEpoch = now + (Number(o.remaining_seconds) || 0) * 1000;
            const showCountdown = o.status === 'en_attente' && Number(o.remaining_seconds) > 0;
            const orderJson = encodeURIComponent(JSON.stringify(o));
            const items = parseItems(o.items_data);
            return `<tr>
                <td>${esc(fmtDateFR(o.created_at))}</td>
                <td>${esc(o.target_name)}</td>
                <td><button class="mdt-btn" onclick="window.__vetiToggleItems('${esc(o.batch_id)}')">${o.item_count} article(s)</button></td>
                <td>${esc(String(o.price))} $</td>
                <td>${esc(o.ordered_by_name)}</td>
                <td>${statusBadge(o.status)}</td>
                <td>${showCountdown ? `<span data-veti-remaining="${endEpoch}">${fmtRemaining(o.remaining_seconds)}</span>` : (o.status === 'en_attente' ? 'Prêt' : '—')}</td>
                <td style="white-space:nowrap;">
                    ${(o.status === 'en_attente' || o.status === 'pret') ? `<button class="mdt-btn mdt-btn-danger" onclick="window.__vetiCancel('${esc(o.batch_id)}')">Annuler</button>` : ''}
                    <button class="mdt-btn" onclick="window.__vetiReorder('${orderJson}')">Recommander</button>
                </td>
            </tr>
            <tr id="veti-items-${esc(o.batch_id)}" class="mdt-hidden">
                <td colspan="8" style="background:rgba(0,0,0,.03);">
                    ${items.map((it) => `<div>${esc(it.label)}${it.asOutfit ? ' — 🧥 tenue' : ''}</div>`).join('')}
                </td>
            </tr>`;
        }).join('');
    }

    function applyFilters(allOrders) {
        const q = (el('veti-search') && el('veti-search').value || '').trim().toLowerCase();
        const status = (el('veti-status-filter') && el('veti-status-filter').value) || '';
        return allOrders.filter((o) =>
            (!q || (o.target_name || '').toLowerCase().includes(q))
            && (!status || o.status === status)
        );
    }

    window.MDT_RENDERERS.boutique_tenue = async function renderBoutique() {
        if (state.vetipolTimer) { clearInterval(state.vetipolTimer); state.vetipolTimer = null; }
        const label = tabLabel();
        setContent(`<div class="mdt-page-title">${esc(label)}</div>${emptyState('⏳', 'Chargement…')}`);
        const catalogue = await fetchNui('mdtboutique:getCatalogue', {});
        window.__vetiCatalogue = catalogue;
        const res = await fetchNui('mdtboutique:getHistory', {});
        const allOrders = (res && Array.isArray(res.orders)) ? res.orders : [];
        const monthSpend = (res && res.monthSpend) || 0;

        setContent(`
            <div class="mdt-page-title">${esc(label)}
                <button class="mdt-btn mdt-btn-primary" id="veti-new" style="float:right;">+ Nouvelle commande</button>
            </div>
            <div class="mdt-page-sub">Portail de gestion des uniformes, équipements et dotations.</div>
            <div class="mdt-page-sub">Dépense ce mois-ci : <strong>${esc(String(monthSpend))} $</strong></div>
            <div class="mdt-form-row" style="display:flex;gap:10px;">
                <input class="mdt-input" type="text" id="veti-search" placeholder="Rechercher un ${esc(staffLabel(false).toLowerCase())}…" style="flex:1;">
                <select class="mdt-select" id="veti-status-filter" style="max-width:220px;">
                    <option value="">Tous les statuts</option>
                    <option value="en_attente">En livraison</option>
                    <option value="pret">Prête au retrait</option>
                    <option value="recupere">Récupérée</option>
                    <option value="annule">Annulée</option>
                </select>
            </div>
            ${allOrders.length ? `
                <table class="mdt-table">
                    <thead><tr><th>Date</th><th>${esc(staffLabel(false))}</th><th>Articles</th><th>Prix</th><th>Commandé par</th><th>Statut</th><th>Livraison</th><th></th></tr></thead>
                    <tbody id="veti-tbody"></tbody>
                </table>
            ` : emptyState('🧥', `Aucune commande ${esc(label)}.`)}
        `);
        document.getElementById('veti-new').addEventListener('click', () => openOrderForm(catalogue));

        if (allOrders.length) {
            renderOrdersTable(applyFilters(allOrders));
            el('veti-search').addEventListener('input', () => renderOrdersTable(applyFilters(allOrders)));
            el('veti-status-filter').addEventListener('change', () => renderOrdersTable(applyFilters(allOrders)));
        }

        state.vetipolTimer = setInterval(() => {
            if (state.currentTab !== 'boutique_tenue' || el('mdt').classList.contains('mdt-hidden')) {
                clearInterval(state.vetipolTimer); state.vetipolTimer = null; return;
            }
            tickCountdowns();
        }, 1000);
    };
})();
