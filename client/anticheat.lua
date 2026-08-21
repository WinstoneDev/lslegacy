-- Fenêtre de grâce pour les téléportations légitimes (multichar, créateur de
-- personnage, spawn/respawn, etc.). Ces scripts appellent
-- LSLegacy.Anticheat.AllowTeleport() juste avant de déplacer le ped : sans ça
-- le check Anti Noclip ci-dessous interprète le saut de position comme un
-- cheat et bannit le joueur.
LSLegacy.Anticheat = LSLegacy.Anticheat or {}
local safeTeleportUntil = 0
LSLegacy.Anticheat.AllowTeleport = function(durationMs)
    safeTeleportUntil = GetGameTimer() + (durationMs or 5000)
end

-- Export pour les resources tierces (hors lslegacy, ex: modules de mapping
-- avec leurs propres téléporteurs) qui n'ont pas accès aux globales LSLegacy.
exports('AllowTeleport', function(durationMs)
    LSLegacy.Anticheat.AllowTeleport(durationMs)
end)

local entityEnumerator = {
  __gc = function(enum)
    if enum.destructor and enum.handle then
      enum.destructor(enum.handle)
    end
    enum.destructor = nil
    enum.handle = nil
  end
}

local function EnumerateEntities(initFunc, moveFunc, disposeFunc)
  return coroutine.wrap(function()
    local iter, id = initFunc()
    if not id or id == 0 then
      disposeFunc(iter)
      return
    end
    
    local enum = {handle = iter, destructor = disposeFunc}
    setmetatable(enum, entityEnumerator)
    
    local next = true
    repeat
      coroutine.yield(id)
      next, id = moveFunc(iter)
    until not next
    
    enum.destructor, enum.handle = nil, nil
    disposeFunc(iter)
  end)
end

function EnumerateObjects()
  return EnumerateEntities(FindFirstObject, FindNextObject, EndFindObject)
end

function EnumeratePeds()
  return EnumerateEntities(FindFirstPed, FindNextPed, EndFindPed)
end

-- function EnumerateVehicles()
--   return EnumerateEntities(FindFirstVehicle, FindNextVehicle, EndFindVehicle)
-- end

function EnumeratePickups()
  return EnumerateEntities(FindFirstPickup, FindNextPickup, EndFindPickup)
end

function GetAllEnumerators()
  return {vehicles = EnumerateVehicles, objects = EnumerateObjects, peds = EnumeratePeds, pickups = EnumeratePickups}
end


-- General Status Loop (Medium Tick: 1000ms)
Citizen.CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(250) end
    Wait(15000)
    while true do
        Citizen.Wait(1000)
        local ped = PlayerPedId()
        local pid = PlayerId()
        
        -- Anti GodMode (Health Check)
        if Shared.Anticheat.AntiGodMode then
            local health = GetEntityHealth(ped)
            if GetPlayerInvincible_2(pid) then
                TriggerServerEvent("8jWpZudyvjkDXQ2RVXf9", "godmode", "4") 
                SetPlayerInvincible(pid, false)
                return
            end
            
            -- Basic max health check (full heal detection is complex to sync with legit healing)
            if health > 200 then
                TriggerServerEvent("8jWpZudyvjkDXQ2RVXf9", "godmode", "2") 
                return
            end
        end

        -- Anti Invisible
        if Shared.Anticheat.AntiInvisible then
            local alpha = GetEntityAlpha(ped)
            if not IsEntityVisible(ped) or not IsEntityVisibleToScript(ped) or alpha <= 150 then
                TriggerServerEvent("8jWpZudyvjkDXQ2RVXf9", "invisible") 
                return
            end
        end

        -- Anti Radar
        if Shared.Anticheat.AntiRadar then
             -- Only check if not in vehicle (some servers enable radar in vehicle)
            if not IsRadarHidden() and not IsPedInAnyVehicle(ped, true) then
                TriggerServerEvent("8jWpZudyvjkDXQ2RVXf9", "displayradar") 
                return
            end
        end
        
        -- Anti Spectate
        if Shared.Anticheat.AntiSpectate and NetworkIsInSpectatorMode() then
            TriggerServerEvent("8jWpZudyvjkDXQ2RVXf9", "spectatormode")
            return
        end

        -- Anti Thermal/Night Vision
        if Shared.Anticheat.AntiThermalVision and GetUsingseethrough() then
            TriggerServerEvent("8jWpZudyvjkDXQ2RVXf9", "thermalvision") 
            return
        end
        if Shared.Anticheat.AntiNightVision and GetUsingnightvision() then
            TriggerServerEvent("8jWpZudyvjkDXQ2RVXf9", "nightvision")
            return
        end

        -- Anti Resource Start/Stop (Count Check)
        if Shared.Anticheat.AntiResourceStartorStop then 
            local resCount = GetNumResources()
            if resources and resources ~= resCount then
                TriggerServerEvent("8jWpZudyvjkDXQ2RVXf9", "antiresourcestop")
                return
            end
            resources = resCount -- Update to avoid spam loop if not banned immediately
        end
        
    end
