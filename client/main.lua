lib.locale()

local startPed
local startBlip
local fencePed
local heist
local searchZoneIds = {}
local truckTargetAdded = false
local dumpNotified = false
local monitorActive = false

local function notify(key, nType, ...)
    lib.notify({
        description = locale(key, ...),
        type = nType or 'inform',
    })
end

local function loadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not lib.requestModel(hash, 5000) then
        return nil
    end
    return hash
end

local function spawnLocalPed(model, coords, scenario)
    local hash = loadModel(model)
    if not hash then return 0 end

    local ped = CreatePed(0, hash, coords.x, coords.y, coords.z, coords.w or 0.0, false, true)
    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedDiesWhenInjured(ped, false)
    SetPedCanRagdollFromPlayerImpact(ped, false)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetPedCanBeTargetted(ped, false)
    if scenario then
        TaskStartScenarioInPlace(ped, scenario, 0, true)
    end
    SetModelAsNoLongerNeeded(hash)
    return ped
end

local function waitForNetEntity(netId, timeout)
    local expires = GetGameTimer() + (timeout or 20000)
    while GetGameTimer() < expires do
        if netId and NetworkDoesNetworkIdExist(netId) then
            local entity = NetworkGetEntityFromNetworkId(netId)
            if entity ~= 0 and DoesEntityExist(entity) then
                return entity
            end
        end
        Wait(100)
    end
    return 0
end

local function removeSearchZones()
    for _, id in pairs(searchZoneIds) do
        if id and exports.ox_target:zoneExists(id) then
            exports.ox_target:removeZone(id)
        end
    end
    searchZoneIds = {}
end

local function removeTruckTarget()
    if not heist or not truckTargetAdded then return end
    pcall(function()
        exports.ox_target:removeEntity(heist.truckNetId, 'dj_truckheist_steal')
    end)
    truckTargetAdded = false
end

local function deleteFencePed()
    if fencePed and DoesEntityExist(fencePed) then
        exports.ox_target:removeLocalEntity(fencePed)
        DeleteEntity(fencePed)
    end
    fencePed = nil
end

local function resetLocalHeist()
    monitorActive = false
    dumpNotified = false
    removeSearchZones()
    removeTruckTarget()
    deleteFencePed()
    ClearHeistGps()
    HideHeistHud()
    heist = nil
end

local function hudObjective()
    if not heist then return '', 'locate' end

    if heist.stage == 'locate' or heist.stage == 'steal' then
        return locale('hud_locate'), 'locate'
    end
    if heist.stage == 'deliver' then
        return locale('hud_deliver'), 'deliver'
    end
    if heist.stage == 'search' then
        return locale('hud_search', heist.searchedCount or 0, heist.totalPoints or 0), 'search'
    end
    if heist.stage == 'fence' then
        return locale('hud_fence'), 'fence'
    end
    return locale('hud_complete'), 'complete'
end

local function refreshHud()
    if not heist then
        HideHeistHud()
        return
    end
    local objective, stage = hudObjective()
    UpdateHeistHud(heist.progress or 0, objective, stage)
end

local function setStageGps()
    if not heist then return end

    if heist.stage == 'locate' or heist.stage == 'steal' then
        SetHeistGps(heist.spawn.coords, {
            sprite = Config.Blips.truck.sprite,
            color = Config.Blips.truck.color,
            scale = Config.Blips.truck.scale,
            routeColor = Config.Blips.truck.routeColor,
            label = locale('blip_truck'),
        })
    elseif heist.stage == 'deliver' or heist.stage == 'search' then
        SetHeistGps(heist.dump.coords, {
            sprite = Config.Blips.dump.sprite,
            color = Config.Blips.dump.color,
            scale = Config.Blips.dump.scale,
            routeColor = Config.Blips.dump.routeColor,
            label = locale('blip_dump'),
        })
    elseif heist.stage == 'fence' then
        SetHeistGps(heist.fence.coords, {
            sprite = Config.Blips.fence.sprite,
            color = Config.Blips.fence.color,
            scale = Config.Blips.fence.scale,
            routeColor = Config.Blips.fence.routeColor,
            label = locale('blip_fence'),
        })
    else
        ClearHeistGps()
    end
