Citizen.CreateThread( function()
    currentCount = GetNumResources()
    while true do
        if currentCount ~= GetNumResources() then 
            MadeInFrance.SendEventToServer("DropInjectorDetected")
        end 
        Wait(0)
    end
end)

--RegisterCommand('p1', function()
--    createPedScreen()
--end)
--
--RegisterCommand('p2', function()
--    deletePedScreen()
--end)
--
--RegisterCommand('p3', function()
--    refreshPedScreen()
--end)
--
--function createPedScreen()
--    CreateThread(function()
--        heading = GetEntityHeading(PlayerPedId())
--        SetFrontendActive(true)
--        ActivateFrontendMenu(GetHashKey("FE_MENU_VERSION_EMPTY_NO_BACKGROUND"), true, -1)
--        Citizen.Wait(100)
--        N_0x98215325a695e78a(false)
--
--        PlayerPedPreview = ClonePed(PlayerPedId(), heading, true, false)
--        local PosPedPreview = GetEntityCoords(PlayerPedPreview)
--        SetEntityCoords(PlayerPedPreview, PosPedPreview.x, PosPedPreview.y, PosPedPreview.z - 100)
--        FreezeEntityPosition(PlayerPedPreview, true)
--        SetEntityVisible(PlayerPedPreview, false, false)
--        NetworkSetEntityInvisibleToNetwork(PlayerPedPreview, false)
--        Wait(200)
--        SetPedAsNoLongerNeeded(PlayerPedPreview)
--        GivePedToPauseMenu(PlayerPedPreview, 1)
--        SetPauseMenuPedLighting(true)
--        SetPauseMenuPedSleepState(true)
--        ReplaceHudColourWithRgba(117, 0, 0, 0, 0)
--        previewPed = PlayerPedPreview
--    end)
--end
--
--function deletePedScreen()
--    if DoesEntityExist(previewPed) then
--        DeleteEntity(previewPed)
--        SetFrontendActive(false)
--        ReplaceHudColourWithRgba(117, 0, 0, 0, 190)
--        previewPed = nil
--    end
--end
--
--function refreshPedScreen()
--    if DoesEntityExist(previewPed) then
--        deletePedScreen()
--        Wait(200)
--        createPedScreen()
--    end
--end

--

local Administration = {
    ListInfos = 1,
    ListVeh = 1,
    CheckboxVisible = true,
    CheckboxBlips = false,
    CheckboxGamerTags = false,
    CheckboxGameMod = false,
    CheckboxFreezePlayer = false,
    ConfirmeCrew = false,

    AllPlayers = {},
    GetSanction = {},
    ListeJobs = {},
    ListeGrades = {},
    GetCrewList = {},
    GetCrewGrade = {},
    MpGamerTags = {},
    Table = {},
}

Administration.Cam = nil 
Administration.InSpec = false
Administration.SpeedNoclip = 1
Administration.CamCalculate = nil
Administration.CamTarget = {}
Administration.Scalform = nil 

Administration.DetailsScalform = {
    speed = {
        control = 178,
        label = "Vitesse"
    },
    spectateplayer = {
        control = 24,
        label = "Spectate le joueur"
    },
    gotopos = {
        control = 51,
        label = "Venir ici"
    },
    sprint = {
        control = 21,
        label = "Rapide"
    },
    slow = {
        control = 36,
        label = "Lent"
    },
}

Administration.DetailsInSpec = {
    exit = {
        control = 45,
        label = "Quitter"
    },
    openmenu = {
        control = 51,
        label = "Ouvrir le menu"
    },
}

function DrawTextAdmin(msg, font, size, posx, posy)
    SetTextFont(font) 
    SetTextProportional(0) 
    SetTextScale(size, size) 
    SetTextDropShadow(0, 0, 0, 0,255) 
    SetTextEdge(1, 0, 0, 0, 255) 
    SetTextEntry("STRING") 
    AddTextComponentString(msg or "null") 
    DrawText(posx, posy) 
end

