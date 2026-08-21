async function atmDeposit(id, amount) {
    if (!amount || amount <= 0) { toast('Montant invalide.', 'error'); return; }
    await fetchNui('bank:atmDeposit', { id, amount });
    toast('Dépôt envoyé.');
}

async function atmWithdraw(id, amount) {
    if (!amount || amount <= 0) { toast('Montant invalide.', 'error'); return; }
    await fetchNui('bank:atmWithdraw', { id, amount });
    toast('Retrait envoyé.');
}

window.BankViews.atm = function (root) {
    const account = BankState.accounts[0];
    if (!account) {
        root.innerHTML = '<div class="bank-empty">Compte introuvable.</div>';
        return;
    }

    const cfg = (BankState.adminCardTiers && BankState.adminCardTiers[account.card_tier]) || null;

    root.innerHTML = `
        <div class="bank-hero">
            <div>
                <div class="bank-hero-label">Compte n°${account.id}</div>
                <div class="bank-hero-amount">${fmtMoney(account.amountMoney)}</div>
                <div class="bank-hero-iban">IBAN ${esc(account.iban)}</div>
            </div>
        </div>

        ${cfg ? `<div style="font-size:11.5px;color:var(--bank-text-dim);margin-bottom:18px;">Il reste ${fmtMoney(Math.max(0, (cfg.withdrawal_ceiling || 0) - (Number(account.withdrawal_spent) || 0)))} de plafond retrait sur la période en cours (sur ${fmtMoney(cfg.withdrawal_ceiling)}).</div>` : ''}

        <div class="bank-section-title">Déposer des espèces</div>
        <div class="bank-card">
            <div class="bank-form-row">
                <input type="number" min="0" class="bank-input" id="bankAtmDepositAmount" placeholder="Montant">
                <button class="bank-btn bank-btn-primary" onclick="callH('${H(() => atmDeposit(account.id, Number(el('bankAtmDepositAmount').value) || 0))}')">Déposer</button>
            </div>
        </div>

        <div class="bank-section-title">Retirer des espèces</div>
        <div class="bank-card">
            <div class="bank-form-row">
                <input type="number" min="0" class="bank-input" id="bankAtmWithdrawAmount" placeholder="Montant">
                <button class="bank-btn bank-btn-secondary" onclick="callH('${H(() => atmWithdraw(account.id, Number(el('bankAtmWithdrawAmount').value) || 0))}')">Retirer</button>
            </div>
        </div>
    `;
};
