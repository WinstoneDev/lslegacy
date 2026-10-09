function tierRow(tier, cfg, selected, onClick) {
    return `
        <div class="bank-pick-card ${selected ? 'selected' : ''}" data-tier="${tier}" onclick="callH('${onClick}')">
            <div class="bank-pick-card-title">${tierLabel(tier)}</div>
            <div class="bank-pick-card-desc">
                Plafond paiement ${fmtMoney(cfg.payment_ceiling)}<br>
                Plafond retrait ${fmtMoney(cfg.withdrawal_ceiling)}<br>
                Plafond virement ${fmtMoney(cfg.transfer_ceiling)}<br>
                Découvert autorisé ${fmtMoney(cfg.overdraft_limit)}${cfg.agios_rate_percent ? ' (agios ' + cfg.agios_rate_percent + '%)' : ''}
            </div>
            <div class="bank-pick-card-rate">${cfg.cost_amount > 0 ? fmtMoney(cfg.cost_amount) + ' / ' + (cfg.cost_period === 'monthly' ? 'mois' : 'semaine') : 'Gratuite'}</div>
        </div>
    `;
}

async function toggleBlockCard(account) {
    await fetchNui('bank:blockCard', { id: account.id, blocked: !account.card_blocked });
    toast(account.card_blocked ? 'Déblocage demandé.' : 'Blocage demandé.');
}

async function replaceCard(account) {
    await fetchNui('bank:replaceCard', { id: account.id });
    toast('Nouvelle carte commandée.');
}

async function createCard(accountId, tier) {
    await fetchNui('bank:createCard', { id: accountId, tier });
    toast('Demande de carte envoyée.');
}

async function setCardTier(accountId, tier) {
    await fetchNui('bank:setCardTier', { id: accountId, tier });
    toast('Changement de palier envoyé.');
}

let bankPinRevealTimeout = null;

function revealCardPin(pin) {
    const el_ = el('bankCardPinValue');
    const btn = el('bankCardPinBtn');
    if (!el_ || !btn) return;

    if (bankPinRevealTimeout) clearTimeout(bankPinRevealTimeout);

    el_.textContent = pin;
    btn.disabled = true;
    let secondsLeft = 5;
    btn.textContent = `Masquage dans ${secondsLeft}s...`;

    const tick = setInterval(() => {
        secondsLeft -= 1;
        if (secondsLeft <= 0) {
            clearInterval(tick);
            return;
        }
        btn.textContent = `Masquage dans ${secondsLeft}s...`;
    }, 1000);

    bankPinRevealTimeout = setTimeout(() => {
        clearInterval(tick);
        el_.textContent = '••••';
        btn.disabled = false;
        btn.textContent = 'Afficher le code PIN (5s)';
    }, 5000);
}

