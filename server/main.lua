lib.locale()

local activeHeists = {}
local cooldowns = {}
local usedSpawns = {}

local function playerName(src)
    local player = exports.qbx_core:GetPlayer(src)
    if player and player.PlayerData and player.PlayerData.charinfo then
        local info = player.PlayerData.charinfo
        return ('%s %s'):format(info.firstname or 'Unknown', info.lastname or '')
    end
    return GetPlayerName(src) or ('id:%s'):format(src)
end

local function localeError(key, ...)
    return locale(key, ...)
end

local function citizenId(src)
    local player = exports.qbx_core:GetPlayer(src)
    return player and player.PlayerData and player.PlayerData.citizenid or nil
end

local function formatSeconds(seconds)
    seconds = math.max(0, math.floor(seconds))
    local minutes = math.floor(seconds / 60)
    local remain = seconds % 60
    if minutes <= 0 then
        return ('%ss'):format(remain)
    end
    return ('%sm %ss'):format(minutes, remain)
end

local function countPolice()
    -- Prefer the Qbox LEO job type so police/sheriff are not counted twice.
    if Config.Police.useLeoType then
        local count = exports.qbx_core:GetDutyCountType('leo')
        return count or 0
    end

    local total = 0
    for i = 1, #Config.Police.jobs do
        local count = exports.qbx_core:GetDutyCountJob(Config.Police.jobs[i])
        total = total + (count or 0)
    end
    return total
end

local function jobIsBlocked(src)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return true end
    local job = player.PlayerData.job
    if not job then return false end
    return Config.Start.blockedJobs[job.name] == true
end

local function jobIsAllowed(src)
    local required = Config.Start.requiredJobs
    if not required or #required == 0 then
        return true
    end

    local player = exports.qbx_core:GetPlayer(src)
    if not player then return false end
    local jobName = player.PlayerData.job and player.PlayerData.job.name
    for i = 1, #required do
        if required[i] == jobName then
            return true
        end
    end
    return false
end

local function countActive()
    local n = 0
    for _ in pairs(activeHeists) do
        n = n + 1
    end
    return n
end

