-- =====================================================================
-- bobo-inventory | client/main.lua
-- Compatible ESX / QBCore / QBox via Bridge
-- =====================================================================

-- Variables globales (vehicleInventoryOpen peut être géré par vehicle.lua)
inventoryOpen        = false
vehicleInventoryOpen = vehicleInventoryOpen or false
local PlayerData  = {}
local appearance  = exports['illenium-appearance']

local armorEquipped = false
local armorThread   = false
local Hotbar        = {}
local savedOutfit   = nil   -- tenue sauvegardée avant déshabillage (bouton TENUE)
local savedMask     = nil   -- masque sauvegardé avant retrait (bouton MASQUE)

-- Raccourci local pour les notifications
local function Notify(msg, ntype, duration)
    Bridge.Notify(msg, ntype, duration)
end

-- =====================================================================
-- ÉVÉNEMENTS FRAMEWORK (chargement / déchargement joueur)
-- =====================================================================

local ev = Bridge.Events()

RegisterNetEvent(ev.onLoad, function()
    PlayerData = Bridge.GetPlayerData()
    -- Hotbar : on attend 1s que le framework soit prêt
    Wait(1000)
    Bridge.TriggerCallback('bobo-inventory:server:getHotbar', function(saved)
        if saved then Hotbar = saved end
    end)
    -- Équipement : on attend encore 1s pour que le ped soit bien chargé (total 2s)
    Wait(1000)
    RestoreEquipment()
end)

RegisterNetEvent(ev.onUnload, function()
    PlayerData = {}
end)

-- Mise à jour des données joueur (items, argent…)
RegisterNetEvent(ev.onDataUpdate, function(data)
    if Bridge._name == 'esx' then
        -- ESX envoie directement la clé modifiée
        PlayerData = Bridge.GetPlayerData()
    else
        -- QBCore / QBox envoient le PlayerData complet
        PlayerData = data
    end

    if inventoryOpen then
        SendNUIMessage({
            action    = 'refresh',
            inventory = Bridge.GetItems() or {},
            cash      = Bridge.GetMoney(),
        })
    end
end)

-- Mise à jour de l'argent en temps réel
RegisterNetEvent(ev.onMoneyChange, function()
    if not inventoryOpen then return end
    PlayerData = Bridge.GetPlayerData()
    SendNUIMessage({
        action = 'money',
        cash   = Bridge.GetMoney(),
    })
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    PlayerData = Bridge.GetPlayerData() or {}
end)

-- =====================================================================
-- ÉQUIPEMENT
-- =====================================================================

function ApplyEquipment(slotConf, data)
    local ped = PlayerPedId()
    if slotConf.kind == 'component' then
        appearance:setPedComponent(ped, {
            component_id = slotConf.id,
            drawable     = data.drawable,
            texture      = data.texture or 0,
        })
    else
        appearance:setPedProp(ped, {
            prop_id  = slotConf.id,
            drawable = data.drawable,
            texture  = data.texture or 0,
        })
    end
end

function RemoveEquipment(slotConf)
    local ped = PlayerPedId()
    if slotConf.kind == 'component' then
        local nakedDrawable = Config.NakedComponents[slotConf.id] or 0
        appearance:setPedComponent(ped, {
            component_id = slotConf.id,
            drawable     = nakedDrawable,
            texture      = 0,
        })
    else
        appearance:setPedProp(ped, {
            prop_id  = slotConf.id,
            drawable = -1,
            texture  = 0,
        })
    end
end

function RestoreEquipment()
    Bridge.TriggerCallback('bobo-inventory:server:getEquipment', function(equipment)
        if not equipment then return end
        for slotName, data in pairs(equipment) do
            local slotConf = Config.EquipmentSlots[slotName]
            if slotConf and data then
                ApplyEquipment(slotConf, data)
            end
        end
    end)
end

-- =====================================================================
-- OUVERTURE / FERMETURE
-- =====================================================================

