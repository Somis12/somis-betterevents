local DEBUG = false
local serv_cooldown_death = {}
local cooldown_duration_death = 500
local recentKills = {}
local playerVehicleStates = {}
local playerPedModels = {}
local playerPeds = {}
local playerWeaponStates = {}
local playerVisibilityStates = {}
local playerPedExists = {}
local playerDeathStates = {}
local joined_players = {}
for _, playerId in ipairs(GetPlayers()) do
    table.insert(joined_players, tonumber(playerId))
end


local function debugPrint(msg)
    if DEBUG then
        print(msg)
    end
end

local function isEntityPed(entity)
    return GetEntityType(entity) == 1
end


local function toUnsigned32(n)
    if n < 0 then
        return n + 4294967296
    end
    return n
end

local function isPlayerDead(playerId)
    local ped = playerPeds[playerId] or GetPlayerPed(playerId)
    if not playerId or not ped then return false end
    if not DoesEntityExist(ped) then return false end
    return GetEntityHealth(ped) <= 0
end

AddEventHandler('weaponDamageEvent', function(sender, data)
    if not data.willKill then return end

    local entity = NetworkGetEntityFromNetworkId(data.hitGlobalId)
    if not DoesEntityExist(entity) or not isEntityPed(entity) or not IsPedAPlayer(entity) then return end
    local victimId = NetworkGetEntityOwner(entity)
    local now = GetGameTimer()
    if serv_cooldown_death[victimId] and now < serv_cooldown_death[victimId] then
        return
    end
    serv_cooldown_death[victimId] = now + cooldown_duration_death

    
    local killerId = sender or "Unknown"
    local weapon = toUnsigned32(data.weaponType) or "Unknown"
    debugPrint(("[KILLED] Player %s killed by %s with %s (Server)"):format(victimId, killerId, weapon))
    recentKills[victimId] = GetGameTimer()
    TriggerEvent('somis-betterevents:killed', victimId, killerId, weapon)
end)

AddEventHandler('playerJoining', function()
    local playerId = source
    joined_players[#joined_players + 1] = playerId
    debugPrint(("[PLAYER JOINED] Player %s (ID: %d) added to joined_players"):format(GetPlayerName(playerId), playerId))
end)

AddEventHandler('playerDropped', function()
    local playerId = source
    for i = 1, #joined_players do
        if joined_players[i] == playerId then
            joined_players[i] = nil
            debugPrint(("[PLAYER DROPPED] Player ID %d removed from joined_players"):format(playerId))
            break
        end
    end
    playerVehicleStates[playerId] = nil
    playerPedModels[playerId] = nil
    playerPeds[playerId] = nil
    playerWeaponStates[playerId] = nil
    playerVisibilityStates[playerId] = nil
    playerPedExists[playerId] = nil
    playerDeathStates[playerId] = nil
    recentKills[playerId] = nil
end)

CreateThread(function()
    while true do
        for i = 1, #joined_players do
            local playerId = joined_players[i]
            if not playerId then goto continue end

            local ped = playerPeds[playerId]

            if playerPedExists[playerId] == nil then
                playerPedExists[playerId] = ped ~= 0 and DoesEntityExist(ped) or false
            end

            if not playerPedExists[playerId] then
                ped = GetPlayerPed(playerId)
                playerPedExists[playerId] = ped ~= 0 and DoesEntityExist(ped) or false
                if playerPedExists[playerId] then
                    playerPeds[playerId] = ped
                    if not playerPedModels[playerId] then
                        playerPedModels[playerId] = GetEntityModel(ped)
                        debugPrint(("Cached ped %d for player %d with model %d"):format(ped, playerId, playerPedModels[playerId]))
                    end
                else
                    goto continue
                end
            end

            local health = GetEntityHealth(ped)
            local wasDead = playerDeathStates[playerId] or false
            if health <= 0 and not wasDead then
                local killer = NetworkGetEntityOwner(GetPedSourceOfDeath(playerPeds[playerId])) or nil
                TriggerEvent('somis-betterevents:death', playerId, killer)
                debugPrint(("[DEATH] Player %s (ID: %d) has died"):format(GetPlayerName(playerId), playerId))
                playerDeathStates[playerId] = true
            elseif health > 0 and wasDead then
                playerDeathStates[playerId] = false 
            end

            local vehicle = GetVehiclePedIsIn(ped, false)
            local currentVehicleState = vehicle ~= 0 and vehicle or nil
            local previousVehicleState = playerVehicleStates[playerId]

            if currentVehicleState and currentVehicleState ~= previousVehicleState then
                TriggerEvent('somis-betterevents:vehicleEntered', playerId, currentVehicleState)
                debugPrint(("[VEHICLE ENTRY] Player %s (ID: %d) entered vehicle %s"):format(GetPlayerName(playerId), playerId, currentVehicleState))
            elseif not currentVehicleState and previousVehicleState then
                TriggerEvent('somis-betterevents:vehicleExit', playerId, previousVehicleState)
                debugPrint(("[VEHICLE EXIT] Player %s (ID: %d) exited vehicle %s"):format(GetPlayerName(playerId), playerId, previousVehicleState))
            end
            playerVehicleStates[playerId] = currentVehicleState

            local model = GetEntityModel(ped)
            local prevModel = playerPedModels[playerId]
            if prevModel ~= model then
                if prevModel then
                    TriggerEvent('somis-betterevents:pedModelChange', playerId, prevModel, model)
                    debugPrint(("[PED MODEL CHANGE] Player %s (ID: %d) changed model: %s → %s"):format(GetPlayerName(playerId), playerId, prevModel, model))
                end
                playerPedModels[playerId] = model
                playerPedExists[playerId] = true
            end

            local currentWeapon = toUnsigned32(GetSelectedPedWeapon(ped))
            local previousWeapon = playerWeaponStates[playerId]
            if not previousWeapon then
                playerWeaponStates[playerId] = currentWeapon
            elseif currentWeapon ~= previousWeapon then
                if tostring(currentWeapon) ~= "2725352035" then
                    TriggerEvent('somis-betterevents:weaponDrawn', playerId, currentWeapon, previousWeapon)
                    debugPrint(("[WEAPON DRAWN] Player %s (ID: %d) equipped weapon: %s (prev: %s)"):format(GetPlayerName(playerId), playerId, currentWeapon, previousWeapon))
                else
                    TriggerEvent('somis-betterevents:weaponHolstered', playerId, previousWeapon)
                    debugPrint(("[WEAPON HOLSTERED] Player %s (ID: %d) holstered weapon: %s"):format(GetPlayerName(playerId), playerId, previousWeapon))
                end
                playerWeaponStates[playerId] = currentWeapon
            end

            local isVisible = IsEntityVisible(ped)
            local wasVisible = playerVisibilityStates[playerId]
            if wasVisible == nil then
                playerVisibilityStates[playerId] = isVisible
            elseif isVisible ~= wasVisible then
                if isVisible then
                    TriggerEvent('somis-betterevents:becameVisible', playerId)
                    debugPrint(("[VISIBILITY] Player %s (ID: %d) became VISIBLE"):format(GetPlayerName(playerId), playerId))
                else
                    TriggerEvent('somis-betterevents:becameInvisible', playerId)
                    debugPrint(("[VISIBILITY] Player %s (ID: %d) became INVISIBLE"):format(GetPlayerName(playerId), playerId))
                end
                playerVisibilityStates[playerId] = isVisible
            end

            ::continue::
        end
        Wait(500)
    end
end)