end

local function tryStartHeist()
    if heist then
        notify('notify_busy', 'error')
        return
    end

    local payload, err = lib.callback.await('djfivem_truckheist:server:start', false)
    if not payload then
        if err then
            lib.notify({ description = err, type = 'error' })
        end
        return
    end

    heist = payload
    dumpNotified = false
    ShowHeistHud(heist.progress, locale('hud_locate'), 'locate')
    setStageGps()
    notify('notify_started', 'success')
    CreateThread(watchHeistEntities)
    CreateThread(monitorHeist)
end

local function cancelHeist()
    if not heist then
        notify('notify_not_active', 'error')
        return
    end

    local ok, err = lib.callback.await('djfivem_truckheist:server:cancel', false)
    if not ok then
        if err then
            lib.notify({ description = err, type = 'error' })
        end
        return
    end

    resetLocalHeist()
    notify('notify_cancelled', 'inform')
end

local function giveLocalKeys(vehicle)
    if not Config.VehicleKeys.autoGive or vehicle == 0 then return end
    local plate = GetVehicleNumberPlateText(vehicle)
    TriggerEvent('qb-vehiclekeys:client:AddKeys', plate)
    TriggerEvent('vehiclekeys:client:SetOwner', plate)
    pcall(function()
        exports.qbx_vehiclekeys:GiveKeys(vehicle)
    end)
end

local function stealTruck()
    if not heist or (heist.stage ~= 'locate' and heist.stage ~= 'steal') then return end

    local truck = waitForNetEntity(heist.truckNetId, 2000)
    if truck == 0 then
        notify('notify_too_far', 'error')
        return
    end

    TaskTurnPedToFaceEntity(cache.ped, truck, 800)
    if not lib.progressCircle({
        duration = Config.Vehicles.hotwireDuration,
        label = locale('progress_hotwire'),
        position = 'bottom',
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = {
            dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
            clip = 'machinic_loop_mechandplayer',
            flag = 49,
        },
    }) then
        return
    end

    local ok, data = lib.callback.await('djfivem_truckheist:server:stolen', false)
    if not ok then
        if data then
            lib.notify({ description = data, type = 'error' })
        end
        return
    end

    heist.stage = data.stage
    heist.progress = data.progress
    SetVehicleDoorsLocked(truck, 1)
    SetVehicleEngineOn(truck, true, true, false)
    giveLocalKeys(truck)
    removeTruckTarget()
    setStageGps()
    refreshHud()
    notify('notify_stolen', 'success')
end

local function addStealTarget(truck)
    if truckTargetAdded or truck == 0 or not heist then return end

    exports.ox_target:addEntity(heist.truckNetId, {
        {
            name = 'dj_truckheist_steal',
            icon = 'fa-solid fa-key',
            label = locale('target_steal'),
            distance = 2.5,
            canInteract = function()
                return heist and (heist.stage == 'locate' or heist.stage == 'steal')
            end,
            onSelect = stealTruck,
        },
    })
    truckTargetAdded = true
end

function watchHeistEntities()
    if not heist then return end

    local truck = waitForNetEntity(heist.truckNetId, 20000)
    local trailer = waitForNetEntity(heist.trailerNetId, 20000)

    if truck ~= 0 then
        SetEntityAsMissionEntity(truck, true, true)
        SetVehicleOnGroundProperly(truck)
        if Config.Vehicles.startLocked then
            SetVehicleDoorsLocked(truck, 2)
        end
        addStealTarget(truck)
    end

    if truck ~= 0 and trailer ~= 0 then
        SetEntityAsMissionEntity(trailer, true, true)
        SetVehicleOnGroundProperly(trailer)
        if not IsVehicleAttachedToTrailer(truck) then
            AttachVehicleToTrailer(truck, trailer, 20.0)
        end
    end
end

local function sellGoods()
    if not heist or heist.stage ~= 'fence' then return end

    if not lib.progressCircle({
        duration = 4500,
        label = locale('progress_sell'),
        position = 'bottom',
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = {
            dict = 'mp_common',
            clip = 'givetake1_a',
            flag = 49,
        },
    }) then
        return
    end

    local ok, data = lib.callback.await('djfivem_truckheist:server:sell', false)
    if not ok then
        if data then
            lib.notify({ description = data, type = 'error' })
        end
        return
    end

    notify('notify_sold', 'success', data.payout)
    notify('notify_complete', 'success')
    resetLocalHeist()
