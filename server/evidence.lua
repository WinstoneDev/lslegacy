-- Sauvegarde disque + envoi Discord des preuves (screenshots/vidéos) capturées via screencapture.
-- Utilisé par server/anticheat.lua (ban/kick) et module/adminmenu/server/main.lua (capture manuelle).
-- Toujours vers les webhooks déjà existants (Shared.Anticheat.WebhookDiscord/OCRWebhook côté anticheat,
-- lslegacy_webhook_admin_screenshots côté admin) : aucun nouveau webhook n'est créé ici.

Shared.Evidence = {}

-- Le sandbox Lua FXServer interdit io.open en dehors du dossier de la ressource courante et
-- rejette tout chemin contenant ".." : le stockage doit donc rester dans resources/lslegacy/evidence/
-- (dossiers déjà présents dans le repo via .gitkeep, Lua ne pouvant pas créer de dossier).
local EvidenceRoot = '@' .. GetCurrentResourceName() .. '/evidence'

-- Panel web (VPS1, lslegacy.top) : visionnage sécurisé des preuves, en complément de la
-- sauvegarde disque et des webhooks Discord existants. Clé API partagée avec le panel
-- (même valeur que FIVEM_API_KEY côté lslegacy-web). Si non configuré, l'upload web est
-- simplement ignoré (aucun impact sur la sauvegarde disque / Discord).
local WebUrl = GetConvar('lslegacy_web_url', '')
local WebApiKey = GetConvar('lslegacy_web_api_key', '')

