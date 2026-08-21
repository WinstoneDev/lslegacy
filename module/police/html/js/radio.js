'use strict';

let currentChannelId = null;
let isActive         = false;

const panel          = document.getElementById('radio-panel');
const statusDot      = document.getElementById('status-dot');
const statusText     = document.getElementById('status-text');
const currentChBadge = document.getElementById('current-channel');
const channelsList   = document.getElementById('channels-list');
const btnDisable     = document.getElementById('btn-disable');
const pttIndicator   = document.getElementById('radio-ptt-indicator');

// ── NUI message handler ──────────────────────────────────────────────

window.addEventListener('message', (e) => {
    const { action, data } = e;

    switch (action) {
        case 'radio:toggle':
            if (data.visible) {
                openPanel(data.channels, data.current, data.active);
            } else {
                closePanel();
            }
            break;
        case 'radio:talking':
            pttIndicator.style.display = data.state ? 'block' : 'none';
            break;
    }
});

// ── Open / Close ─────────────────────────────────────────────────────

function openPanel(channels, current, active) {
    currentChannelId = current;
    isActive         = active;
    renderChannels(channels);
    updateStatus();
    panel.classList.remove('hidden');
}

function closePanel() {
    panel.classList.add('hidden');
}

// ── Render channels ───────────────────────────────────────────────────

function renderChannels(channels) {
    channelsList.innerHTML = '';
    (channels || []).forEach(ch => {
        const item = document.createElement('div');
        item.className = 'channel-item' + (ch.id === currentChannelId ? ' active' : '');
        item.innerHTML = `
            <span class="ch-icon">${ch.icon || '📡'}</span>
            <div class="ch-info">
                <div class="ch-label">${ch.label}</div>
                <div class="ch-freq">${ch.freq} MHz</div>
            </div>
            ${ch.id === currentChannelId ? '<span class="ch-active-badge">ACTIF</span>' : ''}
        `;
        item.style.borderLeftColor = ch.color || '#3498db';
        item.style.borderLeftWidth = '3px';
        item.addEventListener('click', () => selectChannel(ch));
        channelsList.appendChild(item);
    });
}

// ── Select channel ────────────────────────────────────────────────────

function selectChannel(ch) {
    currentChannelId = ch.id;
    isActive         = true;

    // Mettre à jour le badge
    currentChBadge.textContent = ch.label + ' · ' + ch.freq;
    currentChBadge.classList.remove('hidden');

    // Mettre à jour le statut
    statusDot.className  = 'status-dot online';
    statusText.textContent = 'Connecté — ' + ch.label;

    // Mettre à jour les items
    document.querySelectorAll('.channel-item').forEach(el => {
        el.classList.remove('active');
        const badge = el.querySelector('.ch-active-badge');
        if (badge) badge.remove();
    });
    const items = channelsList.querySelectorAll('.channel-item');
    items.forEach((el, i) => {
        // Trouver l'item correspondant au canal sélectionné par index
    });

    // Re-render pour marquer l'actif
    fetch(`https://${GetParentResourceName()}/radio:setChannel`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id: ch.id })
    });

    // Fermer après sélection
    setTimeout(closePanel, 300);
}

// ── Disable ──────────────────────────────────────────────────────────

btnDisable.addEventListener('click', () => {
    isActive         = false;
    currentChannelId = null;
    statusDot.className  = 'status-dot offline';
    statusText.textContent = 'Hors ligne';
    currentChBadge.classList.add('hidden');

    fetch(`https://${GetParentResourceName()}/radio:disable`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    });
    closePanel();
});

// ── Close button ─────────────────────────────────────────────────────

document.getElementById('radio-close').addEventListener('click', () => {
    fetch(`https://${GetParentResourceName()}/radio:close`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    });
    closePanel();
});

// Escape key
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        fetch(`https://${GetParentResourceName()}/radio:close`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({})
        });
        closePanel();
    }
});

// ── Status update ─────────────────────────────────────────────────────

function updateStatus() {
    if (isActive && currentChannelId) {
        statusDot.className   = 'status-dot online';
        statusText.textContent = 'Connecté';
        currentChBadge.classList.remove('hidden');
    } else {
        statusDot.className   = 'status-dot offline';
        statusText.textContent = 'Hors ligne';
        currentChBadge.classList.add('hidden');
    }
}

function GetParentResourceName() {
    return window.GetParentResourceName ? window.GetParentResourceName() : 'lslegacy';
}
