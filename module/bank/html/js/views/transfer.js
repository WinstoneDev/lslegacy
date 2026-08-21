async function submitTransfer(fromAccountId, toIban, amount, message) {
    if (!toIban || !amount || amount <= 0) {
        toast('Veuillez remplir un IBAN et un montant valides.', 'error');
        return;
    }
    await fetchNui('bank:makeTransfer', { fromAccountId, toIban, amount, message });
    toast('Virement envoyé.');
    el('bankTransferIban').value = '';
    el('bankTransferAmount').value = '';
    el('bankTransferMessage').value = '';
}

window.BankViews.transfer = function (root) {
    const accounts = BankState.accounts;

    if (accounts.length === 0) {
        root.innerHTML = '<div class="bank-empty">Vous devez avoir un compte pour effectuer un virement.</div>';
        return;
    }

    const renderCeiling = (accountId) => {
        const account = getAccountById(accountId);
        const cfg = (BankState.adminCardTiers && account) ? BankState.adminCardTiers[account.card_tier] : null;
        if (!cfg) return '';
        const remaining = Math.max(0, (cfg.transfer_ceiling || 0) - (Number(account.transfer_spent) || 0));
        return `Il vous reste ${fmtMoney(remaining)} de plafond virement sur la période en cours (sur ${fmtMoney(cfg.transfer_ceiling)}) · Découvert autorisé : ${fmtMoney(cfg.overdraft_limit)}`;
    };

    root.innerHTML = `
        <div class="bank-section-title">Virement par IBAN</div>
        <div class="bank-card">
            <div class="bank-field">
                <label>Compte à débiter</label>
                <select class="bank-select" id="bankTransferFrom">
                    ${accounts.map(a => `<option value="${a.id}">Compte n°${a.id} — ${fmtMoney(a.amountMoney)}</option>`).join('')}
                </select>
                <div id="bankTransferCeilingHint" style="font-size:11.5px;color:var(--bank-text-dim);margin-top:8px;">${renderCeiling(accounts[0].id)}</div>
            </div>
            <div class="bank-field">
                <label>IBAN du destinataire</label>
                <input type="text" class="bank-input" id="bankTransferIban" placeholder="LSL...">
            </div>
            <div class="bank-field">
                <label>Montant</label>
                <input type="number" min="0" class="bank-input" id="bankTransferAmount" placeholder="Montant en $">
            </div>
            <div class="bank-field">
                <label>Motif (optionnel)</label>
                <input type="text" class="bank-input" id="bankTransferMessage" placeholder="Motif du virement" maxlength="80">
            </div>
            <button class="bank-btn bank-btn-primary bank-btn-block" onclick="callH('${H(() => submitTransfer(
                Number(el('bankTransferFrom').value),
                el('bankTransferIban').value.trim(),
                Number(el('bankTransferAmount').value) || 0,
                el('bankTransferMessage').value.trim()
            ))}')">Envoyer le virement</button>
        </div>
    `;

    el('bankTransferFrom').addEventListener('change', (e) => {
        el('bankTransferCeilingHint').textContent = renderCeiling(Number(e.target.value));
    });
};
