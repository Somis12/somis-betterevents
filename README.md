# somis-betterevents
a SERVER side events to make your development life better. (inspired by baseevents)

# EXAMPLES : 
```lua
AddEventHandler('somis-betterevents:killed', function(victimId, killerId, weapon) -- will only be executed on kill, like being shot at.

end)


AddEventHandler('somis-betterevents:death', function(playerId,killerId)-- will be executed on any death,doesnt matter if a player got shot or rammed by vehicle, killerid will be shown if a player was shot or rammed, but will show 0 if its none (like fall damage.)

end)


AddEventHandler('somis-betterevents:vehicleEntered', function(playerId, vehicle) -- will be executed when a player enters a vehicle.

end)

AddEventHandler('somis-betterevents:vehicleExit', function(playerId, vehicle) -- will be executed when a player leaves a vehicle.

end)

AddEventHandler('somis-betterevents:pedModelChange', function(playerId, prevModel, model) -- will be executed when a player changes his ped model.

end)

AddEventHandler('somis-betterevents:weaponDrawn', function(playerId, currentWeapon, previousWeapon) -- will be executed when a player draws a weapon (even if he already had a weapon, for example pistol -> smg)

end)

AddEventHandler('somis-betterevents:weaponHolstered', function(playerId, previousWeapon) -- will be executed if a player drawn a weapon and now he doesnt have any weapon equipped.

end)

AddEventHandler('somis-betterevents:becameInvisible', function(playerId) -- will be executed when a player becomes invisible (after being visible)

end)


AddEventHandler('somis-betterevents:becameVisible', function(playerId) -- will be executed when a player becomes visible (after being invisible)

end)

```
