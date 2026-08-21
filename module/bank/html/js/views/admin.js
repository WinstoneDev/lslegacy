async function saveRate(livretType) {
    const rate = {
        rate_percent: Number(el('rate_' + livretType + '_pct').value) || 0,
        deposit_cap: el('rate_' + livretType + '_cap').value === '' ? null : Number(el('rate_' + livretType + '_cap').value),
    };
    if (livretType === 'compte_terme') {
        rate.early_withdrawal_penalty_percent = Number(el('rate_' + livretType + '_penalty').value) || 0;
        rate.min_term_days = Number(el('rate_' + livretType + '_days').value) || 7;
    }
    await fetchNui('bank:setAdminRate', { livretType, rate });
    toast('Taux ' + LIVRET_LABELS[livretType] + ' mis à jour.');
}

async function saveCardTier(tier) {
    const config = {
        cost_amount: Number(el('tier_' + tier + '_cost').value) || 0,
        cost_period: el('tier_' + tier + '_period').value,
        payment_ceiling: Number(el('tier_' + tier + '_payment').value) || 0,
        withdrawal_ceiling: Number(el('tier_' + tier + '_withdrawal').value) || 0,
        transfer_ceiling: Number(el('tier_' + tier + '_transfer').value) || 0,
        overdraft_limit: Number(el('tier_' + tier + '_overdraft').value) || 0,
        agios_rate_percent: Number(el('tier_' + tier + '_agios').value) || 0,
    };
    await fetchNui('bank:setAdminCardTier', { tier, config });
    toast('Palier ' + tierLabel(tier) + ' mis à jour.');
}

function rateCard(type, cfg) {
    cfg = cfg || { rate_percent: 0, deposit_cap: null, early_withdrawal_penalty_percent: 0, min_term_days: 7 };
    return `
        <div class="bank-card">
            <div style="font-weight:700;font-size:14px;margin-bottom:12px;">${LIVRET_LABELS[type]}</div>
            <div class="bank-form-row">
                <div class="bank-field">
                    <label>Taux journalier (%)</label>
                    <input type="number" step="0.1" class="bank-input" id="rate_${type}_pct" value="${cfg.rate_percent}">
                </div>
                <div class="bank-field">
                    <label>Plafond de dépôt (vide = illimité)</label>
                    <input type="number" class="bank-input" id="rate_${type}_cap" value="${cfg.deposit_cap == null ? '' : cfg.deposit_cap}">
                </div>
            </div>
            ${type === 'compte_terme' ? `
            <div class="bank-form-row">
                <div class="bank-field">
                    <label>Pénalité retrait anticipé (%)</label>
                    <input type="number" step="0.1" class="bank-input" id="rate_${type}_penalty" value="${cfg.early_withdrawal_penalty_percent || 0}">
                </div>
                <div class="bank-field">
                    <label>Durée de blocage (jours)</label>
                    <input type="number" class="bank-input" id="rate_${type}_days" value="${cfg.min_term_days || 7}">
                </div>
            </div>` : ''}
            <button class="bank-btn bank-btn-primary bank-btn-sm" onclick="callH('${H(() => saveRate(type))}')">Enregistrer</button>
        </div>
    `;
}

function tierCard(tier, cfg) {
    cfg = cfg || { cost_amount: 0, cost_period: 'weekly', payment_ceiling: 0, withdrawal_ceiling: 0, transfer_ceiling: 0, overdraft_limit: 0, agios_rate_percent: 0 };
    return `
        <div class="bank-card">
            <div style="font-weight:700;font-size:14px;margin-bottom:12px;">${tierLabel(tier)}</div>
            <div class="bank-form-row">
                <div class="bank-field">
                    <label>Coût</label>
                    <input type="number" class="bank-input" id="tier_${tier}_cost" value="${cfg.cost_amount}">
                </div>
                <div class="bank-field">
                    <label>Périodicité</label>
                    <select class="bank-select" id="tier_${tier}_period">
                        <option value="weekly" ${cfg.cost_period === 'weekly' ? 'selected' : ''}>Hebdomadaire</option>
                        <option value="monthly" ${cfg.cost_period === 'monthly' ? 'selected' : ''}>Mensuelle</option>
                    </select>
                </div>
            </div>
            <div class="bank-form-row">
                <div class="bank-field">
                    <label>Plafond paiement</label>
                    <input type="number" class="bank-input" id="tier_${tier}_payment" value="${cfg.payment_ceiling}">
                </div>
                <div class="bank-field">
                    <label>Plafond retrait</label>
                    <input type="number" class="bank-input" id="tier_${tier}_withdrawal" value="${cfg.withdrawal_ceiling}">
                </div>
            </div>
            <div class="bank-form-row">
                <div class="bank-field">
                    <label>Plafond virement</label>
                    <input type="number" class="bank-input" id="tier_${tier}_transfer" value="${cfg.transfer_ceiling}">
                </div>
                <div class="bank-field">
                    <label>Découvert autorisé</label>
                    <input type="number" class="bank-input" id="tier_${tier}_overdraft" value="${cfg.overdraft_limit}">
                </div>
            </div>
            <div class="bank-field">
                <label>Agios (% / vérification sur le découvert)</label>
                <input type="number" step="0.1" class="bank-input" id="tier_${tier}_agios" value="${cfg.agios_rate_percent}">
            </div>
            <button class="bank-btn bank-btn-primary bank-btn-sm" onclick="callH('${H(() => saveCardTier(tier))}')">Enregistrer</button>
        </div>
    `;
}

window.BankViews.admin = function (root) {
    if (!BankState.isAdmin) {
        root.innerHTML = '<div class="bank-empty">Accès réservé au personnel de la banque.</div>';
        return;
    }

    const rates = BankState.adminRates || {};
    const tiers = BankState.adminCardTiers || {};

    root.innerHTML = `
        <div class="bank-section-title">Taux des livrets</div>
        <div class="bank-admin-grid">
            ${rateCard('livret_a', rates.livret_a)}
            ${rateCard('ldds', rates.ldds)}
            ${rateCard('compte_terme', rates.compte_terme)}
        </div>

        <div class="bank-section-title">Paliers de carte</div>
        <div class="bank-admin-grid">
            ${tierCard('standard', tiers.standard)}
            ${tierCard('premier', tiers.premier)}
            ${tierCard('platinum', tiers.platinum)}
        </div>
    `;
};
