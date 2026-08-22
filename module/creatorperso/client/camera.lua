function AnimationIntro()
    FreezeEntityPosition(PlayerPedId(), false)
    CreateBoard()
    SetEntityCoords(GetPlayerPed(-1), 406.03, -997.09, -100.00)
    SetEntityHeading(GetPlayerPed(-1), 93.19)
    RequestAnimDict('mp_character_creation@customise@male_a')
    while not HasAnimDictLoaded('mp_character_creation@customise@male_a') do
        Wait(10)
    end
    Wait(100)
    TaskPlayAnim(PlayerPedId(), "mp_character_creation@customise@male_a", "intro", 8.0, -8.0, -1, 0, 0.0, false, false, false)
    Wait(4685)
    TaskPlayAnim(GetPlayerPed(-1), "mp_character_creation@customise@male_a", "loop", 1.0, -1.0,-1, 2, 0, 0, 0, 0)
end

local boardModel = GetHashKey("prop_police_id_board")
local overlayModel = GetHashKey("prop_police_id_text")

-- Cadrage "vue d'ensemble" validé en jeu (relevé via spectate/debug :
-- vec3(402.975830, -999.257141, -97.700317), heading 0.0). Personnage et
-- tapis parfaitement centrés, backdrop droit derrière.
local OVERVIEW_CAM_COORD = vector3(402.975830, -999.257141, -97.700317)
local OVERVIEW_CAM_ROT = vector3(-20.0, 0.0, 0.0)

function LoadScaleform(scaleform)
	local handle = RequestScaleformMovie(scaleform)
	if handle ~= 0 then
		while not HasScaleformMovieLoaded(handle) do
			Wait(0)
		end
	end
	return handle
end

function CreateNamedRenderTargetForModel(name, model)
	local handle = 0
	if not IsNamedRendertargetRegistered(name) then
		RegisterNamedRendertarget(name, 0)
	end
	if not IsNamedRendertargetLinked(model) then
		LinkNamedRendertarget(model)
	end
	if IsNamedRendertargetRegistered(name) then
		handle = GetNamedRendertargetRenderId(name)
	end

	return handle
end

Citizen.CreateThread(function()
	board_scaleform = LoadScaleform("mugshot_board_01")
	handle = CreateNamedRenderTargetForModel("ID_Text", overlayModel)

	while handle do
		SetTextRenderId(handle)
		Set_2dLayer(4)
		Citizen.InvokeNative(0xC6372ECD45D73BCD, 1)
		DrawScaleformMovie(board_scaleform, 0.405, 0.37, 0.81, 0.74, 255, 255, 255, 255, 0)
		Citizen.InvokeNative(0xC6372ECD45D73BCD, 0)
		SetTextRenderId(GetDefaultScriptRendertargetRenderId())

		Citizen.InvokeNative(0xC6372ECD45D73BCD, 1)
		Citizen.InvokeNative(0xC6372ECD45D73BCD, 0)
		Wait(0)
	end
end)

function CallScaleformMethod(scaleform, method, ...)
	local t
	local args = { ... }

	BeginScaleformMovieMethod(scaleform, method)

	for k, v in ipairs(args) do
		t = type(v)
		if t == 'string' then
			PushScaleformMovieMethodParameterString(v)
		elseif t == 'number' then
			if string.match(tostring(v), "%.") then
				PushScaleformMovieFunctionParameterFloat(v)
			else
				PushScaleformMovieFunctionParameterInt(v)
			end
		elseif t == 'boolean' then
			PushScaleformMovieMethodParameterBool(v)
		end
	end
	EndScaleformMovieMethod()
end

local BoardInPerso = {}