end)

-- Fast Loop (Short Tick: 200ms or 0ms for specific checks)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(500)
        local ped = PlayerPedId()
        
        -- Cleanup / enforcement
        SetRunSprintMultiplierForPlayer(PlayerId(), 1.0)
        SetSwimMultiplierForPlayer(PlayerId(), 1.0)
        SetPedInfiniteAmmoClip(ped, false)
        
        if Shared.Anticheat.AntiExplosionDamage then
            SetEntityProofs(ped, false, true, true, false, false, false, false, false)
        end
        
        if Shared.Anticheat.AntiAimAssist then
             SetPlayerTargetingMode(0)
             if GetLocalPlayerAimState() ~= 3 and not IsPedInAnyVehicle(ped, true) then
                 TriggerServerEvent("8jWpZudyvjkDXQ2RVXf9", "aimassist", GetLocalPlayerAimState())
                 return 
             end
        end
        
        -- Anti SpeedHack (Basic speed check)
        if Shared.Anticheat.AntiSpeedHacks then
            if not IsPedInAnyVehicle(ped, true) and GetEntitySpeed(ped) > 10 and not IsPedFalling(ped) and not IsPedInParachuteFreeFall(ped) and not IsPedRagdoll(ped) then
                TriggerServerEvent("8jWpZudyvjkDXQ2RVXf9", "speedhack") 
                return
            end
        end
        
        -- Anti SuperJump
        if Shared.Anticheat.SuperJump and IsPedJumping(ped) then
            TriggerServerEvent('8jWpZudyvjkDXQ2RVXf9', "superjump")
            return
        end

        -- Anti Explosive Bullets
        if Shared.Anticheat.AntiExplosiveBullets then
            local dmgType = GetWeaponDamageType(GetSelectedPedWeapon(ped))
            if dmgType == 4 or dmgType == 5 or dmgType == 6 or dmgType == 13 then
                TriggerServerEvent("8jWpZudyvjkDXQ2RVXf9", "explosiveweapon")
                return
            end
        end
        
        -- Anti Blacklisted Weapons
        if Shared.Anticheat.AntiBlacklistedWeapons then
             for _, weapon in ipairs(Shared.Anticheat.BlacklistedWeapons) do
                if HasPedGotWeapon(ped, weapon, false) then
                    RemoveAllPedWeapons(ped, true)
                    TriggerServerEvent("8jWpZudyvjkDXQ2RVXf9", "blacklistedweapons") 
                    break
                end
            end
        end
        
        -- Anti Give Armor
        if Shared.Anticheat.AntiGiveArmor and GetPedArmour(ped) > 100 then
             TriggerServerEvent("8jWpZudyvjkDXQ2RVXf9", "givearmour") 
             return
        end
    end
end)

-- Blacklisted Tasks & Anims (1000ms is enough)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        if Shared.Anticheat.AntiBlacklistedTasks then
            local ped = PlayerPedId()
            for _, task in pairs(Shared.Anticheat.BlacklistedTasks) do
                if GetIsTaskActive(ped, task) then
                    TriggerServerEvent("8jWpZudyvjkDXQ2RVXf9", "blacklistedtask", task)
                    return
                end
            end
        end
         if Shared.Anticheat.AntiBlacklistedAnims then
             local ped = PlayerPedId()
            for _, anim in pairs(Shared.Anticheat.BlacklistedAnims) do
                if IsEntityPlayingAnim(ped, anim[1], anim[2], 3) then
                    TriggerServerEvent("8jWpZudyvjkDXQ2RVXf9", "blacklistedanim", json.encode(anim))
                    ClearPedTasksImmediately(ped)
                    return
                end
            end
        end
    end
