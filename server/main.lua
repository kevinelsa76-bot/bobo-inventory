-- =====================================================================
-- bobo-inventory | server/main.lua
-- Compatible ESX / QBCore / QBox via Bridge
-- =====================================================================

-- Helper : récupérer le joueur selon le framework
-- Global : utilisé par server/vehicle.lua
function GetPlayer(src)
    if Bridge._name == 'esx' then
        return Bridge._fw.GetPlayerFromId(src)
    else
        return Bridge._fw.Functions.GetPlayer(src)
    end
end
exports('GetPlayer', GetPlayer)

-- Helper : lire le PlayerData selon le framework
-- Global : utilisé par server/vehicle.lua
function GetPData(Player)
    if Bridge._name == 'esx' then
        return { items = Player.getInventory(), citizenid = Player.getIdentifier() }
    else
        return Player.PlayerData
    end
end
exports('GetPData', GetPData)

-- Helper : définir les items du joueur selon le framework
-- Global : utilisé par server/vehicle.lua
function SetItems(Player, items)
    if Bridge._name == 'esx' then
        Player.setInventory(items)
    else
        Player.Functions.SetPlayerData('items', items)
    end
end

-- Helper : lire les SharedItems selon le framework (local, usage interne)
local function GetSharedItems()
    if Bridge._name == 'esx' then return nil end
    return Bridge._fw.Shared.Items
end

-- Helper : créer un callback selon le framework (local, usage interne)
local function CreateCallback(name, fn)
    if Bridge._name == 'esx' then
        Bridge._fw.RegisterServerCallback(name, fn)
    else
        Bridge._fw.Functions.CreateCallback(name, fn)
    end
end

-- ---------------------------------------------------------------------
-- Notifications
-- ---------------------------------------------------------------------
function Notify(source, text, ntype)
    if Config.Notify == 'ox' then
        TriggerClientEvent('ox_lib:notify', source, { description = text, type = ntype })
    elseif Bridge._name == 'esx' then
        TriggerClientEvent('esx:showNotification', source, text)
    else
        TriggerClientEvent('QBCore:Notify', source, text, ntype)
    end
end

-- =====================================================================
-- CHARGEMENT / SAUVEGARDE
-- =====================================================================

