-- Classe Sleeping partagee client/serveur
-- Adaptee pour LSLegacy (skinchanger, identifier license, events LSLegacy)

local LANG = pedOfflineCfg.langs[pedOfflineCfg.lang]

local ox_target
if not IsDuplicityVersion() then
    ox_target = exports['ox_target']
end

---@alias Identifier string
---@alias PlayerSkin { model: number, skin: table }
---@alias PlayerCoords { x: number, y: number, z: number, w: number }

---@class Sleeping
---@field playerCoords PlayerCoords
---@field skinData PlayerSkin
---@field citizenId Identifier
---@field animationIndex number
---@field carrying boolean
---@field ped? number
---@field isOld? boolean
---@field vehicle? { vehicleNetId: number, seat: number }
---@field netId? number

pedOfflineSleepingList = {}
Sleeping = setmetatable({}, { __index = {} })

function Sleeping.get(identifier)
    return pedOfflineSleepingList[identifier]
end

function Sleeping:new(data)
    if not data then return end
    if pedOfflineSleepingList[data.citizenId] then return end
    setmetatable(data, self)
    self.__index = self
    if IsDuplicityVersion() then
        LSLegacy.SendEventToClient('pedOffline:client:sync', -1, "new", data.citizenId, data)
        if not data.isOld then
            MySQL.insert.await(
                'INSERT INTO `exit_sleeping` (citizenid, sleepData) VALUES (?, ?)',
                { data.citizenId, json.encode(data) }
            )
        end
    end
    pedOfflineSleepingList[data.citizenId] = data
    pedOfflineDebug("new", data.citizenId)
    return data
end

function Sleeping:delete(citizenId)
    citizenId = self.citizenId or citizenId
    if pedOfflineSleepingList[citizenId] then
        if IsDuplicityVersion() then
            LSLegacy.SendEventToClient('pedOffline:client:sync', -1, "delete", citizenId)
            MySQL.query.await('DELETE FROM `exit_sleeping` WHERE citizenid = ?', { citizenId })
        else
            local sp = Sleeping.get(citizenId)
            if sp then sp:deletePed() end
        end
        pedOfflineSleepingList[citizenId] = nil
        pedOfflineDebug("delete", citizenId)
    end
end

function Sleeping:setCoords(newCoords)
    self.playerCoords = newCoords
    self.carrying = false
    if IsDuplicityVersion() then
        LSLegacy.SendEventToClient('pedOffline:client:sync', -1, "setCoords", self.citizenId, newCoords)
        -- self.identifier/self.slot (absents sur les peds créés avant ce
        -- correctif, chargés depuis exit_sleeping) : on ignore alors la sync
        -- vers `players` plutôt que de mettre à jour tous les personnages du
        -- compte (self.citizenId seul ne matche plus la colonne identifier).
        if self.identifier then
            MySQL.update.await(
                'UPDATE players SET coords = ? WHERE identifier = ? AND slot = ?',
                { json.encode({ x = newCoords.x, y = newCoords.y, z = newCoords.z }), self.identifier, self.slot or 1 }
            )
        end
    end
    pedOfflineDebug("setCoords", self.citizenId, newCoords)
end

function Sleeping:setCarrying(src, netId)
    self.carryPlayer = src
    self.carrying = true
    self.netId = netId
    if IsDuplicityVersion() then
        LSLegacy.SendEventToClient('pedOffline:client:sync', -1, "setCarrying", self.citizenId, {
            carryPlayer = self.carryPlayer,
            netId       = self.netId,
        })
    end
    pedOfflineDebug("setCarrying", self.citizenId, src, netId)
end

function Sleeping:stopCarrying()
    self.netId = nil
    self.carrying = false
    self.carryPlayer = nil
    if IsDuplicityVersion() then
        LSLegacy.SendEventToClient('pedOffline:client:sync', -1, "stopCarrying", self.citizenId)
    end
    pedOfflineDebug("stopCarrying", self.citizenId)
end

