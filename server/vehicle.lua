-- =====================================================================
-- bobo-inventory | server/vehicle.lua
-- Coffre et boîte à gants des véhicules
-- Compatible ESX / QBCore / QBox via Bridge
-- =====================================================================

-- Cache en mémoire : évite des requêtes SQL à chaque ouverture
local TrunkCache    = {}   -- TrunkCache[plate]    = { items }
local GloveboxCache = {}   -- GloveboxCache[plate] = { items }

-- -----------------------------------------------------------------------
-- Chargement depuis la base
-- -----------------------------------------------------------------------

local function LoadTrunk(plate)
    if TrunkCache[plate] then return TrunkCache[plate] end

    local result = MySQL.prepare.await(
        'SELECT items FROM bobo_trunkitems WHERE plate = ?', { plate }
    )
    TrunkCache[plate] = result and json.decode(result) or {}
    return TrunkCache[plate]
end

local function LoadGlovebox(plate)
    if GloveboxCache[plate] then return GloveboxCache[plate] end

    local result = MySQL.prepare.await(
        'SELECT items FROM bobo_gloveboxitems WHERE plate = ?', { plate }
    )
    GloveboxCache[plate] = result and json.decode(result) or {}
    return GloveboxCache[plate]
end

-- -----------------------------------------------------------------------
-- Sauvegarde en base
-- -----------------------------------------------------------------------

local function SaveTrunk(plate)
    local data = TrunkCache[plate] or {}
    MySQL.prepare(
        'INSERT INTO bobo_trunkitems (plate, items) VALUES (?, ?) ON DUPLICATE KEY UPDATE items = ?',
        { plate, json.encode(data), json.encode(data) }
    )
end

local function SaveGlovebox(plate)
    local data = GloveboxCache[plate] or {}
    MySQL.prepare(
        'INSERT INTO bobo_gloveboxitems (plate, items) VALUES (?, ?) ON DUPLICATE KEY UPDATE items = ?',
        { plate, json.encode(data), json.encode(data) }
    )
end

-- -----------------------------------------------------------------------
-- Helpers items véhicule
-- -----------------------------------------------------------------------

local function GetVehicleFirstFreeSlot(items, maxSlots)
    for i = 1, maxSlots do
        if not items[i] then return i end
    end
    return nil
end

local function GetVehicleTotalWeight(items)
    local weight = 0
    for _, item in pairs(items) do
        weight = weight + ((item.weight or 0) * (item.amount or 1))
    end
    return weight
end

-- -----------------------------------------------------------------------
-- Ouvrir le coffre
-- -----------------------------------------------------------------------

RegisterNetEvent('bobo-inventory:server:openTrunk', function(plate)
    local src   = source
    local items = LoadTrunk(plate)
    TriggerClientEvent('bobo-inventory:client:openTrunk', src, plate, items)
end)

-- -----------------------------------------------------------------------
-- Ouvrir la boîte à gants
-- -----------------------------------------------------------------------

RegisterNetEvent('bobo-inventory:server:openGlovebox', function(plate)
    local src   = source
    local items = LoadGlovebox(plate)
    TriggerClientEvent('bobo-inventory:client:openGlovebox', src, plate, items)
end)

-- -----------------------------------------------------------------------
-- Déposer un item du joueur → véhicule
-- -----------------------------------------------------------------------