local function OpenInventory()
    if inventoryOpen then return end
    -- Bloquer si un inventaire véhicule est déjà ouvert
    if vehicleInventoryOpen then return end

    PlayerData = Bridge.GetPlayerData()
    inventoryOpen = true
    SetNuiFocus(true, true)

    SendNUIMessage({
        action          = 'open',
        inventory       = Bridge.GetItems() or {},
        equipmentSlots  = Config.EquipmentSlots,
        maxWeight       = Config.MaxInventoryWeight,
        maxSlots        = Config.MaxInventorySlots,
        cash            = Bridge.GetMoney(),
        hotbar          = Hotbar,
        clothesStripped = (savedOutfit ~= nil),  -- true si le joueur est actuellement nu
        maskOff         = (savedMask ~= nil),    -- true si le masque est retiré
    })

    local pedArmor = PlayerPedId()
    local armorVal = armorEquipped and GetPedArmour(pedArmor) or 0
    SendNUIMessage({ action = 'armor', value = armorVal })

    RefreshGround()
end

local function CloseInventory()
    if not inventoryOpen then return end
    inventoryOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterKeyMapping('boboinventory', 'Ouvrir inventaire', 'keyboard', Config.OpenKey)
RegisterCommand('boboinventory', function()
    if inventoryOpen then CloseInventory() else OpenInventory() end
end, false)

-- =====================================================================
-- CALLBACKS NUI
-- =====================================================================

RegisterNUICallback('closeInventory', function(_, cb)
    CloseInventory()
    cb('ok')
end)

RegisterNUICallback('equip', function(data, cb)
    local slotName = data.slotName
    local itemSlot = data.itemSlot
    local slotConf = Config.EquipmentSlots[slotName]

    if not slotConf then cb({ success = false }) return end

    local items = Bridge.GetItems()
    local item  = items[itemSlot]
    if not item or not item.info then cb({ success = false }) return end

    if item.info.slot ~= slotName then
        Notify(Config.Lang.wrongslot, 'error')
        cb({ success = false })
        return
    end

    local equipData = { drawable = item.info.drawable, texture = item.info.texture or 0 }
    ApplyEquipment(slotConf, equipData)
    TriggerServerEvent('bobo-inventory:server:equip', slotName, equipData)
    Notify(Config.Lang.equipped, 'success')
    cb({ success = true })
end)

RegisterNUICallback('unequip', function(data, cb)
    local slotName = data.slotName
    local slotConf = Config.EquipmentSlots[slotName]
    if not slotConf then cb({ success = false }) return end

    RemoveEquipment(slotConf)
    TriggerServerEvent('bobo-inventory:server:unequip', slotName)
    Notify(Config.Lang.unequipped, 'primary')
    cb({ success = true })
end)

-- Refresh forcé depuis le serveur
RegisterNetEvent('bobo-inventory:client:forceRefresh', function(items)
    if Bridge._name == 'esx' then
        PlayerData = Bridge.GetPlayerData()
    else
        PlayerData.items = items
    end
    if inventoryOpen then
        SendNUIMessage({
            action    = 'refresh',
            inventory = items or {},
            cash      = Bridge.GetMoney(),
        })
    end
end)

-- =====================================================================
-- MENU CLIC DROIT : Utiliser / Donner / Jeter
-- =====================================================================

function GetClosestPlayer()
    local players          = GetActivePlayers()
    local closestDistance  = -1
    local closestPlayer    = -1
    local myPed            = PlayerPedId()
    local myCoords         = GetEntityCoords(myPed)

    for _, player in ipairs(players) do
        local targetPed = GetPlayerPed(player)
        if targetPed ~= myPed then
            local targetCoords = GetEntityCoords(targetPed)
            local distance     = #(myCoords - targetCoords)
            if closestDistance == -1 or distance < closestDistance then
                closestPlayer    = player
                closestDistance  = distance
            end
        end
    end

    return closestPlayer, closestDistance
end

RegisterNUICallback('useItem', function(data, cb)
    TriggerServerEvent('bobo-inventory:server:useItem', data.slot)
    cb('ok')
end)

RegisterNUICallback('giveItem', function(data, cb)
    local closest, dist = GetClosestPlayer()
    if closest == -1 or dist > 3.0 then
        Notify(Config.Lang.noplayer, 'error')
        cb({ success = false })
        return
    end
    local targetServerId = GetPlayerServerId(closest)
    TriggerServerEvent('bobo-inventory:server:giveItem', data.slot, data.amount or 1, targetServerId)
    cb({ success = true })
end)

