/* Onglet MDT « Garage » : journal d'accès + véhicules garés des garages du job.
   Chargé après mdt.js, s'enregistre via window.MDT_RENDERERS (helpers globaux : esc, setContent, emptyState, fetchNui, fmtDate). */
window.MDT_RENDERERS = window.MDT_RENDERERS || {};

window.MDT_RENDERERS.garage = async function renderGarage() {
    setContent(`
        <div class="mdt-page-title">Garage</div>
        <div class="mdt-page-sub">Véhicules rangés et journal des entrées/sorties des garages du service.</div>
        <div class="mdt-card"><div class="mdt-card-title">Véhicules au garage</div><div id="gar-veh">${emptyState('⏳', 'Chargement…')}</div></div>
        <div class="mdt-card"><div class="mdt-card-title">Journal d'accès</div><div id="gar-logs"></div></div>
    `);
    const d = await fetchNui('mdtgarage:getLogs', {});
    if (!d) { setContent(emptyState('🚫', 'Journal indisponible.')); return; }
    const vehicles = Array.isArray(d.vehicles) ? d.vehicles : [];
    const logs = Array.isArray(d.logs) ? d.logs : [];
    const fmt = (ts) => (typeof fmtDate === 'function' ? fmtDate(ts) : esc(ts));

    const vEl = document.getElementById('gar-veh');
    if (!vEl) return;
    vEl.innerHTML = vehicles.length ? `
        <table class="mdt-table"><thead><tr><th>Garage</th><th>Place</th><th>Plaque</th><th>Modèle</th></tr></thead><tbody>
        ${vehicles.map((v) => `<tr><td>${esc(v.garage || '—')}</td><td>${esc(v.slot || '—')}</td><td><b>${esc(v.plate)}</b></td><td>${esc(v.model)}</td></tr>`).join('')}
        </tbody></table>` : emptyState('🅿️', 'Aucun véhicule rangé.');

    const lEl = document.getElementById('gar-logs');
    lEl.innerHTML = logs.length ? `
        <table class="mdt-table"><thead><tr><th>Date</th><th>Garage</th><th>Action</th><th>Plaque</th><th>Agent</th></tr></thead><tbody>
        ${logs.map((l) => `<tr><td>${fmt(l.created_at)}</td><td>${esc(l.garage || l.garage_id)}</td>
            <td><span class="mdt-badge ${l.action === 'store' ? 'mdt-badge-green' : 'mdt-badge-red'}">${l.action === 'store' ? 'Rangé' : 'Sorti'}</span></td>
            <td><b>${esc(l.plate)}</b></td><td>${esc(l.name || '—')}</td></tr>`).join('')}
        </tbody></table>` : emptyState('📭', 'Aucune entrée.');
};
