/* Vue « Entreprise » : compte du job (chef = gestion, agents = consultation). */
async function societyCreateAccount() {
    await fetchNui('bank:societyCreateAccount', {});
    toast('Ouverture du compte demandée.');
}
async function societyCreateCard() {
    await fetchNui('bank:societyCreateCard', {});
    toast('Carte entreprise demandée.');
}

window.BankViews.society = function (root) {
    const ctx = BankState.context || {};
    const soc = BankState.societyAccount;
    const label = ctx.jobLabel || ctx.job || 'Entreprise';

    if (!soc) {
        root.innerHTML = `
            <div class="bank-section-title">${esc(label)}</div>
            ${ctx.isBoss
                ? `<div class="bank-card">
                        <div style="font-weight:700;font-size:14px;">Aucun compte entreprise</div>
                        <div style="font-size:12px;color:var(--bank-text-dim);margin:6px 0 12px;">En tant que chef, vous pouvez ouvrir le compte de votre entreprise. Il recevra les factures encaissées et servira aux achats professionnels (véhicules, fournitures).</div>
                        <button class="bank-btn bank-btn-primary bank-btn-block" onclick="callH('${H(societyCreateAccount)}')">Ouvrir le compte entreprise</button>
                   </div>`
                : '<div class="bank-empty">Votre entreprise n\'a pas encore de compte. Seul le chef peut l\'ouvrir.</div>'}
        `;
        return;
    }

    const negative = Number(soc.amountMoney) < 0;
    const tx = (soc.transactions || []).slice().reverse().slice(0, 40);
    const hasCard = !!soc.card_infos;

    root.innerHTML = `
        <div class="bank-hero">
            <div>
                <div class="bank-hero-label">Compte entreprise — ${esc(label)}</div>
                <div class="bank-hero-amount" style="${negative ? 'color:var(--bank-red)' : ''}">${fmtMoney(soc.amountMoney)}</div>
                <div class="bank-hero-iban">IBAN ${ibanHtml(soc.iban)}</div>
            </div>
            <span class="bank-hero-badge">${ctx.isBoss ? 'Chef' : 'Membre'}</span>
        </div>

        ${ctx.isBoss ? `
        <div class="bank-section-title">Carte entreprise</div>
        <div class="bank-card">
            <div class="bank-card-row">
                <div>
                    <div style="font-weight:700;font-size:14px;">${hasCard ? 'Carte Business **** ' + String(soc.card_infos.card_number).slice(-4) : 'Aucune carte'}</div>
                    <div style="font-size:12px;color:var(--bank-text-dim);margin-top:2px;">${hasCard ? 'Remettez une copie à chaque agent habilité : seuls les membres de votre service peuvent l\'utiliser.' : 'Créez la carte pour permettre les achats professionnels.'}</div>
                </div>
                <button class="bank-btn bank-btn-primary bank-btn-sm" onclick="callH('${H(societyCreateCard)}')">${hasCard ? 'Nouvelle copie' : 'Créer la carte'}</button>
            </div>
            ${hasCard ? `
            <div class="bank-card-row" style="margin-top:10px;">
                <div>
                    <div style="font-weight:700;font-size:14px;">Code PIN</div>
                    <div style="font-size:12px;color:var(--bank-text-dim);margin-top:2px;">À communiquer aux agents qui reçoivent la carte.</div>
                </div>
                <div style="font-size:20px;font-weight:800;letter-spacing:4px;" id="bankCardPinValue">••••</div>
                <button class="bank-btn bank-btn-secondary bank-btn-sm" id="bankCardPinBtn" onclick="callH('${H(() => revealCardPin(soc.card_infos.card_pin))}')">Afficher le code PIN (5s)</button>
            </div>
            <div class="bank-card-row" style="margin-top:10px;">
                <div>
                    <div style="font-weight:700;font-size:14px;">${soc.card_blocked ? 'Carte bloquée' : 'Bloquer la carte'}</div>
                    <div style="font-size:12px;color:var(--bank-text-dim);margin-top:2px;">Bloque toutes les copies en circulation.</div>
                </div>
                <button class="bank-btn ${soc.card_blocked ? 'bank-btn-secondary' : 'bank-btn-danger'} bank-btn-sm" onclick="callH('${H(() => toggleBlockCard(soc))}')">${soc.card_blocked ? 'Débloquer' : 'Bloquer'}</button>
            </div>
            <div class="bank-card-row" style="margin-top:10px;">
                <div>
                    <div style="font-weight:700;font-size:14px;">Remplacer la carte</div>
                    <div style="font-size:12px;color:var(--bank-text-dim);margin-top:2px;">Nouveau numéro et PIN : toutes les copies actuelles deviennent invalides.</div>
                </div>
                <button class="bank-btn bank-btn-secondary bank-btn-sm" onclick="callH('${H(() => replaceCard(soc))}')">Remplacer</button>
            </div>` : ''}
        </div>
        <div class="bank-section-title">Virement sortant</div>
        <div class="bank-card">
            <div style="font-size:12.5px;color:var(--bank-text-dim);">Le compte entreprise est proposé comme compte à débiter dans l'onglet Virement.</div>
            <button class="bank-btn bank-btn-secondary bank-btn-sm" style="margin-top:10px;" onclick="callH('${H(() => showView('transfer'))}')">Aller aux virements</button>
        </div>` : ''}

        <div class="bank-section-title">Historique</div>
        <div class="bank-card">
            ${tx.length === 0 ? '<div class="bank-empty">Aucune opération.</div>' : tx.map(t => `
                <div class="bank-tx">
                    <div>
                        <div class="bank-tx-msg">${esc(t.message)}</div>
                        <div class="bank-tx-date">${esc(t.type || '')} — ${esc(t.date)}</div>
                    </div>
                    <div class="bank-tx-amount ${amountSign(t) >= 0 ? 'positive' : 'negative'}">${amountSign(t) >= 0 ? '+' : ''}${fmtMoney(amountSign(t))}</div>
                </div>`).join('')}
        </div>
    `;
};
