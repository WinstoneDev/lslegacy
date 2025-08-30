Callbacks = {}

Callbacks.requests = {}
Callbacks.storage = {}
Callbacks.id = 0

function Callbacks:Register(name, resource, cb)
    self.storage[name] = {
        resource = resource,
        cb = cb
    }
end

function Callbacks:Execute(cb, ...)
    local success, errorString = pcall(cb, ...)

    if not success then
        Config.Development.Print(("[^1ERREUR^7] Échec de l'exécution du callback avec identifiant de requête : ^5%s^7"):format(self.currentId))
        Config.Development.Print("^3Erreur du callback:^7 " .. tostring(errorString))  -- juste journaliser, ne pas lancer d'erreur
        self.currentId = nil
        return
    end

    self.currentId = nil
end

function Callbacks:Trigger(player, event, cb, invoker, ...)
    self.requests[self.id] = {
        await = type(cb) == "boolean",
        cb = cb or promise:new()
    }
    local table = self.requests[self.id]

    TriggerClientEvent("esx:triggerClientCallback", player, event, self.id, invoker, ...)

    self.id += 1

    return table.cb
end

function Callbacks:ServerRecieve(player, event, requestId, invoker, ...)
    self.currentId = requestId

    if not self.storage[event] then
        return error(("Le callback serveur avec identifiant de requête ^5%s^1 a été appelé par ^5%s^1 mais n'existe pas."):format(event, invoker))
    end

    local returnCb = function(...)
        TriggerClientEvent("esx:serverCallback", player, requestId, invoker, ...)
    end
    local callback = self.storage[event].cb

    self:Execute(callback, player, returnCb, ...)
end

function Callbacks:RecieveClient(requestId, invoker, ...)
    self.currentId = requestId

    if not self.requests[self.currentId] then
        return error(("Le callback client avec identifiant de requête ^5%s^1 a été appelé par ^5%s^1 mais n'existe pas."):format(self.currentId, invoker))
    end

    local callback = self.requests[self.currentId]

    self.requests[requestId] = nil
    if callback.await then
        callback.cb:resolve({ ... })
    else
        self:Execute(callback.cb, ...)
    end
end


---@param player number idDuJoueur
---@param eventName string
---@param callback function
---@param ... any
function LSLegacy.TriggerClientCallback(player, eventName, callback, ...)
    local invokingResource = GetInvokingResource()
    local invoker = (invokingResource and invokingResource ~= "Unknown") and invokingResource or "lslegacy"

    Callbacks:Trigger(player, eventName, callback, invoker, ...)
end

---@param player number idDuJoueur
---@param eventName string
---@param ... any
---@return ...
function LSLegacy.AwaitClientCallback(player, eventName, ...)
    local invokingResource = GetInvokingResource()
    local invoker = (invokingResource and invokingResource ~= "Unknown") and invokingResource or "lslegacy"

    local p = Callbacks:Trigger(player, eventName, false, invoker, ...)
    if not p then return end

    SetTimeout(15000, function()
        if p.state == "pending" then
            p:reject("Délai d'attente du callback serveur dépassé")
        end
    end)

    Citizen.Await(p)

    return table.unpack(p.value)
end

---@param eventName string
---@param callback function
---@return nil
function LSLegacy.RegisterServerCallback(eventName, callback)
    local invokingResource = GetInvokingResource()
    local invoker = (invokingResource and invokingResource ~= "Unknown") and invokingResource or "lslegacy"

    Callbacks:Register(eventName, invoker, callback)
end

---@param eventName string
---@return boolean
function LSLegacy.DoesServerCallbackExist(eventName)
    return Callbacks.storage[eventName] ~= nil
end


LSLegacy.RegisterServerEvent('clientCallback', function(requestId, invoker, ...)
    Callbacks:RecieveClient(requestId, invoker, ...)
end)

LSLegacy.RegisterServerEvent('triggerServerCallback', function(eventName, requestId, invoker, ...)
    local source = source
    Callbacks:ServerRecieve(source, eventName, requestId, invoker, ...)
end)

LSLegacy.AddEventHandler("onResourceStop", function(resource)
    for k, v in pairs(Callbacks.storage) do
        if v.resource == resource then
            Callbacks.storage[k] = nil
        end
    end
end)