print(('[evidence] init: EvidenceRoot=%s WebUrl=%s WebApiKey=%s'):format(
    EvidenceRoot, WebUrl ~= '' and WebUrl or '(vide)', WebApiKey ~= '' and '(défini, ' .. #WebApiKey .. ' car.)' or '(vide)'))

local B64Chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

-- Table de lookup 0-63 -> caractère, et son inverse (octet ASCII -> valeur 0-63) pour le décodage.
local B64Lookup, B64Rev = {}, {}
for i = 1, 64 do
    local ch = B64Chars:sub(i, i)
    B64Lookup[i - 1] = ch
    B64Rev[ch:byte()] = i - 1
end

-- PerformHttpRequest corrompt les corps binaires contenant des octets NUL (confirmé : un
-- multipart identique envoyé hors FXServer fonctionne, celui envoyé via PerformHttpRequest
-- échoue systématiquement en 400). On encode donc en base64 (texte ASCII pur) avant tout
-- envoi HTTP sortant de fichier binaire (UploadFileToWeb).
-- Implémentation par blocs de 3 octets avec les opérateurs bitwise natifs de Lua 5.4 (FXServer) :
-- l'ancienne version traitait bit par bit via gsub, beaucoup trop lente sur des fichiers de
-- plusieurs Mo (screenshots) voire dizaines de Mo (vidéos).
local function Base64Encode(data)
    local len = #data
    local out = {}
    local n = 0
    local i = 1
    while i + 2 <= len do
        local a, b, c = data:byte(i, i + 2)
        local x = (a << 16) | (b << 8) | c
        n = n + 1
        out[n] = B64Lookup[(x >> 18) & 0x3F] .. B64Lookup[(x >> 12) & 0x3F] .. B64Lookup[(x >> 6) & 0x3F] .. B64Lookup[x & 0x3F]
        i = i + 3
    end
    local rem = len - i + 1
    if rem == 1 then
        local a = data:byte(i)
        local x = a << 16
        n = n + 1
        out[n] = B64Lookup[(x >> 18) & 0x3F] .. B64Lookup[(x >> 12) & 0x3F] .. '=='
    elseif rem == 2 then
        local a, b = data:byte(i, i + 1)
        local x = (a << 16) | (b << 8)
        n = n + 1
        out[n] = B64Lookup[(x >> 18) & 0x3F] .. B64Lookup[(x >> 12) & 0x3F] .. B64Lookup[(x >> 6) & 0x3F] .. '='
    end
    return table.concat(out)
end

local function Base64Decode(data)
    data = data:gsub('[^' .. B64Chars .. '=]', '')
    local len = #data
    -- Ignore le padding final pour le comptage de blocs (traité séparément ci-dessous).
    while len > 0 and data:byte(len) == 61 --[['=']] do len = len - 1 end

    local out = {}
    local n = 0
    local i = 1
    while i + 3 <= len do
        local c1, c2, c3, c4 = data:byte(i, i + 3)
        local x = (B64Rev[c1] << 18) | (B64Rev[c2] << 12) | (B64Rev[c3] << 6) | B64Rev[c4]
        n = n + 1
        out[n] = string.char((x >> 16) & 0xFF, (x >> 8) & 0xFF, x & 0xFF)
        i = i + 4
    end
    local rem = len - i + 1
    if rem == 2 then
        local c1, c2 = data:byte(i, i + 1)
        local x = (B64Rev[c1] << 18) | (B64Rev[c2] << 12)
        n = n + 1
        out[n] = string.char((x >> 16) & 0xFF)
    elseif rem == 3 then
        local c1, c2, c3 = data:byte(i, i + 2)
        local x = (B64Rev[c1] << 18) | (B64Rev[c2] << 12) | (B64Rev[c3] << 6)
        n = n + 1
        out[n] = string.char((x >> 16) & 0xFF, (x >> 8) & 0xFF)
    end
    return table.concat(out)
end

-- Écrit une capture base64 (data URI "data:image/jpeg;base64,....") sur le disque du VPS.
-- Retourne le chemin absolu écrit, ou nil si data invalide.
function Shared.Evidence.SaveBase64Image(dataUri, target, tag)
    local b64 = dataUri and dataUri:match('base64,(.+)$')
    if not b64 then
        print('[evidence] SaveBase64Image: dataUri invalide (pas de "base64,")')
        return nil
    end

    local fileName = string.format('%s/screenshots/%s_%s_%s.jpg', EvidenceRoot, tag, target, os.time())
    local f = io.open(fileName, 'wb')
    if not f then
        print('[evidence] SaveBase64Image: io.open a échoué pour ' .. fileName)
        return nil
    end
    f:write(Base64Decode(b64))
    f:close()
    print('[evidence] SaveBase64Image: OK -> ' .. fileName)
    return fileName
end

-- Déplace un fichier vidéo produit par screencapture (screencapture/tmp/...) vers le stockage
-- persistant du VPS.
function Shared.Evidence.PersistVideo(tmpFilePath, target, tag)
    if not tmpFilePath then
        print('[evidence] PersistVideo: tmpFilePath nil')
        return nil
    end
    local destPath = string.format('%s/videos/%s_%s_%s.webm', EvidenceRoot, tag, target, os.time())

    local src = io.open(tmpFilePath, 'rb')
    if not src then
        print('[evidence] PersistVideo: io.open (lecture) a échoué pour ' .. tmpFilePath)
        return nil
    end
    local content = src:read('*a')
    src:close()

    local dst = io.open(destPath, 'wb')
    if not dst then
        print('[evidence] PersistVideo: io.open (écriture) a échoué pour ' .. destPath)
        return nil
    end
    dst:write(content)
    dst:close()
    os.remove(tmpFilePath)

    print(('[evidence] PersistVideo: OK -> %s (%d octets)'):format(destPath, #content))
    return destPath, content
end

-- Upload un fichier de preuve (screenshot ou vidéo) vers le panel web (lslegacy.top) pour
-- visionnage sécurisé dans l'admin (remplace l'envoi de la vidéo brute sur Discord, qui
-- échoue silencieusement au-delà de la limite de taille de PerformHttpRequest).
-- meta = { type = 'screenshot'|'video', target, tag, reason }.
-- callback(viewUrl) appelé avec l'URL de visionnage en cas de succès, callback(nil) sinon.
-- Ne doit jamais pouvoir interrompre le code appelant (Discord, notifications...) : le panel
-- web est un tiers optionnel, une erreur ou une indisponibilité ici ne doit rien casser
-- ailleurs. D'où le pcall interne, et pourquoi les appelants ne doivent jamais faire dépendre
-- leur envoi Discord du callback de cette fonction.
function Shared.Evidence.UploadFileToWeb(filePath, fileBytes, meta, callback)
    callback = callback or function() end
    print(('[evidence] UploadFileToWeb: appel pour %s (type=%s tag=%s target=%s)'):format(
        tostring(filePath), tostring(meta and meta.type), tostring(meta and meta.tag), tostring(meta and meta.target)))
    local ok, err = pcall(function()
        if WebUrl == '' or WebApiKey == '' then
            print('[evidence] UploadFileToWeb: annulé, lslegacy_web_url/lslegacy_web_api_key non configurés')
            callback(nil)
            return
        end

        local bytes = fileBytes
        if not bytes then
            local f = io.open(filePath, 'rb')
            if not f then callback(nil) return end
            bytes = f:read('*a')
            f:close()
        end

        local fileName = filePath:match('([^/\\]+)$') or 'evidence.bin'
        local fileMime = meta.type == 'video' and 'video/webm' or 'image/jpeg'

        -- JSON + base64 (pas de multipart binaire) : PerformHttpRequest corrompt les corps
        -- contenant des octets NUL (vérifié : le même fichier envoyé hors FXServer en multipart
        -- brut réussit, via PerformHttpRequest il échoue systématiquement en 400).
        local body = json.encode({
            type = meta.type,
            target = tostring(meta.target),
            tag = meta.tag,
            reason = meta.reason,
            fileName = fileName,
            mimeType = fileMime,
            fileBase64 = Base64Encode(bytes)
        })

        print(('[evidence] UploadFileToWeb: envoi vers %s (%d octets -> %d en base64)'):format(WebUrl .. '/api/evidence/upload', #bytes, #body))
        PerformHttpRequest(WebUrl .. '/api/evidence/upload', function(status, response)
            print(('[evidence] UploadFileToWeb: réponse status=%s body=%s'):format(tostring(status), tostring(response):sub(1, 300)))
            local cbOk, cbErr = pcall(function()
                if status ~= 200 and status ~= 201 then callback(nil) return end
                local decOk, data = pcall(json.decode, response)
                if not decOk or not data or not data.viewUrl then callback(nil) return end
                callback(data.viewUrl)
            end)
            if not cbOk then print('[evidence] UploadFileToWeb callback error: ' .. tostring(cbErr)) end
        end, 'POST', body, {
            ['Content-Type'] = 'application/json',
            ['Authorization'] = 'Bearer ' .. WebApiKey
        })
    end)
    if not ok then
        print('[evidence] UploadFileToWeb error: ' .. tostring(err))
        callback(nil)
    end
end

-- Poste un embed texte (sans pièce jointe) sur un webhook Discord existant.
function Shared.Evidence.PostDiscordEmbed(webhook, title, description, color)
    if not webhook or webhook == '' then
        print('[evidence] PostDiscordEmbed: webhook vide, annulé (title=' .. tostring(title) .. ')')
        return
    end
    print('[evidence] PostDiscordEmbed: envoi -> ' .. title)
    PerformHttpRequest(webhook, function(status, response)
        print(('[evidence] PostDiscordEmbed: réponse status=%s body=%s'):format(tostring(status), tostring(response):sub(1, 300)))
    end, 'POST', json.encode({
        embeds = {{ title = title, description = description, color = color or 23295 }}
    }), { ['Content-Type'] = 'application/json' })
end

