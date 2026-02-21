-- Detect entering vehicle
CreateThread(function()
    while true do
        Wait(250)

        local ped = PlayerPedId()
        local veh = GetVehiclePedIsTryingToEnter(ped)

        if veh ~= 0 then
            local model = GetEntityModel(veh)
            local spawncode = GetDisplayNameFromVehicleModel(model)

            TriggerServerEvent('veh:checkAccess', spawncode)
        end
    end
end)

-- Deny access
RegisterNetEvent('veh:deny', function()
    local ped = PlayerPedId()
    ClearPedTasksImmediately(ped)

    lib.notify({
        title = 'Vehicle Access',
        description = 'You do not have access to this vehicle',
        type = 'error'
    })
end)

-- Gets Current spawn code
local function getCurrentSpawncode()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)

    if veh == 0 then return nil end

    local model = GetEntityModel(veh)
    return GetDisplayNameFromVehicleModel(model):lower()
end

-- Owner Menu
lib.registerContext({
    id = 'vehicle_ownership_menu',
    title = 'Vehicle Ownership',
    options = {
        {
            title = 'Give Access',
            description = 'Allow another player to drive this vehicle',
            onSelect = function()
                local spawncode = getCurrentSpawncode()
                if not spawncode then return end

                local input = lib.inputDialog('Give Vehicle Access', {
                    { type = 'number', label = 'Player ID', required = true }
                })

                if not input then return end

                lib.callback.await(
                    'veh:grantAccess',
                    false,
                    spawncode,
                    input[1]
                )
            end
        },
        {
            title = 'Revoke Access',
            description = 'Remove driving access',
            onSelect = function()
                local spawncode = getCurrentSpawncode()
                if not spawncode then return end

                local input = lib.inputDialog('Revoke Vehicle Access', {
                    { type = 'number', label = 'Player ID', required = true }
                })

                if not input then return end

                lib.callback.await(
                    'veh:revokeAccess',
                    false,
                    spawncode,
                    input[1]
                )
            end
        },
        {
            title = 'Transfer Ownership',
            description = 'Give ownership to another player',
            onSelect = function()
                local spawncode = getCurrentSpawncode()
                if not spawncode then return end

                local input = lib.inputDialog('Transfer Ownership', {
                    { type = 'number', label = 'New Owner Player ID', required = true }
                })

                if not input then return end

                lib.callback.await(
                    'veh:transferOwnership',
                    false,
                    spawncode,
                    input[1]
                )
            end
        }
    }
})

-- Admin
lib.registerContext({
    id = 'vehicle_admin_menu',
    title = 'Admin Vehicle Ownership',
    options = {
        {
            title = 'Set Vehicle Owner',
            description = 'Assign spawncode ownership to a player',
            onSelect = function()
                local input = lib.inputDialog('Set Vehicle Owner', {
                    { type = 'number', label = 'Player ID', required = true },
                    { type = 'input', label = 'Vehicle Spawncode', required = true }
                })

                if not input then return end

                lib.callback.await(
                    'veh:setSpawnOwner',
                    false,
                    input[1],
                    input[2]
                )
            end
        }
    }
})

-- Commands
RegisterCommand('vehmenu', function()
    lib.showContext('vehicle_ownership_menu')
end)

RegisterCommand('vehadmin', function()
    lib.showContext('vehicle_admin_menu')
end)