function Sleeping:putInVehicle(vehicleNetId, seatIndex)
    if not self.netId then return pedOfflineDebug("putInVehicle: self.netId is nil") end

    self.carrying = false
    self.vehicle  = { vehicleNetId = vehicleNetId, seat = seatIndex }
    pedOfflineDebug("putInVehicle", self.citizenId, vehicleNetId, seatIndex)

    if IsDuplicityVersion() then
        -- Ordonne au porteur de lacher le ped puis attend qu'il soit detache
        LSLegacy.SendEventToClient("pedOffline:client:forceStopCarrying", self.carryPlayer)
        Wait(500)

        local ped = NetworkGetEntityFromNetworkId(self.netId)
        if not ped or not DoesEntityExist(ped) then
            return pedOfflineDebug("putInVehicle: ped introuvable")
        end
        local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
        if not DoesEntityExist(vehicle) then
            return pedOfflineDebug("putInVehicle: vehicle introuvable")
        end
        LSLegacy.SendEventToClient('pedOffline:client:sync', -1, "putInVehicle", self.citizenId, self.vehicle)
        SetPedIntoVehicle(ped, vehicle, seatIndex)
        Entity(ped).state:set('pedOfflineAnim', false, true)
    else
        ox_target:addEntity(vehicleNetId, {
            {
                label    = LANG.OUT_VEHICLE:format(seatIndex + 1),
                name     = "pedOffline-out-vehicle-" .. seatIndex,
                icon     = "fa-solid fa-right-from-bracket",
                distance = 2.5,
                canInteract = function() return not pedOfflineCarrying end,
                onSelect = function()
                    LSLegacy.SendEventToServer("pedOffline:server:outVehicle", self.citizenId)
                end
            },
        })
    end
end

function Sleeping:outVehicle()
    if IsDuplicityVersion() then
        if not self.netId then return pedOfflineDebug("outVehicle: self.netId is nil") end
        local ped = NetworkGetEntityFromNetworkId(self.netId)
        if not ped or not DoesEntityExist(ped) then
            return pedOfflineDebug("outVehicle: ped introuvable")
        end
        LSLegacy.SendEventToClient('pedOffline:client:sync', -1, "outVehicle", self.citizenId)
        DeleteEntity(ped)
    else
        ox_target:removeEntity(self.vehicle.vehicleNetId, "pedOffline-out-vehicle-" .. self.vehicle.seat)
    end
    self.vehicle = nil
    pedOfflineDebug("outVehicle", self.citizenId)
end