local function LoadInventory(source, citizenid)
    local inventory = MySQL.prepare.await('SELECT inventory FROM players WHERE citizenid = ?', { citizenid })
    local loadedInventory = {}
    local missingItems = {}

    if not inventory then return loadedInventory end

    inventory = json.decode(inventory)
    if not inventory or table.type(inventory) == 'empty' then return loadedInventory end

    local sharedItems = GetSharedItems()

    for _, item in pairs(inventory) do
        if item then
            local itemName = item.name:lower()
            -- QBCore/QBox : enrichir depuis SharedItems ; ESX : stocker tel quel
            if sharedItems then
                local itemInfo = sharedItems[itemName]
                if itemInfo then
                    loadedInventory[item.slot] = {
                        name        = itemInfo.name,
                        amount      = item.amount,
                        info        = item.info or '',
                        label       = itemInfo.label,
                        description = itemInfo.description or '',
                        weight      = itemInfo.weight,
                        type        = itemInfo.type,
                        unique      = itemInfo.unique,
                        useable     = itemInfo.useable,
                        image       = itemInfo.image,
                        shouldClose = itemInfo.shouldClose,
                        slot        = item.slot,
                        combinable  = itemInfo.combinable,
                    }
                else
                    missingItems[#missingItems + 1] = itemName
                end
            else
                loadedInventory[item.slot] = item
            end
        end
    end

    if #missingItems > 0 then
        print(('[bobo-inventory] Items manquants pour %s :'):format(GetPlayerName(source)))
        for _, name in ipairs(missingItems) do print('   - ' .. name) end
    end

    return loadedInventory
end
exports('LoadInventory', LoadInventory)

local function SaveInventory(source, offline)
    local Player
    local PlayerData
    if not offline then
        Player = GetPlayer(source)
        if not Player then return end
        PlayerData = GetPData(Player)
    else
        PlayerData = source
    end

    local items = PlayerData.items
    local ItemsJson = {}

    if items and table.type(items) ~= 'empty' then
        for slot, item in pairs(items) do
            if item then
                ItemsJson[#ItemsJson + 1] = {
                    name   = item.name,
                    amount = item.amount,
                    info   = item.info,
                    type   = item.type,
                    slot   = slot,
                }
            end
        end
        MySQL.prepare('UPDATE players SET inventory = ? WHERE citizenid = ?', {
            json.encode(ItemsJson), PlayerData.citizenid
        })
    else
        MySQL.prepare('UPDATE players SET inventory = ? WHERE citizenid = ?', {
            '[]', PlayerData.citizenid
        })
    end
end
exports('SaveInventory', SaveInventory)

-- =====================================================================
-- OUTILS DE LECTURE
-- =====================================================================

local function GetTotalWeight(items)
    local weight = 0
    if not items then return 0 end
    for _, item in pairs(items) do
        weight = weight + (item.weight * item.amount)
    end
    return tonumber(weight)
end
exports('GetTotalWeight', GetTotalWeight)

local function GetSlotsByItem(items, itemName)
    local slotsFound = {}
    if not items then return slotsFound end
    for slot, item in pairs(items) do
        if item.name:lower() == itemName:lower() then
            slotsFound[#slotsFound + 1] = slot
        end
    end
    return slotsFound
end
exports('GetSlotsByItem', GetSlotsByItem)

local function GetFirstSlotByItem(items, itemName)
    if not items then return nil end
    for slot, item in pairs(items) do
        if item.name:lower() == itemName:lower() then
            return tonumber(slot)
        end
    end
    return nil
end
exports('GetFirstSlotByItem', GetFirstSlotByItem)

local function GetItemBySlot(source, slot)
    local Player = GetPlayer(source)
    if not Player then return nil end
    local pdata = GetPData(Player)
    return pdata.items[tonumber(slot)]
end
exports('GetItemBySlot', GetItemBySlot)

local function GetItemByName(source, item)
    local Player = GetPlayer(source)
    if not Player then return nil end
    local pdata = GetPData(Player)
    local slot = GetFirstSlotByItem(pdata.items, tostring(item):lower())
    return slot and pdata.items[slot] or nil
end
exports('GetItemByName', GetItemByName)

-- =====================================================================
-- AJOUT / RETRAIT D'ITEMS
-- =====================================================================

local function GetFirstFreeSlot(items, maxSlots)
    for i = 1, maxSlots do
        if items[i] == nil then return i end
    end
    return nil
end

local function AddItem(source, item, amount, slot, info)
    local Player = GetPlayer(source)
    if not Player then return false end

    local sharedItems = GetSharedItems()
    local itemInfo
    if sharedItems then
        itemInfo = sharedItems[item:lower()]
        if not itemInfo then
            print(('[bobo-inventory] AddItem : item "%s" inexistant'):format(item))
            return false
        end
    else
        -- ESX : infos minimales
        itemInfo = { name = item:lower(), label = item, weight = 0, unique = false }
    end

    amount = tonumber(amount) or 1
    local pdata = GetPData(Player)
    local items = pdata.items

    local totalWeight = GetTotalWeight(items)
    if totalWeight + (itemInfo.weight * amount) > Config.MaxInventoryWeight then
        Notify(source, Config.Lang.tooheavy, 'error')
        return false
    end

    if not itemInfo.unique then
        local existingSlot = GetFirstSlotByItem(items, item:lower())
        if existingSlot and not slot then
            items[existingSlot].amount = items[existingSlot].amount + amount
            SetItems(Player, items)
            return true
        end
    end

    local targetSlot = slot or GetFirstFreeSlot(items, Config.MaxInventorySlots)
    if not targetSlot then
        Notify(source, Config.Lang.notenough, 'error')
        return false
    end

    items[targetSlot] = {
        name        = itemInfo.name,
        amount      = amount,
        info        = info or '',
        label       = itemInfo.label,
        description = itemInfo.description or '',
        weight      = itemInfo.weight,
        type        = itemInfo.type,
        unique      = itemInfo.unique,
        useable     = itemInfo.useable,
        image       = itemInfo.image,
        shouldClose = itemInfo.shouldClose,
        slot        = targetSlot,
        combinable  = itemInfo.combinable,
    }

    SetItems(Player, items)
    return true
end
exports('AddItem', AddItem)

local function RemoveItem(source, item, amount, slot)
    local Player = GetPlayer(source)
    if not Player then return false end

    amount = tonumber(amount) or 1
    local pdata = GetPData(Player)
    local items = pdata.items

    local targetSlot = slot and tonumber(slot) or GetFirstSlotByItem(items, item:lower())
    if not targetSlot then return false end

    local entry = items[targetSlot] or items[tostring(targetSlot)]
    if not entry then return false end
    if entry.name:lower() ~= item:lower() then return false end
    if entry.amount < amount then return false end

    entry.amount = entry.amount - amount

    if entry.amount <= 0 then
        items[targetSlot] = nil
        items[tostring(targetSlot)] = nil
    end

    SetItems(Player, items)
    return true
end
exports('RemoveItem', RemoveItem)

local function HasItem(source, items, amount)
    local Player = GetPlayer(source)
    if not Player then return false end

    local pdata = GetPData(Player)
    local inventory = pdata.items
    local isTable = type(items) == 'table'
    amount = amount or 1

    if not isTable then
        local slot = GetFirstSlotByItem(inventory, items:lower())
        return slot and inventory[slot].amount >= amount or false
    else
        for name, needed in pairs(items) do
            local slot = GetFirstSlotByItem(inventory, tostring(name):lower())
            if not slot or inventory[slot].amount < needed then return false end
        end
        return true
    end
end
exports('HasItem', HasItem)

local function ClearInventory(source)
    local Player = GetPlayer(source)
    if not Player then return end
    SetItems(Player, {})
end
exports('ClearInventory', ClearInventory)

-- =====================================================================
-- CALLBACK STANDARD QBCore (compatibilité avec les ressources tierces)
-- =====================================================================
if Bridge._name == 'qbcore' or Bridge._name == 'qbox' then
    Bridge._fw.Functions.CreateCallback('QBCore:HasItem', function(source, cb, items, amount)
        cb(HasItem(source, items, amount))
    end)
end

-- =====================================================================
-- SAUVEGARDE À L'ARRÊT
-- =====================================================================
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    -- Notifier tous les clients de supprimer les objets au sol
    for dropId in pairs(GroundDrops) do
        TriggerClientEvent('bobo-inventory:client:removeDropObject', -1, dropId)
    end
    GroundDrops = {}
    -- Sauvegarder les inventaires
    local players
    if Bridge._name == 'esx' then
        players = Bridge._fw.GetExtendedPlayers()
    else
        players = Bridge._fw.Functions.GetQBPlayers()
    end
    for _, Player in pairs(players) do
        local pdata = GetPData(Player)
        SaveInventory(pdata.source or Player.source)
    end
end)

print('^2[bobo-inventory]^7 Serveur chargé (' .. (Bridge._name or 'inconnu') .. ').')

-- =====================================================================
-- COMMANDE ADMIN : /giveitem [id] [item] [quantite]
-- =====================================================================
RegisterCommand('giveitem', function(source, args)
    if not args[1] or not args[2] then
        print('[bobo-inventory] Usage : giveitem [id] [item] [quantite]')
        return
    end

    local playerId = tonumber(args[1])
    local itemName = args[2]:lower()
    local amount   = tonumber(args[3]) or 1

    local sharedItems = GetSharedItems()
    if sharedItems and not sharedItems[itemName] then
        print('[bobo-inventory] Item inexistant : ' .. itemName)
        return
    end

    local Player = GetPlayer(playerId)
    if not Player then
        print('[bobo-inventory] Joueur introuvable : ' .. tostring(args[1]))
        return
    end

    if AddItem(playerId, itemName, amount) then
        print(('[bobo-inventory] %sx %s donné au joueur %s'):format(amount, itemName, playerId))
    else
        print('[bobo-inventory] Echec du giveitem')
    end
end, true)

-- ===================================================================
-- EVENTS SERVEUR : Utiliser / Donner / Jeter
-- ===================================================================

RegisterNetEvent('bobo-inventory:server:useItem', function(slot)
    local src = source
    local Player = GetPlayer(src)
    if not Player then return end

    slot = tonumber(slot)
    local pdata = GetPData(Player)
    local item = pdata.items[slot] or pdata.items[tostring(slot)]
    if not item then
        if Config.Debug then print('[bobo-inventory] useItem : item introuvable slot ' .. tostring(slot)) end
        return
    end

    if Config.Debug then print('[bobo-inventory] useItem : ' .. item.name .. ' slot ' .. tostring(slot)) end

    local ok, err = pcall(function()
        exports['bobo-items']:UseItem(src, item.name, item, 1)
    end)
    if not ok then
        print('[bobo-inventory] ERREUR UseItem : ' .. tostring(err))
    end
end)

RegisterNetEvent('bobo-inventory:server:finishConsume', function(itemName, slot)
    local src = source
    local Player = GetPlayer(src)
    if not Player then return end

    local consumable = Config.Consumables and Config.Consumables[itemName:lower()]
    if not consumable then return end

    if not HasItem(src, itemName, 1) then return end
    if not RemoveItem(src, itemName, 1, tonumber(slot)) then return end

    if Bridge._name ~= 'esx' then
        local pdata = GetPData(Player)
        local metadata = pdata.metadata
        local newHunger = math.min(100, (metadata.hunger or 0) + (consumable.hunger or 0))
        local newThirst = math.min(100, (metadata.thirst or 0) + (consumable.thirst or 0))
        Player.Functions.SetMetaData('hunger', newHunger)
        Player.Functions.SetMetaData('thirst', newThirst)
        TriggerClientEvent('hud:client:UpdateNeeds', src, newHunger, newThirst)
    end

    TriggerClientEvent('bobo-inventory:client:refreshGround', src)
end)

RegisterNetEvent('bobo-inventory:server:giveItem', function(slot, amount, targetId)
    local src = source
    local Player = GetPlayer(src)
    local Target = GetPlayer(tonumber(targetId))
    if not Player or not Target then return end

    amount = tonumber(amount) or 1
    local pdata = GetPData(Player)
    local item = pdata.items[tonumber(slot)] or pdata.items[tostring(slot)]
    if not item or item.amount < amount then
        Notify(src, Config.Lang.invalidqty, 'error')
        return
    end

    if RemoveItem(src, item.name, amount, tonumber(slot)) then
        if AddItem(targetId, item.name, amount, nil, item.info) then
            Notify(src,      Config.Lang.gave:format(amount, item.label),     'success')
            Notify(targetId, Config.Lang.received:format(amount, item.label), 'success')
        else
            AddItem(src, item.name, amount, tonumber(slot), item.info)
            Notify(src, Config.Lang.targetfull, 'error')
        end
    end
end)

-- ===================================================================
-- SYSTÈME DE SOL (drops partagés, en mémoire)
-- ===================================================================

local GroundDrops = {}
local DropCounter = 0
local DROP_RADIUS = 3.0

RegisterNetEvent('bobo-inventory:server:dropItem', function(slot, amount, coords)
    local src = source
    local Player = GetPlayer(src)
    if not Player then return end
    if not coords or not coords.x then return end

    amount = tonumber(amount) or 1
    local pdata = GetPData(Player)
    local item = pdata.items[tonumber(slot)] or pdata.items[tostring(slot)]
    if not item or (item.amount or 1) < amount then return end

    if not RemoveItem(src, item.name, amount, tonumber(slot)) then return end

    DropCounter = DropCounter + 1
    local dropId = DropCounter
    GroundDrops[dropId] = {
        id     = dropId,
        coords = { x = coords.x, y = coords.y, z = coords.z },
        items  = {
            {
                name        = item.name,
                amount      = amount,
                label       = item.label,
                image       = item.image,
                weight      = item.weight,
                info        = item.info,
                description = item.description,
            }
        }
    }

    Notify(src, Config.Lang.dropped:format(amount, item.label), 'primary')
    TriggerClientEvent('bobo-inventory:client:spawnDropObject', -1, dropId, coords)
    TriggerClientEvent('bobo-inventory:client:refreshGround', src)
end)

CreateCallback('bobo-inventory:server:getNearbyDrops', function(source, cb, coords)
    local nearby = {}
    if not coords or not coords.x then cb(nearby) return end

    for id, drop in pairs(GroundDrops) do
        local dx = drop.coords.x - coords.x
        local dy = drop.coords.y - coords.y
        local dz = drop.coords.z - coords.z
        local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
        if dist <= DROP_RADIUS + 2.0 then
            nearby[#nearby + 1] = drop
        end
    end
    cb(nearby)
end)

RegisterNetEvent('bobo-inventory:server:pickupDrop', function(dropId, itemIndex, coords)
    local src = source
    local Player = GetPlayer(src)
    if not Player then return end

    dropId    = tonumber(dropId)
    itemIndex = tonumber(itemIndex)
    local drop = GroundDrops[dropId]
    if not drop then return end

    if coords and coords.x then
        local dx   = drop.coords.x - coords.x
        local dy   = drop.coords.y - coords.y
        local dz   = drop.coords.z - coords.z
        local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
        if dist > DROP_RADIUS + 3.0 then
            Notify(src, Config.Lang.toofar, 'error')
            return
        end
    end

    local dropItem = drop.items[itemIndex]
    if not dropItem then return end

    if AddItem(src, dropItem.name, dropItem.amount, nil, dropItem.info) then
        table.remove(drop.items, itemIndex)
        Notify(src, Config.Lang.picked:format(dropItem.amount, dropItem.label), 'success')

        if #drop.items == 0 then
            GroundDrops[dropId] = nil
            TriggerClientEvent('bobo-inventory:client:removeDropObject', -1, dropId)
        end

        TriggerClientEvent('bobo-inventory:client:refreshGround', src)
    else
        Notify(src, Config.Lang.invfull, 'error')
    end
end)

-- ===================================================================
-- GILET PARE-BALLES
-- ===================================================================

CreateCallback('bobo-inventory:server:hasVest', function(source, cb)
    if HasItem(source, 'bulletproof_vest', 1) then
        if RemoveItem(source, 'bulletproof_vest', 1) then
            cb(true) return
        end
    end
    cb(false)
end)

RegisterNetEvent('bobo-inventory:server:returnVest', function(remaining)
    local src = source
    local Player = GetPlayer(src)
    if not Player then return end

    remaining = tonumber(remaining) or 0
    if remaining <= 0 then return end

    AddItem(src, 'bulletproof_vest', 1, nil, { durability = math.floor(remaining) })
end)

-- ===================================================================
-- TENUE : strip / restore côté serveur
-- ===================================================================

RegisterNetEvent('bobo-inventory:server:stripAllClothes', function()
    -- Hook optionnel pour sauvegarder l'état tenue en BDD (futur)
end)

-- ===================================================================
-- ÉQUIPEMENT (vêtements)
-- ===================================================================

CreateCallback('bobo-inventory:server:getEquipment', function(source, cb)
    local Player = GetPlayer(source)
    if not Player then cb(nil) return end

    local result = MySQL.prepare.await(
        'SELECT equipment FROM bobo_equipment WHERE citizenid = ?',
        { GetPData(Player).citizenid }
    )
    cb(result and json.decode(result) or nil)
end)

RegisterNetEvent('bobo-inventory:server:equip', function(slotName, equipData)
    local src = source
    local Player = GetPlayer(src)
    if not Player then return end

    local pdata = GetPData(Player)
    local result = MySQL.prepare.await(
        'SELECT equipment FROM bobo_equipment WHERE citizenid = ?',
        { pdata.citizenid }
    )
    local equipment = result and json.decode(result) or {}
    equipment[slotName] = equipData

    MySQL.insert(
        'INSERT INTO bobo_equipment (citizenid, equipment) VALUES (?, ?) ON DUPLICATE KEY UPDATE equipment = ?',
        { pdata.citizenid, json.encode(equipment), json.encode(equipment) }
    )
end)

RegisterNetEvent('bobo-inventory:server:unequip', function(slotName)
    local src = source
    local Player = GetPlayer(src)
    if not Player then return end

    local pdata = GetPData(Player)
    local result = MySQL.prepare.await(
        'SELECT equipment FROM bobo_equipment WHERE citizenid = ?',
        { pdata.citizenid }
    )
    local equipment = result and json.decode(result) or {}
    equipment[slotName] = nil

    MySQL.insert(
        'INSERT INTO bobo_equipment (citizenid, equipment) VALUES (?, ?) ON DUPLICATE KEY UPDATE equipment = ?',
        { pdata.citizenid, json.encode(equipment), json.encode(equipment) }
    )
end)

-- ===================================================================
-- DÉPLACEMENT D'ITEMS ENTRE SLOTS
-- ===================================================================

RegisterNetEvent('bobo-inventory:server:moveItem', function(fromSlot, toSlot)
    local src = source
    local Player = GetPlayer(src)
    if not Player then return end

    fromSlot = tonumber(fromSlot)
    toSlot   = tonumber(toSlot)
    if not fromSlot or not toSlot or fromSlot == toSlot then return end

    local pdata  = GetPData(Player)
    local raw    = pdata.items or {}
    local bySlot = {}

    for k, v in pairs(raw) do
        if v and v.name then
            local slotNum = tonumber(v.slot) or tonumber(k)
            if slotNum then
                v.slot = slotNum
                bySlot[slotNum] = v
            end
        end
    end

    local fromItem = bySlot[fromSlot]
    if not fromItem then return end
    local toItem = bySlot[toSlot]

    if not toItem then
        fromItem.slot = toSlot
        bySlot[toSlot]   = fromItem
        bySlot[fromSlot] = nil
    elseif toItem.name == fromItem.name and not fromItem.unique then
        toItem.amount = (toItem.amount or 1) + (fromItem.amount or 1)
        toItem.slot   = toSlot
        bySlot[toSlot]   = toItem
        bySlot[fromSlot] = nil
    else
        fromItem.slot = toSlot
        toItem.slot   = fromSlot
        bySlot[toSlot]   = fromItem
        bySlot[fromSlot] = toItem
    end

    local indexed = {}
    for slotNum, v in pairs(bySlot) do
        if v then
            v.slot = slotNum
            indexed[slotNum] = v
        end
    end

    SetItems(Player, indexed)
    TriggerClientEvent('bobo-inventory:client:forceRefresh', src, indexed)
end)

-- Commande console pour vider un inventaire
RegisterCommand('clearinv', function(source, args)
    local targetId = tonumber(args[1]) or source
    if targetId == 0 then
        print('[bobo-inventory] Usage : clearinv [id joueur]')
        return
    end
    ClearInventory(targetId)
    print(('[bobo-inventory] Inventaire du joueur %s vidé'):format(targetId))
end, true)

-- ===================================================================
-- HOTBAR (raccourcis 1-5)
-- ===================================================================

CreateCallback('bobo-inventory:server:getHotbar', function(source, cb)
    local Player = GetPlayer(source)
    if not Player then cb(nil) return end

    local result = MySQL.prepare.await(
        'SELECT hotbar FROM bobo_hotbar WHERE citizenid = ?',
        { GetPData(Player).citizenid }
    )
    if result then
        local decoded = json.decode(result)
        local hotbar = {}
        if decoded then
            for k, v in pairs(decoded) do
                if v then hotbar[tostring(k)] = v end
            end
        end
        cb(hotbar)
    else
        cb({})
    end
end)

RegisterNetEvent('bobo-inventory:server:saveHotbar', function(hotbar)
    local src = source
    local Player = GetPlayer(src)
    if not Player then return end

    local cleanHotbar = {}
    if hotbar then
        for k, v in pairs(hotbar) do
            if v then cleanHotbar[tostring(k)] = v end
        end
    end

    if Config.Debug then
        print('[bobo-inventory] saveHotbar : ' .. json.encode(cleanHotbar))
    end

    local cid = GetPData(Player).citizenid
    MySQL.insert(
        'INSERT INTO bobo_hotbar (citizenid, hotbar) VALUES (?, ?) ON DUPLICATE KEY UPDATE hotbar = ?',
        { cid, json.encode(cleanHotbar), json.encode(cleanHotbar) }
    )
end)

RegisterNetEvent('bobo-inventory:server:useItemByName', function(itemName)
    local src = source
    local Player = GetPlayer(src)
    if not Player then return end

    local pdata = GetPData(Player)
    local slot = GetFirstSlotByItem(pdata.items, itemName:lower())
    if not slot then
        Notify(src, Config.Lang.noitem, 'error')
        return
    end

    local item = pdata.items[slot]
    if not item then return end

    local sharedItems = GetSharedItems()
    if sharedItems then
        local itemInfo = sharedItems[item.name:lower()]
        if not itemInfo or not itemInfo.useable then return end
    end

    exports['bobo-items']:UseItem(src, item.name, item, 1)
end)