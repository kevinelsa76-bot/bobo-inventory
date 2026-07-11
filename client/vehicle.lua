-- =====================================================================
-- bobo-inventory | client/vehicle.lua
-- Coffre et boîte à gants des véhicules
-- =====================================================================

-- Variable globale pour que main.lua puisse vérifier l'état
vehicleInventoryOpen = false
local currentVehicleData = nil
local TRUNK_DISTANCE     = 3.5

-- -----------------------------------------------------------------------
-- Helpers
-- -----------------------------------------------------------------------

local function IsInVehicle(ped)
    return IsPedInAnyVehicle(ped, false)
end

local function GetClosestVehicleCustom(pedCoords, maxDist)
    local closest = nil
    local closestDist = maxDist
    local vehicles = GetGamePool('CVehicle')
    for _, v in ipairs(vehicles) do
        if DoesEntityExist(v) then
            local dist = #(pedCoords - GetEntityCoords(v))
            if dist < closestDist then
                closestDist = dist
                closest = v
            end
        end
    end
    return closest, closestDist
end

-- -----------------------------------------------------------------------
-- Ouvrir / Fermer
-- -----------------------------------------------------------------------

local function OpenVehicleInventory(vehType, plate, vehSlots, playerItems, playerCash, hotbar)
    if inventoryOpen or vehicleInventoryOpen then return end

    vehicleInventoryOpen = true
    currentVehicleData   = { type = vehType, plate = plate }

    local maxVehWeight = vehType == 'trunk' and Config.MaxTrunkWeight or Config.MaxGloveboxWeight
    local maxVehSlots  = vehType == 'trunk' and Config.MaxTrunkSlots  or Config.MaxGloveboxSlots

    SetNuiFocus(true, true)
    SendNUIMessage({
        action           = 'openVehicleWithPlayer',
        vehType          = vehType,
        plate            = plate,
        vehicleInventory = vehSlots or {},
        maxVehicleWeight = maxVehWeight,
        maxVehicleSlots  = maxVehSlots,
        playerInventory  = playerItems or {},
        maxPlayerWeight  = Config.MaxInventoryWeight,
        maxPlayerSlots   = Config.MaxInventorySlots,
        cash             = playerCash or 0,
        hotbar           = hotbar or {},
    })
end

-- Véhicule en cours d'utilisation (pour l'animation)
local currentVehicleEntity = nil

local function OpenTrunkPhysically(vehicle)
    if not DoesEntityExist(vehicle) then return end
    -- Ouvre le coffre physiquement (bone "boot")
    SetVehicleDoorOpen(vehicle, 5, false, false)
end

local function CloseTrunkPhysically()
    if currentVehicleEntity and DoesEntityExist(currentVehicleEntity) then
        SetVehicleDoorShut(currentVehicleEntity, 5, false)
    end
    currentVehicleEntity = nil
end

local vehicleJustClosed = false

local function CloseVehicleInventory()
    if not vehicleInventoryOpen then return end
    vehicleInventoryOpen = false
    -- Fermer le coffre physiquement si c'était un coffre
    if currentVehicleData and currentVehicleData.type == 'trunk' then
        CloseTrunkPhysically()
    end
    currentVehicleData   = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    vehicleJustClosed = true
    SetTimeout(300, function()
        vehicleJustClosed = false
    end)
end

-- -----------------------------------------------------------------------
-- Commandes / Touches
-- -----------------------------------------------------------------------

RegisterCommand('bobocoffre', function()
    if vehicleJustClosed then return end
    if vehicleInventoryOpen then
        CloseVehicleInventory()
        return
    end
    if inventoryOpen then return end

    local ped       = PlayerPedId()
    local pedCoords = GetEntityCoords(ped)
    local vehicle, dist = GetClosestVehicleCustom(pedCoords, TRUNK_DISTANCE)

    if not vehicle then
        Bridge.Notify(Config.Lang.noVehicleNearby, 'error')
        return
    end

    -- Ouvrir le coffre physiquement
    currentVehicleEntity = vehicle
    OpenTrunkPhysically(vehicle)

    local plate = GetVehicleNumberPlateText(vehicle):gsub('%s+', '')
    TriggerServerEvent('bobo-inventory:server:openTrunk', plate)
end, false)

