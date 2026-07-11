-- =====================================================================
-- bobo-inventory | server/bridge.lua
-- Fonctions serveur compatibles ESX / QBCore / QBox
-- =====================================================================

-- -----------------------------------------------------------------------
-- Récupérer un joueur
-- -----------------------------------------------------------------------

function Bridge.GetPlayer(source)
    if Bridge._name == 'qbcore' then
        return Bridge._fw.Functions.GetPlayer(source)
    elseif Bridge._name == 'qbox' then
        return exports.qbx_core:GetPlayer(source)
    elseif Bridge._name == 'esx' then
        return Bridge._fw.GetPlayerFromId(source)
    end
    return nil
end

-- -----------------------------------------------------------------------
-- Récupérer les données brutes du joueur (PlayerData unifié)
-- -----------------------------------------------------------------------

function Bridge.GetPlayerData(source)
    local player = Bridge.GetPlayer(source)
    if not player then return nil end

    if Bridge._name == 'esx' then
        return {
            citizenid   = player.identifier,
            name        = player.getName(),
            items       = player.inventory,   -- table ESX
            money       = { cash = player.getMoney() },
            job         = { name = player.job.name, grade = player.job.grade },
            metadata    = {},
        }
    end
    -- QBCore / QBox
    return player.PlayerData
end

-- -----------------------------------------------------------------------
-- Récupérer l'identifiant unique du joueur
-- -----------------------------------------------------------------------

function Bridge.GetIdentifier(source)
    local data = Bridge.GetPlayerData(source)
    if not data then return nil end
    if Bridge._name == 'esx' then
        return data.citizenid  -- = identifier (licence:xxx)
    end
    return data.citizenid
end

-- -----------------------------------------------------------------------
-- Récupérer les items du joueur (indexés par slot pour QBCore/QBox,
-- ou convertis depuis ESX)
-- -----------------------------------------------------------------------

function Bridge.GetItems(source)
    local data = Bridge.GetPlayerData(source)
    if not data then return {} end

    if Bridge._name == 'esx' then
        -- ESX : convertit inventory en table indexée par slot simulé
        local items = {}
        local slot = 1
        for _, item in pairs(data.items or {}) do
            if item.count > 0 then
                items[slot] = {
                    name   = item.name,
                    amount = item.count,
                    label  = item.label,
                    weight = item.weight,
                    info   = '',
                    slot   = slot,
                }
                slot = slot + 1
            end
        end
        return items
    end
    -- QBCore / QBox
    return data.items or {}
end

-- -----------------------------------------------------------------------
-- Mettre à jour les items du joueur
-- -----------------------------------------------------------------------

function Bridge.SetItems(source, items)
    local player = Bridge.GetPlayer(source)
    if not player then return end

    if Bridge._name == 'esx' then
        -- ESX ne supporte pas SetPlayerData directement pour l'inventaire
        -- On doit gérer item par item (limitation ESX)
        -- Pour bobo-inventory on passe par AddItem/RemoveItem natifs ESX
        -- => Cette fonction est utilisée uniquement par QBCore/QBox
        print('[bobo-inventory] Bridge.SetItems : non supporté pour ESX, utiliser AddItem/RemoveItem')
        return
    end
    -- QBCore / QBox
    player.Functions.SetPlayerData('items', items)
end

-- -----------------------------------------------------------------------
-- Informations sur un item depuis le catalogue du framework
-- -----------------------------------------------------------------------

function Bridge.GetItemInfo(itemName)
    if Bridge._name == 'esx' then
        -- ESX : on fait une requête SQL via oxmysql pour obtenir les infos item
        local result = MySQL.prepare.await('SELECT * FROM items WHERE name = ?', { itemName:lower() })
        if result then
            return {
                name   = result.name,
                label  = result.label,
                weight = result.weight or 0,
                type   = 'item',
                unique = false,
                useable= false,
                image  = result.name .. '.png',
            }
        end
        return nil
    end
    -- QBCore / QBox
    local item = Bridge._fw.Shared.Items[itemName:lower()]
    if item then return item end

    -- Fallback : item non trouvé dans QBCore mais existe quand même
    -- On le garde avec des infos minimales pour éviter qu'il soit supprimé
    return {
        name        = itemName:lower(),
        label       = itemName,
        weight      = 0,
        type        = 'item',
        unique      = false,
        useable     = true,
        image       = itemName:lower() .. '.png',
        shouldClose = false,
        combinable  = nil,
        description = '',
    }
end

-- -----------------------------------------------------------------------
-- Récupérer tous les joueurs connectés
-- -----------------------------------------------------------------------

function Bridge.GetAllPlayers()
    if Bridge._name == 'qbcore' then
        return Bridge._fw.Functions.GetQBPlayers()
    elseif Bridge._name == 'qbox' then
        return exports.qbx_core:GetPlayers()
    elseif Bridge._name == 'esx' then
        local players = {}
        for _, player in pairs(Bridge._fw.GetPlayers()) do
            players[player] = Bridge._fw.GetPlayerFromId(player)
        end
        return players
    end
    return {}
end

-- -----------------------------------------------------------------------
-- Notifications serveur → client
-- -----------------------------------------------------------------------

function Bridge.Notify(source, message, notifType)
    if Config.Notify == 'ox' then
        TriggerClientEvent('ox_lib:notify', source, { description = message, type = notifType })
        return
    end

    if Bridge._name == 'qbcore' or Bridge._name == 'qbox' then
        TriggerClientEvent('QBCore:Notify', source, message, notifType)
    elseif Bridge._name == 'esx' then
        TriggerClientEvent('ESX:ShowNotification', source, message)
    end
end

-- -----------------------------------------------------------------------
-- Callbacks serveur (CreateCallback)
-- -----------------------------------------------------------------------

function Bridge.CreateCallback(name, cb)
    if Bridge._name == 'qbcore' then
        Bridge._fw.Functions.CreateCallback(name, cb)
    elseif Bridge._name == 'qbox' then
        exports.qbx_core:RegisterCallback(name, cb)
    elseif Bridge._name == 'esx' then
        Bridge._fw.RegisterServerCallback(name, cb)
    end
end

-- -----------------------------------------------------------------------
-- Métadonnées joueur (hunger, thirst, etc.)
-- -----------------------------------------------------------------------

function Bridge.SetMetaData(source, key, value)
    local player = Bridge.GetPlayer(source)
    if not player then return end

    if Bridge._name == 'esx' then
        -- ESX ne gère pas les métadonnées nativement
        -- On peut utiliser esx_status si installé, sinon on ignore
        if exports['esx_status'] then
            TriggerClientEvent('esx_status:set', source, key, value)
        end
        return
    end
    -- QBCore / QBox
    player.Functions.SetMetaData(key, value)
end

function Bridge.GetMetaData(source, key)
    local data = Bridge.GetPlayerData(source)
    if not data then return nil end

    if Bridge._name == 'esx' then
        return nil -- ESX gère ça via esx_status séparément
    end
    return data.metadata and data.metadata[key]
end

-- -----------------------------------------------------------------------
-- HUD (faim / soif)
-- -----------------------------------------------------------------------

function Bridge.UpdateNeeds(source, hunger, thirst)
    if Bridge._name == 'esx' then
        -- esx_status utilise des events différents
        TriggerClientEvent('esx_status:set', source, 'hunger', math.floor(hunger * 10000))
        TriggerClientEvent('esx_status:set', source, 'thirst', math.floor(thirst * 10000))
    else
        -- QBCore / QBox : event standard
        TriggerClientEvent('hud:client:UpdateNeeds', source, hunger, thirst)
    end
end