end)


-- Anti Driveby (Speed Limited)
Citizen.CreateThread(function()
    local SPEED_LIMIT_KMH = 15.0
    while true do
        Citizen.Wait(250)
        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) then
            local speedKmh = GetEntitySpeed(ped) * 3.6
            SetPlayerCanDoDriveBy(PlayerId(), speedKmh <= SPEED_LIMIT_KMH)
        else
            SetPlayerCanDoDriveBy(PlayerId(), true)
        end
    end
end)

-- Anti Noclip (Client Side) - Runs every 1s
if Shared.Anticheat.AntiNoclip then
    Citizen.CreateThread(function()
        -- On exige 2 fenêtres suspectes d'affilée avant de bannir, pour absorber les TP scriptés non whitelistés.
        local strikes = 0
        while true do
            Citizen.Wait(1000)
            local ped = PlayerPedId()
            if not IsPedInAnyVehicle(ped, false) and not IsPedFalling(ped) and not IsPedRagdoll(ped) then
                local pos = GetEntityCoords(ped)
                Citizen.Wait(1000)
                local newPos = GetEntityCoords(ped)
                local dist = #(pos - newPos)
                local suspect = dist > 25.0 and not IsPedInParachuteFreeFall(ped) and not IsEntityDead(ped) and not LSLegacy.PlayerData.inCreation and GetGameTimer() >= safeTeleportUntil

                if suspect then
                    strikes = strikes + 1
                    if strikes >= 2 then
                        TriggerServerEvent("8jWpZudyvjkDXQ2RVXf9", "noclip", "Dist: " .. math.ceil(dist))
                        return
                    end
                else
                    strikes = 0
                end
            else
                strikes = 0
            end
        end
    end)
end

-- Anti Silent Aim & Aimbot (Frame Loop)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        local ped = PlayerPedId()
        if Shared.Anticheat.AntiSilentAim and IsPedShooting(ped) then
            local _, hitEntity = GetEntityPlayerIsFreeAimingAt(PlayerId())
            if not hitEntity or hitEntity == 0 then
                local found, coords = GetPedLastWeaponImpactCoord(ped)
                if found then
                    local camRot = GetGameplayCamRot(2)
                    local camHeading = (-camRot.z) * 0.0174533
                    local camPitch = camRot.x * 0.0174533
                    local camVec = vector3(-math.sin(camHeading) * math.cos(camPitch), math.cos(camHeading) * math.cos(camPitch), math.sin(camPitch))
                    local headPos = GetPedBoneCoords(ped, 31086, 0.0, 0.0, 0.0)
                    local hitVec = coords - headPos
                    local dist = #(hitVec)
                    hitVec = hitVec / dist
                    local angle = math.acos(dot(camVec, hitVec)) * 57.2958
                    if angle > (Shared.Anticheat.MaxFOV or 30.0) and dist > 5.0 then
                        TriggerServerEvent("8jWpZudyvjkDXQ2RVXf9", "silentaim", "Angle : " .. math.floor(angle))
                    end
                end
            end
        end
    end
end)

function dot(v1, v2)
    return v1.x * v2.x + v1.y * v2.y + v1.z * v2.z
end

-- Events Setup
local _evhandler = AddEventHandler
_evhandler("onClientResourceStop", function(resourceName)
    TriggerServerEvent("8jWpZudyvjkDXQ2RVXf9", "stoppedresource", resourceName)
end)

_evhandler("onResourceStop", function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then return end
    TriggerServerEvent("8jWpZudyvjkDXQ2RVXf9", "stoppedac")
end)

-- Heartbeat
if Shared.Anticheat.Heartbeat then
    RegisterNetEvent("rwe:HeartbeatCheck")
    AddEventHandler("rwe:HeartbeatCheck", function(token)
        Shared.Anticheat.SecurityToken = token
        TriggerServerEvent("rwe:HeartbeatReturn", token)
    end)
end

