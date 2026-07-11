-- =====================================================================
-- bobo-inventory | client/bridge.lua
-- Fonctions client compatibles ESX / QBCore / QBox
-- =====================================================================

-- -----------------------------------------------------------------------
-- Données joueur
-- -----------------------------------------------------------------------

function Bridge.GetPlayerData()
    if Bridge._name == 'qbcore' then
        return Bridge._fw.Functions.GetPlayerData()
    elseif Bridge._name == 'qbox' then
        return exports.qbx_core:GetPlayerData()
    elseif Bridge._name == 'esx' then
        return Bridge._fw.GetPlayerData()
    end
    return {}
end

function Bridge.GetItems()
    local data = Bridge.GetPlayerData()
    if Bridge._name == 'esx' then
        -- ESX : items dans data.inventory (table avec name/count/weight)
        local items = {}
        if data.inventory then
            for _, item in pairs(data.inventory) do
                if item.count > 0 then
                    items[item.name] = item
                end
            end
        end
        return items
    end
    -- QBCore / QBox : data.items indexé par slot
    return data.items or {}
end

function Bridge.GetMoney()
    local data = Bridge.GetPlayerData()
    if Bridge._name == 'esx' then
        return data.money or 0
    end
    -- QBCore / QBox
    return (data.money and data.money.cash) or 0
end

-- -----------------------------------------------------------------------
-- Notifications
-- -----------------------------------------------------------------------

function Bridge.Notify(message, notifType, duration)
    duration = duration or 3000

    if Config.Notify == 'ox' then
        exports.ox_lib:notify({ description = message, type = notifType, duration = duration })
        return
    end

    if Bridge._name == 'qbcore' then
        Bridge._fw.Functions.Notify(message, notifType, duration)
    elseif Bridge._name == 'qbox' then
        exports.qbx_core:Notify(message, notifType, duration)
    elseif Bridge._name == 'esx' then
        Bridge._fw.ShowNotification(message)
    end
end

-- -----------------------------------------------------------------------
-- Callbacks (TriggerCallback → compatibilité ESX)
-- -----------------------------------------------------------------------

function Bridge.TriggerCallback(name, cb, ...)
    if Bridge._name == 'qbcore' then
        Bridge._fw.Functions.TriggerCallback(name, cb, ...)
    elseif Bridge._name == 'qbox' then
        exports.qbx_core:TriggerCallback(name, cb, ...)
    elseif Bridge._name == 'esx' then
        -- ESX utilise ESX.TriggerServerCallback
        Bridge._fw.TriggerServerCallback(name, cb, ...)
    end
end

-- -----------------------------------------------------------------------
-- Events framework (chargement / déchargement joueur)
-- -----------------------------------------------------------------------

-- Retourne les noms d'events du framework actif
function Bridge.Events()
    if Bridge._name == 'qbcore' then
        return {
            onLoad      = 'QBCore:Client:OnPlayerLoaded',
            onUnload    = 'QBCore:Client:OnPlayerUnload',
            onDataUpdate= 'QBCore:Player:SetPlayerData',
            onMoneyChange = 'QBCore:Client:OnMoneyChange',
        }
    elseif Bridge._name == 'qbox' then
        return {
            onLoad      = 'QBCore:Client:OnPlayerLoaded',
            onUnload    = 'QBCore:Client:OnPlayerUnload',
            onDataUpdate= 'QBCore:Player:SetPlayerData',
            onMoneyChange = 'QBCore:Client:OnMoneyChange',
        }
    elseif Bridge._name == 'esx' then
        return {
            onLoad      = 'esx:playerLoaded',
            onUnload    = 'esx:onPlayerLogout',
            onDataUpdate= 'esx:setPlayerData',
            onMoneyChange = 'esx:setPlayerData', -- ESX envoie tout dans setPlayerData
        }
    end
    return {}
end