const LIVRET_LABELS = {
    livret_a: 'Livret A',
    ldds: 'LDDS',
    compte_terme: 'Compte à terme',
};
const LIVRET_DESCRIPTIONS = {
    livret_a: 'Épargne libre, retrait possible à tout moment.',
    ldds: 'Épargne libre à taux réglementé, retrait à tout moment.',
    compte_terme: "Dépôt bloqué jusqu'à échéance, retrait anticipé pénalisé.",
};

function getRateConfig(type) {
    return (BankState.adminRates && BankState.adminRates[type]) || null;
}

async function openLivret(linkedAccountId, livretType, initialDeposit) {
    await fetchNui('bank:openLivret', { linkedAccountId, livretType, initialDeposit });
    toast('Demande d\'ouverture envoyée.');
    showView('livrets');
}

async function depositLivret(livret, amount) {
    await fetchNui('bank:depositLivret', { livretId: livret.id, amount });
    toast('Dépôt envoyé.');
}

async function withdrawLivret(livret, amount) {
    await fetchNui('bank:withdrawLivret', { livretId: livret.id, amount });
    toast('Retrait envoyé.');
}

async function closeLivret(livret) {
    await fetchNui('bank:closeLivret', { livretId: livret.id });
    toast('Fermeture envoyée.');
    showView('livrets');
}

function renderOpenLivretForm(root) {
    const accounts = BankState.accounts;
    let selectedType = 'livret_a';

    const rerenderPickCards = () => {
        document.querySelectorAll('.bank-pick-card').forEach(c => {
            c.classList.toggle('selected', c.dataset.type === selectedType);
        });
    };

    root.innerHTML = `
        <a href="#" onclick="callH('${H(() => showView('livrets'))}');return false;" style="font-size:12.5px;color:var(--bank-text-dim);font-weight:600;">&#8592; Livrets</a>
        <div class="bank-section-title">Choisir un type de livret</div>
        <div class="bank-pick-grid" id="bankLivretPickGrid">
            ${['livret_a', 'ldds', 'compte_terme'].map(type => {
                const cfg = getRateConfig(type);
                return `
                <div class="bank-pick-card ${type === selectedType ? 'selected' : ''}" data-type="${type}" onclick="callH('${H(() => { selectedType = type; rerenderPickCards(); })}')">
                    <div class="bank-pick-card-title">${LIVRET_LABELS[type]}</div>
                    <div class="bank-pick-card-desc">${LIVRET_DESCRIPTIONS[type]}</div>
                    <div class="bank-pick-card-rate">${cfg ? cfg.rate_percent : 0}% <span style="font-size:11px;font-weight:600;color:var(--bank-text-dim);">/ jour</span></div>
                    ${cfg && cfg.deposit_cap ? `<div style="font-size:11.5px;color:var(--bank-text-dim);margin-top:4px;">Plafond ${fmtMoney(cfg.deposit_cap)}</div>` : ''}
                    ${type === 'compte_terme' && cfg ? `<div style="font-size:11.5px;color:var(--bank-text-dim);margin-top:4px;">Blocage ${cfg.min_term_days || 7}j · pénalité ${cfg.early_withdrawal_penalty_percent || 0}%</div>` : ''}
                </div>
            `}).join('')}
        </div>

        <div class="bank-section-title">Compte à débiter</div>
        <div class="bank-field">
            <select class="bank-select" id="bankLivretAccountSelect">
                ${accounts.map(a => `<option value="${a.id}">Compte n°${a.id} — ${fmtMoney(a.amountMoney)}</option>`).join('')}
            </select>
        </div>

        <div class="bank-section-title">Dépôt initial</div>
        <div class="bank-field">
            <input type="number" min="0" class="bank-input" id="bankLivretInitialAmount" placeholder="Montant en $">
        </div>

        <button class="bank-btn bank-btn-primary bank-btn-block" onclick="callH('${H(() => {
            const accountId = Number(el('bankLivretAccountSelect').value);
            const amount = Number(el('bankLivretInitialAmount').value) || 0;
            openLivret(accountId, selectedType, amount);
        })}')">Ouvrir le livret</button>
    `;
}

