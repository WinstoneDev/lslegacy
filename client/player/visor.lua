local VisorPairs = {
    [20] = 21, [21] = 20,
    [22] = 23, [23] = 22,
    [24] = 25, [25] = 24,
    [26] = 27, [27] = 26,
    [30] = 31, [31] = 30,
    [32] = 33, [33] = 32,
    [153] = 154, [154] = 153,
    [158] = 159, [159] = 158,
    [160] = 161, [161] = 160,
    [171] = 172, [172] = 171,
    [183] = 184, [184] = 183,
    [203] = 204, [204] = 203,
    [205] = 206, [206] = 205,
    [207] = 208, [208] = 207,
    [227] = 228, [228] = 227,
    [275] = 276, [276] = 275,
    [279] = 280, [280] = 279
}

local visorDict = 'anim@mp_helmets@on_foot'
local toggling = false

RegisterCommand('lslegacy_visor', function()
    if toggling then return end

    local ped = PlayerPedId()
    local currentIndex = GetPedPropIndex(ped, 0)
    local newIndex = VisorPairs[currentIndex]

    if not newIndex then return end
    if IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) or IsPedRagdoll(ped) or not IsPedOnFoot(ped) then return end

    toggling = true

    local texture = GetPedPropTextureIndex(ped, 0)
    local closing = newIndex > currentIndex
    local clip = closing and 'visor_down' or 'visor_up'

    RequestAnimDict(visorDict)
    while not HasAnimDictLoaded(visorDict) do Wait(0) end

    TaskPlayAnim(ped, visorDict, clip, 8.0, -8.0, -1, 0, 0, false, false, false)
    RemoveAnimDict(visorDict)

    Wait(500)
    SetPedPropIndex(ped, 0, newIndex, texture, true)

    toggling = false
end, false)

RegisterKeyMapping('lslegacy_visor', 'Lever/baisser la visière du casque', 'keyboard', 'N')
