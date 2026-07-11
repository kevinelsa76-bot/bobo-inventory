-- =====================================================================
-- bobo-inventory | server/equipment.lua
-- Compatible ESX / QBCore / QBox via Bridge
-- =====================================================================

local equipmentCache = {}

local function LoadEquipment(citizenid)
    local result = MySQL.prepare.await('SELECT equipment FROM bobo_equipment WHERE citizenid = ?', { citizenid })
    if result then
        equipmentCache[citizenid] = json.decode(result) or {}
    else
        equipmentCache[citizenid] = {}
    end
    return equipmentCache[citizenid]
end

local function SaveEquipment(citizenid)
    local data = equipmentCache[citizenid] or {}
    MySQL.prepare('INSERT INTO bobo_equipment (citizenid, equipment) VALUES (?, ?) ON DUPLICATE KEY UPDATE equipment = ?', {
        citizenid, json.encode(data), json.encode(data)
    })
end

Bridge.CreateCallback('bobo-inventory:server:getEquipment', function(source, cb)
    local citizenid = Bridge.GetIdentifier(source)
    if not citizenid then cb({}) return end

    if not equipmentCache[citizenid] then
        LoadEquipment(citizenid)
    end
    cb(equipmentCache[citizenid])
end)

RegisterNetEvent('bobo-inventory:server:equip', function(slotName, data)
    local src       = source
    local citizenid = Bridge.GetIdentifier(src)
    if not citizenid then return end

    if not equipmentCache[citizenid] then LoadEquipment(citizenid) end
    equipmentCache[citizenid][slotName] = data
    SaveEquipment(citizenid)
end)

RegisterNetEvent('bobo-inventory:server:unequip', function(slotName)
    local src       = source
    local citizenid = Bridge.GetIdentifier(src)
    if not citizenid then return end

    if not equipmentCache[citizenid] then LoadEquipment(citizenid) end
    equipmentCache[citizenid][slotName] = nil
    SaveEquipment(citizenid)
end)

AddEventHandler('playerDropped', function()
    local src       = source
    local citizenid = Bridge.GetIdentifier(src)
    if not citizenid then return end

    if equipmentCache[citizenid] then
        SaveEquipment(citizenid)
        equipmentCache[citizenid] = nil
    end
end)

print('^2[bobo-inventory]^7 Module équipement serveur chargé (' .. (Bridge._name or 'inconnu') .. ').')