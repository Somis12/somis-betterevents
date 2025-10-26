AddEventHandler('gameEventTriggered', function(event, args)
    if event ~= 'CEventNetworkEntityDamage' then return end
    local victim = args[1]
    local isFatal = args[4] == 1
    local weaponHash = args[5]

    if victim == PlayerPedId() then
        if GetEntityHealth(victim) <= 0 then
            SetTimeout(300, function()
                TriggerServerEvent('somis-betterevents:clientReportedDeath')
            end)
        end
    end
end)