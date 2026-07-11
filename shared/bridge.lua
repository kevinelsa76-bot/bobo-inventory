-- =====================================================================
-- bobo-inventory | shared/bridge.lua
-- Détection automatique du framework (ESX / QBCore / QBox)
-- Fournit une interface unifiée pour client ET serveur.
-- =====================================================================

Bridge = {}
Bridge._fw   = nil
Bridge._name = nil

-- -----------------------------------------------------------------------
-- Détection au démarrage
-- -----------------------------------------------------------------------
if GetResourceState('qbx_core') == 'started' then
    Bridge._fw   = exports.qbx_core:GetCoreObject()
    Bridge._name = 'qbox'
elseif GetResourceState('qb-core') == 'started' then
    Bridge._fw   = exports['qb-core']:GetCoreObject()
    Bridge._name = 'qbcore'
elseif GetResourceState('es_extended') == 'started' then
    Bridge._fw   = exports['es_extended']:getSharedObject()
    Bridge._name = 'esx'
else
    -- Fallback manuel via Config.Framework
    if Config and Config.Framework ~= 'auto' then
        Bridge._name = Config.Framework
        if     Bridge._name == 'qbox'   then Bridge._fw = exports.qbx_core:GetCoreObject()
        elseif Bridge._name == 'qbcore' then Bridge._fw = exports['qb-core']:GetCoreObject()
        elseif Bridge._name == 'esx'    then Bridge._fw = exports['es_extended']:getSharedObject()
        end
    end
end

if Bridge._name then
    print('^2[bobo-inventory]^7 Framework détecté : ^3' .. Bridge._name)
else
    print('^1[bobo-inventory]^7 ERREUR : Aucun framework détecté !')
end

-- -----------------------------------------------------------------------
-- Helpers internes
-- -----------------------------------------------------------------------
local function isQB()
    return Bridge._name == 'qbcore' or Bridge._name == 'qbox'
end

local function isClient()
    -- IsCitizen() n'existe que côté client dans FiveM
    return IsDuplicityVersion and not IsDuplicityVersion()
end

-- -----------------------------------------------------------------------
-- Items partagés du framework (catalogue global)
-- -----------------------------------------------------------------------
function Bridge.GetSharedItems()
    if isQB() then
        return Bridge._fw.Shared.Items
    end
    return {}
end

-- =====================================================================
-- API CLIENT UNIQUEMENT
-- Les fonctions ci-dessous ne sont disponibles que côté client.
-- =====================================================================

-- -----------------------------------------------------------------------
-- Noms des événements framework (onPlayerLoaded, onPlayerUnloaded, etc.)
-- -----------------------------------------------------------------------
function Bridge.Events()
    if Bridge._name == 'esx' then
        return {
            onLoad       = 'esx:playerLoaded',
            onUnload     = 'esx:onPlayerLogout',
            onDataUpdate = 'esx:setPlayerData',
            onMoneyChange= 'esx:setPlayerData',
        }
    elseif Bridge._name == 'qbox' then
        return {
            onLoad       = 'QBCore:Client:OnPlayerLoaded',
            onUnload     = 'QBCore:Client:OnPlayerUnload',
            onDataUpdate = 'QBCore:Player:SetPlayerData',
            onMoneyChange= 'QBCore:Player:SetPlayerData',
        }
    else
        -- QBCore (défaut)
        return {
            onLoad       = 'QBCore:Client:OnPlayerLoaded',
            onUnload     = 'QBCore:Client:OnPlayerUnload',
            onDataUpdate = 'QBCore:Player:SetPlayerData',
            onMoneyChange= 'QBCore:Player:SetPlayerData',
        }
    end
end

-- -----------------------------------------------------------------------
-- Récupère le PlayerData complet du framework
-- -----------------------------------------------------------------------
function Bridge.GetPlayerData()
    if Bridge._name == 'esx' then
        local player = Bridge._fw.GetPlayerData()
        return player or {}
    elseif isQB() then
        local player = Bridge._fw.Functions.GetPlayerData()
        return player or {}
    end
    return {}
end

-- -----------------------------------------------------------------------
-- Récupère la table d'items du joueur (indexée par slot)
-- -----------------------------------------------------------------------
function Bridge.GetItems()
    if Bridge._name == 'esx' then
        local pd = Bridge._fw.GetPlayerData()
        if not pd then return {} end
        -- ESX stocke l'inventaire dans pd.inventory (table avec name/count/etc.)
        local items = {}
        if pd.inventory then
            for _, entry in ipairs(pd.inventory) do
                if entry and entry.name and entry.count and entry.count > 0 then
                    items[#items + 1] = {
                        name   = entry.name,
                        amount = entry.count,
                        label  = entry.label or entry.name,
                        weight = (entry.weight or 0),
                        slot   = #items + 1,
                    }
                end
            end
        end
        return items
    elseif isQB() then
        local pd = Bridge._fw.Functions.GetPlayerData()
        return (pd and pd.items) or {}
    end
    return {}
end

-- -----------------------------------------------------------------------
-- Récupère l'argent du joueur { cash, dirty }
-- -----------------------------------------------------------------------
function Bridge.GetMoney()
    if Bridge._name == 'esx' then
        local pd = Bridge._fw.GetPlayerData()
        if not pd then return { cash = 0, dirty = 0 } end
        local cash  = 0
        local dirty = 0
        if pd.accounts then
            for _, acc in ipairs(pd.accounts) do
                if acc.name == 'money'       then cash  = acc.money or 0 end
                if acc.name == 'black_money' then dirty = acc.money or 0 end
            end
        end
        return { cash = cash, dirty = dirty }
    elseif isQB() then
        local pd = Bridge._fw.Functions.GetPlayerData()
        if not pd or not pd.money then return { cash = 0, dirty = 0 } end
        return {
            cash  = pd.money.cash    or 0,
            dirty = pd.money.dirty   or 0,
        }
    end
    return { cash = 0, dirty = 0 }
end

-- -----------------------------------------------------------------------
-- Notifications
-- -----------------------------------------------------------------------
function Bridge.Notify(msg, ntype, duration)
    duration = duration or 3000
    if Config.Notify == 'ox' then
        exports['ox_lib']:notify({ description = msg, type = ntype, duration = duration })
        return
    end
    -- Notification via framework
    if Bridge._name == 'esx' then
        Bridge._fw.ShowNotification(msg)
    elseif isQB() then
        Bridge._fw.Functions.Notify(msg, ntype, duration)
    end
end

-- -----------------------------------------------------------------------
-- TriggerCallback (abstraction client → serveur)
-- -----------------------------------------------------------------------
function Bridge.TriggerCallback(name, cb, ...)
    if Bridge._name == 'esx' then
        Bridge._fw.TriggerServerCallback(name, cb, ...)
    elseif isQB() then
        Bridge._fw.Functions.TriggerCallback(name, cb, ...)
    end
end