-- COTE CLIENT UNIQUEMENT
if not IsDuplicityVersion() then
    pedOfflineCarrying  = false
    pedOfflineCarryData = nil  -- variable de module pour StopCarrying

    local function playAnim(entity, dict, anim, blendIn, blendOut, duration, flags)
        if not HasAnimDictLoaded(dict) then
            RequestAnimDict(dict)
            while not HasAnimDictLoaded(dict) do Wait(100) end
        end
        TaskPlayAnim(entity, dict, anim, blendIn or 8.0, blendOut or 8.0, duration or -1, flags or 0, 0, false, false, false)
    end

    local function requestModelAsync(model)
        if not HasModelLoaded(model) then
            RequestModel(model)
            while not HasModelLoaded(model) do Wait(100) end
        end
    end

    -- Applique le skin (format skinchanger LSLegacy) sur un ped arbitraire.
    -- Le skinchanger n'expose pas d'API pour des peds autres que PlayerPedId(),
    -- on appelle donc directement les memes natives GTA qu'il utilise en interne.
    function Sleeping.SetPedClothing(ped, skin)
        if not skin then return end

        -- Head blend (visage)
        local mom     = skin.mom or 0
        local dad     = skin.dad or 0
        local faceMix = math.max(0.0, math.min(1.0, (skin.face_md_weight or 50) / 100.0))
        local skinMix = math.max(0.0, math.min(1.0, (skin.skin_md_weight or 50) / 100.0))
        SetPedHeadBlendData(ped, mom, dad, 0, mom, dad, 0, faceMix, skinMix, 0.0, false)

        -- Cheveux
        if skin.hair_1 ~= nil then
            SetPedComponentVariation(ped, 2, skin.hair_1, skin.hair_2 or 0, 0)
            SetPedHairColor(ped, skin.hair_color_1 or 0, skin.hair_color_2 or 0)
        end

        -- Yeux
        if skin.eye_color ~= nil then
            SetPedEyeColor(ped, math.max(0, math.min(31, math.floor(skin.eye_color))), 0, 1)
        end

        -- Overlays (barbe, maquillage, tatouages...)
        local overlays = {
            blemishes_1  = { id = 0,  opa = "blemishes_2" },
            beard_1      = { id = 1,  opa = "beard_2",     c1 = "beard_3",     c2 = "beard_4",     ct = 1 },
            eyebrows_1   = { id = 2,  opa = "eyebrows_2",  c1 = "eyebrows_3",  c2 = "eyebrows_4",  ct = 1 },
            age_1        = { id = 3,  opa = "age_2" },
            makeup_1     = { id = 4,  opa = "makeup_2",    c1 = "makeup_3",    c2 = "makeup_4",    ct = 2 },
            blush_1      = { id = 5,  opa = "blush_2",     c1 = "blush_3",                          ct = 2 },
            complexion_1 = { id = 6,  opa = "complexion_2" },
            sun_1        = { id = 7,  opa = "sun_2" },
            lipstick_1   = { id = 8,  opa = "lipstick_2",  c1 = "lipstick_3",  c2 = "lipstick_4",  ct = 2 },
            moles_1      = { id = 9,  opa = "moles_2" },
            chest_1      = { id = 10, opa = "chest_2",     c1 = "chest_3",                          ct = 1 },
            bodyb_1      = { id = 11, opa = "bodyb_2" },
        }
        for field, def in pairs(overlays) do
            if skin[field] ~= nil then
                local drawVal = skin[field]
                if drawVal < 0 then drawVal = 255 end
                local opaVal = math.max(0.0, math.min(1.0, (skin[def.opa] or 0) / 10.0))
                SetPedHeadOverlay(ped, def.id, drawVal, opaVal)
                if def.ct then
                    SetPedHeadOverlayColor(ped, def.id, def.ct, skin[def.c1] or 0, (def.c2 and skin[def.c2]) or 0)
                end
            end
        end

        -- Face features
        local faceFeatures = {
            nose_1 = 0, nose_2 = 1, nose_3 = 2, nose_4 = 3, nose_5 = 4, nose_6 = 5,
            eyebrows_5 = 6, eyebrows_6 = 7,
            cheeks_1 = 8, cheeks_2 = 9, cheeks_3 = 10,
            eye_squint = 11, lip_thickness = 12,
            jaw_1 = 13, jaw_2 = 14,
            chin_1 = 15, chin_2 = 16, chin_3 = 17, chin_4 = 18,
            neck_thickness = 19,
        }
        for name, id in pairs(faceFeatures) do
            if skin[name] ~= nil then
                SetPedFaceFeature(ped, id, math.max(-1.0, math.min(1.0, (skin[name] or 0) / 10.0)))
            end
        end

        -- Vetements (composants) — meme mapping que skinchanger ClothesMap
        local clothes = {
            mask_1   = { cid = 1,  tex = "mask_2" },
            arms_1   = { cid = 3,  tex = "arms_2" },
            pants_1  = { cid = 4,  tex = "pants_2" },
            bags_1   = { cid = 5,  tex = "bags_2" },
            shoes_1  = { cid = 6,  tex = "shoes_2" },
            chain_1  = { cid = 7,  tex = "chain_2" },
            tshirt_1 = { cid = 8,  tex = "tshirt_2" },
            bproof_1 = { cid = 9,  tex = "bproof_2" },
            decals_1 = { cid = 10, tex = "decals_2" },
            torso_1  = { cid = 11, tex = "torso_2" },
        }
        for name, def in pairs(clothes) do
            if skin[name] ~= nil then
                SetPedComponentVariation(ped, def.cid, skin[name], skin[def.tex] or 0, 0)
            end
        end

        -- Props (casque, lunettes, oreilles...) — meme mapping que skinchanger PropMap
        local props = {
            helmet_1    = { pid = 0, tex = "helmet_2" },
            glasses_1   = { pid = 1, tex = "glasses_2" },
            ears_1      = { pid = 2, tex = "ears_2" },
            watches_1   = { pid = 6, tex = "watches_2" },
            bracelets_1 = { pid = 7, tex = "bracelets_2" },
        }
        for name, def in pairs(props) do
            if skin[name] ~= nil then
                if skin[name] == -1 then
                    ClearPedProp(ped, def.pid)
                else
                    SetPedPropIndex(ped, def.pid, skin[name], skin[def.tex] or 0, true)
                end
            end
        end
    end

    function Sleeping.SpawnPed(data, isServer)
        local skinData = data.skinData
        local skin     = skinData.skin or {}
        local model    = skinData.model or ((skin.sex == 1)
            and `mp_f_freemode_01` or `mp_m_freemode_01`)
        local coords   = data.playerCoords

        requestModelAsync(model)
        local ped = CreatePed(4, model, coords.x, coords.y, coords.z - 1, coords.w or 0.0, isServer, true)
        -- Laisser un frame pour que le ped soit bien initialise avant d'appliquer le skin
        Wait(0)
        FreezeEntityPosition(ped, true)
        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetModelAsNoLongerNeeded(model)

        -- Ignore uniquement la collision avec les vehicules proches (evite les
        -- degats/blocage si on lui roule dessus) sans desactiver sa collision
        -- generale, sinon ox_target (raycast) ne peut plus le cibler pour le porter.
        if not isServer then
            Citizen.CreateThread(function()
                while DoesEntityExist(ped) do
                    -- thisFrameOnly=true : la native doit etre rappelee chaque frame,
                    -- sinon la collision (et donc les degats) revient au frame suivant.
                    local pedCoords = GetEntityCoords(ped)
                    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
                        if #(GetEntityCoords(vehicle) - pedCoords) < 15.0 then
                            SetEntityNoCollisionEntity(ped, vehicle, true)
                        end
                    end
                    Wait(0)
                end
            end)
        end

        -- Appliquer le skin AVANT l'animation pour garantir l'execution
        pedOfflineDebug("SpawnPed skin keys: sex=" .. tostring(skin.sex)
            .. " tshirt_1=" .. tostring(skin.tshirt_1)
            .. " torso_1="  .. tostring(skin.torso_1)
            .. " pants_1="  .. tostring(skin.pants_1))
        Sleeping.SetPedClothing(ped, skin)

        -- Animation dans un thread separe pour ne pas bloquer SetPedClothing
        if not isServer then
            local anim = pedOfflineCfg.sleepAnimation[data.animationIndex]
            if anim then
                Citizen.CreateThread(function()
                    playAnim(ped, anim.dict, anim.anim, 8.0, 8.0, -1, anim.flags)
                end)
            end
        end

        return ped
    end

    function Sleeping.GetFreeSeatIndex(vehicle)
        local seatAmount = GetVehicleModelNumberOfSeats(GetEntityModel(vehicle))
        for i = 0, seatAmount - 1 do
            if IsVehicleSeatFree(vehicle, i) then return i end
        end
        return false
    end

    function Sleeping.TargetCarryAction(data)
        if pedOfflineCarrying then return end
        pedOfflineCarrying = true

        pedOfflineCarryData = { serverPed = nil, citizenId = data.citizenId, netId = 0 }
        pedOfflineCarryData.serverPed = Sleeping.SpawnPed(data, true)

        while pedOfflineCarryData.netId == 0 do
            pedOfflineCarryData.netId = NetworkGetNetworkIdFromEntity(pedOfflineCarryData.serverPed)
            Wait(100)
        end
        LSLegacy.SendEventToServer("pedOffline:server:startCarrying", pedOfflineCarryData.citizenId, pedOfflineCarryData.netId)

        local p1Anim    = pedOfflineCfg.carryAnimation.player1
        local attach    = pedOfflineCfg.carryAnimation.attach
        local playerPed = PlayerPedId()
        SetPedRelationshipGroupHash(pedOfflineCarryData.serverPed, joaat("PLAYER"))
        AttachEntityToEntity(
            pedOfflineCarryData.serverPed, playerPed,
            attach[1], attach[2], attach[3], attach[4],
            attach[5], attach[6], attach[7],
            false, false, false, false, 2, false
        )
        playAnim(playerPed, p1Anim.dict, p1Anim.anim, 8.0, 8.0, -1, p1Anim.flags)

        ox_target:addGlobalVehicle({
            {
                label    = LANG.PUT_IN_VEHICLE,
                name     = "pedOffline-put-in-vehicle",
                icon     = "fa-solid fa-right-to-bracket",
                distance = 2.5,
                canInteract = function() return pedOfflineCarrying end,
                onSelect = function(targetData)
                    local vehicle   = targetData.entity
                    local seatIndex = Sleeping.GetFreeSeatIndex(vehicle)
                    if not seatIndex then return end
                    LSLegacy.SendEventToServer(
                        "pedOffline:server:putInVehicle",
                        pedOfflineCarryData.citizenId,
                        NetworkGetNetworkIdFromEntity(vehicle),
                        seatIndex
                    )
                end
            },
        })

        Citizen.CreateThread(function()
            while pedOfflineCarrying do
                Wait(0)
                BeginTextCommandDisplayHelp('STRING')
                AddTextComponentSubstringPlayerName('[X] ' .. LANG.STOP_CARRYING)
                EndTextCommandDisplayHelp(0, false, false, -1)

                if IsControlJustReleased(0, 73) then
                    Sleeping.StopCarrying(true)
                    break
                end
                if pedOfflineCarryData and not DoesEntityExist(pedOfflineCarryData.serverPed) then
                    Sleeping.StopCarrying(true)
                    break
                end
            end
            ClearHelp(false)
        end)
    end

    -- updateServer=true -> notifie le serveur (joueur a appuye X)
    -- updateServer=false -> ne notifie pas (serveur a ordonne via forceStopCarrying)
    function Sleeping.StopCarrying(updateServer)
        if not pedOfflineCarrying then return false end
        pedOfflineCarrying = false
        if pedOfflineCarryData then
            if pedOfflineCarryData.serverPed and DoesEntityExist(pedOfflineCarryData.serverPed) then
                DetachEntity(pedOfflineCarryData.serverPed, true, false)
            end
            if updateServer then
                LSLegacy.SendEventToServer(
                    "pedOffline:server:stopCarrying",
                    pedOfflineCarryData.citizenId,
                    pedOfflineCarryData.netId
                )
            end
            pedOfflineCarryData = nil
        end
        ClearPedTasks(PlayerPedId())
        ox_target:removeGlobalVehicle("pedOffline-put-in-vehicle")
        return true
    end

    function Sleeping:spawnPed()
        self.ped = Sleeping.SpawnPed(self, false)
        ox_target:addLocalEntity(self.ped, {
            {
                label    = LANG.CARRY,
                name     = 'pedOffline-carry',
                icon     = 'fa-solid fa-up-down-left-right',
                distance = 2.5,
                canInteract = function() return not pedOfflineCarrying end,
                onSelect = function()
                    Sleeping.TargetCarryAction(self)
                end
            },
        })
    end

    function Sleeping:deletePed()
        if self.ped and DoesEntityExist(self.ped) then
            ox_target:removeLocalEntity(self.ped, 'pedOffline-carry')
            DeleteEntity(self.ped)
            self.ped = nil
        end
    end

else
    -- COTE SERVEUR UNIQUEMENT
    function Sleeping:updateSql()
        MySQL.update.await(
            'UPDATE exit_sleeping SET sleepData = ? WHERE citizenid = ?',
            { json.encode(self), self.citizenId }
        )
        pedOfflineDebug("updateSql", self.citizenId)
    end
end

function pedOfflineDebug(...)
    if not pedOfflineCfg.debug then return end
    print("[pedOffline]", ...)
end