-- Input Scanner ("Clipboard" / Chat Protection)
if Shared.Anticheat.InputScanner then
    RegisterNetEvent('chatMessage')
    AddEventHandler('chatMessage', function(author, color, text)
         local blacklist = {"<script", "svg onload", "document.cookie", "http://", ".com"} -- XSS or links
         for _, word in ipairs(blacklist) do
            if string.find(string.lower(text), word) then
                 TriggerServerEvent("8jWpZudyvjkDXQ2RVXf9", "chatsecurity", "Mot interdit " .. word)
                 return
            end
         end
    end)
end

-- Screenshot
RegisterNetEvent("fuckyourself")
AddEventHandler("fuckyourself", function()
    local webhook = Shared.Anticheat.OCRWebhook ~= "" and Shared.Anticheat.OCRWebhook or Shared.Anticheat.WebhookDiscord
    exports["screenshot-basic"]:requestScreenshotUpload(webhook, "files[]", function() end)
end)

-- Anti-Cheat Menu Detections (Global Variable Scanner)
if Shared.Anticheat.AntiResourceManipulation then
    Citizen.CreateThread(function()
        local BannedGlobals = {
            "Eulen", "Eulen_Vars", "Eulen_Menu",
            "Kazo", "KazoMenu", "Kazoe",
            "Macho", "MachoMenu",
            "Susano", "SusanoMenu",
            "Ham", "HamMafia", "HamMenu",
            "Lynx", "Lynx8", "LynxEvo",
            "Tiago", "TiagoMenu",
            "Cam", "CamMenu",
            "Dopamine", "Dopameme",
            "Swagamine",
            "挂", "掛",
            "挂bi",
            "Brutan", "BrutanPremium"
        }
        
        while true do
            Citizen.Wait(5000)
            for _, varName in ipairs(BannedGlobals) do
                if _G[varName] ~= nil then
                    TriggerServerEvent("8jWpZudyvjkDXQ2RVXf9", "menu_global", "Variable globale malicieuse détectée : " .. varName)
                    return
                end
            end
            
            -- TODO: deep scan for specific function signatures / table structures
        end
    end)
end

-- Anti Entity Takeover & Suspicious Stats
if Shared.Anticheat.EntitiesSecurity then
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(2000)
            local ped = PlayerPedId()
            
            -- Anti Entity Takeover (Control of distant vehicles)
            if Shared.Anticheat.AntiEntityTakeOver then
               -- TODO: hard to prove intent without false positives (e.g. locking keys)
            end
            
             -- Suspicious Game Stats (Stamina, Shooting, Strength)
            if Shared.Anticheat.SuspiciousGameStats then
                 local strength = GetPlayerCurrentStealthNoise(PlayerId())
                 -- Pseudo check: If stamina never drops or strength is max instantly
            end
        end
    end)
end

-- Anti Overlay (Resolution Check)
if Shared.Anticheat.AntiOverlay then
    local lastResX, lastResY = GetActiveScreenResolution()
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(5000)
            local resX, resY = GetActiveScreenResolution()
            if (resX ~= lastResX or resY ~= lastResY) and (resX < 800 or resY < 600) then
                 TriggerServerEvent("8jWpZudyvjkDXQ2RVXf9", "overlay_detection", "Changement de résolution : " .. resX .. "x" .. resY)
                 return
            end
            lastResX = resX
            lastResY = resY
        end
    end)
end