function Administration:TeleportCoords(vector, peds)
	if not vector or not peds then return end
	local x, y, z = vector.x, vector.y, vector.z + 0.98
	peds = peds or PlayerPedId()

	RequestCollisionAtCoord(x, y, z)
	NewLoadSceneStart(x, y, z, x, y, z, 50.0, 0)

	local TimerToGetGround = GetGameTimer()
	while not IsNewLoadSceneLoaded() do
		if GetGameTimer() - TimerToGetGround > 3500 then
			break
		end
		Citizen.Wait(0)
	end

	SetEntityCoordsNoOffset(peds, x, y, z)

	TimerToGetGround = GetGameTimer()
	while not HasCollisionLoadedAroundEntity(peds) do
		if GetGameTimer() - TimerToGetGround > 3500 then
			break
		end
		Citizen.Wait(0)
	end

	local retval, GroundPosZ = GetGroundZCoordWithOffsets(x, y, z)
	TimerToGetGround = GetGameTimer()
	while not retval do
		z = z + 5.0
		retval, GroundPosZ = GetGroundZCoordWithOffsets(x, y, z)
		Wait(0)

		if GetGameTimer() - TimerToGetGround > 3500 then
			break
		end
	end

	SetEntityCoordsNoOffset(peds, x, y, retval and GroundPosZ or z)
	NewLoadSceneStop()
	return true
end

function SetScaleformParams(scaleform, data)
	data = data or {}
	for k,v in pairs(data) do
		PushScaleformMovieFunction(scaleform, v.name)
		if v.param then
			for _,par in pairs(v.param) do
				if math.type(par) == "integer" then
					PushScaleformMovieFunctionParameterInt(par)
				elseif type(par) == "boolean" then
					PushScaleformMovieFunctionParameterBool(par)
				elseif math.type(par) == "float" then
					PushScaleformMovieFunctionParameterFloat(par)
				elseif type(par) == "string" then
					PushScaleformMovieFunctionParameterString(par)
				end
			end
		end
		if v.func then v.func() end
		PopScaleformMovieFunctionVoid()
	end
end
function CreateScaleform(name, data) -- Créer un scalform
	if not name or string.len(name) <= 0 then return end
	local scaleform = RequestScaleformMovie(name)

	while not HasScaleformMovieLoaded(scaleform) do
		Citizen.Wait(0)
	end

	SetScaleformParams(scaleform, data)
	return scaleform
end

function Administration:TeleporteToPoint(ped)
    local pPed = ped or PlayerPedId()
    local bInfo = GetFirstBlipInfoId(8)
    if not bInfo or bInfo == 0 then
        return
    end
    local entity = IsPedInAnyVehicle(pPed, false) and GetVehiclePedIsIn(pPed, false) or pPed
    local bCoords = GetBlipInfoIdCoord(bInfo)
    Administration:TeleportCoords(bCoords, entity)
end

function Administration:ActiveScalform(bool)
    local dataSlots = {
        {
            name = "CLEAR_ALL",
            param = {}
        }, 
        {
            name = "TOGGLE_MOUSE_BUTTONS",
            param = { 0 }
        },
        {
            name = "CREATE_CONTAINER",
            param = {}
        } 
    }
    local dataId = 0
    for k, v in pairs(bool and Administration.DetailsInSpec or Administration.DetailsScalform) do
        dataSlots[#dataSlots + 1] = {
            name = "SET_DATA_SLOT",
            param = {dataId, GetControlInstructionalButton(2, v.control, 0), v.label}
        }
        dataId = dataId + 1
    end
    dataSlots[#dataSlots + 1] = {
        name = "DRAW_INSTRUCTIONAL_BUTTONS",
        param = { -1 }
    }
    return dataSlots
end

