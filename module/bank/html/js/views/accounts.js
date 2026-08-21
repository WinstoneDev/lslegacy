function renderAccountDetail(root, account) {
    const negative = Number(account.amountMoney) < 0;
    const tx = (account.transactions || []).slice().reverse();
    const tierCfg = (BankState.adminCardTiers && BankState.adminCardTiers[account.card_tier]) || null;

    root.innerHTML = `
        <a href="#" class="bank-subback" onclick="callH('${H(() => showView('accounts'))}');return false;" style="font-size:12.5px;color:var(--bank-text-dim);font-weight:600;">&#8592; Tous les comptes</a>

        <div class="bank-hero" style="margin-top:14px;">
            <div>
                <div class="bank-hero-label">Compte n°${account.id}</div>
                <div class="bank-hero-amount" style="${negative ? 'color:var(--bank-red)' : ''}">${fmtMoney(account.amountMoney)}</div>
                <div class="bank-hero-iban">IBAN ${esc(account.iban)}</div>
            </div>
            <span class="bank-hero-badge">${esc(tierLabel(account.card_tier))}</span>
        </div>

        ${tierCfg ? `
        <div class="bank-section-title">Plafonds</div>
        <div class="bank-card">
            ${ceilingLine('Paiement', account.payment_spent, tierCfg.payment_ceiling)}
            ${ceilingLine('Retrait', account.withdrawal_spent, tierCfg.withdrawal_ceiling)}
            ${ceilingLine('Virement', account.transfer_spent, tierCfg.transfer_ceiling)}
        </div>` : ''}

        <div class="bank-section-title">Actions</div>
        <div class="bank-card">
            <div class="bank-card-row">
                <div>
                    <div style="font-weight:700;font-size:14px;">Compte courant</div>
                    <div style="font-size:12px;color:var(--bank-text-dim);margin-top:2px;">${account.courant ? 'Ce compte est votre compte courant.' : 'Définir ce compte comme compte courant.'}</div>
                </div>
                <button class="bank-btn bank-btn-secondary bank-btn-sm" ${account.courant ? 'disabled' : ''} onclick="callH('${H(() => setCourant(account))}')">${account.courant ? 'Actif' : 'Définir'}</button>
            </div>
        </div>
        <div class="bank-card">
            <div class="bank-card-row">
                <div>
                    <div style="font-weight:700;font-size:14px;">Supprimer le compte</div>
                    <div style="font-size:12px;color:var(--bank-text-dim);margin-top:2px;">Action définitive.</div>
                </div>
                <button class="bank-btn bank-btn-danger bank-btn-sm" onclick="callH('${H(() => deleteAccount(account))}')">Supprimer</button>
            </div>
        </div>

        <div class="bank-section-title">Historique</div>
        <div class="bank-card">
            ${tx.length === 0 ? '<div class="bank-empty">Aucune transaction pour le moment.</div>' : tx.map(t => `
                <div class="bank-tx">
                    <div>
                        <div class="bank-tx-msg">${esc(t.message)}</div>
                        <div class="bank-tx-date">${esc(t.type || '')} — ${esc(t.date)}</div>
                    </div>
                    <div class="bank-tx-amount ${amountSign(t) >= 0 ? 'positive' : 'negative'}">${amountSign(t) >= 0 ? '+' : ''}${fmtMoney(amountSign(t))}</div>
                </div>
            `).join('')}
        </div>
    `;
}

function amountSign(t) {
    const outTypes = ['Retrait', 'Achat', 'Virement sortant', 'Livret', 'Agios', 'Cotisation'];
    const n = Number(t.amount) || 0;
    return outTypes.indexOf(t.type) !== -1 ? -Math.abs(n) : Math.abs(n);
}

async function setCourant(account) {
    await fetchNui('bank:setCourant', { id: account.id, state: true });
    toast('Compte courant mis à jour.');
}

async function deleteAccount(account) {
    await fetchNui('bank:deleteAccount', { id: account.id });
    toast('Compte supprimé.');
    showView('accounts');
}

async function createAccount() {
    await fetchNui('bank:createAccount', {});
    toast('Compte créé.');
}

window.BankViews.accounts = function (root, ctx) {
    if (ctx && ctx.accountId) {
        const account = getAccountById(ctx.accountId);
        if (account) { renderAccountDetail(root, account); return; }
    }

    const accounts = BankState.accounts;
    root.innerHTML = `
        <div class="bank-card-row" style="margin-bottom:16px;">
            <div class="bank-section-title" style="margin:0;">Vos comptes</div>
            <button class="bank-btn bank-btn-primary bank-btn-sm" onclick="callH('${H(createAccount)}')">+ Créer un compte</button>
        </div>
        <div id="bankAccountsList">
            ${accounts.length === 0 ? '<div class="bank-empty">Vous n\'avez aucun compte bancaire.</div>' : accounts.map(a => `
                <div class="bank-account-item" onclick="callH('${H(() => showView('accounts', { accountId: a.id }))}')">
                    <div class="bank-account-main">
                        <div class="bank-account-id">Compte n°${a.id} ${a.courant ? '<span class="bank-badge bank-badge-green" style="margin-left:8px;">Courant</span>' : ''}</div>
                        <div class="bank-account-iban">${esc(a.iban)}</div>
                    </div>
                    <div class="bank-account-amount ${Number(a.amountMoney) < 0 ? 'negative' : ''}">${fmtMoney(a.amountMoney)}</div>
                </div>
            `).join('')}
        </div>
    `;
};