function CreateBoard()
    RequestModel(boardModel)
    while not HasModelLoaded(boardModel) do Wait(0) end
    RequestModel(overlayModel)
    while not HasModelLoaded(overlayModel) do Wait(0) end
    BoardInPerso.board = CreateObject(boardModel, GetEntityCoords(PlayerPedId()), false, true, false)
    BoardInPerso.overlay = CreateObject(overlayModel, GetEntityCoords(PlayerPedId()), false, true, false)
    AttachEntityToEntity(BoardInPerso.overlay, BoardInPerso.board, -1, 4103, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
    ClearPedWetness(PlayerPedId())
    ClearPedBloodDamage(PlayerPedId())
    ClearPlayerWantedLevel(PlayerId())
    SetCurrentPedWeapon(PlayerPedId(), GetHashKey("weapon_unarmed"), 1)
    AttachEntityToEntity(BoardInPerso.board, PlayerPedId(), GetPedBoneIndex(PlayerPedId(), 28422), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 2, 1)
    CallScaleformMethod(board_scaleform, 'SET_BOARD', 'Chomeur', 'LS Legacy', 'LOS SANTOS POLICE DEPT', '' , 0, 15)
end

function DeleteBoard()
    if BoardInPerso.board and DoesEntityExist(BoardInPerso.board) then
        DetachEntity(BoardInPerso.board, true, false)
        DeleteEntity(BoardInPerso.board)
    end
    if BoardInPerso.overlay and DoesEntityExist(BoardInPerso.overlay) then
        DeleteEntity(BoardInPerso.overlay)
    end
    BoardInPerso.board = nil
    BoardInPerso.overlay = nil
end

local _Cam

function RegenCreatorCam()
    _Cam = CamCreatorInit()
    creatorPitchOffset = 0.0
end

function GetCreatorCam()
    return _Cam
end

-- ─── Zoom à la molette ───────────────────────────────────────────────────────
-- Ajuste le FOV (donc le niveau de zoom) des deux caméras du créateur, quelle
-- que soit celle actuellement active/affichée, pour rester synchronisées.
local MIN_ZOOM_FOV = 8.0
local MAX_ZOOM_FOV = 45.0

function CreatorZoomAdjust(delta)
    local cam = GetCreatorCam()
    if not cam then return end
    for _, c in ipairs({ cam.f_466, cam.f_465 }) do
        if c and DoesCamExist(c) then
            local newFov = GetCamFov(c) + delta
            newFov = math.max(MIN_ZOOM_FOV, math.min(MAX_ZOOM_FOV, newFov))
            SetCamFov(c, newFov)
        end
    end
end

-- ─── Regard à la souris (clic gauche maintenu + déplacement) ─────────────────
-- Inclinaison (tangage) de la caméra, sans jamais déplacer sa position — le
-- personnage lui-même gère l'axe horizontal (voir LSLegacy.CreatorPerso.RotateCharacter).
local MIN_PITCH_OFFSET = -15.0
local MAX_PITCH_OFFSET = 15.0
creatorPitchOffset = 0.0

function CreatorLookAdjust(deltaPitch)
    local cam = GetCreatorCam()
    if not cam or not deltaPitch or deltaPitch == 0 then return end

    local newOffset = math.max(MIN_PITCH_OFFSET, math.min(MAX_PITCH_OFFSET, creatorPitchOffset + deltaPitch))
    local applied = newOffset - creatorPitchOffset
    creatorPitchOffset = newOffset
    if applied == 0 then return end

    for _, c in ipairs({ cam.f_466, cam.f_465 }) do
        if c and DoesCamExist(c) then
            local rot = GetCamRot(c, 2)
            SetCamRot(c, rot.x + applied, rot.y, rot.z, 2)
        end
    end
end

function CreatorLoadContent()
    SetOverrideWeather("EXTRASUNNY")
    SetWeatherTypePersist("EXTRASUNNY")
    RegenCreatorCam()
    RequestScriptAudioBank("DLC_GTAO/MUGSHOT_ROOM", false, -1)
    RequestScriptAudioBank("Mugshot_Character_Creator", false, -1)
    Stage_01(_Cam)
    Stage_01_A(_Cam)
    RenderScriptCams(true, false, 3000, 1, 0, 0)
end

-- Règle la profondeur de champ (DOF) d'une caméra (natives DOF non documentées).
function SetCamDepthOfField(camera, arg1, arg2, arg3, arg4)
    -- DOF désactivé volontairement (flou du creator perso retiré)
end


function CamCreatorInit()
    local _Cam = {
        f_466 = CreateCam("DEFAULT_SCRIPTED_CAMERA", false),
        f_465 = CreateCam("DEFAULT_SCRIPTED_CAMERA", false)
    }
    _Cam.f_466 = CreateCam("DEFAULT_SCRIPTED_CAMERA", false)
    _Cam.f_465 = CreateCam("DEFAULT_SCRIPTED_CAMERA", false)
    return _Cam
end


function Stage_01(uParam0)
    SetCamCoord(uParam0.f_466, OVERVIEW_CAM_COORD.x, OVERVIEW_CAM_COORD.y, OVERVIEW_CAM_COORD.z)
    SetCamRot(uParam0.f_466, OVERVIEW_CAM_ROT.x, OVERVIEW_CAM_ROT.y, OVERVIEW_CAM_ROT.z, 2)
    SetCamFov(uParam0.f_466, 36.95373)
    SetCamDepthOfField(uParam0.f_466, 3, 1, 1.2, 1)
    SetCamActive(uParam0.f_466, true)
    StopCamShaking(uParam0.f_466, 1)
end

function Stage_01_A(uParam0)
    SetCamCoord(uParam0.f_465, OVERVIEW_CAM_COORD.x, OVERVIEW_CAM_COORD.y, OVERVIEW_CAM_COORD.z)
    SetCamRot(uParam0.f_465, OVERVIEW_CAM_ROT.x, OVERVIEW_CAM_ROT.y, OVERVIEW_CAM_ROT.z, 2)
    SetCamFov(uParam0.f_465, 36.95373)
    SetCamDepthOfField(uParam0.f_465, 7, 1, 1, 1)
    SetCamActive(uParam0.f_465, true)
    StopCamShaking(uParam0.f_465, 1)
    SetCamActiveWithInterp(uParam0.f_466, uParam0.f_465, 6000, 1, 1)
end

-- Ramène la caméra en position "vue d'ensemble" en interpolant depuis la
-- caméra gameplay courante (utilisé par CreatorZoomOut).
function ResetToOverviewCam(uParam0)
    local vVar0 = GetGameplayCamCoords()
    local vVar1 = GetCamRot(uParam0.f_465, 2)
    local fVar2 = Citizen.InvokeNative(0x80ec114669daeff4)

    SetCamCoord(uParam0.f_465, vVar0)
    SetCamRot(uParam0.f_465, vVar1, 2)
    SetCamFov(uParam0.f_465, fVar2)
    SetCamDepthOfField(uParam0.f_465, 3.8, 1, 1.2, 1)
    SetCamActive(uParam0.f_465, true)

    StopCamShaking(uParam0.f_465, 1)
    SetCamCoord(uParam0.f_466, OVERVIEW_CAM_COORD.x, OVERVIEW_CAM_COORD.y, OVERVIEW_CAM_COORD.z)
    SetCamRot(uParam0.f_466, OVERVIEW_CAM_ROT.x, OVERVIEW_CAM_ROT.y, OVERVIEW_CAM_ROT.z, 2)
    SetCamFov(uParam0.f_466, 36.95373)
    StopCamShaking(uParam0.f_466, 1)
    SetCamDepthOfField(uParam0.f_466, 3, 1, 1.2, 1)
    SetCamActiveWithInterp(uParam0.f_466, uParam0.f_465, 300, 1, 1)
end

-- Cadrage en gros plan sur le visage. iParam1: 1 = personnalisation, 2 = prise
-- de photo/sortie. `Stats` sélectionne un angle de cadrage alternatif.
function ApplyCloseUpCam(uParam0, iParam1, Stats)
    local vVar0 = GetGameplayCamCoords()
    local vVar1 = GetCamRot(uParam0.f_465, 2)
    local fVar2 = Citizen.InvokeNative(0x80ec114669daeff4)
    SetCamCoord(uParam0.f_465, vVar0)
    SetCamRot(uParam0.f_465, vVar1, 2)
    SetCamFov(uParam0.f_465, fVar2)
    SetCamDepthOfField(uParam0.f_465, 3.0, 1.0, 1.2, 1.0)
    SetCamActive(uParam0.f_465, true)
    StopCamShaking(uParam0.f_465, 1)
    if (iParam1 == 1) then
        --- Custom
        if not (Stats) then
            SetCamCoord(uParam0.f_466, 403.150, -1000.55, -98.41412)
            SetCamRot(uParam0.f_466, 2.254577, 0, 0.893029, 2)
            SetCamFov(uParam0.f_466, 9.999582)
            SetCamDepthOfField(uParam0.f_466, 3.8, 1.0, 1.2, 1.0)
        else
            SetCamCoord(uParam0.f_466, 403.150, -1000.622, -98.41412)
            SetCamRot(uParam0.f_466, 1.260873, 0, 0.834392, 2)
            SetCamFov(uParam0.f_466, 10.01836)
            SetCamDepthOfField(uParam0.f_466, 3.8, 1.0, 1.2, 1.0)
        end
    else
        --- Take picture and exit
        if not (Stats) then
            SetCamCoord(uParam0.f_466, 403.300, -1000.129, -98.41554)
            SetCamRot(uParam0.f_466, 2.366912, 0, -2.14811, 2)
            SetCamFov(uParam0.f_466, 9.958394)
            SetCamDepthOfField(uParam0.f_466, 4.0, 1.0, 1.2, 1.0)
        else
            SetCamCoord(uParam0.f_466, 403.300, -1000.129, -98.41554)
            SetCamRot(uParam0.f_466, 0.861356, 0, -2.348183, 2)
            SetCamFov(uParam0.f_466, 10.00255)
            SetCamDepthOfField(uParam0.f_466, 4.0, 1.0, 1.2, 1.0)
        end
    end
    StopCamShaking(uParam0.f_466, 1)
    SetCamActiveWithInterp(uParam0.f_466, uParam0.f_465, 300, 1, 1)
end

function CreatorZoomIn(_Cam)
    PlaySoundFrontend(-1, "Zoom_In", "MUGSHOT_CHARACTER_CREATION_SOUNDS", 0, 0, 1)
    if (GetEntityModel(PlayerPedId()) == GetHashKey("mp_m_freemode_01")) then
        ApplyCloseUpCam(_Cam, 1, 1)
    else
        ApplyCloseUpCam(_Cam, 1, 0)
    end
    RenderScriptCams(true, false, 3000, 1, 0, 0)
end

function CreatorZoomOut(_Cam)
    PlaySoundFrontend(-1, "Zoom_Out", "MUGSHOT_CHARACTER_CREATION_SOUNDS", 0, 0, 1)
    ResetToOverviewCam(_Cam)
    RenderScriptCams(true, false, 3000, 1, 0, 0)
end

function CreatorTakePictureIn(_Cam)
    PlaySoundFrontend(-1, "Zoom_In", "MUGSHOT_CHARACTER_CREATION_SOUNDS", 0, 0, 1)
    if (GetEntityModel(PlayerPedId()) == GetHashKey("mp_m_freemode_01")) then
        ApplyCloseUpCam(_Cam, 2, 1)
    else
        ApplyCloseUpCam(_Cam, 2, 0)
    end
    RenderScriptCams(false, false, 3000, 1, 0, 0)

    SetFocusEntity(PlayerPedId())
end