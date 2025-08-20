local activeFood = nil
local activeData = nil
local activeUniqueId = nil
local scaleform = nil
local foodProp = nil

local function AttachPropToHand(propName)
    local playerPed = PlayerPedId()
    local boneIndex = GetPedBoneIndex(playerPed, 57005)
    local model = propName

    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(0)
    end

    if foodProp then
        DeleteEntity(foodProp)
    end

    foodProp = CreateObject(GetHashKey(model), 1.0, 1.0, 1.0, true, true, true)
    AttachEntityToEntity(foodProp, playerPed, boneIndex, 0.12, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
end

local function DetachFood()
    if foodProp then
        DeleteEntity(foodProp)
        foodProp = nil
    end
end

local function PlayEatDrinkAnim(isDrink)
    local playerPed = PlayerPedId()
    local dict = isDrink and "amb@world_human_drinking@coffee@male@idle_a" or "mp_player_inteat@burger"
    local anim = isDrink and "idle_a" or "mp_player_int_eat_burger"

    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(0)
    end

    DetachFood()
    TaskPlayAnim(playerPed, dict, anim, 3.0, 3.0, 3000, 49, 0, false, false, false)
end

local function SetupFoodScaleform(durability, itemWeightKg, isDrink)
    local sf = RequestScaleformMovie("instructional_buttons")
    while not HasScaleformMovieLoaded(sf) do
        Wait(0)
    end

    local weightGrams = math.floor(itemWeightKg * 1000 * (durability / 100))

    PushScaleformMovieFunction(sf, "CLEAR_ALL")
    PopScaleformMovieFunctionVoid()

    PushScaleformMovieFunction(sf, "SET_CLEAR_SPACE")
    PushScaleformMovieFunctionParameterInt(200)
    PopScaleformMovieFunctionVoid()

    PushScaleformMovieFunction(sf, "SET_DATA_SLOT")
    PushScaleformMovieFunctionParameterInt(0)
    N_0xe83a3e3557a56640(GetControlInstructionalButton(2, 38, true))
    if isDrink then
        ButtonMessage("Boire (" .. weightGrams .. "ml restants)")
    else
        ButtonMessage("Croquer (" .. weightGrams .. "g restants)")
    end
    PopScaleformMovieFunctionVoid()

    PushScaleformMovieFunction(sf, "SET_DATA_SLOT")
    PushScaleformMovieFunctionParameterInt(1)
    N_0xe83a3e3557a56640(GetControlInstructionalButton(2, 73, true))
    ButtonMessage("Ranger")
    PopScaleformMovieFunctionVoid()

    PushScaleformMovieFunction(sf, "DRAW_INSTRUCTIONAL_BUTTONS")
    PopScaleformMovieFunctionVoid()

    PushScaleformMovieFunction(sf, "SET_BACKGROUND_COLOUR")
    PushScaleformMovieFunctionParameterInt(0)
    PushScaleformMovieFunctionParameterInt(0)
    PushScaleformMovieFunctionParameterInt(0)
    PushScaleformMovieFunctionParameterInt(80)
    PopScaleformMovieFunctionVoid()

    return sf
end

LSLegacy.RegisterClientEvent('useNeed', function(name, data, uniqueId)
    activeFood = name
    activeData = data
    activeUniqueId = uniqueId
    local itemCfg = Config.NeedsItems[name]
    local itemWeight = Config.Items[name] and Config.Items[name].weight or 0
    scaleform = SetupFoodScaleform(data.durability or 100, itemWeight, itemCfg.anim == 'drinking')
    AttachPropToHand(Config.Items[name].props)
end)

CreateThread(function()
    while true do
        local waitTime = 1000
        if activeFood and scaleform then
            waitTime = 0
            DrawScaleformMovieFullscreen(scaleform, 255, 255, 255, 255, 0)

            if IsControlJustPressed(0, 38) then
                local itemCfg = Config.NeedsItems[activeFood]
                PlayEatDrinkAnim(itemCfg.anim == 'drinking')
                Wait(3000)
                AttachPropToHand(Config.Items[activeFood].props)
                LSLegacy.SendEventToServer('applyNeedEffect', activeFood, activeData, activeUniqueId)
            end

            if IsControlJustPressed(0, 73) then
                activeFood = nil
                activeData = nil
                activeUniqueId = nil
                scaleform = nil
                DetachFood()
            end
        end
        Wait(waitTime)
    end
end)

LSLegacy.RegisterClientEvent("updateFoodDurability", function(uniqueId, durabilityPercent)
    if activeUniqueId == uniqueId and durabilityPercent > 0 then
        local itemCfg = Config.NeedsItems[activeFood]
        local itemWeight = Config.Items[activeFood] and Config.Items[activeFood].weight or 0
        scaleform = SetupFoodScaleform(durabilityPercent, itemWeight, itemCfg.anim == 'drinking')
        activeData.durability = durabilityPercent
    elseif durabilityPercent <= 0 and activeUniqueId == uniqueId then
        activeFood = nil
        activeData = nil
        activeUniqueId = nil
        scaleform = nil
        DetachFood()
    end
end)
