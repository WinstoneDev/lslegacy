-- NetworkOverrideClockTime doit être rappelé CHAQUE FRAME pour rester actif (un simple SetClockTime se fait écraser par l'horloge réseau FXServer au tick suivant) ; SetClockDate n'a pas cette contrainte.
-- Le serveur reste l'unique source de vérité et diffuse l'heure via 'weather:syncClock' ; ce fichier ne fait que la maintenir affichée.

local currentHour, currentMinute

local function Clamp(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end

-- NetworkOverrideClockTime plante le client si hours/minutes sortent de leur plage : on clamp par sécurité.
LSLegacy.RegisterClientEvent('weather:syncClock', function(hour, minute, day, month, year)
    currentHour = math.floor(Clamp(tonumber(hour) or 0, 0, 23))
    currentMinute = math.floor(Clamp(tonumber(minute) or 0, 0, 59))
    SetClockDate(day, month, year)
end)

CreateThread(function()
    -- Sans ça, on resterait sur l'heure par défaut du jeu jusqu'au prochain tick serveur.
    LSLegacy.SendEventToServer('weather:requestClockSync')

    while true do
        Wait(0)
        if currentHour then
            NetworkOverrideClockTime(currentHour, currentMinute, 0)
        end
    end
end)