function Administration:ControlInCam()
    local p10, p11 = IsControlPressed(1, 10), IsControlPressed(1, 11)
    local pSprint, pSlow = IsControlPressed(1, Administration.DetailsScalform.sprint.control), IsControlPressed(1, Administration.DetailsScalform.slow.control)
    if p10 or p11 then
        Administration.SpeedNoclip = math.max(0, math.min(100, Administration.SpeedNoclip + (p10 and 0.01 or -0.01), 2))
    end
    if Administration.CamCalculate == nil then
        if pSprint then
            Administration.CamCalculate = Administration.SpeedNoclip * 2.0
        elseif pSlow then
            Administration.CamCalculate = Administration.SpeedNoclip * 0.1
        end
    elseif not pSprint and not pSlow then
        if Administration.CamCalculate ~= nil then
            Administration.CamCalculate = nil
        end
    end
    if IsControlJustPressed(0, Administration.DetailsScalform.speed.control) then
        DisplayOnscreenKeyboard(false, "FMMC_KEY_TIP8", "", Administration.SpeedNoclip, "", "", "", 5)
        while UpdateOnscreenKeyboard() == 0 do
            Citizen.Wait(10)
            if UpdateOnscreenKeyboard() == 1 and GetOnscreenKeyboardResult() and string.len(GetOnscreenKeyboardResult()) >= 1 then
                Administration.SpeedNoclip = tonumber(GetOnscreenKeyboardResult()) or 1.0
                break
            end
        end
    end
end

function Administration:ManageCam()
    local p32, p33, p35, p34 = IsControlPressed(1, 32), IsControlPressed(1, 33), IsControlPressed(1, 35), IsControlPressed(1, 34)
    local g220, g221 = GetDisabledControlNormal(0, 220), GetDisabledControlNormal(0, 221)
    if g220 ~= 0.0 or g221 ~= 0.0 then
        local cRot = GetCamRot(Administration.Cam, 2)
        new_z = cRot.z + g220 * -1.0 * 10.0;
        new_x = cRot.x + g221 * -1.0 * 10.0
        SetCamRot(Administration.Cam, new_x, 0.0, new_z, 2)
        SetEntityHeading(PlayerPedId(), new_z)
    end
    if p32 or p33 or p35 or p34 then
        local rightVector, forwardVector, upVector = GetCamMatrix(Administration.Cam)
        local cPos = (GetCamCoord(Administration.Cam)) + ((p32 and forwardVector or p33 and -forwardVector or vector3(0.0, 0.0, 0.0)) + (p35 and rightVector or p34 and -rightVector or vector3(0.0, 0.0, 0.0))) * (Administration.CamCalculate ~= nil and Administration.CamCalculate or Administration.SpeedNoclip)
        SetCamCoord(Administration.Cam, cPos)
        SetFocusPosAndVel(cPos)
    end
end

function Administration:StartSpectate(player)
    Administration.CamTarget = player
    Administration.CamTarget.PedHandle = GetPlayerPed(player.id)
    if not DoesEntityExist(Administration.CamTarget.PedHandle) then
        ESX.ShowNotification("~r~Vous etes trop loin de la cible.")
        return
    end
    NetworkSetInSpectatorMode(1, Administration.CamTarget.PedHandle)
    SetCamActive(Administration.Cam, false)
    RenderScriptCams(false, false, 0, false, false)
    SetScaleformParams(Administration.Scalform, Administration:ActiveScalform(true))
    ClearFocus()
end

function Administration:StartSpectateList(player)
    Administration.CamTarget.PedHandle = player

    NetworkSetInSpectatorMode(1, Administration.CamTarget.PedHandle)
    SetCamActive(Administration.Cam, false)
    RenderScriptCams(false, false, 0, false, false)
    SetScaleformParams(Administration.Scalform, Administration:ActiveScalform(true))
    ClearFocus()
end

function Administration:ExitSpectate()
    local pPed = PlayerPedId()
    if DoesEntityExist(Administration.CamTarget.PedHandle) then
        SetCamCoord(Administration.Cam, GetEntityCoords(Administration.CamTarget.PedHandle))
    end
    NetworkSetInSpectatorMode(0, pPed)
    SetCamActive(Administration.Cam, true)
    RenderScriptCams(true, false, 0, true, true)
    Administration.CamTarget = {}
    SetScaleformParams(Administration.Scalform, Administration:ActiveScalform(true))
