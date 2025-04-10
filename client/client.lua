local bagEquipped, bagObj
local hash = `p_michael_backpack_s`
local ox_inventory = exports.ox_inventory
local ped = cache.ped
local firstSpawn = true -- Track first spawn

-- Function to put on the backpack
local function PutOnBag()
    local x, y, z = table.unpack(GetOffsetFromEntityInWorldCoords(ped, 0.0, 3.0, 0.5))
    lib.requestModel(hash, 100)
    bagObj = CreateObjectNoOffset(hash, x, y, z, true, false)
    AttachEntityToEntity(bagObj, ped, GetPedBoneIndex(ped, 24818), 0.07, -0.11, -0.05, 0.0, 90.0, 175.0, true, true, false, true, 1, true)
    bagEquipped = true
end

-- Function to remove the backpack
local function RemoveBag()
    if DoesEntityExist(bagObj) then
        DeleteObject(bagObj)
    end
    SetModelAsNoLongerNeeded(hash)
    bagObj = nil
    bagEquipped = nil
end

-- ✅ Correct QBox Event for Player Loading
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    if firstSpawn then
        firstSpawn = false
        Wait(5000) -- Ensure the character fully loads before equipping the backpack

        local count = ox_inventory:Search('count', 'backpack')
        if count and count >= 1 then
            PutOnBag()
        end
    end
end)

-- ✅ Fix backpack when refreshing skin (Now Supports Illenium Appearance)
AddEventHandler('illenium-appearance:client:resetAppearance', function()
    if bagEquipped then
        RemoveBag()
        Wait(100) -- Small delay to ensure proper removal

        local count = ox_inventory:Search('count', 'backpack')
        if count and count >= 1 then
            PutOnBag()
        end
    end
end)

-- Update backpack when inventory changes
AddEventHandler('ox_inventory:updateInventory', function(changes)
    for k, v in pairs(changes) do
        if type(v) == 'table' then
            local count = ox_inventory:Search('count', 'backpack')
            if count > 0 and (not bagEquipped or not bagObj) then
                PutOnBag()
            elseif count < 1 and bagEquipped then
                RemoveBag()
            end
        end
        if type(v) == 'boolean' then
            local count = ox_inventory:Search('count', 'backpack')
            if count < 1 and bagEquipped then
                RemoveBag()
            end
        end
    end
end)

-- Remove backpack when entering a vehicle
lib.onCache('vehicle', function(value)
    if GetResourceState('ox_inventory') ~= 'started' then return end
    if value then
        RemoveBag()
    else
        local count = ox_inventory:Search('count', 'backpack')
        if count and count >= 1 then
            PutOnBag()
        end
    end
end)

-- Backpack Open Function
exports('openBackpack', function(data, slot)
    if not slot?.metadata?.identifier then
        local identifier = lib.callback.await('wasabi_backpack:getNewIdentifier', 100, data.slot)
        ox_inventory:openInventory('stash', 'bag_'..identifier)
    else
        TriggerServerEvent('wasabi_backpack:openBackpack', slot.metadata.identifier)
        ox_inventory:openInventory('stash', 'bag_'..slot.metadata.identifier)
    end
end)
