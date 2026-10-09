/* Onglet MDT « Permissions » (atelier uniquement : Red's Tunershop, Benny's) :
   grille grade × permission éditable, en remplacement des grants figés dans
   module/atelier/config/companies.lua. Helpers globaux : esc, setContent,
   emptyState, fetchNui. */
window.MDT_RENDERERS = window.MDT_RENDERERS || {};

(function () {
    const PERM_LABELS = {
        diagnostic: 'Diagnostiquer',
        repair_mechanical: 'Réparation mécanique',
        repair_bodywork: 'Carrosserie',
        maintenance: 'Entretien',
        performance: 'Performance',
        customization: 'Personnalisation',
        billing: 'Facturation',
        manage_stock: 'Gérer le stock',
        manage_employees: 'Gérer les employés',
        manage_company: 'Administration (accorde tout)',
    };

    function renderTable(grid) {
        const grades = grid.grades || [];
        const perms = grid.permissions || [];
        return `
            <div class="mdt-page-title">Permissions par grade</div>
            <div class="mdt-page-sub">Cumulatif : un grade hérite des permissions cochées sur les grades inférieurs.</div>
            <div style="overflow-x:auto;">
                <table class="mdt-table">
                    <thead><tr><th>Permission</th>${grades.map((g) => `<th>${esc(g.label)}</th>`).join('')}</tr></thead>
                    <tbody>
                        ${perms.map((p) => `<tr>
                            <td>${esc(PERM_LABELS[p] || p)}</td>
                            ${grades.map((g) => `<td style="text-align:center;">
                                <input type="checkbox" data-grade="${g.grade}" data-perm="${esc(p)}" ${g.grants[p] ? 'checked' : ''}>
                            </td>`).join('')}
                        </tr>`).join('')}
                    </tbody>
                </table>
            </div>
        `;
    }

    window.MDT_RENDERERS.grade_permissions = async function renderGradePermissions() {
        setContent(`<div class="mdt-page-title">Permissions par grade</div>${emptyState('⏳', 'Chargement…')}`);
        const grid = await fetchNui('mdtgrades:get', {});
        if (state.currentTab !== 'grade_permissions') return;
        if (!grid || !grid.grades) {
            setContent(emptyState('🎖️', 'Impossible de charger les permissions.'));
            return;
        }
        setContent(renderTable(grid));
        document.querySelectorAll('[data-grade][data-perm]').forEach((cb) => {
            cb.addEventListener('change', async () => {
                cb.disabled = true;
                await fetchNui('mdtgrades:set', { grade: Number(cb.dataset.grade), permission: cb.dataset.perm, enabled: cb.checked });
                cb.disabled = false;
            });
        });
    };
})();