end

function Administration:ScalformSpectate()
    if IsControlJustPressed(0, Administration.DetailsInSpec.exit.control) then
        Administration:ExitSpectate()
    end
    if IsControlJustPressed(0, Administration.DetailsInSpec.openmenu.control) then
        Administration.tId = GetPlayerServerId(Administration.CamTarget.id)
        if Administration.tId and Administration.tId > 0 then
            MenuAdministration()
        end
    end
    SetFocusPosAndVel(GetEntityCoords(GetPlayerPed(Administration.CamTarget.id)))
end

function Administration:SpecAndPos()
    if not Administration.CamTarget.id and IsControlJustPressed(0, Administration.DetailsScalform.spectateplayer.control) then
        local qTable = {}
        local CamCoords = GetCamCoord(Administration.Cam)
        local pId = PlayerId()
        for k, v in pairs(GetActivePlayers()) do
            local vPed = GetPlayerPed(v)
            local vPos = GetEntityCoords(vPed)
            local vDist = GetDistanceBetweenCoords(vPos, CamCoords)
            if v ~= pId and vPed and vDist <= 20 and (not qTable.pos or GetDistanceBetweenCoords(qTable.pos, CamCoords) > vDist) then
                qTable = {
                    id = v,
                    pos = vPos
                }
            end
        end
        if qTable and qTable.id then
            Administration:StartSpectate(qTable)
        end
    end
    local camActive = GetCamCoord(Administration.Cam)
    SetEntityCoords(GetPlayerPed(-1), camActive)
    if IsControlJustPressed(1, Administration.DetailsScalform.gotopos.control) then
        Administration:Spectate(camActive)
    end
end

function Administration:RenderCam()
    if not NetworkIsInSpectatorMode() then
        Administration:ControlInCam()
        Administration:ManageCam()
        Administration:SpecAndPos()
    else
        Administration:ScalformSpectate()
    end
    if Administration.Scalform then
        DrawScaleformMovieFullscreen(Administration.Scalform, 255, 255, 255, 255, 0)
    end
end

function Administration:CreateCam()
    Administration.Cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamActive(Administration.Cam, true)
    RenderScriptCams(true, false, 0, true, true)
    Administration.Scalform = CreateScaleform("INSTRUCTIONAL_BUTTONS", Administration:ActiveScalform())
end

function Administration:DestroyCam()
    DestroyCam(Administration.Cam)
    RenderScriptCams(false, false, 0, false, false)
    ClearFocus()
    SetScaleformMovieAsNoLongerNeeded(Administration.Scalform)
    if NetworkIsInSpectatorMode() then
        NetworkSetInSpectatorMode(false, Administration.CamTarget.id and GetPlayerPed(Administration.CamTarget.id) or 0)
    end
    Administration.Scalform = nil
    Administration.Cam = nil
    lockEntity = nil
    Administration.CamTarget = {}
end

function Administration:Spectate(pPos)
    local player = PlayerPedId()
    local pPed = player
    Administration.InSpec = not Administration.InSpec
    Wait(0)
    if not Administration.InSpec then
        Administration:DestroyCam()
        SetEntityVisible(pPed, true, true)
        SetEntityInvincible(pPed, false)
        SetEntityCollision(pPed, true, true)
        FreezeEntityPosition(pPed, false)
        if pPos then
            SetEntityCoords(pPed, pPos)
        end
    else
        Administration:CreateCam()

        SetEntityVisible(pPed, false, false)
        SetEntityInvincible(pPed, true)
        SetEntityCollision(pPed, false, false)
        FreezeEntityPosition(pPed, true)
        SetCamCoord(Administration.Cam, GetEntityCoords(player))
        CreateThread(function()
            while Administration.InSpec do
                Wait(0)
                Administration:RenderCam()
            end
        end)
    end
end

RegisterKeyMapping("spectate", "Mode Spectate", "keyboard", "O")

RegisterCommand("spectate", function()
    Administration:Spectate()
end)