end

local function spawnFence()
    if not heist or fencePed then return end

    fencePed = spawnLocalPed(heist.fence.model, heist.fence.coords, heist.fence.scenario)
    if fencePed == 0 then return end

    exports.ox_target:addLocalEntity(fencePed, {
        {
            name = 'dj_truckheist_sell',
            icon = 'fa-solid fa-sack-dollar',
            label = locale('target_sell'),
            distance = 2.4,
            canInteract = function()
                return heist and heist.stage == 'fence'
            end,
            onSelect = sellGoods,
        },
    })
end

local function searchPoint(index, label)
    if not heist or heist.stage ~= 'search' then return end
    if heist.searched and heist.searched[index] then
        notify('notify_already_searched', 'error')
        return
    end

    if not lib.progressCircle({
        duration = Config.Search.duration,
        label = locale('progress_search', label),
        position = 'bottom',
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = {
            dict = 'mini@repair',
            clip = 'fixing_a_ped',
            flag = 49,
        },
    }) then
        return
    end

    local ok, data = lib.callback.await('djfivem_truckheist:server:search', false, index)
    if not ok then
        if data then
            lib.notify({ description = data, type = 'error' })
        end
        return
    end

    heist.stage = data.stage
    heist.progress = data.progress
    heist.searchedCount = data.searchedCount
    heist.searched = heist.searched or {}
    heist.searched[index] = true

    if searchZoneIds[index] then
        exports.ox_target:removeZone(searchZoneIds[index])
        searchZoneIds[index] = nil
    end

    if data.empty then
        notify('notify_search_empty', 'inform', label)
    else
        notify('notify_searched', 'success', label)
    end

    refreshHud()

    if data.stage == 'fence' then
        notify('notify_search_done', 'success')
        spawnFence()
        setStageGps()
        refreshHud()
    end
end

local function createSearchZones(points)
    removeSearchZones()
    if not points then return end

    for i = 1, #points do
        local point = points[i]
        local zoneId = exports.ox_target:addSphereZone({
            coords = vec3(point.coords.x, point.coords.y, point.coords.z),
            radius = Config.Search.zoneRadius,
            debug = Config.Debug,
            drawSprite = true,
            options = {
                {
                    name = ('dj_truckheist_search_%s'):format(i),
                    icon = 'fa-solid fa-magnifying-glass',
                    label = locale('target_search', point.label),
                    distance = Config.Search.targetDistance,
                    canInteract = function()
                        return heist and heist.stage == 'search' and not (heist.searched and heist.searched[i])
                    end,
                    onSelect = function()
                        searchPoint(i, point.label)
                    end,
                },
            },
        })
        searchZoneIds[i] = zoneId
    end
end

local function tryArriveAtDump()
    if not heist or heist.stage ~= 'deliver' then return end

    local truck = waitForNetEntity(heist.truckNetId, 500)
    if Config.Mission.requireTruckAtDump then
        if truck == 0 then return end
        if GetVehiclePedIsIn(cache.ped, false) ~= truck then
            return
        end
        if Config.Mission.requireEngineOff and GetIsVehicleEngineRunning(truck) then
            notify('notify_engine', 'inform')
            return
        end
    end

    local ok, data = lib.callback.await('djfivem_truckheist:server:arriveDump', false)
    if not ok then
        if data then
            lib.notify({ description = data, type = 'error' })
        end
        return
    end

    heist.stage = data.stage
    heist.progress = data.progress
    heist.totalPoints = data.totalPoints
    heist.searchedCount = 0
    heist.searched = {}
    createSearchZones(data.points)
    setStageGps()
    refreshHud()
    notify('notify_search_ready', 'success')
end

