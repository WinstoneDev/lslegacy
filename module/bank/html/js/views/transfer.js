async function addBeneficiary() {
    const name = el('bankBenefName').value.trim();
    const iban = el('bankBenefIban').value.trim();
    if (!name || !iban) { toast('Nom et IBAN requis.', 'error'); return; }
    await fetchNui('bank:addBeneficiary', { name, iban });
    el('bankBenefName').value = '';
    el('bankBenefIban').value = '';
}

async function removeBeneficiary(id) {
    await fetchNui('bank:removeBeneficiary', { id });
    toast('Bénéficiaire retiré.');
}

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
        const account = getAccountById(accountId) || (BankState.societyAccount && Number(BankState.societyAccount.id) === Number(accountId) ? BankState.societyAccount : null);
        if (account && account.society) return 'Compte entreprise : aucun plafond ni découvert.';
        const cfg = (BankState.adminCardTiers && account) ? BankState.adminCardTiers[account.card_tier] : null;
        if (!cfg) return '';
        const remaining = Math.max(0, (cfg.transfer_ceiling || 0) - (Number(account.transfer_spent) || 0));
        return `Il vous reste ${fmtMoney(remaining)} de plafond virement sur la période en cours (sur ${fmtMoney(cfg.transfer_ceiling)}) · Découvert autorisé : ${fmtMoney(cfg.overdraft_limit)}`;
    };

    const benefs = BankState.beneficiaries || [];
    const ctx = BankState.context || {};
    const soc = BankState.societyAccount;
    const fromOptions = accounts.map(a => `<option value="${a.id}">Compte n°${a.id} — ${fmtMoney(a.amountMoney)}</option>`);
    if (soc && ctx.isBoss) fromOptions.push(`<option value="${soc.id}">Compte entreprise ${esc(ctx.jobLabel || ctx.job)} — ${fmtMoney(soc.amountMoney)}</option>`);

    root.innerHTML = `
        <div class="bank-section-title">Bénéficiaires enregistrés</div>
        <div class="bank-card">
            ${benefs.length === 0 ? '<div class="bank-empty">Aucun bénéficiaire. Ajoutez-en un ci-dessous pour retrouver son IBAN en un clic.</div>' : benefs.map(b => `
                <div class="bank-card-row" style="margin-bottom:8px;">
                    <div style="cursor:pointer;" onclick="callH('${H(() => { el('bankTransferIban').value = b.iban; toast('IBAN de ' + b.name + ' sélectionné.'); })}')">
                        <div style="font-weight:700;font-size:14px;">${esc(b.name)}</div>
                        <div style="font-size:12px;color:var(--bank-text-dim);">${ibanHtml(b.iban)}</div>
                    </div>
                    <button class="bank-btn bank-btn-danger bank-btn-sm" onclick="callH('${H(() => removeBeneficiary(b.id))}')">Retirer</button>
                </div>`).join('')}
            <div style="display:flex;gap:8px;margin-top:10px;">
                <input type="text" class="bank-input" id="bankBenefName" placeholder="Nom" maxlength="60" style="flex:1;">
                <input type="text" class="bank-input" id="bankBenefIban" placeholder="IBAN LSL..." style="flex:1.4;">
                <button class="bank-btn bank-btn-secondary bank-btn-sm" onclick="callH('${H(addBeneficiary)}')">Ajouter</button>
            </div>
        </div>

        <div class="bank-section-title">Virement par IBAN</div>
        <div class="bank-card">
            <div class="bank-field">
                <label>Compte à débiter</label>
                <select class="bank-select" id="bankTransferFrom">
                    ${fromOptions.join('')}
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