function renderLivretDetail(root, livret) {
    const isTerme = livret.livret_type === 'compte_terme';
    const maturityTs = livret.maturity_date ? new Date(livret.maturity_date.replace(' ', 'T')).getTime() : null;
    const locked = isTerme && maturityTs && maturityTs > Date.now();
    const tx = (livret.transactions || []).slice().reverse();

    root.innerHTML = `
        <a href="#" onclick="callH('${H(() => showView('livrets'))}');return false;" style="font-size:12.5px;color:var(--bank-text-dim);font-weight:600;">&#8592; Livrets</a>

        <div class="bank-hero" style="margin-top:14px;">
            <div>
                <div class="bank-hero-label">${LIVRET_LABELS[livret.livret_type]}</div>
                <div class="bank-hero-amount">${fmtMoney(livret.amountMoney)}</div>
                ${isTerme ? `<div class="bank-hero-iban">${locked ? 'Bloqué jusqu\'au ' + fmtDate(livret.maturity_date) : 'Échéance atteinte, retrait libre'}</div>` : ''}
            </div>
            <span class="bank-hero-badge">${livret.interest_rate_snapshot}% / jour</span>
        </div>

        ${locked ? '<div class="bank-card" style="border-color:var(--bank-red);"><div style="font-size:12.5px;color:var(--bank-red);font-weight:600;">Un retrait avant échéance entraîne une pénalité.</div></div>' : ''}

        ${!isTerme ? `
        <div class="bank-section-title">Déposer</div>
        <div class="bank-card">
            <div class="bank-form-row">
                <input type="number" min="0" class="bank-input" id="bankLivretDepositAmount" placeholder="Montant">
                <button class="bank-btn bank-btn-primary" onclick="callH('${H(() => depositLivret(livret, Number(el('bankLivretDepositAmount').value) || 0))}')">Déposer</button>
            </div>
        </div>` : ''}

        <div class="bank-section-title">Retirer</div>
        <div class="bank-card">
            <div class="bank-form-row">
                <input type="number" min="0" max="${livret.amountMoney}" class="bank-input" id="bankLivretWithdrawAmount" placeholder="Montant">
                <button class="bank-btn bank-btn-secondary" onclick="callH('${H(() => withdrawLivret(livret, Number(el('bankLivretWithdrawAmount').value) || 0))}')">Retirer</button>
            </div>
        </div>

        <div class="bank-card">
            <div class="bank-card-row">
                <div>
                    <div style="font-weight:700;font-size:14px;">Fermer le livret</div>
                    <div style="font-size:12px;color:var(--bank-text-dim);margin-top:2px;">Solde reversé sur votre compte lié.</div>
                </div>
                <button class="bank-btn bank-btn-danger bank-btn-sm" onclick="callH('${H(() => closeLivret(livret))}')">Fermer</button>
            </div>
        </div>

        <div class="bank-section-title">Historique</div>
        <div class="bank-card">
            ${tx.length === 0 ? '<div class="bank-empty">Aucune opération pour le moment.</div>' : tx.map(t => `
                <div class="bank-tx">
                    <div>
                        <div class="bank-tx-msg">${esc(t.message)}</div>
                        <div class="bank-tx-date">${esc(t.type || '')} — ${esc(t.date)}</div>
                    </div>
                    <div class="bank-tx-amount ${t.type === 'Retrait' || t.type === 'Fermeture' ? 'negative' : 'positive'}">${t.type === 'Retrait' || t.type === 'Fermeture' ? '-' : '+'}${fmtMoney(t.amount)}</div>
                </div>
            `).join('')}
        </div>
    `;
}

window.BankViews.livrets = function (root, ctx) {
    if (ctx && ctx.open) { renderOpenLivretForm(root); return; }
    if (ctx && ctx.livretId) {
        const livret = BankState.livrets.find(l => Number(l.id) === Number(ctx.livretId));
        if (livret) { renderLivretDetail(root, livret); return; }
    }

    const active = BankState.livrets.filter(l => l.status === 'active');

    root.innerHTML = `
        <div class="bank-card-row" style="margin-bottom:16px;">
            <div class="bank-section-title" style="margin:0;">Vos livrets</div>
            <button class="bank-btn bank-btn-primary bank-btn-sm" onclick="callH('${H(() => showView('livrets', { open: true }))}')">+ Ouvrir un livret</button>
        </div>
        ${active.length === 0 ? '<div class="bank-empty">Vous n\'avez aucun livret ouvert.</div>' : active.map(l => `
            <div class="bank-account-item" onclick="callH('${H(() => showView('livrets', { livretId: l.id }))}')">
                <div class="bank-account-main">
                    <div class="bank-account-id">${LIVRET_LABELS[l.livret_type]}</div>
                    <div class="bank-account-iban">${l.livret_type === 'compte_terme' && l.maturity_date ? 'Échéance ' + fmtDate(l.maturity_date) : (l.interest_rate_snapshot + '% / jour')}</div>
                </div>
                <div class="bank-account-amount">${fmtMoney(l.amountMoney)}</div>
            </div>
        `).join('')}
    `;
};
