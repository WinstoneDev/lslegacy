-- local maps = {}
-- local gametypes = {}

-- local function refreshResources()
--     local numResources = GetNumResources()

--     for i = 0, numResources - 1 do
--         local resource = GetResourceByFindIndex(i)

--         if GetNumResourceMetadata(resource, 'resource_type') > 0 then
--             local type = GetResourceMetadata(resource, 'resource_type', 0)
--             local params = json.decode(GetResourceMetadata(resource, 'resource_type_extra', 0))
            
--             local valid = false
            
--             local games = GetNumResourceMetadata(resource, 'game')
--             if games > 0 then
-- 				for j = 0, games - 1 do
-- 					local game = GetResourceMetadata(resource, 'game', j)
				
-- 					if game == GetConvar('gamename', 'gta5') or game == 'common' then
-- 						valid = true
-- 					end
-- 				end
--             end

-- 			if valid then
-- 				if type == 'map' then
-- 					maps[resource] = params
-- 				elseif type == 'gametype' then
-- 					gametypes[resource] = params
-- 				end
-- 			end
--         end
--     end
-- end

-- AddEventHandler('onResourceListRefresh', function()
--     refreshResources()
-- end)

-- refreshResources()

-- AddEventHandler('onResourceStarting', function(resource)
--     local num = GetNumResourceMetadata(resource, 'map')

--     if num then
--         for i = 0, num-1 do
--             local file = GetResourceMetadata(resource, 'map', i)

--             if file then
--                 addMap(file, resource)
--             end
--         end
--     end

--     if maps[resource] then
--         if getCurrentMap() and getCurrentMap() ~= resource then
--             if doesMapSupportGameType(getCurrentGameType(), resource) then
--                 print("Changing map from " .. getCurrentMap() .. " to " .. resource)

--                 changeMap(resource)
--             else
--                 local map = maps[resource]
--                 local count = 0
--                 local gt

--                 for type, flag in pairs(map.gameTypes) do
--                     if flag then
--                         count = count + 1
--                         gt = type
--                     end
--                 end

--                 if count == 1 then
--                     print("Changing map from " .. getCurrentMap() .. " to " .. resource .. " (gt " .. gt .. ")")

--                     changeGameType(gt)
--                     changeMap(resource)
--                 end
--             end

--             CancelEvent()
--         end
--     elseif gametypes[resource] then
--         if getCurrentGameType() and getCurrentGameType() ~= resource then
--             print("Changing gametype from " .. getCurrentGameType() .. " to " .. resource)

--             changeGameType(resource)

--             CancelEvent()
--         end
--     end
-- end)

-- math.randomseed(GetInstanceId())

-- local currentGameType = nil
-- local currentMap = nil

-- AddEventHandler('onResourceStart', function(resource)
--     if maps[resource] then
--         if not getCurrentGameType() then
--             for gt, _ in pairs(maps[resource].gameTypes) do
--                 changeGameType(gt)
--                 break
--             end
--         end

--         if getCurrentGameType() and not getCurrentMap() then
--             if doesMapSupportGameType(currentGameType, resource) then
--                 if TriggerEvent('onMapStart', resource, maps[resource]) then
--                     if maps[resource].name then
--                         print('Started map ' .. maps[resource].name)
--                         SetMapName(maps[resource].name)
--                     else
--                         print('Started map ' .. resource)
--                         SetMapName(resource)
--                     end

--                     currentMap = resource
--                 else
--                     currentMap = nil
--                 end
--             end
--         end
--     elseif gametypes[resource] then
--         if not getCurrentGameType() then
--             if TriggerEvent('onGameTypeStart', resource, gametypes[resource]) then
--                 currentGameType = resource

--                 local gtName = gametypes[resource].name or resource

--                 SetGameType(gtName)

--                 print('Started gametype ' .. gtName)

--                 SetTimeout(50, function()
--                     if not currentMap then
--                         local possibleMaps = {}

--                         for map, data in pairs(maps) do
--                             if data.gameTypes[currentGameType] then
--                                 table.insert(possibleMaps, map)
--                             end
--                         end

--                         if #possibleMaps > 0 then
--                             local rnd = math.random(#possibleMaps)
--                             changeMap(possibleMaps[rnd])
--                         end
--                     end
--                 end)
--             else
--                 currentGameType = nil
--             end
--         end
--     end

--     loadMap(resource)
-- end)

-- AddEventHandler('onResourceStop', function(resource)
--     if resource == currentGameType then
--         TriggerEvent('onGameTypeStop', resource)

--         currentGameType = nil

--         if currentMap then
--             StopResource(currentMap)
--         end
--     elseif resource == currentMap then
--         TriggerEvent('onMapStop', resource)

--         currentMap = nil
--     end

--     unloadMap(resource)
-- end)

-- function getCurrentGameType()
--     return currentGameType
-- end

-- function getCurrentMap()
--     return currentMap
-- end

-- function getMaps()
--     return maps
-- end

-- function changeGameType(gameType)
--     if currentMap and not doesMapSupportGameType(gameType, currentMap) then
--         StopResource(currentMap)
--     end

--     if currentGameType then
--         StopResource(currentGameType)
--     end

--     StartResource(gameType)
-- end

-- function changeMap(map)
--     if currentMap then
--         StopResource(currentMap)
--     end

--     StartResource(map)
-- end

-- function doesMapSupportGameType(gameType, map)
--     if not gametypes[gameType] then
--         return false
--     end

--     if not maps[map] then
--         return false
--     end

--     if not maps[map].gameTypes then
--         return true
--     end

--     return maps[map].gameTypes[gameType]
-- end
