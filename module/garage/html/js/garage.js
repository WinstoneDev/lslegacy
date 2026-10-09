(function () {
    const hud = document.getElementById('hud');
    const showroom = document.getElementById('showroom');
    const cards = new Map(); // id -> element

    const esc = (s) => String(s == null ? '' : s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
    const barClass = (v) => (v < 30 ? 'bad' : v < 60 ? 'warn' : '');

    function row(label, val, cls, suffix) {
        return `<div class="row"><span class="lbl">${label}</span><div class="bar ${cls || ''}"><i style="width:${Math.max(0, Math.min(100, val))}%"></i></div><span class="val">${val}${suffix || '%'}</span></div>`;
    }

    function pips(cur, max, on) {
        max = Math.max(max, 1);
        let h = '';
        for (let i = 1; i <= max; i++) h += `<i class="${i <= cur ? 'on' : ''}"></i>`;
        return h;
    }

    function cardHtml(s) {
        const mods = (s.mods || []).slice(0, 4).map((m) =>
            `<div class="mod"><div class="pips">${pips(m.cur, m.max)}</div>${esc(m.label)}</div>`).join('')
            + `<div class="mod turbo"><div class="pips">${pips(s.turbo ? 1 : 0, 1)}</div>Turbo</div>`;
        return `
            <div class="top"><span class="name">${esc(s.name)}</span><span class="plate">${esc(s.plate)}</span></div>
            <div class="slot">Place ${s.slot || '—'}</div>
            ${row('Moteur', s.engine, barClass(s.engine))}
            ${row('Carrosserie', s.body, barClass(s.body))}
            ${row('Carburant', s.fuel, 'fuel')}
            <div class="mods">${mods}</div>`;
    }

    function renderHud(items) {
        const seen = new Set();
        for (const s of items) {
            seen.add(s.id);
            let el = cards.get(s.id);
            if (!el) {
                el = document.createElement('div');
                el.className = 'card';
                hud.appendChild(el);
                cards.set(s.id, el);
                el.dataset.sig = '';
            }
            const sig = `${s.plate}|${s.engine}|${s.body}|${s.fuel}|${s.slot}|${s.turbo}|${(s.mods || []).map((m) => m.cur).join(',')}`;
            if (el.dataset.sig !== sig) { el.innerHTML = cardHtml(s); el.dataset.sig = sig; }
            // zoom (et non transform: scale) : le texte reste rastérisé net dans CEF
            const z = s.scale || 1;
            el.style.zoom = z;
            el.style.left = (s.x * 100 / z) + 'vw';
            el.style.top = (s.y * 100 / z) + 'vh';
        }
        for (const [id, el] of cards) {
            if (!seen.has(id)) { el.remove(); cards.delete(id); }
        }
    }

    function renderShowroom(s) {
        document.getElementById('sr-name').textContent = s.name || '—';
        document.getElementById('sr-plate').textContent = s.plate || '—';
        document.getElementById('sr-state').innerHTML =
            row('Moteur', s.engine, barClass(s.engine)) +
            row('Carrosserie', s.body, barClass(s.body)) +
            row('Carburant', s.fuel, 'fuel') +
            row('Saleté', s.dirt, 'warn');
        document.getElementById('sr-mods').innerHTML = (s.mods || []).map((m) =>
            `<div class="sr-mod"><span>${esc(m.label)}</span><div class="pips">${pips(m.cur, m.max)}</div><span class="val">${m.cur}/${m.max}</span></div>`).join('')
            + `<div class="sr-mod turbo"><span>Turbo</span><div class="pips">${pips(s.turbo ? 1 : 0, 1)}</div><span class="val">${s.turbo ? 'Oui' : 'Non'}</span></div>`;
    }

    window.addEventListener('message', (e) => {
        const d = e.data || {};
        if (d.action === 'garage:hud') renderHud(d.items || []);
        else if (d.action === 'garage:showroom') {
            if (d.show) { showroom.classList.remove('hidden'); if (d.stats) renderShowroom(d.stats); }
            else showroom.classList.add('hidden');
        }
    });
})();
