local registeredStashes = {}
local ox_inventory = exports.ox_inventory

-- Generate a random 3-letter uppercase string (excluding reserved names)
local function GenerateText(num)
    local str
    repeat
        str = {}
        for i = 1, num do
            str[i] = string.char(math.random(65, 90)) -- A-Z
        end
        str = table.concat(str)
    until str ~= 'POL' and str ~= 'EMS' -- Avoid reserved words
    return str
end

-- Generate a unique serial (used for backpack identifier)
local function GenerateSerial(text)
    if text and #text > 3 then
        return text
    end
    return ('%s%s%s'):format(math.random(100000, 999999), text or GenerateText(3), math.random(100000, 999999))
end

-- Ensure ox_inventory is running before proceeding
CreateThread(function()
    while GetResourceState('ox_inventory') ~= 'started' do Wait(500) end
end)

-- Register a new backpack stash if it doesn't already exist
RegisterServerEvent('wasabi_backpack:openBackpack')
AddEventHandler('wasabi_backpack:openBackpack', function(identifier)
    if not registeredStashes[identifier] then
        ox_inventory:RegisterStash('bag_' .. identifier, 'Backpack', Config.BackpackStorage.slots, Config.BackpackStorage.weight, false)
        registeredStashes[identifier] = true
    end
end)

-- Generate a new unique identifier for a backpack and store it
lib.callback.register('wasabi_backpack:getNewIdentifier', function(source, slot)
    local newId = GenerateSerial()
    ox_inventory:SetMetadata(source, slot, { identifier = newId })
    ox_inventory:RegisterStash('bag_' .. newId, 'Backpack', Config.BackpackStorage.slots, Config.BackpackStorage.weight, false)
    registeredStashes[newId] = true
    return newId
end)

-- Hook for swapping items (Prevents putting a backpack inside another backpack)
local swapHook = ox_inventory:registerHook('swapItems', function(payload)
    local fromInventory, toInventory, moveType = payload.fromInventory, payload.toInventory, payload.toType
    local player = payload.source
    local backpackCount = ox_inventory:GetItem(player, 'backpack', nil, true)

    -- Prevent backpacks inside backpacks
    if string.find(toInventory, 'bag_') then
        TriggerClientEvent('ox_lib:notify', player, { type = 'error', title = Strings.action_incomplete, description = Strings.backpack_in_backpack })
        return false
    end

    -- Prevent multiple backpacks if Config is enabled
    if Config.OneBagInInventory and backpackCount > 0 and moveType == 'player' and toInventory ~= fromInventory then
        TriggerClientEvent('ox_lib:notify', player, { type = 'error', title = Strings.action_incomplete, description = Strings.one_backpack_only })
        return false
    end

    return true
end, {
    print = false, -- Debug toggle
    itemFilter = { backpack = true }
})

-- Hook for preventing multiple backpacks in inventory
local createHook
if Config.OneBagInInventory then
    createHook = ox_inventory:registerHook('createItem', function(payload)
        local player = payload.inventoryId
        local backpackCount = ox_inventory:GetItem(player, 'backpack', nil, true)

        -- If player already has a backpack, remove the extra one
        if backpackCount > 0 then
            local backpackSlot
            for _, item in pairs(ox_inventory:GetInventoryItems(player)) do
                if item.name == 'backpack' then
                    backpackSlot = item.slot
                    break
                end
            end

            -- Remove extra backpack after a short delay
            CreateThread(function()
                Wait(1000)
                for _, item in pairs(ox_inventory:GetInventoryItems(player)) do
                    if item.name == 'backpack' and item.slot ~= backpackSlot then
                        if ox_inventory:RemoveItem(player, 'backpack', 1, nil, item.slot) then
                            TriggerClientEvent('ox_lib:notify', player, { type = 'error', title = Strings.action_incomplete, description = Strings.one_backpack_only })
                        end
                        break
                    end
                end
            end)
        end
    end, {
        print = false, -- Debug toggle
        itemFilter = { backpack = true }
    })
end

-- Cleanup hooks when resource stops
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        ox_inventory:removeHooks(swapHook)
        if Config.OneBagInInventory then
            ox_inventory:removeHooks(createHook)
        end
    end
end)