RegisterNUICallback('dropItem', function(data, cb)
    local coords = GetEntityCoords(PlayerPedId())
    TriggerServerEvent('bobo-inventory:server:dropItem', data.slot, data.amount or 1, {
        x = coords.x, y = coords.y, z = coords.z
    })
    cb('ok')
end)

-- =====================================================================
-- GILET PARE-BALLES
-- =====================================================================

function StartArmorWatch()
    if armorThread then return end
    armorThread = true

    CreateThread(function()
        while armorEquipped do
            local ped     = PlayerPedId()
            local current = GetPedArmour(ped)

            if inventoryOpen then
                SendNUIMessage({ action = 'armor', value = current })
            end

            if current <= 0 then
                armorEquipped = false
                if inventoryOpen then
                    SendNUIMessage({ action = 'armor', value = 0 })
                end
                Notify(Config.Lang.vestdestroy, 'error')
                break
            end

            Wait(500)
        end
        armorThread = false
    end)
end

RegisterNUICallback('equipArmor', function(_, cb)
    if armorEquipped then
        Notify(Config.Lang.veston, 'error')
        cb({ success = false })
        return
    end

    Bridge.TriggerCallback('bobo-inventory:server:hasVest', function(hasVest)
        if not hasVest then
            Notify(Config.Lang.novest, 'error')
            cb({ success = false })
            return
        end

        local ped = PlayerPedId()
        SetPedArmour(ped, 100)
        armorEquipped = true
        StartArmorWatch()

        if inventoryOpen then
            SendNUIMessage({ action = 'armor', value = 100 })
        end
        Notify(Config.Lang.vestequip, 'success')
        cb({ success = true })
    end)
end)

RegisterNUICallback('unequipArmor', function(_, cb)
    if not armorEquipped then cb({ success = false }) return end

    local ped       = PlayerPedId()
    local remaining = GetPedArmour(ped)

    SetPedArmour(ped, 0)
    armorEquipped = false

    if remaining > 0 then
        TriggerServerEvent('bobo-inventory:server:returnVest', remaining)
    end

    if inventoryOpen then
        SendNUIMessage({ action = 'armor', value = 0 })
    end
    Notify(Config.Lang.vestremove, 'primary')
    cb({ success = true })
end)

-- =====================================================================
-- TOGGLE TENUE (bouton TENUE) — Sauvegarder puis déshabiller / rhabiller
-- =====================================================================

-- Verrou anti-double-clic (partagé tenue + masque)
-- Capture la tenue actuelle du ped (components 1,3,4,5,6,7,8,9,10,11 + props 0,1,2,6,7)
local function SaveCurrentOutfit()
    local ped = PlayerPedId()
    local outfit = { components = {}, props = {} }

    -- Composants vestimentaires principaux
    local compIds = {1, 3, 4, 5, 6, 7, 8, 9, 10, 11}
    for _, id in ipairs(compIds) do
        outfit.components[id] = {
            drawable = GetPedDrawableVariation(ped, id),
            texture  = GetPedTextureVariation(ped, id),
        }
    end

    -- Props (chapeau, lunettes, oreilles, bracelet, montre)
    local propIds = {0, 1, 2, 6, 7}
    for _, id in ipairs(propIds) do
        local drawable = GetPedPropIndex(ped, id)
        local texture  = GetPedPropTextureIndex(ped, id)
        outfit.props[id] = { drawable = drawable, texture = texture }
    end

    return outfit
end

-- Réapplique une tenue sauvegardée
local function RestoreOutfit(outfit)
    if not outfit then return end
    local ped = PlayerPedId()

    for id, comp in pairs(outfit.components) do
        SetPedComponentVariation(ped, id, comp.drawable, comp.texture, 0)
    end

    for id, prop in pairs(outfit.props) do
        if prop.drawable >= 0 then
            SetPedPropIndex(ped, id, prop.drawable, prop.texture, true)
        else
            ClearPedProp(ped, id)
        end
    end
end

