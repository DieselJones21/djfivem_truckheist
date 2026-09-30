local routeBlip

local function clearRouteBlip()
    if routeBlip and DoesBlipExist(routeBlip) then
        SetBlipRoute(routeBlip, false)
        RemoveBlip(routeBlip)
    end
    routeBlip = nil
end

function ClearHeistGps()
    clearRouteBlip()
    ClearGpsPlayerWaypoint()
    SetWaypointOff()
end

---@param coords vector3|vector4
---@param style table
function SetHeistGps(coords, style)
    if not coords then return end

    clearRouteBlip()

    local x, y, z = coords.x, coords.y, coords.z or 0.0
    SetNewWaypoint(x, y)

    routeBlip = AddBlipForCoord(x, y, z)
    SetBlipSprite(routeBlip, style.sprite or 1)
    SetBlipColour(routeBlip, style.color or 5)
    SetBlipScale(routeBlip, style.scale or 0.8)
    SetBlipAsShortRange(routeBlip, false)
    SetBlipRoute(routeBlip, true)
    SetBlipRouteColour(routeBlip, style.routeColor or style.color or 5)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(style.label or 'Objective')
    EndTextCommandSetBlipName(routeBlip)
end
