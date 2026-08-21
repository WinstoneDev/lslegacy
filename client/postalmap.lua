local EnableCayoMiniMap = true

CreateThread(function()
    -- Valeurs reprises du mapzoomdata.meta du pack "DLK HD Map For FiveM"
    -- (DieLikeKane), recalibrées pour les tuiles minimap HD de stream/[PostalMap].
    SetMapZoomDataLevel(0, 0.96, 0.9, 0.08, 0.0, 0.0) -- Level 0
    SetMapZoomDataLevel(1, 1.6, 0.9, 0.08, 0.0, 0.0) -- Level 1
    SetMapZoomDataLevel(2, 8.6, 0.9, 0.08, 0.0, 0.0) -- Level 2
    SetMapZoomDataLevel(3, 12.3, 0.9, 0.08, 0.0, 0.0) -- Level 3
    SetMapZoomDataLevel(4, 24.3, 0.9, 0.08, 0.0, 0.0) -- Level 4
    SetMapZoomDataLevel(5, 55.0, 0.0, 0.1, 2.0, 1.0) -- ZOOM_LEVEL_GOLF_COURSE
    SetMapZoomDataLevel(6, 450.0, 0.0, 0.1, 1.0, 1.0) -- ZOOM_LEVEL_INTERIOR
    SetMapZoomDataLevel(7, 4.5, 0.0, 0.0, 0.0, 0.0) -- ZOOM_LEVEL_GALLERY
    SetMapZoomDataLevel(8, 11.0, 0.0, 0.0, 2.0, 3.0) -- ZOOM_LEVEL_GALLERY_MAXIMIZE
    SetRadarZoom(1200) -- Radar zoom one time on resource start
end)

local function UpdateRadarZoom() -- Some people have reported that the minimap is buggy...
    SetRadarZoom(1100)
    SetTimeout(10000, UpdateRadarZoom)
end

UpdateRadarZoom()

if EnableCayoMiniMap then
    local function CreateBlip()
        local BlipCoords = {
            vec3(4800.85, -6159.22, 0.0),
            vec3(6420.60, -5169.87, 37.43),
        }
        for coords=1, #BlipCoords do
            local coords = BlipCoords[coords]
            local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
            SetBlipSprite(blip, 1)
            SetBlipAlpha(blip, 0)
            SetBlipScale(blip, 0.1)
            SetBlipAsShortRange(blip, true)
        end
    end
    CreateThread(function()
        CreateBlip()
        while true do
            SetRadarAsExteriorThisFrame()
            local coords = vec(4700.0, -5145.0)
            SetRadarAsInteriorThisFrame(`h4_fake_islandx`, coords.x, coords.y, 0, 0)
            Wait(0)
        end
    end)
end