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

local board_model = GetHashKey("prop_police_id_board")
local overlay_model = GetHashKey("prop_police_id_text")

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
	handle = CreateNamedRenderTargetForModel("ID_Text", overlay_model)

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
    RequestModel(board_model)
    while not HasModelLoaded(board_model) do Wait(0) end
    RequestModel(overlay_model)
    while not HasModelLoaded(overlay_model) do Wait(0) end
    BoardInPerso.board = CreateObject(board_model, GetEntityCoords(PlayerPedId()), false, true, false)
    BoardInPerso.overlay = CreateObject(overlay_model, GetEntityCoords(PlayerPedId()), false, true, false)
    AttachEntityToEntity(BoardInPerso.overlay, BoardInPerso.board, -1, 4103, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
    ClearPedWetness(PlayerPedId())
    ClearPedBloodDamage(PlayerPedId())
    ClearPlayerWantedLevel(PlayerId())
    SetCurrentPedWeapon(PlayerPedId(), GetHashKey("weapon_unarmed"), 1)
    AttachEntityToEntity(BoardInPerso.board, PlayerPedId(), GetPedBoneIndex(PlayerPedId(), 28422), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 2, 1)
    CallScaleformMethod(board_scaleform, 'SET_BOARD', 'Chomeur', 'Los Santos', 'LOS SANTOS POLICE DEPT', '' , 0, 15)
end

function DeleteBoard()
    DeleteEntity(BoardInPerso.board)
    DeleteEntity(BoardInPerso.overlay)
    DeleteEntity(BoardInPerso.board)
    DeleteEntity(BoardInPerso.overlay)
end

local _Cam

function RegenCreatorCam()
    _Cam = CamCreatorInit()
end

function GetCreatorCam()
    return _Cam
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

function func_1673(camera, arg1, arg2, arg3, arg4)
    Citizen.InvokeNative(0xF55E4046F6F831DC, camera, arg1)
    Citizen.InvokeNative(0xE111A7C0D200CBC5, camera, arg2)
    SetCamDofFnumberOfLens(camera, arg3)
    SetCamDofMaxNearInFocusDistanceBlendLevel(camera, arg4)
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
    SetCamCoord(uParam0.f_466, 402.7553, -1000.622, -98.48412)
    SetCamRot(uParam0.f_466, -6.716503, 0, -0.276376, 2)
    SetCamFov(uParam0.f_466, 36.95373)
    func_1673(uParam0.f_466, 3, 1, 1.2, 1)
    SetCamActive(uParam0.f_466, true)
    StopCamShaking(uParam0.f_466, 1)
end

function Stage_01_A(uParam0)
    SetCamCoord(uParam0.f_465, 402.7391, -1003.981, -98.43439)
    SetCamRot(uParam0.f_465, -3.589798, 0, -0.276381, 2)
    SetCamFov(uParam0.f_465, 36.95373)
    func_1673(uParam0.f_465, 7, 1, 1, 1)
    SetCamActive(uParam0.f_465, true)
    StopCamShaking(uParam0.f_465, 1)
    SetCamActiveWithInterp(uParam0.f_466, uParam0.f_465, 6000, 1, 1)
end

function func_1678(uParam0)
    local vVar0 = GetGameplayCamCoords()
    local vVar1 = GetCamRot(uParam0.f_465, 2)
    local fVar2 = Citizen.InvokeNative(0x80ec114669daeff4)

    SetCamCoord(uParam0.f_465, vVar0)
    SetCamRot(uParam0.f_465, vVar1, 2)
    SetCamFov(uParam0.f_465, fVar2)
    func_1673(uParam0.f_465, 3.8, 1, 1.2, 1)
    SetCamActive(uParam0.f_465, true)

    StopCamShaking(uParam0.f_465, 1)
    SetCamCoord(uParam0.f_466, 402.7553, -1000.622, -98.48412)
    SetCamRot(uParam0.f_466, -6.716503, 0, -0.276376, 2)
    SetCamFov(uParam0.f_466, 36.95373)
    StopCamShaking(uParam0.f_466, 1)
    func_1673(uParam0.f_466, 3, 1, 1.2, 1)
    SetCamActiveWithInterp(uParam0.f_466, uParam0.f_465, 300, 1, 1)
end

function func_1675(uParam0, iParam1, Stats)
    local vVar0 = GetGameplayCamCoords()
    local vVar1 = GetCamRot(uParam0.f_465, 2)
    local fVar2 = Citizen.InvokeNative(0x80ec114669daeff4)
    SetCamCoord(uParam0.f_465, vVar0)
    SetCamRot(uParam0.f_465, vVar1, 2)
    SetCamFov(uParam0.f_465, fVar2)
    func_1673(uParam0.f_465, 3.0, 1.0, 1.2, 1.0)
    SetCamActive(uParam0.f_465, true)
    StopCamShaking(uParam0.f_465, 1)
    if (iParam1 == 1) then
        --- Custom
        if not (Stats) then
            SetCamCoord(uParam0.f_466, 402.7553, -1000.55, -98.48412)
            SetCamRot(uParam0.f_466, 2.254577, 0, 0.893029, 2)
            SetCamFov(uParam0.f_466, 9.999582)
            func_1673(uParam0.f_466, 3.8, 1.0, 1.2, 1.0)
        else
            SetCamCoord(uParam0.f_466, 402.7553, -1000.622, -98.48412)
            SetCamRot(uParam0.f_466, 1.260873, 0, 0.834392, 2)
            SetCamFov(uParam0.f_466, 10.01836)
            func_1673(uParam0.f_466, 3.8, 1.0, 1.2, 1.0)
        end
    else
        --- Take picture and exit
        if not (Stats) then
            SetCamCoord(uParam0.f_466, 402.6852, -1000.129, -98.46554)
            SetCamRot(uParam0.f_466, 2.366912, 0, -2.14811, 2)
            SetCamFov(uParam0.f_466, 9.958394)
            func_1673(uParam0.f_466, 4.0, 1.0, 1.2, 1.0)
        else
            SetCamCoord(uParam0.f_466, 402.6852, -1000.129, -98.46554)
            SetCamRot(uParam0.f_466, 0.861356, 0, -2.348183, 2)
            SetCamFov(uParam0.f_466, 10.00255)
            func_1673(uParam0.f_466, 4.0, 1.0, 1.2, 1.0)
        end
    end
    StopCamShaking(uParam0.f_466, 1)
    SetCamActiveWithInterp(uParam0.f_466, uParam0.f_465, 300, 1, 1)
end

function CreatorZoomIn(_Cam)
    PlaySoundFrontend(-1, "Zoom_In", "MUGSHOT_CHARACTER_CREATION_SOUNDS", 0, 0, 1)
    if (GetEntityModel(PlayerPedId()) == GetHashKey("mp_m_freemode_01")) then
        func_1675(_Cam, 1, 1)
    else
        func_1675(_Cam, 1, 0)
    end
    RenderScriptCams(true, false, 3000, 1, 0, 0)
end

function CreatorZoomOut(_Cam)
    PlaySoundFrontend(-1, "Zoom_Out", "MUGSHOT_CHARACTER_CREATION_SOUNDS", 0, 0, 1)
    func_1678(_Cam)
    RenderScriptCams(true, false, 3000, 1, 0, 0)
end

function CreatorTakePictureIn(_Cam)
    PlaySoundFrontend(-1, "Zoom_In", "MUGSHOT_CHARACTER_CREATION_SOUNDS", 0, 0, 1)
    if (GetEntityModel(PlayerPedId()) == GetHashKey("mp_m_freemode_01")) then
        func_1675(_Cam, 2, 1)
    else
        func_1675(_Cam, 2, 0)
    end
    RenderScriptCams(false, false, 3000, 1, 0, 0)

    SetFocusEntity(PlayerPedId())
end

function ButtonMessage(text)
    BeginTextCommandScaleformString("STRING")
    AddTextComponentScaleform(text)
    EndTextCommandScaleformString()
end

function setupScaleform()
    local scaleform = RequestScaleformMovie("instructional_buttons")

    PushScaleformMovieFunction(scaleform, "CLEAR_ALL")
    PopScaleformMovieFunctionVoid()

    PushScaleformMovieFunction(scaleform, "SET_CLEAR_SPACE")
    PushScaleformMovieFunctionParameterInt(200)
    PopScaleformMovieFunctionVoid()

    PushScaleformMovieFunction(scaleform, "SET_DATA_SLOT")
    PushScaleformMovieFunctionParameterInt(1)
    N_0xe83a3e3557a56640(GetControlInstructionalButton(2, 51, true))
    ButtonMessage("Tourner votre personnage à droite")
    PopScaleformMovieFunctionVoid()

    PushScaleformMovieFunction(scaleform, "SET_DATA_SLOT")
    PushScaleformMovieFunctionParameterInt(0)
    N_0xe83a3e3557a56640(GetControlInstructionalButton(2, 44, true))
    ButtonMessage("Tourner votre personnage à gauche")
    PopScaleformMovieFunctionVoid()

    PushScaleformMovieFunction(scaleform, "DRAW_INSTRUCTIONAL_BUTTONS")
    PopScaleformMovieFunctionVoid()

    PushScaleformMovieFunction(scaleform, "SET_BACKGROUND_COLOUR")
    PushScaleformMovieFunctionParameterInt(0)
    PushScaleformMovieFunctionParameterInt(0)
    PushScaleformMovieFunctionParameterInt(0)
    PushScaleformMovieFunctionParameterInt(80)
    PopScaleformMovieFunctionVoid()

    return scaleform
end