/* ════════════════════════════════════════════════════════════════
   LSLegacyBank Pay — NUI du menu de paiement (remplace l'ancien menu
   RageUI). Toute la logique métier (vérif PIN, plafonds, découvert)
   reste côté serveur (sv_paymentMenu.lua) ; ce fichier ne fait que du
   rendu + relais des actions vers 'payment:xxx' (RegisterNUICallback
   dans cl_paymentMenu.lua).
   ════════════════════════════════════════════════════════════════ */

const PAY_RES = 'lslegacy';

const PayState = {
    transactionMessage: '',
    price: 0,
    cards: [],          // [{label, data:{card_number, card_pin, card_type, card_tier, owner_name, card_expiration_date, card_account}}]
    contactlessMax: 50,
    allowCash: true,
    view: 'choice',      // 'choice' | 'tpe' | 'pin'
    pinCard: null,
    pinBuffer: '',
};

function payEl(id) { return document.getElementById(id); }

function payEsc(v) {
    if (v === null || v === undefined) return '';
    return String(v).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

function payFmtMoney(n) {
    n = Number(n) || 0;
    return Math.round(n * 100) / 100 + ' $';
}

async function payFetchNui(name, data) {
    try {
        const resp = await fetch(`https://${PAY_RES}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data || {}),
        });
        return await resp.json();
    } catch (e) { return null; }
}

function payToast(message, type) {
    const t = document.createElement('div');
    t.className = 'bank-toast' + (type === 'error' ? ' err' : '');
    t.textContent = message;
    payEl('payToasts').appendChild(t);
    setTimeout(() => t.remove(), 3800);
}

let payHandlers = {};
let payHandlerSeq = 0;
function PH(fn) { const id = 'p' + (payHandlerSeq++); payHandlers[id] = fn; return id; }
window.callPH = function (id) { const fn = payHandlers[id]; if (fn) fn(); };

/* ── Rendu : choix du moyen de paiement ─────────────────────────── */

function renderPayChoice() {
    payEl('payBackBtn').classList.add('bank-hidden');
    payEl('payContent').innerHTML = `
        <div class="pay-summary">
            <div class="pay-summary-label">Transaction</div>
            <div class="pay-summary-desc">${payEsc(PayState.transactionMessage)}</div>
            <div class="pay-summary-amount">${payFmtMoney(PayState.price)}</div>
        </div>

        <div class="bank-section-title">Moyen de paiement</div>
        <div class="bank-tiles">
            <button class="bank-tile" onclick="callPH('${PH(payCash)}')">
                <div class="bank-tile-icon">&#128181;</div>
                <div class="bank-tile-title">Espèces</div>
                <div class="bank-tile-desc">Payer en liquide directement.</div>
            </button>
            <button class="bank-tile" onclick="callPH('${PH(() => { PayState.view = 'tpe'; renderPay(); })}')">
                <div class="bank-tile-icon">&#128179;</div>
                <div class="bank-tile-title">Carte bancaire</div>
                <div class="bank-tile-desc">Sans contact ou insertion + code PIN.</div>
            </button>
        </div>
    `;
}

async function payCash() {
    await payFetchNui('payment:payCash', {});
}

/* ── Rendu : TPE ─────────────────────────────────────────────────── */

function cardScreenIdle() {
    return `
        <div class="tpe-screen-line">LSLegacyBank Pay</div>
        <div class="tpe-screen-amount">${payFmtMoney(PayState.price)}</div>
        <div class="tpe-screen-line">${payEsc(PayState.transactionMessage)}</div>
        <div class="tpe-screen-hint">Glissez une carte en haut (sans contact)<br>ou en bas (insertion + code PIN)</div>
    `;
}

function renderTpe() {
    payEl('payBackBtn').classList.toggle('bank-hidden', !PayState.allowCash);

    if (PayState.cards.length === 0) {
        payEl('payContent').innerHTML = `
            <div class="bank-empty">Vous n'avez aucune carte bancaire sur vous.</div>
        `;
        return;
    }

    payEl('payContent').innerHTML = `
        <div class="tpe-stage">
            <div class="tpe-image-wrap" id="tpeImageWrap">
                <img src="img/tpe.png" alt="TPE" draggable="false">
                <div class="tpe-screen" id="tpeScreen">${cardScreenIdle()}</div>
                <div class="tpe-drop-zone tpe-drop-top" id="tpeDropTop"></div>
                <div class="tpe-drop-zone tpe-drop-bottom" id="tpeDropBottom"></div>
                <div class="tpe-inserted-card bank-hidden" id="tpeInsertedCard"></div>
                <div class="tpe-phys-keys" id="tpePhysKeys"></div>
            </div>
            <div class="tpe-card-rail">
                <div class="tpe-card-rail-title">Vos cartes</div>
                ${PayState.cards.map((c, i) => renderCardHtml(c, i)).join('')}
                <div class="tpe-hint">Glissez-déposez une carte sur le terminal</div>
            </div>
        </div>
    `;

    PayState.cards.forEach((c, i) => {
        const cardEl = payEl('tpeCard' + i);
        if (cardEl) attachCardDrag(cardEl, c);
    });
    renderPhysKeys();
}

function renderCardHtml(card, index) {
    const d = card.data || {};
    const num = String(d.card_number || '0000000000000000');
    const masked = '•••• •••• •••• ' + num.slice(-4);
    return `
        <div class="tpe-card" id="tpeCard${index}">
            <div class="tpe-card-top">
                <span class="tpe-card-brand">${payEsc(d.card_type || 'Carte bancaire')}</span>
                <span class="tpe-card-tier">${payEsc(d.card_tier || 'standard')}</span>
            </div>
            <div class="tpe-card-number">${masked}</div>
            <div class="tpe-card-bottom">
                <div>
                    <div class="tpe-card-holder">${payEsc(d.owner_name || '')}</div>
                    <div class="tpe-card-expiry">${payEsc(d.card_expiration_date || '')}</div>
                </div>
                <div class="tpe-card-mc"><span></span><span></span></div>
            </div>
        </div>
    `;
}

/* ── Glisser-déposer (pointer events, pas de DnD HTML5) ─────────── */

function attachCardDrag(cardEl, card) {
    cardEl.addEventListener('pointerdown', (ev) => {
        ev.preventDefault();
        startCardDrag(ev, cardEl, card);
    });
}

function startCardDrag(startEv, sourceEl, card) {
    const ghost = document.createElement('div');
    ghost.className = 'tpe-ghost';
    ghost.innerHTML = renderCardHtml(card, -1).replace('id="tpeCard-1"', '');
    document.body.appendChild(ghost);

    sourceEl.classList.add('dragging-source');
    moveGhost(ghost, startEv.clientX, startEv.clientY);

    const topZone = payEl('tpeDropTop');
    const bottomZone = payEl('tpeDropBottom');

    function onMove(ev) {
        moveGhost(ghost, ev.clientX, ev.clientY);
        updateDropHighlight(topZone, ev.clientX, ev.clientY);
        updateDropHighlight(bottomZone, ev.clientX, ev.clientY);
    }

    function onUp(ev) {
        document.removeEventListener('pointermove', onMove);
        document.removeEventListener('pointerup', onUp);
        ghost.remove();
        sourceEl.classList.remove('dragging-source');
        topZone.classList.remove('drag-active');
        bottomZone.classList.remove('drag-active');

        if (isOverZone(topZone, ev.clientX, ev.clientY)) {
            handleContactless(card);
        } else if (isOverZone(bottomZone, ev.clientX, ev.clientY)) {
            handleInsert(card);
        }
    }

    document.addEventListener('pointermove', onMove);
    document.addEventListener('pointerup', onUp);
}

function moveGhost(ghost, x, y) {
    ghost.style.left = x + 'px';
    ghost.style.top = y + 'px';
}

function isOverZone(zoneEl, x, y) {
    const r = zoneEl.getBoundingClientRect();
    return x >= r.left && x <= r.right && y >= r.top && y <= r.bottom;
}

function updateDropHighlight(zoneEl, x, y) {
    zoneEl.classList.toggle('drag-active', isOverZone(zoneEl, x, y));
}

/* ── Sans contact ────────────────────────────────────────────────── */

async function handleContactless(card) {
    if (PayState.price > PayState.contactlessMax) {
        payToast(`Montant trop élevé pour le sans contact (max ${payFmtMoney(PayState.contactlessMax)}). Insérez la carte.`, 'error');
        return;
    }
    payEl('tpeScreen').innerHTML = `
        <div class="tpe-screen-line">Paiement sans contact...</div>
        <div class="tpe-screen-amount">${payFmtMoney(PayState.price)}</div>
    `;
    await payFetchNui('payment:payContactless', { card });
}

/* ── Insertion + code PIN ───────────────────────────────────────── */

function showInsertedCard(card) {
    const el = payEl('tpeInsertedCard');
    if (!el) return;
    // Réutilise le même rendu de carte que la pile "Vos cartes" (mêmes
    // proportions/éléments, taille naturelle non réduite), pivoté via le
    // wrapper .tpe-inserted-card-face pour sortir de la fente du bas.
    el.innerHTML = `<div class="tpe-inserted-card-face">${renderCardHtml(card, -3).replace('id="tpeCard-3"', '')}</div>`;
    el.classList.remove('bank-hidden');
}

function hideInsertedCard() {
    const el = payEl('tpeInsertedCard');
    if (!el) return;
    el.classList.add('bank-hidden');
    el.innerHTML = '';
}

// La carte "physiquement dans le lecteur" ne doit plus apparaître dans la
// pile de droite tant qu'elle n'est pas retirée (annulation) ou que le
// panneau se referme (fin de transaction).
function setRailCardHidden(card, hidden) {
    const idx = PayState.cards.indexOf(card);
    if (idx === -1) return;
    const el = payEl('tpeCard' + idx);
    if (el) el.classList.toggle('bank-hidden', hidden);
}

function handleInsert(card) {
    PayState.pinCard = card;
    PayState.pinBuffer = '';
    showInsertedCard(card);
    setRailCardHidden(card, true);
    renderPinScreen();
}

function renderPinScreen() {
    // Pas de clavier à l'écran : on tape sur les vraies touches physiques
    // du TPE (voir renderPhysKeys) — l'écran ne fait qu'afficher le
    // retour (points remplis), comme un vrai terminal.
    const dots = [0, 1, 2, 3].map(i => `<span class="tpe-pin-dot ${i < PayState.pinBuffer.length ? 'filled' : ''}"></span>`).join('');
    payEl('tpeScreen').innerHTML = `
        <div class="tpe-screen-line">Code PIN</div>
        <div class="tpe-pin-dots">${dots}</div>
        <div class="tpe-screen-hint">Tapez sur le clavier du terminal</div>
    `;
}

/* ── Clavier physique du TPE (touches réelles de la photo) ──────────── */

const PHYS_KEY_COLS = [
    { left: 19.8, width: 15 },
    { left: 35.3, width: 15 },
    { left: 50.4, width: 15 },
    { left: 65.8, width: 15 },
];
const PHYS_KEY_ROWS = [
    { top: 56.4, height: 5.5 },
    { top: 62.3, height: 5.5 },
    { top: 68.6, height: 5.5 },
    { top: 75.0, height: 5.5 },
];
// null = touche non utilisée (impression, symboles...) ; grille identique à la photo.
const PHYS_KEY_LAYOUT = [
    ['1', '2', '3', null],
    ['4', '5', '6', 'cancel'],
    ['7', '8', '9', 'clear'],
    [null, '0', null, 'enter'],
];

function onPhysKey(action) {
    if (!PayState.pinCard) return; // pas de carte insérée : clavier inactif
    if (action === 'cancel') { pinCancel(); return; }
    if (action === 'clear') { pinClear(); return; }
    if (action === 'enter') { if (PayState.pinBuffer.length === 4) submitPin(); return; }
    pinPress(action);
}

function renderPhysKeys() {
    const el = payEl('tpePhysKeys');
    if (!el) return;
    let html = '';
    PHYS_KEY_LAYOUT.forEach((row, r) => {
        row.forEach((action, c) => {
            if (action === null) return;
            const col = PHYS_KEY_COLS[c], rowPos = PHYS_KEY_ROWS[r];
            html += `<button class="tpe-phys-key" style="left:${col.left}%;top:${rowPos.top}%;width:${col.width}%;height:${rowPos.height}%;" onclick="callPH('${PH(() => onPhysKey(action))}')"></button>`;
        });
    });
    el.innerHTML = html;
}

function pinPress(digit) {
    if (PayState.pinBuffer.length >= 4) return;
    PayState.pinBuffer += digit;
    renderPinScreen();
    if (PayState.pinBuffer.length === 4) {
        submitPin();
    }
}

function pinClear() {
    PayState.pinBuffer = '';
    renderPinScreen();
}

function pinCancel() {
    if (PayState.pinCard) setRailCardHidden(PayState.pinCard, false);
    PayState.pinCard = null;
    PayState.pinBuffer = '';
    hideInsertedCard();
    payEl('tpeScreen').innerHTML = cardScreenIdle();
}

async function submitPin() {
    const card = PayState.pinCard;
    const pin = PayState.pinBuffer;
    payEl('tpeScreen').innerHTML = `
        <div class="tpe-screen-line">Vérification...</div>
    `;
    await payFetchNui('payment:payChip', { card, pin });
}

/* ── Clavier physique pendant la saisie PIN ─────────────────────── */

window.addEventListener('keydown', (e) => {
    if (PayState.view !== 'tpe' || !PayState.pinCard) return;
    if (/^[0-9]$/.test(e.key)) pinPress(e.key);
    else if (e.key === 'Backspace') pinClear();
    else if (e.key === 'Escape') pinCancel();
});

/* ── Routeur minimal (2 vues) ────────────────────────────────────── */

function renderPay() {
    payHandlers = {};
    payHandlerSeq = 0;
    if (PayState.view === 'choice') renderPayChoice();
    else renderTpe();
}

/* ── Ouverture / fermeture / messages Lua ───────────────────────── */

function applyPayOpenPayload(data) {
    PayState.transactionMessage = data.transactionMessage || '';
    PayState.price = Number(data.price) || 0;
    PayState.cards = data.cards || [];
    PayState.contactlessMax = Number(data.contactlessMax) || 50;
    PayState.allowCash = data.allowCash !== false;
    PayState.view = PayState.allowCash ? 'choice' : 'tpe';
    PayState.pinCard = null;
    PayState.pinBuffer = '';

    payEl('payTransactionLabel').textContent = payFmtMoney(PayState.price);
    payEl('pay-root').classList.remove('bank-hidden');
    renderPay();
}

function playPaySound(success) {
    const src = success ? 'sounds/pay-success.mp3' : 'sounds/pay-declined.mp3';
    const audio = new Audio(src);
    audio.volume = 0.6;
    audio.play().catch(() => {});
}

window.addEventListener('message', function (event) {
    const data = event.data;
    if (!data || !data.action) return;

    switch (data.action) {
        case 'payment:open':
            applyPayOpenPayload(data);
            break;
        case 'payment:hide':
            payEl('pay-root').classList.add('bank-hidden');
            break;
        case 'payment:sound':
            playPaySound(!!data.success);
            break;
    }
});

payEl('payCloseBtn').addEventListener('click', function () {
    payFetchNui('payment:close', {});
    payEl('pay-root').classList.add('bank-hidden');
});

payEl('payBackBtn').addEventListener('click', function () {
    PayState.view = 'choice';
    PayState.pinCard = null;
    renderPay();
});

document.addEventListener('keydown', function (e) {
    if (e.key !== 'Escape') return;
    if (payEl('pay-root').classList.contains('bank-hidden')) return;
    // Carte insérée, saisie PIN en cours : Échap annule juste la saisie
    // (géré par le listener clavier dédié au TPE), pas tout le menu.
    if (PayState.view === 'tpe' && PayState.pinCard) return;
    payFetchNui('payment:close', {});
    payEl('pay-root').classList.add('bank-hidden');
});
