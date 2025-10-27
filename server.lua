local DEBUG = false
local serv_cooldown_death = {}
local cooldown_duration_death = 500
local recentDeaths = {}
local playerVehicleStates = {}
local playerPedModels = {}
local playerPeds = {}
local playerWeaponStates = {}
local joined_players = {}

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

RegisterNetEvent('weaponDamageEvent', function(sender, data)
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
    debugPrint(("[Death] Player %s killed by %s with %s (Server)"):format(victimId, killerId, weapon))
    recentDeaths[victimId] = GetGameTimer()
    TriggerEvent('somis-betterevents:death', victimId, killerId, weapon)
end)

RegisterNetEvent('somis-betterevents:clientReportedDeath', function()
    local victimId = source
    if not isPlayerDead(victimId) then return end
    local currentTime = GetGameTimer()
    local lastDeath = recentDeaths[victimId] or 0

    if currentTime - lastDeath > 1000 then
        debugPrint(("[Death] Player %s died (Client)"):format(victimId))
        recentDeaths[victimId] = currentTime
        TriggerEvent('somis-betterevents:death', victimId, nil, nil)
    end
end)

RegisterNetEvent('playerJoining', function()
    local playerId = source
    joined_players[#joined_players + 1] = playerId
    debugPrint(("[PLAYER JOINED] Player %s (ID: %d) added to joined_players"):format(GetPlayerName(playerId), playerId))
end)

RegisterNetEvent('playerDropped', function()
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
    
end)

CreateThread(function()
    while true do
        for i = 1, #joined_players do
            local playerId = joined_players[i]
            if not playerId then
                goto continue
            end

            local ped = playerPeds[playerId]
            if not ped or ped == 0 or not DoesEntityExist(ped) then
                ped = GetPlayerPed(playerId)
                if ped == 0 or not DoesEntityExist(ped) then
                    goto continue
                end
                playerPeds[playerId] = ped

                if not playerPedModels[playerId] then
                    playerPedModels[playerId] = GetEntityModel(ped)
                    debugPrint(("Cached ped %d for player %d with model %d"):format(ped, playerId, playerPedModels[playerId]))
                end
            end


            local vehicle = GetVehiclePedIsIn(ped, false)
            local currentVehicleState = vehicle ~= 0 and vehicle or nil
            local previousVehicleState = playerVehicleStates[playerId]

            if currentVehicleState and currentVehicleState ~= previousVehicleState then
                TriggerEvent('somis-betterevents:vehicleEntered', playerId, currentVehicleState)
                debugPrint(("[VEHICLE ENTRY] Player %s (ID: %d) entered vehicle %s"):format(
                    GetPlayerName(playerId), playerId, currentVehicleState))
            elseif not currentVehicleState and previousVehicleState then
                TriggerEvent('somis-betterevents:vehicleExit', playerId, previousVehicleState)
                debugPrint(("[VEHICLE EXIT] Player %s (ID: %d) exited vehicle %s"):format(
                    GetPlayerName(playerId), playerId, previousVehicleState))
            end
            playerVehicleStates[playerId] = currentVehicleState


            local model = GetEntityModel(ped)
            local prevModel = playerPedModels[playerId]
            if prevModel ~= model then
                if prevModel then
                    TriggerEvent('somis-betterevents:pedModelChange', playerId, prevModel, model)
                    debugPrint(("[PED MODEL CHANGE] Player %s (ID: %d) changed model: %s → %s"):format(
                        GetPlayerName(playerId), playerId, prevModel, model))
                end
                playerPedModels[playerId] = model
            end
            local currentWeapon = toUnsigned32(GetSelectedPedWeapon(ped)) 
            local previousWeapon = playerWeaponStates[playerId]
            if not previousWeapon then
                playerWeaponStates[playerId] = currentWeapon
            elseif currentWeapon ~= previousWeapon then
                if tostring(currentWeapon) ~= "2725352035" then
                    TriggerEvent('somis-betterevents:weaponDrawn', playerId, currentWeapon, previousWeapon)
                    debugPrint(("[WEAPON DRAWN] Player %s (ID: %d) equipped weapon: %s (prev: %s)"):format(
                        GetPlayerName(playerId), playerId, currentWeapon, previousWeapon))
                else
                    TriggerEvent('somis-betterevents:weaponHolstered', playerId, previousWeapon)
                    debugPrint(("[WEAPON HOLSTERED] Player %s (ID: %d) holstered weapon: %s"):format(
                        GetPlayerName(playerId), playerId, previousWeapon))
                end
                playerWeaponStates[playerId] = currentWeapon
            end

            ::continue::
        end
        Wait(500)
    end
end)
