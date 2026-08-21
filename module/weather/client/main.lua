-- ════════════════════════════════════════════════════════════════════
--  MÉTÉO DYNAMIQUE — Client
--  Un simple SetClockTime ne suffit pas : FXServer fait tourner sa
--  propre horloge réseau en continu, et un override ponctuel se fait
--  écraser au tick suivant (c'est pour ça que le freeze ne "tenait"
--  pas). Le native qui MAINTIENT une heure imposée est
--  NetworkOverrideClockTime — mais il faut le rappeler à CHAQUE FRAME
--  pour que l'override reste actif (comme fait PainedPsyche/weathertimesync).
--  SetClockDate n'a pas cette contrainte (rien ne le réécrase en
--  continu), un appel par sync serveur suffit.
--
--  Le serveur (module/weather/server/main.lua) reste l'unique source de
--  vérité (saison, freeze, calcul de l'heure) et diffuse juste l'heure
--  à appliquer via 'weather:syncClock' ; ce fichier ne fait que la
--  maintenir affichée.
-- ════════════════════════════════════════════════════════════════════

local currentHour, currentMinute

local function Clamp(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end

-- NetworkOverrideClockTime plante le client si hours/minutes sortent de
-- leur plage (voir la doc du native) : on clamp par sécurité même si le
-- serveur envoie déjà des valeurs propres.
LSLegacy.RegisterClientEvent('weather:syncClock', function(hour, minute, day, month, year)
    currentHour = math.floor(Clamp(tonumber(hour) or 0, 0, 23))
    currentMinute = math.floor(Clamp(tonumber(minute) or 0, 0, 59))
    SetClockDate(day, month, year)
end)

CreateThread(function()
    -- Demande l'heure courante au démarrage : sans ça, on resterait sur
    -- l'heure par défaut du jeu jusqu'au prochain tick serveur (jusqu'à
    -- Config.Weather.TimeTickMs de délai).
    LSLegacy.SendEventToServer('weather:requestClockSync')

    while true do
        Wait(0)
        if currentHour then
            NetworkOverrideClockTime(currentHour, currentMinute, 0)
        end
    end
end)
