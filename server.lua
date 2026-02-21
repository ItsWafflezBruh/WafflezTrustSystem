-- Gets identifier
local Vehicles = {}

-- Load on start
CreateThread(function()
    local result = exports.oxmysql:query_async(
        'SELECT * FROM vehicle_spawn_ownership'
    )

    for _, row in ipairs(result) do
        Vehicles[row.spawncode] = {
            owner = row.owner_identifier,
            access = json.decode(row.access) or {}
        }
    end

    print('[Vehicle Trust System] Loaded ' .. #result .. ' vehicle ownership records')
end)

local function getIdentifier(src, idType)
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if id:sub(1, #idType + 1) == idType .. ':' then
            return id
        end
    end
end

-- Save to Database
local function saveVehicle(spawncode)
    local data = Vehicles[spawncode]
    if not data then return end

    exports.oxmysql:insert_async(
        [[
            INSERT INTO vehicle_spawn_ownership (spawncode, owner_identifier, access)
            VALUES (?, ?, ?)
            ON DUPLICATE KEY UPDATE
                owner_identifier = VALUES(owner_identifier),
                access = VALUES(access)
        ]],
        {
            spawncode,
            data.owner,
            json.encode(data.access)
        }
    )
end


local function logDiscord(action, src, spawncode, targetIdentifier)
    if not Config.DiscordWebhook or Config.DiscordWebhook == '' then return end

    local name = GetPlayerName(src) or 'Console'
    local srcLicense = getIdentifier(src, 'license') or 'unknown'

    local embed = {
        {
            title = '🚗 Vehicle Ownership Log',
            color = 3447003,
            fields = {
                { name = 'Action', value = action, inline = true },
                { name = 'Vehicle Spawncode', value = spawncode, inline = true },
                { name = 'Executor', value = name, inline = false },
                { name = 'Executor License', value = srcLicense, inline = false },
                { name = 'Target Identifier', value = targetIdentifier or 'N/A', inline = false }
            },
            footer = {
                text = Config.ServerName
            },
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
        }
    }

    PerformHttpRequest(
        Config.DiscordWebhook,
        function() end,
        'POST',
        json.encode({
            username = 'Vehicle Ownership',
            embeds = embed
        }),
        { ['Content-Type'] = 'application/json' }
    )
end

-- Admin Can Set Ownership
lib.callback.register('veh:setSpawnOwner', function(src, targetId, spawncode)
    if not IsPlayerAceAllowed(src, Config.AdminAce) then
        return false
    end

    targetId = tonumber(targetId)
    if not targetId or not GetPlayerPed(targetId) then
        return false
    end

    local ownerIdentifier = getIdentifier(targetId, Config.OwnerIdentifier)
    if not ownerIdentifier then
        return false
    end

    spawncode = spawncode:lower()

    Vehicles[spawncode] = {
        owner = ownerIdentifier,
        access = {}
    }

    saveVehicle(spawncode)
    logDiscord('Admin Set Owner', src, spawncode, ownerIdentifier)

    return true
end)

-- Owner grants keys
lib.callback.register('veh:grantAccess', function(src, spawncode, targetId)
    spawncode = spawncode:lower()

    local ownerIdentifier = getIdentifier(src, Config.OwnerIdentifier)
    local data = Vehicles[spawncode]

    if not data or data.owner ~= ownerIdentifier then
        return false
    end

    targetId = tonumber(targetId)
    if not targetId then return false end

    local targetLicense = getIdentifier(targetId, 'license')
    if not targetLicense then return false end

    data.access[targetLicense] = true
    saveVehicle(spawncode)
    logDiscord('Access Granted', src, spawncode, targetLicense)
    return true
end)

-- Owner Transfers ownership
lib.callback.register('veh:transferOwnership', function(src, spawncode, targetId)
    spawncode = spawncode:lower()

    local ownerIdentifier = getIdentifier(src, Config.OwnerIdentifier)
    local data = Vehicles[spawncode]

    if not data or data.owner ~= ownerIdentifier then
        return false
    end

    targetId = tonumber(targetId)
    if not targetId then return false end

    local newOwner = getIdentifier(targetId, Config.OwnerIdentifier)
    if not newOwner then return false end

    data.owner = newOwner
    data.access = {}

    saveVehicle(spawncode)
    logDiscord('Ownership Transferred', src, spawncode, newOwner)

    return true
end)

-- Checks access
RegisterNetEvent('veh:checkDriverAccess', function(spawncode)
    local src = source
    spawncode = spawncode:lower()

    local data = Vehicles[spawncode]
    if not data then return end

    local ownerIdentifier = getIdentifier(src, Config.OwnerIdentifier)
    local license = getIdentifier(src, 'license')

    -- Owner always allowed
    if data.owner == ownerIdentifier then return end

    -- Granted access allowed
    if data.access[license] then return end

    -- Not allowed → kick
    TriggerClientEvent('veh:kickDriver', src)
end)

-- Revoke keys
lib.callback.register('veh:revokeAccess', function(src, spawncode, targetId)
    spawncode = spawncode:lower()

    local ownerIdentifier = getIdentifier(src, Config.OwnerIdentifier)
    local data = Vehicles[spawncode]

    if not data or data.owner ~= ownerIdentifier then
        return false
    end

    targetId = tonumber(targetId)
    if not targetId then return false end

    local targetLicense = getIdentifier(targetId, 'license')
    if not targetLicense then return false end

    data.access[targetLicense] = nil
    saveVehicle(spawncode)
    logDiscord('Access Revoked', src, spawncode, targetLicense)
    return true
end)




