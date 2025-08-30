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

function Callbacks:Execute(cb, id, ...)
    local success, errorString = pcall(cb, ...)

    if not success then
        print(("[^1ERREUR^7] Échec d'exécution du callback avec RequestId : ^5%s^7"):format(id))
        error(errorString)
        return
    end
end

function Callbacks:Trigger(event, cb, invoker, ...)
    self.requests[self.id] = {
        await = type(cb) == "boolean",
        cb = cb or promise:new()
    }
    local table = self.requests[self.id]

    TriggerServerEvent("esx:triggerServerCallback", event, self.id, invoker, ...)

    self.id += 1

    return table.cb
end

function Callbacks:ServerRecieve(requestId, invoker, ...)
    if not self.requests[requestId] then
        return error(("Le callback serveur avec requestId ^5%s^1 a été appelé par ^5%s^1 mais n'existe pas."):format(requestId, invoker))
    end

    local callback = self.requests[requestId]

    self.requests[requestId] = nil

    if callback.await then
        callback.cb:resolve({ ... })
    else
        self:Execute(callback.cb, requestId, ...)
    end
end

function Callbacks:ClientRecieve(eventName, requestId, invoker, ...)
    if not self.storage[eventName] then
        return error(("Le callback client avec requestId ^5%s^1 a été appelé par ^5%s^1 mais n'existe pas."):format(eventName, invoker))
    end

    local returnCb = function(...)
        TriggerServerEvent("esx:clientCallback", requestId, invoker, ...)
    end
    local callback = self.storage[eventName].cb

    self:Execute(callback, requestId, returnCb, ...)
end

---@param eventName string
---@param callback function
---@param ... any
---@return nil
function LSLegacy.TriggerServerCallback(eventName, callback, ...)
    local invokingResource = GetInvokingResource()
    local invoker = (invokingResource and invokingResource ~= "unknown") and invokingResource or "lslegacy"

    Callbacks:Trigger(eventName, callback, invoker, ...)
end

---@param eventName string
---@param ... any
---@return ...
function LSLegacy.AwaitServerCallback(eventName, ...)
    local invokingResource = GetInvokingResource()
    local invoker = (invokingResource and invokingResource ~= "unknown") and invokingResource or "lslegacy"

    local p = Callbacks:Trigger(eventName, false, invoker, ...)
    if not p then return end

    -- si le callback serveur prend plus de 15 secondes à répondre, rejette la promesse
    SetTimeout(15000, function()
        if p.state == "pending" then
            p:reject("Le callback serveur a expiré")
        end
    end)

    Citizen.Await(p)

    return table.unpack(p.value)
end

function LSLegacy.RegisterClientCallback(eventName, callback)
    local invokingResource = GetInvokingResource()
    local invoker = (invokingResource and invokingResource ~= "Unknown") and invokingResource or "lslegacy"

    Callbacks:Register(eventName, invoker, callback)
end

---@param eventName string
---@return boolean
function LSLegacy.DoesClientCallbackExist(eventName)
    return Callbacks.storage[eventName] ~= nil
end

LSLegacy.RegisterClientEvent("serverCallback", function(...)
    Callbacks:ServerRecieve(...)
end)

LSLegacy.RegisterClientEvent("triggerClientCallback", function(...)
    Callbacks:ClientRecieve(...)
end)

LSLegacy.AddEventHandler("onResourceStop", function(resource)
    for k, v in pairs(Callbacks.storage) do
        if v.resource == resource then
            Callbacks.storage[k] = nil
        end
    end
end)