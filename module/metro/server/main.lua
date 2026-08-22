-- ═══════════════════════════════════════════════════════════════════
--  MODULE MÉTRO — Serveur principal
--  Le moteur du jeu spawn/pilote les rames lui-même (voir client/main.lua) :
--  le serveur n'a plus qu'à gérer l'achat du ticket et l'activation staff.
-- ═══════════════════════════════════════════════════════════════════

local PendingTickets = {} -- [token] = { src, hour, minute } — pas de station : le ticket est générique
local MetroEnabled   = true -- basculé par /metrotoggle (staff)

local function Dbg(msg) Config.Development.Print('[metro] ' .. msg) end

-- ── Achat du ticket ─────────────────────────────────────────────────

LSLegacy.Bank.RegisterPaymentResultHandler('metro', function(token, success)
    Dbg(('résultat paiement token=%s success=%s'):format(tostring(token), tostring(success)))

    local pending = PendingTickets[token]
    if not pending then
        Dbg('résultat paiement ignoré : token inconnu/expiré')
        return
    end
    PendingTickets[token] = nil

    local src = pending.src
    if not success then
        LSLegacy.Events.SendToClient('metro:ticketFailed', src, Lang.Metro.ticket_failed)
        return
    end

    local player = LSLegacy.Players.Get(src)
    if not player then
        Dbg('résultat paiement : joueur introuvable pour src ' .. tostring(src))
        return
    end

    if not LSLegacy.Inventory.CanCarryItem(player, 'ticket', 1) then
        Dbg('résultat paiement : inventaire plein pour src ' .. src)
        LSLegacy.Events.SendToClient('metro:ticketFailed', src, Lang.Metro.inventory_full)
        return
    end

    local label = string.format(Lang.Metro.ticket_item_label, pending.hour, pending.minute)
    LSLegacy.Inventory.AddItemInInventory(player, 'ticket', 1, label, nil, {
        hour   = pending.hour,
        minute = pending.minute,
    })
    Dbg('ticket "' .. label .. '" donné à src ' .. src)
    LSLegacy.Events.SendToClient('metro:ticketBought', src)
end)

-- Le ticket n'est associé à aucune station : achetable sur n'importe
-- quelle borne (voir le ciblage global côté client), donc rien à
-- vérifier ici hormis le paiement.
LSLegacy.Security.RegisterRateLimit('metro:buyTicket', 50)
LSLegacy.Events.Register('metro:buyTicket', function(hour, minute)
    local src = source

    if not MetroEnabled then
        Dbg('buyTicket refusé : métro désactivé (src ' .. src .. ')')
        LSLegacy.Events.SendToClient('metro:ticketFailed', src, Lang.Metro.metro_disabled)
        return
    end

    Dbg(('buyTicket reçu : src=%d heure=%s:%s'):format(src, tostring(hour), tostring(minute)))

    -- Heure fournie par le client (GetClockHours est client-only) : on la
    -- borne pour qu'un client trafiqué ne puisse pas forger un label libre.
    hour   = math.floor(tonumber(hour) or 0) % 24
    minute = math.floor(tonumber(minute) or 0) % 60

    local token = ('metro_%d_%d'):format(src, math.random(100000, 999999))
    PendingTickets[token] = { src = src, hour = hour, minute = minute }
    Citizen.SetTimeout(120000, function() PendingTickets[token] = nil end)

    Dbg('buyTicket : ouverture du payment menu, token=' .. token)
    local opened = LSLegacy.Bank.OpenPaymentMenu(src, 'Ticket de métro', Config.Metro.Price, {
        meta = { type = 'metro', refId = token },
    })
    Dbg('OpenPaymentMenu -> ' .. tostring(opened))
end)

-- ── Activation / désactivation staff ─────────────────────────────────

LSLegacy.RegisterCommand('metrotoggle', 2, function(player, args)
    local src = player.source
    local action = args and args.action

    if action ~= 'on' and action ~= 'off' then
        LSLegacy.Events.SendToClient('notify', src, 'Métro', 'Usage: /metrotoggle on|off', 'error')
        return
    end

    MetroEnabled = (action == 'on')
    Dbg(('métro %s (par src %d)'):format(MetroEnabled and 'ACTIVÉ' or 'DÉSACTIVÉ', src))

    TriggerClientEvent('metro:setEnabled', -1, MetroEnabled)
    LSLegacy.Events.SendToClient('notify', src, 'Métro', 'Métro ' .. (MetroEnabled and 'activé.' or 'désactivé.'), 'success')
end, {
    help = 'Active/désactive le métro (staff)',
    validate = true,
    arguments = { { name = 'action', help = 'on | off', type = 'string' } },
}, false)

-- ── Outil de calibrage staff ─────────────────────────────────────────
-- Position/heading du joueur, pour ajuster les bornes de tickets.

LSLegacy.RegisterCommand('metropos', 2, function(player)
    local src = player.source
    local coords = LSLegacy.GetEntityCoords(src)
    local msg = string.format('vector3(%.6f, %.6f, %.6f) heading=%.5f',
        coords.x, coords.y, coords.z, GetEntityHeading(GetPlayerPed(src)))
    LSLegacy.Events.SendToClient('notify', src, 'Métro', msg, 'success')
    Dbg(msg)
end, { help = 'Position/heading du joueur (calibrage métro)' }, false)

-- Blip de debug sur chaque rame ambiante trouvée sur la carte, pour
-- vérifier où le moteur les fait effectivement apparaître/circuler.
LSLegacy.RegisterCommand('metrotrainblips', 2, function(player)
    LSLegacy.Events.SendToClient('metro:toggleTrainBlips', player.source)
end, { help = 'Active/désactive les blips de debug sur toutes les rames (calibrage métro)' }, false)