RegisterNUICallback('stripClothes', function(_, cb)
    savedOutfit        = SaveCurrentOutfit()
    local ped          = PlayerPedId()
    local maskDrawable = GetPedDrawableVariation(ped, 1)
    local maskTexture  = GetPedTextureVariation(ped, 1)
    cb('ok')

    SetPedDefaultComponentVariation(ped)
    local naked = Config.NakedComponents or {}
    for compId, drawable in pairs(naked) do
        if compId ~= 1 then SetPedComponentVariation(ped, compId, drawable, 0, 0) end
    end
    SetPedComponentVariation(ped, 1, maskDrawable, maskTexture, 0)
    TriggerServerEvent('bobo-inventory:server:stripAllClothes')
    Notify(Config.Lang.unequipped, 'primary')
end)

RegisterNUICallback('restoreClothes', function(_, cb)
    local ped           = PlayerPedId()
    local outfitToApply = savedOutfit
    savedOutfit         = nil
    cb('ok')

    if outfitToApply then
        RestoreOutfit(outfitToApply)
    else
        RestoreEquipment()
    end
    Notify(Config.Lang.equipped, 'success')
end)

-- =====================================================================
-- TOGGLE MASQUE — Enlever / remettre uniquement le masque (component 1)
-- =====================================================================

RegisterNUICallback('stripMask', function(_, cb)
    local ped = PlayerPedId()
    savedMask = {
        drawable = GetPedDrawableVariation(ped, 1),
        texture  = GetPedTextureVariation(ped, 1),
    }
    local nakedDrawable = (Config.NakedComponents and Config.NakedComponents[1]) or 0
    cb('ok')

    SetPedComponentVariation(ped, 1, nakedDrawable, 0, 0)
    Notify(Config.Lang.maskOff, 'primary')
end)

RegisterNUICallback('restoreMask', function(_, cb)
    local ped         = PlayerPedId()
    local maskToApply = savedMask
    savedMask         = nil
    cb('ok')

    if maskToApply then
        SetPedComponentVariation(ped, 1, maskToApply.drawable, maskToApply.texture, 0)
    else
        Bridge.TriggerCallback('bobo-inventory:server:getEquipment', function(equipment)
            if equipment and equipment['mask'] then
                local data = equipment['mask']
                SetPedComponentVariation(ped, 1, data.drawable, data.texture or 0, 0)
            end
        end)
    end
    Notify(Config.Lang.maskOn, 'success')
end)

RegisterNetEvent('bobo-inventory:client:syncArmorOnOpen', function()
    local ped   = PlayerPedId()
    local armor = armorEquipped and GetPedArmour(ped) or 0
    SendNUIMessage({ action = 'armor', value = armor })
end)

-- =====================================================================
-- DÉPLACEMENT D'ITEMS
-- =====================================================================

RegisterNUICallback('moveItem', function(data, cb)
    TriggerServerEvent('bobo-inventory:server:moveItem', data.fromSlot, data.toSlot)
    cb('ok')
end)

-- Appelé par app.js en mode véhicule pour récupérer les items joueur séparément
RegisterNUICallback('getPlayerInventory', function(_, cb)
    SendNUIMessage({
        action    = 'refreshPlayer',
        inventory = Bridge.GetItems() or {},
        cash      = Bridge.GetMoney(),
    })
    cb('ok')
end)

-- =====================================================================
-- SYSTÈME DE SOL (drops)
-- =====================================================================

function RefreshGround()
    local coords = GetEntityCoords(PlayerPedId())
    Bridge.TriggerCallback('bobo-inventory:server:getNearbyDrops', function(drops)
        SendNUIMessage({
            action = 'groundUpdate',
            drops  = drops or {},
        })
    end, { x = coords.x, y = coords.y, z = coords.z })
end

RegisterNUICallback('pickupDrop', function(data, cb)
    local coords = GetEntityCoords(PlayerPedId())
    TriggerServerEvent('bobo-inventory:server:pickupDrop', data.dropId, data.itemIndex, {
        x = coords.x, y = coords.y, z = coords.z
    })
    cb('ok')
end)

RegisterNetEvent('bobo-inventory:client:refreshGround', function()
    PlayerData = Bridge.GetPlayerData()
    if inventoryOpen then
        SendNUIMessage({
            action    = 'refresh',
            inventory = Bridge.GetItems() or {},
            cash      = Bridge.GetMoney(),
        })
    end
    RefreshGround()
end)

-- =====================================================================
-- CONSOMMATION (manger / boire)
-- =====================================================================