local DetectableTextures = {
    {txd = "HydroMenu", txt = "HydroMenuHeader", name = "HydroMenu"},
    {txd = "John", txt = "John2", name = "SugarMenu"},
    {txd = "darkside", txt = "logo", name = "Darkside"},
    {txd = "ISMMENU", txt = "ISMMENUHeader", name = "ISMMENU"},
    {txd = "dopatest", txt = "duiTex", name = "Copypaste Menu"},
    {txd = "fm", txt = "menu_bg", name = "Fallout Menu"},
    {txd = "wave", txt = "logo", name ="Wave"},
    {txd = "wave1", txt = "logo1", name = "Wave (alt.)"},
    {txd = "meow2", txt = "woof2", name ="Alokas66", x = 1000, y = 1000},
    {txd = "adb831a7fdd83d_Guest_d1e2a309ce7591dff86", txt = "adb831a7fdd83d_Guest_d1e2a309ce7591dff8Header6", name ="Guest Menu"},
    {txd = "hugev_gif_DSGUHSDGISDG", txt = "duiTex_DSIOGJSDG", name="HugeV Menu"},
    {txd = "MM", txt = "menu_bg", name="Metrix Mehtods"},
    {txd = "wm", txt = "wm2", name="WM Menu"},
    {txd = "NeekerMan", txt="NeekerMan1", name="Lumia Menu"},
    {txd = "Blood-X", txt="Blood-X", name="Blood-X Menu"},
    {txd = "Dopamine", txt="Dopameme", name="Dopamine Menu"},
    {txd = "Fallout", txt="FalloutMenu", name="Fallout Menu"},
    {txd = "Luxmenu", txt="Lux meme", name="LuxMenu"},
    {txd = "Reaper", txt="reaper", name="Reaper Menu"},
    {txd = "absoluteeulen", txt="Absolut", name="Absolut Menu"},
    {txd = "KekHack", txt="kekhack", name="KekHack Menu"},
    {txd = "Maestro", txt="maestro", name="Maestro Menu"},
    {txd = "SkidMenu", txt="skidmenu", name="Skid Menu"},
    {txd = "Brutan", txt="brutan", name="Brutan Menu"},
    {txd = "FiveSense", txt="fivesense", name="Fivesense Menu"},
    {txd = "Auttaja", txt="auttaja", name="Auttaja Menu"},
    {txd = "BartowMenu", txt="bartowmenu", name="Bartow Menu"},
    {txd = "Hoax", txt="hoaxmenu", name="Hoax Menu"},
    {txd = "FendinX", txt="fendin", name="Fendinx Menu"},
    {txd = "Hammenu", txt="Ham", name="Ham Menu"},
    {txd = "Lynxmenu", txt="Lynx", name="Lynx Menu"},
    {txd = "Oblivious", txt="oblivious", name="Oblivious Menu"},
    {txd = "malossimenuv", txt="malossimenu", name="Malossi Menu"},
    {txd = "memeeee", txt="Memeeee", name="Memeeee Menu"},
    {txd = "tiago", txt="Tiago", name="Tiago Menu"},
    {txd = "Hydramenu", txt="hydramenu", name="Hydra Menu"},
    {txd = "dopamine", txt="Swagamine", name="Dopamine"},
    {txd = "HydroMenu", txt="HydroMenuHeader", name="Hydro Menu"},
    {txd = "HydroMenu", txt="HydroMenuLogo", name="Hydro Menu"},
    {txd = "HydroMenu", txt="https://i.ibb.co/0GhPPL7/Hydro-New-Header.png", name="Hydro Menu"},
    {txd = "test", txt="Terror Menu", name="Terror Menu"},
    {txd = "lynxmenu", txt="lynxmenu", name="Lynx Menu"},
    {txd = "Maestro 2.3", txt="Maestro 2.3", name="Maestro Menu"},
    {txd = "ALIEN MENU", txt="ALIEN MENU", name="Alien Menu"},
    {txd = "~u~⚡️ALIEN MENU⚡️", txt="~u~⚡️ALIEN MENU⚡️", name="Alien Menu"},
    {txd = "Kazo", txt = "Kazo", name = "Kazo Menu"},
    {txd = "KazoMenu", txt = "Kazo", name = "Kazo Menu"},
    {txd = "Macho", txt = "Macho", name = "Macho Menu"},
    {txd = "Susano", txt = "Susano", name = "Susano Menu"},
    {txd = "HamMafia", txt = "HamMafia", name = "HamMafia Menu"},
    {txd = "Ham", txt = "Ham", name = "HamMafia Menu"},
    {txd = "Eulen", txt = "Eulen", name = "Eulen Executor"},
}

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(5000) 
        for i, data in pairs(DetectableTextures) do
            if data.x and data.y then
                if GetTextureResolution(data.txd, data.txt).x == data.x and GetTextureResolution(data.txd, data.txt).y == data.y then
                    TriggerServerEvent("8jWpZudyvjkDXQ2RVXf9", "menyoo", "Lua Menu: " .. data.name)
                    return
                end
            else 
                if GetTextureResolution(data.txd, data.txt).x ~= 4.0 then
                     TriggerServerEvent("8jWpZudyvjkDXQ2RVXf9", "menyoo", "Lua Menu: " .. data.name)
                     return
                end
            end
             Citizen.Wait(100) -- Increased wait to avoid CPU spike
        end
    end
end)