function renderCardForAccount(root, account) {
    const tiers = BankState.adminCardTiers || {};
    const tierNames = Object.keys(tiers).length ? Object.keys(tiers) : ['standard', 'premier', 'platinum'];
    let selectedTier = account.card_tier || 'standard';

    const hasCard = !!account.card_infos;
    bankPinRevealTimeout = null;

    const rerender = () => {
        document.querySelectorAll('#bankCardTierGrid .bank-pick-card').forEach(c => {
            c.classList.toggle('selected', c.dataset.tier === selectedTier);
        });
    };

    root.innerHTML = `
        <a href="#" onclick="callH('${H(() => showView('card'))}');return false;" style="font-size:12.5px;color:var(--bank-text-dim);font-weight:600;">&#8592; Comptes</a>

        <div class="bank-hero" style="margin-top:14px;">
            <div>
                <div class="bank-hero-label">Compte n°${account.id}</div>
                <div class="bank-hero-amount" style="font-size:22px;">${hasCard ? esc(account.card_infos.card_type) + ' — Palier ' + esc(tierLabel(account.card_tier)) : 'Aucune carte'}</div>
                ${hasCard ? `<div class="bank-hero-iban">**** **** **** ${String(account.card_infos.card_number).slice(-4)} · exp. ${esc(account.card_infos.card_expiration_date)}</div>` : ''}
            </div>
            <span class="bank-hero-badge">${tierLabel(account.card_tier)}</span>
        </div>

        ${hasCard ? `
        <div class="bank-section-title">Sécurité</div>
        <div class="bank-card">
            <div class="bank-card-row">
                <div>
                    <div style="font-weight:700;font-size:14px;">${account.card_blocked ? 'Carte bloquée' : 'Bloquer la carte'}</div>
                    <div style="font-size:12px;color:var(--bank-text-dim);margin-top:2px;">${account.card_blocked ? 'Aucun paiement ni retrait accepté. Débloquez-la si vous l\'avez retrouvée.' : 'Carte perdue ou volée : bloque immédiatement tous les paiements.'}</div>
                </div>
                <button class="bank-btn ${account.card_blocked ? 'bank-btn-secondary' : 'bank-btn-danger'} bank-btn-sm" onclick="callH('${H(() => toggleBlockCard(account))}')">${account.card_blocked ? 'Débloquer' : 'Bloquer'}</button>
            </div>
            <div class="bank-card-row" style="margin-top:10px;">
                <div>
                    <div style="font-weight:700;font-size:14px;">Commander une nouvelle carte</div>
                    <div style="font-size:12px;color:var(--bank-text-dim);margin-top:2px;">Nouveau numéro et nouveau code PIN. L'ancienne carte devient définitivement invalide.</div>
                </div>
                <button class="bank-btn bank-btn-secondary bank-btn-sm" onclick="callH('${H(() => replaceCard(account))}')">Remplacer</button>
            </div>
        </div>
        <div class="bank-section-title">Code PIN</div>
        <div class="bank-card bank-card-row">
            <div style="font-size:22px;font-weight:800;letter-spacing:4px;font-variant-numeric:tabular-nums;" id="bankCardPinValue">••••</div>
            <button class="bank-btn bank-btn-secondary bank-btn-sm" id="bankCardPinBtn" onclick="callH('${H(() => revealCardPin(account.card_infos.card_pin))}')">Afficher le code PIN (5s)</button>
        </div>` : ''}

        <div class="bank-section-title">${hasCard ? 'Changer de palier' : 'Choisir un palier'}</div>
        <div class="bank-pick-grid" id="bankCardTierGrid">
            ${tierNames.map(t => tierRow(t, tiers[t] || { payment_ceiling: 0, withdrawal_ceiling: 0, transfer_ceiling: 0, overdraft_limit: 0, agios_rate_percent: 0, cost_amount: 0, cost_period: 'weekly' }, t === selectedTier, H(() => { selectedTier = t; rerender(); }))).join('')}
        </div>

        <button class="bank-btn bank-btn-primary bank-btn-block" onclick="callH('${H(() => {
            if (hasCard) { setCardTier(account.id, selectedTier); } else { createCard(account.id, selectedTier); }
        })}')">${hasCard ? 'Confirmer le changement de palier' : 'Créer la carte'}</button>
    `;
}

window.BankViews.card = function (root, ctx) {
    if (ctx && ctx.accountId) {
        const account = getAccountById(ctx.accountId);
        if (account) { renderCardForAccount(root, account); return; }
    }

    const accounts = BankState.accounts;
    root.innerHTML = `
        <div class="bank-section-title">Carte bancaire</div>
        ${accounts.length === 0 ? '<div class="bank-empty">Vous devez avoir un compte pour créer une carte.</div>' : accounts.map(a => `
            <div class="bank-account-item" onclick="callH('${H(() => showView('card', { accountId: a.id }))}')">
                <div class="bank-account-main">
                    <div class="bank-account-id">Compte n°${a.id}</div>
                    <div class="bank-account-iban">${a.card_infos ? 'Carte ' + esc(a.card_infos.card_type) : 'Aucune carte'}</div>
                </div>
                ${a.card_blocked ? '<span class="bank-badge bank-badge-red" style="margin-right:6px;">Bloquée</span>' : ''}<span class="bank-badge ${tierBadgeClass(a.card_tier)}">${tierLabel(a.card_tier)}</span>
            </div>
        `).join('')}
    `;
};