local function randomFrom(list)
    return list[math.random(1, #list)]
end

local function pickUnused(list, usedKey)
    usedSpawns[usedKey] = usedSpawns[usedKey] or {}
    local available = {}
    for i = 1, #list do
        if not usedSpawns[usedKey][i] then
            available[#available + 1] = i
        end
    end
    if #available == 0 then
        usedSpawns[usedKey] = {}
        for i = 1, #list do
            available[i] = i
        end
    end
    local index = available[math.random(1, #available)]
    usedSpawns[usedKey][index] = true
    return list[index], index
end

local function headingOffset(coords, heading, distance)
    local rad = math.rad(heading)
    return vec3(
        coords.x + (-math.sin(rad) * distance),
        coords.y + (math.cos(rad) * distance),
        coords.z
    )
end

local function waitForEntity(entity, timeout)
    local expires = GetGameTimer() + (timeout or 5000)
    while not DoesEntityExist(entity) and GetGameTimer() < expires do
        Wait(0)
    end
    return DoesEntityExist(entity)
end

local function spawnNetworkVehicle(model, coords, heading, vehicleType)
    local hash = joaat(model)
    local entity

    if CreateVehicleServerSetter then
        entity = CreateVehicleServerSetter(hash, vehicleType or 'automobile', coords.x, coords.y, coords.z, heading)
    else
        entity = CreateVehicle(hash, coords.x, coords.y, coords.z, heading, true, true)
    end

    if not waitForEntity(entity, 5000) then
        return 0, 0
    end

    SetEntityHeading(entity, heading)
    SetVehicleDoorsLocked(entity, Config.Vehicles.startLocked and 2 or 1)
    return entity, NetworkGetNetworkIdFromEntity(entity)
end

local function deleteHeistVehicles(heist)
    if not Config.Cleanup.deleteVehicles then return end

    if heist.truckEntity and DoesEntityExist(heist.truckEntity) then
        pcall(function()
            exports.qbx_core:DeleteVehicle(heist.truckEntity)
        end)
        if DoesEntityExist(heist.truckEntity) then
            DeleteEntity(heist.truckEntity)
        end
    end
    if heist.trailerEntity and DoesEntityExist(heist.trailerEntity) then
        if DoesEntityExist(heist.trailerEntity) then
            DeleteEntity(heist.trailerEntity)
        end
    end
end

local function removeContraband(src)
    if not Config.Cleanup.removeContrabandOnFail then return end
    for i = 1, #Config.Contraband do
        local item = Config.Contraband[i].item
        local count = exports.ox_inventory:GetItemCount(src, item)
        if count and count > 0 then
            exports.ox_inventory:RemoveItem(src, item, count)
        end
    end
end

local function setCooldown(src)
    local cid = citizenId(src)
    if cid then
        cooldowns[cid] = os.time() + Config.Limits.cooldown
    end
end

local function remainingCooldown(src)
    local cid = citizenId(src)
    if not cid then return 0 end
    local untilTime = cooldowns[cid]
    if not untilTime then return 0 end
    return untilTime - os.time()
end

local function rollPrice(entry)
    if not entry.price then return 0 end
    if entry.price.min == entry.price.max then
        return entry.price.min
    end
    return math.random(entry.price.min, entry.price.max)
end

local function rollCount(entry)
    if entry.min == entry.max then
        return entry.min
    end
    return math.random(entry.min, entry.max)
end

local function buildPointLoot(pointCount)
    local points = {}
    for i = 1, pointCount do
        points[i] = {
            loot = {},
            contraband = {},
        }

        for l = 1, #Config.Loot do
            local entry = Config.Loot[l]
            if math.random(100) <= (entry.chance or 0) then
                points[i].loot[#points[i].loot + 1] = {
                    item = entry.item,
                    count = rollCount(entry),
                }
            end
        end

        for c = 1, #Config.Contraband do
            local entry = Config.Contraband[c]
            if math.random(100) <= (entry.chance or 0) then
                points[i].contraband[#points[i].contraband + 1] = {
                    item = entry.item,
                    count = rollCount(entry),
                    value = rollPrice(entry),
                }
            end
        end
    end

    -- Guarantee at least one of each marked contraband item.
    for c = 1, #Config.Contraband do
        local entry = Config.Contraband[c]
        if entry.guaranteed then
            local found = false
            for i = 1, pointCount do
                for p = 1, #points[i].contraband do
                    if points[i].contraband[p].item == entry.item then
                        found = true
                        break
                    end
                end
                if found then break end
            end
            if not found then
                local slot = math.random(1, pointCount)
                points[slot].contraband[#points[slot].contraband + 1] = {
                    item = entry.item,
                    count = rollCount(entry),
                    value = rollPrice(entry),
                }
            end
        end
    end

    return points
end

local function calcProgress(heist)
    if heist.stage == 'locate' or heist.stage == 'steal' then
        return Config.Progress.locate
    end
    if heist.stage == 'deliver' then
        return Config.Progress.stolen
    end
    if heist.stage == 'search' then
        local total = math.max(heist.totalPoints, 1)
        local span = Config.Progress.searchMax - Config.Progress.searchMin
        return Config.Progress.searchMin + math.floor((heist.searchedCount / total) * span)
    end
    if heist.stage == 'fence' then
        return Config.Progress.fence
    end
    if heist.stage == 'complete' then
        return Config.Progress.complete
    end
    return 0
end

local function clientHeist(heist)
    return {
        id = heist.id,
        stage = heist.stage,
        progress = calcProgress(heist),
        truckNetId = heist.truckNetId,
        trailerNetId = heist.trailerNetId,
        spawn = heist.spawn,
        dump = heist.dump,
        fence = heist.fence,
        totalPoints = heist.totalPoints,
        searchedCount = heist.searchedCount,
    }
end

local function failHeist(src, reason, silent)
    local heist = activeHeists[src]
    if not heist then return end

    if Config.Debug then
        print(locale('log_fail', playerName(src), heist.id, reason or 'unknown'))
    end

    deleteHeistVehicles(heist)
    removeContraband(src)
    setCooldown(src)
    activeHeists[src] = nil

    if not silent then
        TriggerClientEvent('djfivem_truckheist:client:forceEnd', src, reason or 'failed')
    end
end

local function giveKeys(src, vehicle)
    if not Config.VehicleKeys.autoGive or vehicle == 0 then return end

    if GetResourceState('qbx_vehiclekeys') == 'started' then
        pcall(function()
            exports.qbx_vehiclekeys:GiveKeys(src, vehicle)
        end)
    elseif GetResourceState('qb-vehiclekeys') == 'started' then
        local plate = GetVehicleNumberPlateText(vehicle)
        pcall(function()
            exports['qb-vehiclekeys']:GiveKeys(src, plate)
        end)
    end
end

local function alertPolice(src, coords)
    if not Config.Dispatch.enabled then return end

    local message = locale('notify_dispatch')
    local handled = false
    if Config.SendDispatch then
        handled = Config.SendDispatch(src, coords, message) == true
    end

    if handled then return end

    local jobs = Config.Police.jobs
    local players = exports.qbx_core:GetQBPlayers()
    for id, player in pairs(players) do
        local job = player.PlayerData.job
        if job and job.onduty then
            local match = false
            if Config.Police.useLeoType and job.type == 'leo' then
                match = true
            end
            for i = 1, #jobs do
                if job.name == jobs[i] then
                    match = true
                    break
                end
            end
            if match then
                exports.qbx_core:Notify(id, message, 'error')
                TriggerClientEvent('djfivem_truckheist:client:dispatchBlip', id, coords, Config.Dispatch.blipDuration)
            end
        end
    end
end

local function playerCoords(src)
    local ped = GetPlayerPed(src)
    if ped == 0 then return nil end
    return GetEntityCoords(ped)
end

local function within(a, b, maxDist)
    if not a or not b then return false end
    return #(a - vec3(b.x, b.y, b.z)) <= maxDist
end

lib.callback.register('djfivem_truckheist:server:start', function(source)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then
        return false, localeError('notify_failed')
    end

    if activeHeists[src] then
        return false, localeError('notify_busy')
    end

    local wait = remainingCooldown(src)
    if wait > 0 then
        return false, localeError('notify_cooldown', formatSeconds(wait))
    end

    if countActive() >= Config.Limits.maxActive then
        return false, localeError('notify_max_active')
    end

    if jobIsBlocked(src) then
        return false, localeError('notify_job_blocked')
    end

    if not jobIsAllowed(src) then
        return false, localeError('notify_job_required')
    end

    if countPolice() < Config.Police.minOnDuty then
        return false, localeError('notify_police')
    end

    if Config.Start.requiredItem then
        local have = exports.ox_inventory:GetItemCount(src, Config.Start.requiredItem) or 0
        if have < (Config.Start.requiredItemCount or 1) then
            return false, localeError('notify_need_item', Config.Start.requiredItem)
        end
    end

    local spawn = pickUnused(Config.TruckSpawns, 'truck')
    local dump = pickUnused(Config.DumpLocations, 'dump')
    local fence = pickUnused(Config.Fences, 'fence')
    local truckModel = randomFrom(Config.Vehicles.trucks)
    local trailerModel = randomFrom(Config.Vehicles.trailers)

    local spawnCoords = vec3(spawn.coords.x, spawn.coords.y, spawn.coords.z)
    local heading = spawn.coords.w or 0.0
    local truckEntity, truckNetId = spawnNetworkVehicle(truckModel, spawnCoords, heading, 'automobile')
    if truckEntity == 0 then
        return false, localeError('notify_failed')
    end

    local trailerPos = headingOffset(spawnCoords, heading, -Config.Vehicles.trailerBackOffset)
    local trailerEntity, trailerNetId = spawnNetworkVehicle(trailerModel, trailerPos, heading, 'trailer')

    local pointCount = #Config.Search.offsets
    local heist = {
        id = ('%s-%s'):format(src, os.time()),
        owner = src,
        stage = 'locate',
        startedAt = os.time(),
        spawn = spawn,
        dump = dump,
        fence = fence,
        truckModel = truckModel,
        trailerModel = trailerModel,
        truckEntity = truckEntity,
        trailerEntity = trailerEntity,
        truckNetId = truckNetId,
        trailerNetId = trailerNetId,
        pointLoot = buildPointLoot(pointCount),
        searched = {},
        searchedCount = 0,
        totalPoints = pointCount,
        requiredSearches = Config.Search.requireAllPoints and pointCount or Config.Search.requiredSearches,
    }

    activeHeists[src] = heist

    if Config.Debug then
        print(locale('log_start', playerName(src), heist.id, spawn.label or 'spawn'))
    end

    return clientHeist(heist)
end)

lib.callback.register('djfivem_truckheist:server:stolen', function(source)
    local heist = activeHeists[source]
    if not heist then
        return false, localeError('notify_not_active')
    end
    if heist.stage ~= 'locate' and heist.stage ~= 'steal' then
        return false, localeError('notify_not_active')
    end

    local coords = playerCoords(source)
    if not heist.truckEntity or not DoesEntityExist(heist.truckEntity) then
        failHeist(source, 'destroyed')
        return false, localeError('notify_destroyed')
    end

    local truckCoords = GetEntityCoords(heist.truckEntity)
    if not within(coords, truckCoords, Config.Limits.stealDistance) then
        return false, localeError('notify_too_far')
    end

    SetVehicleDoorsLocked(heist.truckEntity, 1)
    giveKeys(source, heist.truckEntity)

    heist.stage = 'deliver'
    alertPolice(source, truckCoords)

    return true, {
        stage = heist.stage,
        progress = calcProgress(heist),
    }
end)

lib.callback.register('djfivem_truckheist:server:arriveDump', function(source)
    local heist = activeHeists[source]
    if not heist then
        return false, localeError('notify_not_active')
    end
    if heist.stage ~= 'deliver' then
        return false, localeError('notify_not_active')
    end

    local coords = playerCoords(source)
    if not within(coords, heist.dump.coords, Config.Limits.dumpDistance) then
        return false, localeError('notify_too_far')
    end

    if Config.Mission.requireTruckAtDump then
        if not heist.truckEntity or not DoesEntityExist(heist.truckEntity) then
            return false, localeError('notify_need_truck')
        end
        local truckCoords = GetEntityCoords(heist.truckEntity)
        if not within(truckCoords, heist.dump.coords, Config.Limits.truckDumpDistance) then
            return false, localeError('notify_need_truck')
        end
    end

    local origin = heist.trailerEntity
    if not origin or not DoesEntityExist(origin) then
        origin = heist.truckEntity
    end

    local heading = origin and GetEntityHeading(origin) or (heist.dump.heading or 0.0)
    local base = origin and GetEntityCoords(origin) or vec3(heist.dump.coords.x, heist.dump.coords.y, heist.dump.coords.z)
    local rad = math.rad(heading)
    local forwardX, forwardY = -math.sin(rad), math.cos(rad)
    local rightX, rightY = math.cos(rad), math.sin(rad)

    local points = {}
    for i = 1, #Config.Search.offsets do
        local offset = Config.Search.offsets[i]
        local x = base.x + (rightX * offset.x) + (forwardX * offset.y)
        local y = base.y + (rightY * offset.x) + (forwardY * offset.y)
        local z = base.z + offset.z
        points[i] = {
            label = offset.label or ('Point %s'):format(i),
            coords = { x = x, y = y, z = z },
        }
        heist.pointLoot[i].world = points[i].coords
    end

    heist.stage = 'search'
    heist.searchPoints = points

    return true, {
        stage = heist.stage,
        progress = calcProgress(heist),
        points = points,
        totalPoints = heist.totalPoints,
    }
end)

lib.callback.register('djfivem_truckheist:server:search', function(source, index)
    local heist = activeHeists[source]
    if not heist then
        return false, localeError('notify_not_active')
    end
    if heist.stage ~= 'search' then
        return false, localeError('notify_not_active')
    end

    index = tonumber(index)
    if not index or not heist.pointLoot[index] then
        return false, localeError('notify_too_far')
    end
    if heist.searched[index] then
        return false, localeError('notify_already_searched')
    end

    local coords = playerCoords(source)
    local point = heist.pointLoot[index].world
    if point and not within(coords, point, Config.Limits.searchDistance) then
        return false, localeError('notify_too_far')
    end

    local given = 0
    local blocked = false

    local function tryGive(item, count, metadata)
        if not exports.ox_inventory:CanCarryItem(source, item, count) then
            blocked = true
            return false
        end
        local success = exports.ox_inventory:AddItem(source, item, count, metadata)
        if success then
            given = given + 1
            return true
        end
        blocked = true
        return false
    end

    local loot = heist.pointLoot[index]
    for i = 1, #loot.loot do
        local entry = loot.loot[i]
        tryGive(entry.item, entry.count)
    end
    for i = 1, #loot.contraband do
        local entry = loot.contraband[i]
        tryGive(entry.item, entry.count, {
            heistGoods = true,
            heistId = heist.id,
            value = entry.value,
            description = 'Hot freight. Take it to the marked fence.',
        })
    end

    if blocked and given == 0 then
        return false, localeError('notify_search_full')
    end

    heist.searched[index] = true
    heist.searchedCount = heist.searchedCount + 1

    if heist.searchedCount >= heist.requiredSearches then
        heist.stage = 'fence'
    end

    return true, {
        stage = heist.stage,
        progress = calcProgress(heist),
        searchedCount = heist.searchedCount,
        empty = given == 0,
    }
end)

lib.callback.register('djfivem_truckheist:server:sell', function(source)
    local heist = activeHeists[source]
    if not heist then
        return false, localeError('notify_not_active')
    end
    if heist.stage ~= 'fence' then
        return false, localeError('notify_not_active')
    end

    local coords = playerCoords(source)
    if not within(coords, heist.fence.coords, Config.Limits.fenceDistance) then
        return false, localeError('notify_too_far')
    end

    local payout = 0
    local soldAny = false

    local function slotsFor(item)
        local slots = exports.ox_inventory:GetSlotsWithItem(source, item)
        if slots and next(slots) then
            return slots
        end
        return exports.ox_inventory:Search(source, 'slots', item) or {}
    end

    for i = 1, #Config.Contraband do
        local entry = Config.Contraband[i]
        local slots = slotsFor(entry.item)
        for _, slot in pairs(slots) do
            local count = slot.count or 0
            if count > 0 then
                local unit = (slot.metadata and slot.metadata.value) or rollPrice(entry)
                if exports.ox_inventory:RemoveItem(source, entry.item, count, nil, slot.slot) then
                    payout = payout + (unit * count)
                    soldAny = true
                end
            end
        end
    end

    if not soldAny then
        return false, localeError('notify_sold_none')
    end

    payout = payout + (Config.Rewards.completionBonus or 0)
    exports.qbx_core:AddMoney(source, Config.Rewards.moneyType, payout, Config.Rewards.reason)

    heist.stage = 'complete'
    setCooldown(source)
    deleteHeistVehicles(heist)
    activeHeists[source] = nil

    if Config.Debug then
        print(locale('log_complete', playerName(source), heist.id, payout))
    end

    return true, {
        payout = payout,
        stage = 'complete',
        progress = 100,
    }
end)

lib.callback.register('djfivem_truckheist:server:cancel', function(source)
    if not activeHeists[source] then
        return false, localeError('notify_not_active')
    end
    failHeist(source, 'cancelled', true)
    return true
end)

lib.callback.register('djfivem_truckheist:server:fail', function(source, reason)
    if not activeHeists[source] then
        return false
    end
    failHeist(source, reason or 'failed', true)
    return true
end)

CreateThread(function()
    while true do
        Wait(15000)
        local now = os.time()
        for src, heist in pairs(activeHeists) do
            if now - heist.startedAt >= Config.Limits.timeout then
                failHeist(src, 'timeout')
            elseif heist.truckEntity and not DoesEntityExist(heist.truckEntity) and heist.stage ~= 'fence' then
                failHeist(src, 'destroyed')
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    if activeHeists[src] then
        failHeist(src, 'dropped', true)
    end
end)

lib.addCommand('resettruckheist', {
    help = 'Clear a player truck heist and its spawned vehicles',
    params = {
        { name = 'id', type = 'playerId', help = 'Player server id', optional = true },
    },
    restricted = 'group.admin',
}, function(source, args)
    local target = args.id or source
    if activeHeists[target] then
        failHeist(target, 'admin', false)
        if source > 0 then
            exports.qbx_core:Notify(source, ('Cleared truck heist for %s'):format(target), 'success')
        end
    elseif source > 0 then
        exports.qbx_core:Notify(source, 'That player has no active truck heist.', 'error')
    end
end)