RegisterKeyMapping('bobocoffre', 'Ouvrir le coffre du véhicule', 'keyboard', Config.TrunkKey or 'G')

RegisterCommand('boboboiteagants', function()
    if vehicleInventoryOpen then
        CloseVehicleInventory()
        return
    end
    if inventoryOpen then return end

    local ped = PlayerPedId()
    if not IsInVehicle(ped) then
        Bridge.Notify(Config.Lang.notInVehicle, 'error')
        return
    end

    local vehicle = GetVehiclePedIsIn(ped, false)
    local plate   = GetVehicleNumberPlateText(vehicle):gsub('%s+', '')
    TriggerServerEvent('bobo-inventory:server:openGlovebox', plate)
end, false)

RegisterKeyMapping('boboboiteagants', 'Ouvrir la boîte à gants', 'keyboard', Config.GloveboxKey or 'I')

-- -----------------------------------------------------------------------
-- Réception depuis le serveur
-- -----------------------------------------------------------------------

RegisterNetEvent('bobo-inventory:client:openTrunk', function(plate, vehItems)
    OpenVehicleInventory('trunk', plate, vehItems,
        Bridge.GetItems(),
        Bridge.GetMoney(),
        Hotbar or {}
    )
end)

RegisterNetEvent('bobo-inventory:client:openGlovebox', function(plate, vehItems)
    OpenVehicleInventory('glovebox', plate, vehItems,
        Bridge.GetItems(),
        Bridge.GetMoney(),
        Hotbar or {}
    )
end)

-- -----------------------------------------------------------------------
-- Callbacks NUI
-- -----------------------------------------------------------------------

RegisterNUICallback('closeVehicleInventory', function(_, cb)
    CloseVehicleInventory()
    cb('ok')
end)

RegisterNUICallback('moveToVehicle', function(data, cb)
    if not currentVehicleData then cb({ success = false }) return end
    TriggerServerEvent('bobo-inventory:server:moveToVehicle',
        currentVehicleData.type,
        currentVehicleData.plate,
        data.fromSlot,
        data.amount or 1
    )
    cb('ok')
end)

RegisterNUICallback('moveFromVehicle', function(data, cb)
    if not currentVehicleData then cb({ success = false }) return end
    TriggerServerEvent('bobo-inventory:server:moveFromVehicle',
        currentVehicleData.type,
        currentVehicleData.plate,
        data.fromSlot,
        data.amount or 1
    )
    cb('ok')
end)

-- -----------------------------------------------------------------------
-- Refresh depuis le serveur
-- -----------------------------------------------------------------------

RegisterNetEvent('bobo-inventory:client:refreshVehicle', function(vehItems, playerItems)
    if not vehicleInventoryOpen or not currentVehicleData then return end
    SendNUIMessage({
        action           = 'refreshVehicle',
        vehicleInventory = vehItems or {},
        playerInventory  = playerItems or {},
        cash             = Bridge.GetMoney(),
    })
end)

-- -----------------------------------------------------------------------
-- Fermeture auto si le joueur s'éloigne
-- -----------------------------------------------------------------------

CreateThread(function()
    while true do
        if not vehicleInventoryOpen then
            Wait(1000)
        else
            Wait(500)
            if not currentVehicleData then
                -- Sécurité : état incohérent
                vehicleInventoryOpen = false
            elseif currentVehicleData.type == 'trunk' then
                -- Utilise l'entité déjà connue plutôt que de re-scanner le pool
                local tooFar = false
                if currentVehicleEntity and DoesEntityExist(currentVehicleEntity) then
                    local dist = #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(currentVehicleEntity))
                    tooFar = dist > TRUNK_DISTANCE + 1.0
                else
                    tooFar = true
                end
                if tooFar then
                    CloseVehicleInventory()
                    Bridge.Notify(Config.Lang.tooFarVehicle, 'error')
                end
            elseif currentVehicleData.type == 'glovebox' then
                if not IsInVehicle(PlayerPedId()) then
                    CloseVehicleInventory()
                    Bridge.Notify(Config.Lang.tooFarVehicle, 'error')
                end
            end
        end
    end
end)

print('^2[bobo-inventory]^7 Module véhicule client chargé.')