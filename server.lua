local DEBUG = false

local recentDeaths = {}

 function isentityped(entity)
    return GetEntityType(entity) == 1
 end

 function IsPlayerDead(playerId)
    if not playerId or not GetPlayerPed(playerId) then return false end
    local ped = GetPlayerPed(playerId)
    if not DoesEntityExist(ped) then return false end
    local health = GetEntityHealth(ped)
    return health <= 0
end

AddEventHandler('weaponDamageEvent', function(sender, data)
    if not data.willKill then return end

    local entity = NetworkGetEntityFromNetworkId(data.hitGlobalId)
    if not DoesEntityExist(entity) or not isentityped(entity) or not IsPedAPlayer(entity) then return end

    local victimId = NetworkGetEntityOwner(entity)
    local killerId = sender or "Unknown"
    local weapon = data.weaponType or "Unknown"
if DEBUG then
    print(("[Death] Player %s killed by %s with %s (Server)"):format(victimId, killerId, weapon))
end
    recentDeaths[victimId] = GetGameTimer()
    TriggerEvent('somis-betterevents:death', victimId, killerId, weapon)
end)

RegisterNetEvent('custom:clientReportedDeath')
AddEventHandler('custom:clientReportedDeath', function()
    local victimId = source
    if not IsPlayerDead(victimId) then
        return
    end
    local currentTime = GetGameTimer()
    local lastDeath = recentDeaths[victimId] or 0

    if currentTime - lastDeath > 1000 then
        if DEBUG then
        print(("[Death] Player %s died (Client)"):format(victimId))
        end
        recentDeaths[victimId] = currentTime
        TriggerEvent('somis-betterevents:death', victimId, nil, nil)
    end
end)



local joined_players = {}


AddEventHandler('playerJoining', function()
    local playerId = source
    local playerName = GetPlayerName(playerId)
    table.insert(joined_players, playerId)
    if DEBUG then
    print(string.format("[PLAYER JOINED] Player %s (ID: %d) added to joined_players", playerName, playerId))
    end
end)

AddEventHandler('playerDropped', function()
    local playerId = source
    for i, id in ipairs(joined_players) do
        if id == playerId then
            table.remove(joined_players, i)
            if DEBUG then
            print(string.format("[PLAYER DROPPED] Player ID %d removed from joined_players", playerId))
            end
            break
        end
    end
    playerVehicleStates[playerId] = nil
end)
local playerVehicleStates = {}
local playerPedModels = {}

Citizen.CreateThread(function()
    while true do
        for _, playerId in ipairs(joined_players) do
            if DoesP_PedExist(playerId) then
                local ped = GetPlayerPed(playerId)
                local playerName = GetPlayerName(playerId)

                local vehicle = GetVehiclePedIsIn(ped, false)
                local currentVehicleState = vehicle ~= 0 and vehicle or nil
                local previousVehicleState = playerVehicleStates[playerId]
                
                if currentVehicleState and currentVehicleState ~= previousVehicleState then
                    TriggerEvent('somis-betterevents:vehicleEntered', playerId, currentVehicleState)
                    if DEBUG then
                        print(string.format("[VEHICLE ENTRY] Player %s (ID: %d) entered vehicle %s",
                            playerName, playerId, currentVehicleState))
                    end
                elseif not currentVehicleState and previousVehicleState then
                    TriggerEvent('somis-betterevents:vehicleExit', playerId, previousVehicleState)
                    if DEBUG then
                        print(string.format("[VEHICLE EXIT] Player %s (ID: %d) exited vehicle %s",
                            playerName, playerId, previousVehicleState))
                    end
                end
                playerVehicleStates[playerId] = currentVehicleState

                local model = GetEntityModel(ped)
                local prevModel = playerPedModels[playerId]

                if not prevModel then
                    playerPedModels[playerId] = model
                elseif model ~= prevModel then
                    TriggerEvent('somis-betterevents:pedModelChange', playerId, prevModel, model)
                    if DEBUG then
                        print(string.format(
                            "[PED MODEL CHANGE] Player %s (ID: %d) changed model: %s → %s",
                            playerName, playerId, prevModel, model
                        ))
                    end
                    playerPedModels[playerId] = model
                end
            end
        end
        Citizen.Wait(1000)
    end
end)


function DoesP_PedExist(playerId)
    return GetPlayerPed(playerId) ~= 0
end



