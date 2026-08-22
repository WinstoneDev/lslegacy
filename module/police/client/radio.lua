--  MODULE POLICE NATIONALE — Radio police (client)
--  Canaux par service — voix via pma-voice (exports natifs)
--  Le PTT et le routing voix sont entièrement délégués à pma-voice.

local Radio = {}
Radio.Open    = false
Radio.Active  = false
Radio.Channel = nil   -- id numérique du canal actif

local function Notify(msg, type)
    TriggerEvent(Config.Police.NotifyEvent, 'Radio', msg, 3000, type or 'info')
end

-- Helpers pma-voice

local function PmaSetChannel(channelId)
    exports['pma-voice']:setRadioChannel(channelId)
end

local function PmaLeaveChannel(channelId)
    if channelId then
        exports['pma-voice']:removeRadioChannel(channelId)
    end
end

-- Ouvrir / Fermer le panneau NUI

local function OpenRadioPanel()
    if not Police.IsOnDuty() then
        Notify('Radio disponible uniquement en service.', 'error')
        return
    end
    Radio.Open = not Radio.Open
    SetNuiFocus(Radio.Open, Radio.Open)
    SendNUIMessage({
        action   = 'radio:toggle',
        visible  = Radio.Open,
        channels = Config.Police.RadioChannels,
        current  = Radio.Channel,
        active   = Radio.Active,
    })
end

RegisterCommand('police_radio', function()
    if not LSLegacy.MDT.IsLocalLeoOnDuty() then return end
    OpenRadioPanel()
end, false)
RegisterKeyMapping('police_radio', 'Radio Police', 'keyboard', 'F7')

-- NUI callbacks

RegisterNUICallback('radio:close', function(_, cb)
    Radio.Open = false
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('radio:setChannel', function(data, cb)
    if not data or not data.id then cb('err') return end

    -- Quitter l'ancien canal pma-voice avant d'en rejoindre un nouveau
    if Radio.Channel then
        PmaLeaveChannel(Radio.Channel)
    end

    Radio.Channel = data.id
    Radio.Active  = true

    -- Rejoindre le canal sur pma-voice
    PmaSetChannel(Radio.Channel)

    -- Notifier le serveur (tracking HUD + logs)
    LSLegacy.Events.SendToServer('police:radio:join', { channelId = data.id })

    -- Feedback UI
    local ch = nil
    for _, c in ipairs(Config.Police.RadioChannels) do
        if c.id == data.id then ch = c break end
    end
    if ch then
        Notify(string.format(Lang.Police.radio_channel_set, ch.label, ch.freq), 'success')
    end

    cb('ok')
end)

RegisterNUICallback('radio:disable', function(_, cb)
    if Radio.Channel then
        PmaLeaveChannel(Radio.Channel)
    end
    Radio.Active  = false
    Radio.Channel = nil
    Notify(Lang.Police.radio_off, 'info')
    LSLegacy.Events.SendToServer('police:radio:leave')
    cb('ok')
end)

-- Affichage du canal actif en HUD

Citizen.CreateThread(function()
    while true do
        local waittime = 1000
        if Radio.Active and Radio.Channel then
            waittime = 0
            local ch = nil
            for _, c in ipairs(Config.Police.RadioChannels) do
                if c.id == Radio.Channel then ch = c break end
            end
            if ch then
                SetTextFont(0)
                SetTextScale(0.30, 0.30)
                SetTextColour(27, 79, 134, 220)
                SetTextOutline()
                BeginTextCommandDisplayText('STRING')
                AddTextComponentSubstringPlayerName('📡 ' .. ch.label .. ' — ' .. ch.freq)
                EndTextCommandDisplayText(0.01, 0.06)
            end
        end
        Wait(waittime)
    end
end)

-- Désactiver proprement à la fin de service

LSLegacy.Events.AddHandler('police:dutyChanged', function(onDuty)
    if not onDuty and Radio.Active then
        PmaLeaveChannel(Radio.Channel)
        Radio.Active  = false
        Radio.Channel = nil
        LSLegacy.Events.SendToServer('police:radio:leave')
    end
end)