local isConsuming = false

RegisterNetEvent('bobo-inventory:client:consume', function(itemName, slot, consumable)
    if isConsuming then return end
    isConsuming = true

    if inventoryOpen then CloseInventory() end

    local ped                    = PlayerPedId()
    local animDict, animName

    if consumable.anim == 'drink' then
        animDict = 'mp_player_intdrink'
        animName = 'loop_bottle'
    else
        animDict = 'mp_player_inteat@burger'
        animName = 'mp_player_int_eat_burger'
    end

    RequestAnimDict(animDict)
    local timeout = 0
    while not HasAnimDictLoaded(animDict) and timeout < 100 do
        Wait(10)
        timeout = timeout + 1
    end
    TaskPlayAnim(ped, animDict, animName, 8.0, -8.0, -1, 49, 0, false, false, false)

    local waitTime = consumable.time or 3000
    Wait(waitTime)

    ClearPedTasks(ped)
    RemoveAnimDict(animDict)

    TriggerServerEvent('bobo-inventory:server:finishConsume', itemName, slot)

    isConsuming = false
end)

-- =====================================================================
-- HOTBAR (raccourcis 1-5)
-- =====================================================================

RegisterNUICallback('saveHotbar', function(data, cb)
    Hotbar = data.hotbar or {}
    TriggerServerEvent('bobo-inventory:server:saveHotbar', Hotbar)
    cb('ok')
end)

local function UseHotbarKey(key)
    if inventoryOpen then return end
    local itemName = Hotbar[tostring(key)]
    if not itemName then return end
    TriggerServerEvent('bobo-inventory:server:useItemByName', itemName)
end

local function HotbarHasItems()
    for i = 1, 5 do
        if Hotbar[tostring(i)] then return true end
    end
    return false
end

CreateThread(function()
    local keys = { [1]=157, [2]=158, [3]=160, [4]=164, [5]=165 }
    while true do
        -- Inventaire ouvert → on dort, pas besoin de surveiller les touches
        if inventoryOpen then
            Wait(200)
        -- Hotbar entièrement vide → on dort 500ms, rien à faire
        elseif not HotbarHasItems() then
            Wait(500)
        else
            -- Hotbar active : Wait(0) uniquement quand nécessaire
            Wait(0)
            for num, control in pairs(keys) do
                local slotKey = tostring(num)
                if Hotbar[slotKey] then
                    DisableControlAction(0, control, true)
                    if IsDisabledControlJustPressed(0, control) then
                        UseHotbarKey(num)
                    end
                end
            end
        end
    end
end)

print('^2[bobo-inventory]^7 Client chargé (' .. (Bridge._name or 'inconnu') .. ').')

-- =====================================================================
-- OBJETS 3D AU SOL (carton quand un item est jeté)
-- =====================================================================

local DropObjects = {}  -- dropId -> handle de l'objet
local DROP_MODEL  = `prop_paper_bag_small`

RegisterNetEvent('bobo-inventory:client:spawnDropObject', function(dropId, coords)
    -- Thread séparé pour ne pas bloquer
    CreateThread(function()
        RequestModel(DROP_MODEL)
        local timeout = 0
        while not HasModelLoaded(DROP_MODEL) and timeout < 100 do
            Wait(10)
            timeout = timeout + 1
        end
        if not HasModelLoaded(DROP_MODEL) then return end

        local obj = CreateObject(DROP_MODEL,
            coords.x, coords.y, coords.z,
            true,   -- réseau : visible par tous
            false,
            false
        )

        PlaceObjectOnGroundProperly(obj)
        FreezeEntityPosition(obj, true)
        SetEntityCollision(obj, true, true)

        DropObjects[dropId] = obj
        SetModelAsNoLongerNeeded(DROP_MODEL)
    end)
end)

RegisterNetEvent('bobo-inventory:client:removeDropObject', function(dropId)
    local obj = DropObjects[dropId]
    if obj and DoesEntityExist(obj) then
        DeleteObject(obj)
    end
    DropObjects[dropId] = nil
end)

-- Cleanup local de tous les objets au sol si la ressource redémarre
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for _, obj in pairs(DropObjects) do
        if DoesEntityExist(obj) then DeleteObject(obj) end
    end
    DropObjects = {}
end)