RegisterNetEvent('bobo-inventory:server:moveToVehicle', function(vehType, plate, fromSlot, amount)
    local src    = source
    local Player = GetPlayer(src)
    if not Player then return end
    local data   = GetPData(Player)

    fromSlot = tonumber(fromSlot)
    amount   = tonumber(amount) or 1

    local item = data.items[fromSlot] or data.items[tostring(fromSlot)]
    if not item or (item.amount or 1) < amount then
        Notify(src, Config.Lang.invalidqty, 'error')
        return
    end

    -- Choisir le bon cache
    local cache     = vehType == 'trunk' and TrunkCache or GloveboxCache
    local maxSlots  = vehType == 'trunk' and Config.MaxTrunkSlots  or Config.MaxGloveboxSlots
    local maxWeight = vehType == 'trunk' and Config.MaxTrunkWeight or Config.MaxGloveboxWeight

    if not cache[plate] then
        if vehType == 'trunk' then LoadTrunk(plate) else LoadGlovebox(plate) end
    end

    local vehItems = cache[plate]

    -- Vérification poids
    if GetVehicleTotalWeight(vehItems) + ((item.weight or 0) * amount) > maxWeight then
        Notify(src, Config.Lang.tooheavy, 'error')
        return
    end

    -- Trouver un slot libre dans le véhicule
    local targetSlot = GetVehicleFirstFreeSlot(vehItems, maxSlots)
    if not targetSlot then
        Notify(src, Config.Lang.notenough, 'error')
        return
    end

    -- Retirer du joueur
    if not exports['bobo-inventory']:RemoveItem(src, item.name, amount, fromSlot) then return end

    -- Ajouter au véhicule
    vehItems[targetSlot] = {
        name        = item.name,
        amount      = amount,
        info        = item.info or '',
        label       = item.label,
        weight      = item.weight,
        image       = item.image,
        description = item.description or '',
        slot        = targetSlot,
    }

    -- Sauvegarder
    if vehType == 'trunk' then SaveTrunk(plate) else SaveGlovebox(plate) end

    -- Rafraîchir le NUI : reconstruire les items joueur depuis le framework
    local PlayerAfter = GetPlayer(src)
    local itemsAfter  = PlayerAfter and GetPData(PlayerAfter).items or {}
    TriggerClientEvent('bobo-inventory:client:refreshVehicle', src, vehItems, itemsAfter)
end)

-- -----------------------------------------------------------------------
-- Reprendre un item du véhicule → joueur
-- -----------------------------------------------------------------------

RegisterNetEvent('bobo-inventory:server:moveFromVehicle', function(vehType, plate, fromSlot, amount)
    local src    = source
    local Player = GetPlayer(src)
    if not Player then return end

    fromSlot = tonumber(fromSlot)
    amount   = tonumber(amount) or 1

    local cache = vehType == 'trunk' and TrunkCache or GloveboxCache
    if not cache[plate] then
        if vehType == 'trunk' then LoadTrunk(plate) else LoadGlovebox(plate) end
    end

    local vehItems = cache[plate]
    local item     = vehItems[fromSlot]

    if not item or (item.amount or 1) < amount then
        Notify(src, Config.Lang.invalidqty, 'error')
        return
    end

    -- Ajouter au joueur
    if not exports['bobo-inventory']:AddItem(src, item.name, amount, nil, item.info) then
        Notify(src, Config.Lang.notenough, 'error')
        return
    end

    -- Retirer du véhicule
    item.amount = item.amount - amount
    if item.amount <= 0 then
        vehItems[fromSlot] = nil
    end

    -- Sauvegarder
    if vehType == 'trunk' then SaveTrunk(plate) else SaveGlovebox(plate) end

    -- Rafraîchir le NUI : reconstruire les items joueur depuis le framework
    local PlayerAfter = GetPlayer(src)
    local itemsAfter  = PlayerAfter and GetPData(PlayerAfter).items or {}
    TriggerClientEvent('bobo-inventory:client:refreshVehicle', src, vehItems, itemsAfter)
end)

-- -----------------------------------------------------------------------
-- Sauvegarde auto au stop de la resource
-- -----------------------------------------------------------------------

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for plate, _ in pairs(TrunkCache) do
        SaveTrunk(plate)
    end
    for plate, _ in pairs(GloveboxCache) do
        SaveGlovebox(plate)
    end
    print('[bobo-inventory] Coffres et boîtes à gants sauvegardés.')
end)

print('^2[bobo-inventory]^7 Module véhicule serveur chargé.')