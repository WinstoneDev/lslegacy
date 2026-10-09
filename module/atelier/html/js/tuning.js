/* Poste de tuning — rendu NUI. Toute la logique métier (permissions,
   facturation) vit côté serveur (module/atelier/server/tuning.lua) ; cette
   page ne fait qu'appeler les mods natifs via le client Lua, gérer le
   panier (aperçu immédiat + facturation groupée à la confirmation) et la
   caméra libre autour du véhicule. */

const RES = 'lslegacy';

const T = {
    companyLabel: 'Atelier',
    companyColor: '#8b1a1a',
    catalog: null,
    state: null,
    original: null,
    cart: {},
    paymentMode: 'customer',
    discountPercent: 0,
    canPerformance: false,
    canCustomization: false,
    canMaintenance: false,
    canRepair: false,
    activeTab: 'performance',
    pendingWheelType: null,
    pendingWheelCount: 0,
};

function el(id) { return document.getElementById(id); }

function esc(v) {
    if (v === null || v === undefined) return '';
    return String(v)
        .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
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

function open(payload) {
    T.companyLabel = payload.companyLabel || 'Atelier';
    T.companyColor = payload.companyColor || '#8b1a1a';
    T.catalog = payload.catalog;
    T.state = payload.state;
    T.original = JSON.parse(JSON.stringify(payload.state));
    T.cart = {};
    T.paymentMode = 'customer';
    T.discountPercent = 0;
    el('cartDiscount').value = 0;
    setPaymentMode('customer');
    T.canPerformance = payload.canPerformance === true;
    T.canCustomization = payload.canCustomization === true;
    T.canMaintenance = payload.canMaintenance === true;
    T.activeTab = 'performance';
    T.esthSubTab = 'carrosserie';
    T.pendingWheelType = null;
    T.pendingWheelCount = 0;

    document.documentElement.style.setProperty('--tuning-accent', T.companyColor);
    el('tuningBrandName').textContent = T.companyLabel;
    el('tuning-root').classList.remove('tuning-hidden');
    renderCart();
    setActiveTab('performance');
}

function hide() {
    el('tuning-root').classList.add('tuning-hidden');
}

function setActiveTab(tab) {
    T.activeTab = tab;
    el('tabPerformance').classList.toggle('active', tab === 'performance');
    el('tabEsthetique').classList.toggle('active', tab === 'esthetique');
    el('tabClean').classList.toggle('active', tab === 'clean');
    render();
}

function render() {
    if (T.activeTab === 'performance') renderPerformance();
    else if (T.activeTab === 'esthetique') renderEsthetique();
    else if (T.activeTab === 'clean') renderService('clean');
}

// ---- Panier -----------------------------------------------------------
// Une seule entrée par "emplacement" (slotKey) : reposer une pièce sur le
// même emplacement remplace l'entrée précédente. `applyRevert` sait annuler
// l'aperçu (rappelle le natif avec la valeur d'origine, capturée à l'ouverture).

function addToCart(slotKey, category, label, price, applyRevert, action) {
    T.cart[slotKey] = { slotKey, category, label, price, applyRevert, action };
    renderCart();
}

// Retrait silencieux : le joueur est revenu au réglage d'origine en cliquant
// à nouveau dessus, rien à annuler (déjà dans l'état d'origine).
function removeFromCartSilent(slotKey) {
    delete T.cart[slotKey];
    renderCart();
}

// Retrait explicite (bouton "x" du panier) : on annule l'aperçu appliqué.
function removeFromCart(slotKey) {
    const entry = T.cart[slotKey];
    if (!entry) return;
    delete T.cart[slotKey];
    if (entry.applyRevert) entry.applyRevert();
    renderCart();
    render();
}

// Fermer la NUI sans payer ne doit jamais laisser un aperçu non facturé sur
// le véhicule : on annule tout ce qui reste dans le panier avant de fermer.
function revertPendingCart() {
    Object.values(T.cart).forEach((entry) => {
        if (entry.applyRevert) entry.applyRevert();
    });
    T.cart = {};
}

function cartTotal() {
    return Object.values(T.cart).reduce((sum, it) => sum + it.price, 0);
}

function renderCart() {
    const list = el('cartList');
    const items = Object.values(T.cart);

    list.innerHTML = items.length
        ? items.map(it => `<div class="tuning-cart-item">
            <span class="tuning-cart-item-label">${esc(it.label)}</span>
            <span class="tuning-cart-item-price">${it.price}$</span>
            <button class="tuning-cart-item-remove" data-slot="${esc(it.slotKey)}" title="Retirer">&#10005;</button>
        </div>`).join('')
        : `<div class="tuning-cart-empty">Panier vide</div>`;

    list.querySelectorAll('.tuning-cart-item-remove').forEach((btn) => {
        btn.addEventListener('click', () => removeFromCart(btn.dataset.slot));
    });

    const subtotal = cartTotal();
    const discountAmount = Math.round(subtotal * T.discountPercent / 100);
    const total = subtotal - discountAmount;

    el('cartSubtotal').textContent = subtotal + '$';
    el('cartDiscountAmount').textContent = '-' + discountAmount + '$';
    el('cartTotal').textContent = total + '$';
    el('cartCheckoutBtn').disabled = items.length === 0;
}

function setPaymentMode(mode) {
    T.paymentMode = mode;
    el('paymodeCustomer').classList.toggle('active', mode === 'customer');
    el('paymodeCompany').classList.toggle('active', mode === 'company');
}

el('paymodeCustomer').addEventListener('click', () => setPaymentMode('customer'));
el('paymodeCompany').addEventListener('click', () => setPaymentMode('company'));

el('cartDiscount').addEventListener('input', () => {
    let v = Math.floor(Number(el('cartDiscount').value) || 0);
    v = Math.max(0, Math.min(100, v));
    T.discountPercent = v;
    renderCart();
});

el('cartCheckoutBtn').addEventListener('click', () => {
    const items = Object.values(T.cart).map(it => ({ category: it.category, label: it.label, price: it.price, action: it.action || null }));
    if (!items.length) return;
    el('cartCheckoutBtn').disabled = true;
    fetchNui('tuning:checkout', { items, paymentMode: T.paymentMode, discountPercent: T.discountPercent });
});

// ---- Carte à paliers réutilisée pour Performance ET Carrosserie -------

function levelCardHtml(cat, s, locked) {
    const hasNames = Array.isArray(s.names);
    const nameFor = (lvl) => (hasNames && s.names[lvl]) || ('Niv.' + (lvl + 1));

    let html = `<div class="tuning-card${locked ? ' locked' : ''}">
        <div class="tuning-card-title"><span>${esc(cat.label)}</span></div>`;

    html += hasNames
        ? `<div class="tuning-card-sub">Actuel : ${esc(s.level >= 0 ? nameFor(s.level) : 'Stock')}</div>`
        : `<div class="tuning-card-sub">Palier actuel : ${s.level + 1} / ${s.maxLevel}</div>`;

    html += `<div class="tuning-levels">`;

    if (s.maxLevel <= 0) {
        html += `<span class="tuning-card-sub">Aucune amélioration disponible pour ce véhicule.</span>`;
    } else {
        for (let lvl = 0; lvl < s.maxLevel; lvl++) {
            const price = cat.pricePerLevel * (lvl + 1);
            const name = nameFor(lvl);
            html += `<button class="tuning-level-btn${s.level === lvl ? ' selected' : ''}"
                data-modtype="${cat.modType}" data-level="${lvl}" data-label="${esc(cat.label)} — ${esc(name)}" data-price="${price}" data-cat="${cat.id}">
                ${esc(name)} — ${price}$</button>`;
        }
    }
    return html + `</div></div>`;
}

function bindLevelCards(container, stateGroup, originalGroup, nuiAction, categoryTag, rerender) {
    container.querySelectorAll('.tuning-level-btn').forEach((btn) => {
        btn.addEventListener('click', () => {
            const modType = Number(btn.dataset.modtype);
            const level = Number(btn.dataset.level);
            const catId = btn.dataset.cat;
            const label = btn.dataset.label;
            const price = Number(btn.dataset.price);
            const orig = originalGroup[catId] || { level: -1 };
            const slotKey = categoryTag + ':' + catId;

            fetchNui(nuiAction, { modType, level });
            stateGroup[catId].level = level;

            if (level === orig.level) {
                removeFromCartSilent(slotKey);
            } else {
                addToCart(slotKey, categoryTag, label, price, () => {
                    fetchNui(nuiAction, { modType, level: orig.level });
                    stateGroup[catId].level = orig.level;
                });
            }
            rerender();
        });
    });
}

// ---- Peinture : type + couleur native (menus déroulants), avec une option
// "couleur précise" payante (sélecteur RGB) qui bascule sur une couleur
// hors-palette (SetVehicleCustomPrimaryColour/_Secondary côté Lua).

function paintSlotDescription(slot) {
    const s = T.state.paint[slot];
    if (s.custom) {
        const hex = '#' + [s.r, s.g, s.b].map(v => Math.max(0, Math.min(255, v || 0)).toString(16).padStart(2, '0')).join('');
        return 'Couleur précise ' + hex;
    }
    const typeLabel = (T.catalog.paintTypes.find(t => t.id === s.type) || {}).label || '—';
    const colorLabel = (T.catalog.paints.find(c => c.id === s.color) || {}).label || '—';
    return typeLabel + ' — ' + colorLabel;
}

function paintSlotHtml(slot, label) {
    const s = T.state.paint[slot];
    return `<div class="tuning-paint-slot">
        <div class="tuning-card-sub">${esc(label)} — ${esc(paintSlotDescription(slot))}</div>
        <div class="tuning-paint-row">
            <select class="tuning-select" id="paintType-${slot}"></select>
            <select class="tuning-select" id="paintColor-${slot}"></select>
        </div>
        <div class="tuning-paint-custom-row">
            <button class="tuning-list-btn" id="paintCustomToggle-${slot}">Couleur précise (+${T.catalog.customPaintPrice}$)</button>
            <input type="color" id="paintCustomInput-${slot}" class="tuning-paint-custom-input" value="#${[s.r || 0, s.g || 0, s.b || 0].map(v => v.toString(16).padStart(2, '0')).join('')}">
        </div>
    </div>`;
}

function isPaintOriginal(slot, candidate) {
    const orig = T.original.paint[slot];
    if (candidate.custom) {
        return orig.custom === true && orig.r === candidate.r && orig.g === candidate.g && orig.b === candidate.b;
    }
    return orig.custom !== true && orig.type === candidate.type && orig.color === candidate.color;
}

function revertPaintSlotFn(slot) {
    const orig = T.original.paint[slot];
    return () => {
        if (orig.custom) {
            fetchNui('tuning:applyCustomPaint', { slot, r: orig.r, g: orig.g, b: orig.b });
        } else {
            fetchNui('tuning:applyPaint', { slot, paintType: orig.type, colorId: orig.color });
        }
        T.state.paint[slot] = { type: orig.type, color: orig.color, custom: orig.custom, r: orig.r, g: orig.g, b: orig.b };
    };
}

function bindPaintSlot(slot) {
    const typeSelect = el('paintType-' + slot);
    const colorSelect = el('paintColor-' + slot);
    const s = T.state.paint[slot];

    T.catalog.paintTypes.forEach((t) => {
        const opt = document.createElement('option');
        opt.value = t.id;
        opt.textContent = t.label;
        if (!s.custom && s.type === t.id) opt.selected = true;
        typeSelect.appendChild(opt);
    });

    T.catalog.paints.forEach((c) => {
        const opt = document.createElement('option');
        opt.value = c.id;
        opt.textContent = c.label;
        if (!s.custom && s.color === c.id) opt.selected = true;
        colorSelect.appendChild(opt);
    });

    const applyPaletteChoice = () => {
        const paintType = Number(typeSelect.value);
        const colorId = Number(colorSelect.value);
        const colorLabel = (T.catalog.paints.find(c => c.id === colorId) || {}).label || '';
        const typeLabel = (T.catalog.paintTypes.find(t => t.id === paintType) || {}).label || '';

        fetchNui('tuning:applyPaint', { slot, paintType, colorId });
        T.state.paint[slot] = { type: paintType, color: colorId, custom: false };

        const slotKey = 'paint:' + slot;
        const candidate = { type: paintType, color: colorId, custom: false };
        if (isPaintOriginal(slot, candidate)) {
            removeFromCartSilent(slotKey);
        } else {
            addToCart(slotKey, 'customization', 'Peinture ' + (slot === 'primary' ? 'primaire' : 'secondaire') + ' — ' + typeLabel + ' ' + colorLabel, T.catalog.paintPrice, revertPaintSlotFn(slot));
        }
        renderEsthetique();
    };

    typeSelect.addEventListener('change', applyPaletteChoice);
    colorSelect.addEventListener('change', applyPaletteChoice);

    const customInput = el('paintCustomInput-' + slot);
    el('paintCustomToggle-' + slot).addEventListener('click', () => customInput.click());

    customInput.addEventListener('input', () => {
        const hex = customInput.value.replace('#', '');
        const r = parseInt(hex.substring(0, 2), 16);
        const g = parseInt(hex.substring(2, 4), 16);
        const b = parseInt(hex.substring(4, 6), 16);

        fetchNui('tuning:applyCustomPaint', { slot, r, g, b });
        T.state.paint[slot] = { custom: true, r, g, b };

        const slotKey = 'paint:' + slot;
        const candidate = { custom: true, r, g, b };
        if (isPaintOriginal(slot, candidate)) {
            removeFromCartSilent(slotKey);
        } else {
            addToCart(slotKey, 'customization', 'Peinture ' + (slot === 'primary' ? 'primaire' : 'secondaire') + ' — couleur précise', T.catalog.customPaintPrice, revertPaintSlotFn(slot));
        }
        renderEsthetique();
    });
}

function renderPerformance() {
    const content = el('tuningContent');
    let html = '';

    for (const cat of T.catalog.performance) {
        const s = T.state.performance[cat.id] || { level: -1, maxLevel: 0 };
        html += levelCardHtml(cat, s, !T.canPerformance);
    }

    const turbo = T.catalog.turbo;
    html += `<div class="tuning-card${T.canPerformance ? '' : ' locked'}">
        <div class="tuning-card-title"><span>${esc(turbo.label)}</span></div>
        <div class="tuning-card-sub">${T.state.turboOn ? 'Installé' : 'Non installé'}</div>
        <div class="tuning-toggle-row">
            <span>Activer (${turbo.price}$)</span>
            <div class="tuning-toggle${T.state.turboOn ? ' on' : ''}" id="turboToggle"></div>
        </div>
    </div>`;

    content.innerHTML = html;

    bindLevelCards(content, T.state.performance, T.original.performance, 'tuning:applyPerformance', 'performance', renderPerformance);

    const turboToggle = el('turboToggle');
    if (turboToggle) {
        turboToggle.addEventListener('click', () => {
            const enabled = !T.state.turboOn;
            fetchNui('tuning:applyTurbo', { enabled });
            T.state.turboOn = enabled;

            const slotKey = 'turbo';
            if (enabled === T.original.turboOn) {
                removeFromCartSilent(slotKey);
            } else {
                addToCart(slotKey, 'performance', turbo.label, turbo.price, () => {
                    fetchNui('tuning:applyTurbo', { enabled: T.original.turboOn });
                    T.state.turboOn = T.original.turboOn;
                });
            }
            renderPerformance();
        });
    }
}

// ---- Esthétique : sous-onglets par catégorie (au lieu d'un unique long
// scroll empilant carrosserie/jantes/peinture/néons/vitres/motifs/extras,
// ce qui rendait l'interface illisible) ------------------------------------

const ESTH_SUBTABS = [
    { id: 'carrosserie', label: 'Carrosserie' },
    { id: 'jantes',      label: 'Jantes' },
    { id: 'peinture',    label: 'Peinture' },
    { id: 'neons',       label: 'Néons' },
    { id: 'vitres',      label: 'Vitres' },
    { id: 'motifs',      label: 'Motifs' },
    { id: 'extras',      label: 'Extras' },
];

function esthSubnavHtml() {
    return `<div class="tuning-esth-subnav">${ESTH_SUBTABS.map(t =>
        `<button class="tuning-esth-subtab${T.esthSubTab === t.id ? ' active' : ''}" data-subtab="${t.id}">${esc(t.label)}</button>`
    ).join('')}</div>`;
}

function bindEsthSubnav(content) {
    content.querySelectorAll('.tuning-esth-subtab').forEach((btn) => {
        btn.addEventListener('click', () => {
            T.esthSubTab = btn.dataset.subtab;
            renderEsthetique();
        });
    });
}

function renderEsthetique() {
    if (!T.esthSubTab) T.esthSubTab = 'carrosserie';
    const content = el('tuningContent');
    content.innerHTML = esthSubnavHtml() + '<div class="tuning-esth-section" id="esthSection"></div>';
    bindEsthSubnav(content);

    if (T.esthSubTab === 'carrosserie') renderEsthCarrosserie();
    else if (T.esthSubTab === 'jantes') renderEsthJantes();
    else if (T.esthSubTab === 'peinture') renderEsthPeinture();
    else if (T.esthSubTab === 'neons') renderEsthNeons();
    else if (T.esthSubTab === 'vitres') renderEsthVitres();
    else if (T.esthSubTab === 'motifs') renderEsthMotifs();
    else if (T.esthSubTab === 'extras') renderEsthExtras();
}

function renderEsthCarrosserie() {
    const section = el('esthSection');
    let html = '';
    for (const cat of T.catalog.bodykit) {
        const s = T.state.bodykit[cat.id] || { level: -1, maxLevel: 0 };
        html += levelCardHtml(cat, s, !T.canCustomization);
    }
    section.innerHTML = html;
    bindLevelCards(section, T.state.bodykit, T.original.bodykit, 'tuning:applyBodykit', 'customization', renderEsthCarrosserie);
}

function renderEsthJantes() {
    const section = el('esthSection');
    const locked = T.canCustomization ? '' : ' locked';

    section.innerHTML = `<div class="tuning-card${locked}">
        <div class="tuning-card-title"><span>Jantes</span></div>
        <div class="tuning-card-sub">Type actuel : ${esc((T.catalog.wheelTypes.find(w => w.id === T.state.wheelType) || {}).label || '—')}</div>
        <div class="tuning-list" id="wheelTypeList"></div>
        <div class="tuning-levels" id="wheelIndexList"></div>
        <div class="tuning-price">Prix par jante posée : <b>${T.catalog.wheelPrice}$</b></div>
    </div>`;

    // Jantes — types
    const wheelTypeList = el('wheelTypeList');
    T.catalog.wheelTypes.forEach((wt) => {
        const btn = document.createElement('button');
        btn.className = 'tuning-list-btn' + (T.state.wheelType === wt.id ? ' selected' : '');
        btn.textContent = wt.label;
        btn.addEventListener('click', async () => {
            const res = await fetchNui('tuning:previewWheelType', { typeId: wt.id });
            T.pendingWheelType = wt.id;
            T.pendingWheelCount = (res && res.count) || 0;
            T.state.wheelType = wt.id;
            renderEsthJantes();
        });
        wheelTypeList.appendChild(btn);
    });

    // Jantes — index (seulement si un type vient d'être choisi)
    const wheelIndexList = el('wheelIndexList');
    if (T.pendingWheelType !== null) {
        const typeLabel = (T.catalog.wheelTypes.find(w => w.id === T.pendingWheelType) || {}).label || '';
        for (let i = 0; i < T.pendingWheelCount; i++) {
            const btn = document.createElement('button');
            btn.className = 'tuning-level-btn' + (T.state.wheelIndex === i ? ' selected' : '');
            btn.textContent = 'Jante #' + (i + 1);
            btn.addEventListener('click', () => {
                fetchNui('tuning:applyWheelIndex', { index: i });
                T.state.wheelType = T.pendingWheelType;
                T.state.wheelIndex = i;

                const slotKey = 'wheel';
                const isOriginal = T.pendingWheelType === T.original.wheelType && i === T.original.wheelIndex;
                if (isOriginal) {
                    removeFromCartSilent(slotKey);
                } else {
                    addToCart(slotKey, 'customization', 'Jantes — ' + typeLabel + ' #' + (i + 1), T.catalog.wheelPrice, () => {
                        fetchNui('tuning:previewWheelType', { typeId: T.original.wheelType });
                        fetchNui('tuning:applyWheelIndex', { index: T.original.wheelIndex });
                        T.pendingWheelType = T.original.wheelType;
                        T.state.wheelType = T.original.wheelType;
                        T.state.wheelIndex = T.original.wheelIndex;
                    });
                }
                renderEsthJantes();
            });
            wheelIndexList.appendChild(btn);
        }
    }
}

function renderEsthPeinture() {
    const section = el('esthSection');
    const locked = T.canCustomization ? '' : ' locked';

    section.innerHTML = `<div class="tuning-card${locked}">
        <div class="tuning-card-title"><span>Peinture</span></div>
        ${paintSlotHtml('primary', 'Primaire')}
        ${paintSlotHtml('secondary', 'Secondaire')}
        <div class="tuning-price">Type + couleur : <b>${T.catalog.paintPrice}$</b> — couleur précise : <b>${T.catalog.customPaintPrice}$</b> (par couche)</div>
    </div>`;

    bindPaintSlot('primary');
    bindPaintSlot('secondary');
}

function renderEsthNeons() {
    const section = el('esthSection');
    const locked = T.canCustomization ? '' : ' locked';
    const n = T.state.neon;

    section.innerHTML = `<div class="tuning-card${locked}">
        <div class="tuning-card-title"><span>Néons</span></div>
        <div class="tuning-toggle-row"><span>Avant</span><div class="tuning-toggle${n.front ? ' on' : ''}" data-pos="front"></div></div>
        <div class="tuning-toggle-row"><span>Arrière</span><div class="tuning-toggle${n.back ? ' on' : ''}" data-pos="back"></div></div>
        <div class="tuning-toggle-row"><span>Gauche</span><div class="tuning-toggle${n.left ? ' on' : ''}" data-pos="left"></div></div>
        <div class="tuning-toggle-row"><span>Droite</span><div class="tuning-toggle${n.right ? ' on' : ''}" data-pos="right"></div></div>
        <div class="tuning-swatches" id="neonColors" style="margin-top:8px;"></div>
        <button class="tuning-apply-btn" id="neonApply">Appliquer (${T.catalog.neonPrice}$)</button>
    </div>`;

    section.querySelectorAll('[data-pos]').forEach((toggle) => {
        toggle.addEventListener('click', () => {
            const pos = toggle.dataset.pos;
            T.state.neon[pos] = !T.state.neon[pos];
            toggle.classList.toggle('on', T.state.neon[pos]);
        });
    });

    const neonColorsEl = el('neonColors');
    let selectedNeonColor = T.catalog.neonColors[0];
    T.catalog.neonColors.forEach((c, idx) => {
        const sw = document.createElement('div');
        sw.className = 'tuning-swatch' + (idx === 0 ? ' selected' : '');
        sw.style.background = `rgb(${c.r},${c.g},${c.b})`;
        sw.title = c.label;
        sw.addEventListener('click', () => {
            selectedNeonColor = c;
            neonColorsEl.querySelectorAll('.tuning-swatch').forEach(s => s.classList.remove('selected'));
            sw.classList.add('selected');
        });
        neonColorsEl.appendChild(sw);
    });

    el('neonApply').addEventListener('click', () => {
        const positions = { front: T.state.neon.front, back: T.state.neon.back, left: T.state.neon.left, right: T.state.neon.right };
        const color = { r: selectedNeonColor.r, g: selectedNeonColor.g, b: selectedNeonColor.b };
        fetchNui('tuning:applyNeon', { positions, color });

        const orig = T.original.neon;
        const slotKey = 'neon';
        const isOriginal = positions.front === orig.front && positions.back === orig.back
            && positions.left === orig.left && positions.right === orig.right
            && color.r === orig.r && color.g === orig.g && color.b === orig.b;

        if (isOriginal) {
            removeFromCartSilent(slotKey);
        } else {
            addToCart(slotKey, 'customization', 'Néons', T.catalog.neonPrice, () => {
                fetchNui('tuning:applyNeon', {
                    positions: { front: orig.front, back: orig.back, left: orig.left, right: orig.right },
                    color: { r: orig.r, g: orig.g, b: orig.b },
                });
                T.state.neon = { front: orig.front, back: orig.back, left: orig.left, right: orig.right, r: orig.r, g: orig.g, b: orig.b };
                renderEsthNeons();
            });
        }
    });
}

function renderEsthVitres() {
    const section = el('esthSection');
    const locked = T.canCustomization ? '' : ' locked';

    section.innerHTML = `<div class="tuning-card${locked}">
        <div class="tuning-card-title"><span>Vitres teintées</span></div>
        <div class="tuning-list" id="tintList"></div>
        <div class="tuning-price">Prix : <b>${T.catalog.tintPrice}$</b></div>
    </div>`;

    const tintList = el('tintList');
    T.catalog.tints.forEach((t) => {
        const btn = document.createElement('button');
        btn.className = 'tuning-list-btn' + (T.state.tint === t.id ? ' selected' : '');
        btn.textContent = t.label;
        btn.addEventListener('click', () => {
            fetchNui('tuning:applyTint', { id: t.id });
            T.state.tint = t.id;

            const slotKey = 'tint';
            if (t.id === T.original.tint) {
                removeFromCartSilent(slotKey);
            } else {
                addToCart(slotKey, 'customization', 'Vitres teintées — ' + t.label, T.catalog.tintPrice, () => {
                    fetchNui('tuning:applyTint', { id: T.original.tint });
                    T.state.tint = T.original.tint;
                });
            }
            renderEsthVitres();
        });
        tintList.appendChild(btn);
    });
}

function renderEsthMotifs() {
    const section = el('esthSection');
    const locked = T.canCustomization ? '' : ' locked';

    section.innerHTML = `<div class="tuning-card${locked}">
        <div class="tuning-card-title"><span>Motifs</span></div>
        <div class="tuning-list" id="liveryList"></div>
        <div class="tuning-price">Prix : <b>${T.catalog.liveryPrice}$</b></div>
    </div>`;

    // Motifs — "Aucun" (-1) puis chaque motif disponible pour ce véhicule.
    const liveryList = el('liveryList');
    if (!T.state.liveryCount) {
        liveryList.innerHTML = '<div class="tuning-card-sub">Aucun motif disponible pour ce véhicule.</div>';
    } else {
        const options = [{ id: -1, label: 'Aucun' }];
        for (let i = 0; i < T.state.liveryCount; i++) options.push({ id: i, label: 'Motif #' + (i + 1) });

        options.forEach((lv) => {
            const btn = document.createElement('button');
            btn.className = 'tuning-list-btn' + (T.state.livery === lv.id ? ' selected' : '');
            btn.textContent = lv.label;
            btn.addEventListener('click', () => {
                fetchNui('tuning:applyLivery', { index: lv.id });
                T.state.livery = lv.id;

                const slotKey = 'livery';
                if (lv.id === T.original.livery) {
                    removeFromCartSilent(slotKey);
                } else {
                    addToCart(slotKey, 'customization', 'Motif — ' + lv.label, T.catalog.liveryPrice, () => {
                        fetchNui('tuning:applyLivery', { index: T.original.livery });
                        T.state.livery = T.original.livery;
                    });
                }
                renderEsthMotifs();
            });
            liveryList.appendChild(btn);
        });
    }
}

// Extras (SetVehicleExtra) — uniquement ceux détectés sur ce véhicule
// (DoesExtraExist côté client), ce qui couvre nativement les extras propres
// aux véhicules addon Gabz ([Véhicules]/gb_vehicles_*) sans liste figée.
function renderEsthExtras() {
    const section = el('esthSection');
    const locked = T.canCustomization ? '' : ' locked';
    const extraIds = Object.keys(T.state.extras || {}).map(Number).sort((a, b) => a - b);

    if (extraIds.length === 0) {
        section.innerHTML = `<div class="tuning-card${locked}">
            <div class="tuning-card-title"><span>Extras</span></div>
            <div class="tuning-card-sub">Aucun extra disponible pour ce véhicule.</div>
        </div>`;
        return;
    }

    section.innerHTML = `<div class="tuning-card${locked}">
        <div class="tuning-card-title"><span>Extras</span></div>
        <div class="tuning-card-sub">Pièces optionnelles propres à ce véhicule (becquets, décos, éléments additionnels).</div>
        <div id="extrasList"></div>
        <div class="tuning-price">Prix par extra activé : <b>${T.catalog.extraPrice}$</b></div>
    </div>`;

    const extrasList = el('extrasList');
    extraIds.forEach((id) => {
        const on = T.state.extras[id] === true;
        const row = document.createElement('div');
        row.className = 'tuning-toggle-row';
        row.innerHTML = `<span>Extra ${id}</span><div class="tuning-toggle${on ? ' on' : ''}"></div>`;
        row.querySelector('.tuning-toggle').addEventListener('click', () => {
            const enabled = !T.state.extras[id];
            fetchNui('tuning:applyExtra', { index: id, enabled });
            T.state.extras[id] = enabled;

            const slotKey = 'extra:' + id;
            if (enabled === (T.original.extras[id] === true)) {
                removeFromCartSilent(slotKey);
            } else {
                addToCart(slotKey, 'customization', 'Extra ' + id, T.catalog.extraPrice, () => {
                    const orig = T.original.extras[id] === true;
                    fetchNui('tuning:applyExtra', { index: id, enabled: orig });
                    T.state.extras[id] = orig;
                });
            }
            renderEsthExtras();
        });
        extrasList.appendChild(row);
    });
}

// ---- Nettoyer -------------------------------------------------
// Forfait unique ajouté au panier ; l'action réelle n'est exécutée par le
// client Lua qu'après confirmation de paiement par le serveur.

function renderService(kind) {
    const content = el('tuningContent');
    const svc = (T.catalog.services || []).find(s => s.id === kind);
    if (!svc) { content.innerHTML = ''; return; }

    const slotKey = 'service:' + kind;
    const inCart = !!T.cart[slotKey];
    const canDo = T.canMaintenance;

    content.innerHTML = `<div class="tuning-card${canDo ? '' : ' locked'}">
        <div class="tuning-card-title"><span>${esc(svc.label)}</span></div>
        <div class="tuning-card-sub">Prix forfaitaire : <b>${svc.price}$</b></div>
        <div class="tuning-card-sub">${inCart ? 'Ajouté au panier — sera effectué après paiement.' : 'Ajoutez ce service au panier pour le programmer.'}</div>
        <button class="tuning-apply-btn" id="serviceBtn">${inCart ? 'Retirer du panier' : 'Ajouter au panier'}</button>
    </div>`;

    el('serviceBtn').addEventListener('click', () => {
        if (T.cart[slotKey]) {
            removeFromCartSilent(slotKey);
        } else {
            addToCart(slotKey, kind, svc.label, svc.price, null, kind);
        }
        renderService(kind);
    });
}

// ---- Caméra libre : glisser pour tourner, molette pour zoomer ---------

let dragging = false;
let lastX = 0, lastY = 0;

function isOverPanel(target) {
    return !!(target && target.closest && target.closest('.tuning-sidepanel'));
}

document.addEventListener('mousedown', (e) => {
    if (el('tuning-root').classList.contains('tuning-hidden')) return;
    if (isOverPanel(e.target)) return;
    dragging = true;
    lastX = e.clientX;
    lastY = e.clientY;
});

document.addEventListener('mouseup', () => { dragging = false; });
document.addEventListener('mouseleave', () => { dragging = false; });

document.addEventListener('mousemove', (e) => {
    if (!dragging) return;
    const dx = e.clientX - lastX;
    const dy = e.clientY - lastY;
    lastX = e.clientX;
    lastY = e.clientY;
    fetchNui('tuning:cameraOrbit', { dx: dx * 0.3, dy: dy * -0.2 });
});

document.addEventListener('wheel', (e) => {
    if (el('tuning-root').classList.contains('tuning-hidden')) return;
    if (isOverPanel(e.target)) return;
    fetchNui('tuning:cameraZoom', { delta: e.deltaY * 0.01 });
}, { passive: true });

// ---- Câblage général ----------------------------------------------------

window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data || !data.action) return;

    if (data.action === 'tuning:open') open(data);
    else if (data.action === 'tuning:hide') hide();
    else if (data.action === 'tuning:checkoutDone') {
        if (data.success) {
            T.cart = {};
            T.discountPercent = 0;
            el('cartDiscount').value = 0;
        }
        renderCart();
    }
});

el('tuningCloseBtn').addEventListener('click', () => {
    revertPendingCart();
    fetchNui('tuning:close', {});
    hide();
});

el('tabPerformance').addEventListener('click', () => setActiveTab('performance'));
el('tabEsthetique').addEventListener('click', () => setActiveTab('esthetique'));
el('tabClean').addEventListener('click', () => setActiveTab('clean'));
el('tabRepair').addEventListener('click', () => setActiveTab('repair'));

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && !el('tuning-root').classList.contains('tuning-hidden')) {
        revertPendingCart();
        fetchNui('tuning:close', {});
        hide();
    }
});