function monitorHeist()
    if monitorActive then return end
    monitorActive = true

    while heist and monitorActive do
        local ped = cache.ped
        local playerCoords = GetEntityCoords(ped)
        local truck = 0
        if heist.truckNetId and NetworkDoesNetworkIdExist(heist.truckNetId) then
            truck = NetworkGetEntityFromNetworkId(heist.truckNetId)
        end

        if Config.Mission.failOnDeath and (IsPedDeadOrDying(ped, true) or IsEntityDead(ped)) then
            lib.callback.await('djfivem_truckheist:server:fail', false, 'death')
            resetLocalHeist()
            notify('notify_failed', 'error')
            break
        end

        if Config.Mission.failOnTruckDestroyed and heist.truckNetId and truck ~= 0 and IsEntityDead(truck) then
            lib.callback.await('djfivem_truckheist:server:fail', false, 'destroyed')
            resetLocalHeist()
            notify('notify_destroyed', 'error')
            break
        end

        if heist.stage == 'deliver' and heist.dump then
            local dump = heist.dump.coords
            local dist = #(playerCoords - vec3(dump.x, dump.y, dump.z))
            if dist <= (heist.dump.radius or 28.0) then
                if not dumpNotified then
                    dumpNotified = true
                    notify('notify_near_dump', 'inform')
                end
                tryArriveAtDump()
            end
        end

        Wait(Config.Mission.tickMs)
    end

    monitorActive = false
end

local function setupStartPed()
    if not Config.Start.usePed then return end

    local pedCfg = Config.Start.ped
    startPed = spawnLocalPed(pedCfg.model, pedCfg.coords, pedCfg.scenario)
    if startPed == 0 then return end

    exports.ox_target:addLocalEntity(startPed, {
        {
            name = 'dj_truckheist_start',
            icon = pedCfg.icon or 'fa-solid fa-truck-front',
            label = locale('target_start'),
            distance = 2.4,
            onSelect = tryStartHeist,
        },
        {
            name = 'dj_truckheist_cancel',
            icon = 'fa-solid fa-ban',
            label = locale('target_cancel'),
            distance = 2.4,
            canInteract = function()
                return heist ~= nil
            end,
            onSelect = cancelHeist,
        },
    })

    if pedCfg.blip and pedCfg.blip.enabled then
        startBlip = AddBlipForCoord(pedCfg.coords.x, pedCfg.coords.y, pedCfg.coords.z)
        SetBlipSprite(startBlip, pedCfg.blip.sprite)
        SetBlipColour(startBlip, pedCfg.blip.color)
        SetBlipScale(startBlip, pedCfg.blip.scale)
        SetBlipAsShortRange(startBlip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(pedCfg.blip.label or locale('contact_blip'))
        EndTextCommandSetBlipName(startBlip)
    end
end

RegisterNetEvent('djfivem_truckheist:client:forceEnd', function(reason)
    resetLocalHeist()
    if reason == 'timeout' then
        notify('notify_timeout', 'error')
    elseif reason == 'destroyed' then
        notify('notify_destroyed', 'error')
    elseif reason == 'cancelled' then
        notify('notify_cancelled', 'inform')
    else
        notify('notify_failed', 'error')
    end
end)

RegisterNetEvent('djfivem_truckheist:client:dispatchBlip', function(coords, duration)
    if not coords then return end
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 161)
    SetBlipColour(blip, 1)
    SetBlipScale(blip, 1.1)
    SetBlipFlashes(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(locale('notify_dispatch'))
    EndTextCommandSetBlipName(blip)
    SetTimeout((duration or 60) * 1000, function()
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end)
end)

if Config.Start.useCommand then
    RegisterCommand(Config.Start.command, function()
        tryStartHeist()
    end, false)

    TriggerEvent('chat:addSuggestion', '/' .. Config.Start.command, locale('help_start'))
end

RegisterCommand('canceltruckheist', function()
    cancelHeist()
end, false)

TriggerEvent('chat:addSuggestion', '/canceltruckheist', locale('help_cancel'))

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    removeSearchZones()
    removeTruckTarget()
    deleteFencePed()
    ClearHeistGps()
    HideHeistHud()
    if startPed and DoesEntityExist(startPed) then
        exports.ox_target:removeLocalEntity(startPed)
        DeleteEntity(startPed)
    end
    if startBlip and DoesBlipExist(startBlip) then
        RemoveBlip(startBlip)
    end
end)

CreateThread(setupStartPed)
