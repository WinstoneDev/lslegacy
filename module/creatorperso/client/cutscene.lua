-- ─── Cutscene d'intro (arrivée en avion façon GTA Online) ────────────────
-- Adapté de https://github.com/Doublox/CutScene, joué juste après la
-- confirmation du personnage (SetIdentity accepté par le serveur) et avant
-- la téléportation au spawn du framework.

local IntroConfig = {
    WeatherType = "EXTRASUNNY",
}

-- Les 7 PNJ passagers de fond font planter le process (crash natif
-- SET_PED_RANDOM_COMPONENT_VARIATION sur cette build du jeu, confirmé en
-- jeu) : désactivés volontairement. Seule la substitution du ped joueur
-- (GeneratePed) reste active, ce qui suffit pour l'effet recherché.
local SKIP_PASSENGERS = true

local pedsList = {
    [0] = "MP_Plane_Passenger_1",
    [1] = "MP_Plane_Passenger_2",
    [2] = "MP_Plane_Passenger_3",
    [3] = "MP_Plane_Passenger_4",
    [4] = "MP_Plane_Passenger_5",
    [5] = "MP_Plane_Passenger_6",
    [6] = "MP_Plane_Passenger_7",
}

local function ClearPedProps(ped)
    for i = 0, 8, 1 do
        ClearPedProp(ped, i)
    end
end

local function HandlePassengersClothes(ped)
    SetPedRandomComponentVariation(ped, 0)
    ClearPedProps(ped)
end

local function GeneratePed(modelString, modelString2, playerId)
    RegisterEntityForCutscene(0, modelString, 3, GetEntityModel(playerId), 0)
    RegisterEntityForCutscene(playerId, modelString, 0, 0, 0)
    SetCutsceneEntityStreamingFlags(modelString, 0, 1)

    local ped = RegisterEntityForCutscene(0, modelString2, 3, 0, 64)
    NetworkSetEntityInvisibleToNetwork(ped, true)
end

-- CreatePed échoue silencieusement (handle 0/invalide) si le modèle n'est
-- pas streamé au préalable ; IsEntityDead(0) ne le détecte pas, d'où le
-- crash natif observé (SET_PED_RANDOM_COMPONENT_VARIATION sur ped invalide).
local function RequestPedModel(modelHash)
    RequestModel(modelHash)
    local waitUntil = GetGameTimer() + 5000
    while not HasModelLoaded(modelHash) and GetGameTimer() < waitUntil do
        Wait(10)
    end
    return HasModelLoaded(modelHash)
end

function LSLegacy.CreatorPerso.PlayIntroCutscene()
    local playerPed = PlayerPedId()
    local isMale = LSLegacy.CreatorPerso.playerSex == 0

    PrepareMusicEvent("FM_INTRO_START")
    TriggerMusicEvent("FM_INTRO_START")

    if isMale then
        RequestCutsceneWithPlaybackList("MP_INTRO_CONCAT", 31, 8)
    else
        RequestCutsceneWithPlaybackList("MP_INTRO_CONCAT", 103, 8)
    end

    while not HasCutsceneLoaded() do Wait(10) end

    if isMale then
        GeneratePed("MP_Male_Character", "MP_Female_Character", playerPed)
    else
        GeneratePed("MP_Female_Character", "MP_Male_Character", playerPed)
    end

    local maleHash = GetHashKey("mp_m_freemode_01")
    local femaleHash = GetHashKey("mp_f_freemode_01")
    local maleLoaded = RequestPedModel(maleHash)
    local femaleLoaded = RequestPedModel(femaleHash)

    local peds = {}
    if not SKIP_PASSENGERS then
        for pedIdx = 0, 6, 1 do
            local isFemalePassenger = (pedIdx == 1 or pedIdx == 2 or pedIdx == 4 or pedIdx == 6)
            local modelHash, modelLoaded = maleHash, maleLoaded
            if isFemalePassenger then
                modelHash, modelLoaded = femaleHash, femaleLoaded
            end

            if modelLoaded then
                peds[pedIdx] = CreatePed(26, modelHash, -1117.77783203125, -1557.6248779296875, 3.3819, 0.0, 0, 0)
            end

            if peds[pedIdx] and DoesEntityExist(peds[pedIdx]) and not IsEntityDead(peds[pedIdx]) then
                HandlePassengersClothes(peds[pedIdx])
                FinalizeHeadBlend(peds[pedIdx])
                RegisterEntityForCutscene(peds[pedIdx], pedsList[pedIdx], 0, 0, 64)
            end
        end
    end

    SetModelAsNoLongerNeeded(maleHash)
    SetModelAsNoLongerNeeded(femaleHash)

    NewLoadSceneStartSphere(-1212.79, -1673.52, 7, 1000, 0)
    SetWeatherTypeNow(IntroConfig.WeatherType)
    StartCutscene(4)

    local CUTSCENE_DURATION = 34000
    Wait(CUTSCENE_DURATION)

    if IsCutscenePlaying() then
        StopCutsceneImmediately()
    end

    for pedIdx = 0, 6, 1 do
        if peds[pedIdx] and DoesEntityExist(peds[pedIdx]) then
            DeleteEntity(peds[pedIdx])
        end
    end

    PrepareMusicEvent("AC_STOP")
    TriggerMusicEvent("AC_STOP")
    LSLegacy.SetCoords(vector3(-1149.811035, -2804.202148, 26.398560))
end
