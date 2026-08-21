window.BankViews.dashboard = function (root) {
    const courant = getCourantAccount();

    let heroHtml = '';
    if (courant) {
        const negative = Number(courant.amountMoney) < 0;
        heroHtml = `
            <div class="bank-hero">
                <div>
                    <div class="bank-hero-label">Compte courant</div>
                    <div class="bank-hero-amount" style="${negative ? 'color:var(--bank-red)' : ''}">${fmtMoney(courant.amountMoney)}</div>
                    <div class="bank-hero-iban">IBAN ${esc(courant.iban)}</div>
                </div>
                <span class="bank-hero-badge">${esc(tierLabel(courant.card_tier))}</span>
            </div>
        `;
    } else {
        heroHtml = `
            <div class="bank-hero">
                <div>
                    <div class="bank-hero-label">Aucun compte courant</div>
                    <div class="bank-hero-iban" style="margin-top:8px;">Créez un compte pour commencer.</div>
                </div>
            </div>
        `;
    }

    const tiles = [
        { icon: '&#128179;', title: 'Comptes', desc: 'Vos comptes, création, statut courant', view: 'accounts' },
        { icon: '&#128200;', title: 'Livrets', desc: "Livret A, LDDS, Compte à terme", view: 'livrets' },
        { icon: '&#8646;', title: 'Virement', desc: 'Envoyer de l\'argent par IBAN', view: 'transfer' },
        { icon: '&#128308;', title: 'Carte bancaire', desc: 'Créer ou changer de palier', view: 'card' },
    ];
    if (BankState.isAdmin) {
        tiles.push({ icon: '&#9881;', title: 'Administration', desc: 'Taux et plafonds (staff)', view: 'admin' });
    }

    root.innerHTML = `
        ${heroHtml}
        <div class="bank-section-title">Services</div>
        <div class="bank-tiles">
            ${tiles.map(t => `
                <button class="bank-tile" onclick="callH('${H(() => showView(t.view))}')">
                    <div class="bank-tile-icon">${t.icon}</div>
                    <div class="bank-tile-title">${esc(t.title)}</div>
                    <div class="bank-tile-desc">${esc(t.desc)}</div>
                </button>
            `).join('')}
        </div>
    `;
};
