--- Server-only economy, loot, and anti-abuse. Never trust the client with these values.

Config.Police = {
    --- Minimum on-duty officers before a heist can start. Leave 0 for testing.
    minOnDuty = 0,
    --- Job names counted toward minOnDuty.
    jobs = { 'police', 'sheriff' },
    --- If true, also count Qbox job type `leo`.
    useLeoType = true,
}

Config.Limits = {
    --- Seconds before the same character can start another heist.
    cooldown = 30 * 60,
    --- Seconds before an unfinished heist is failed and cleaned up.
    timeout = 40 * 60,
    --- How many heists may run on the server at once.
    maxActive = 4,
    --- Max distance (m) the player may be from the cab when reporting it stolen.
    stealDistance = 8.0,
    --- Max distance (m) from the dump coord when reporting arrival.
    dumpDistance = 35.0,
    --- Max distance (m) from a search point when looting it.
    searchDistance = 6.0,
    --- Max distance (m) from the fence when selling.
    fenceDistance = 6.0,
    --- Extra slack when validating the truck is at the dump.
    truckDumpDistance = 40.0,
}

--------------------------------------------------------------------------------
-- Regular loot: optional extras players can keep.
-- chance is 0-100. min/max is the item count if the roll succeeds.
--------------------------------------------------------------------------------
Config.Loot = {
    { item = 'lockpick', chance = 35, min = 1, max = 2 },
    { item = 'repairkit', chance = 25, min = 1, max = 1 },
    { item = 'bandage', chance = 40, min = 1, max = 3 },
    { item = 'radio', chance = 20, min = 1, max = 1 },
    { item = 'water', chance = 50, min = 1, max = 2 },
    { item = 'copper', chance = 30, min = 2, max = 5 },
    { item = 'plastic', chance = 30, min = 2, max = 6 },
    { item = 'steel', chance = 22, min = 1, max = 4 },
}

--------------------------------------------------------------------------------
-- Custom heist goods. These are the items the player MUST take to the marked
-- fence. Each item is registered in install/ox_inventory_items.lua.
--
-- price.min / price.max is the cash paid per item when sold.
-- guaranteed = true forces at least one of this item to drop during the heist.
-- chance is used when rolling extra copies onto a search point.
--------------------------------------------------------------------------------
Config.Contraband = {
    {
        item = 'heist_sealed_crate',
        label = 'Sealed Freight Crate',
        chance = 70,
        min = 1,
        max = 1,
        guaranteed = true,
        price = { min = 3200, max = 4800 },
    },
    {
        item = 'heist_electronics',
        label = 'Stolen Electronics Pallet',
        chance = 55,
        min = 1,
        max = 1,
        guaranteed = true,
        price = { min = 4100, max = 6200 },
    },
    {
        item = 'heist_watches',
        label = 'Luxury Watch Case',
        chance = 40,
        min = 1,
        max = 1,
        guaranteed = false,
        price = { min = 5500, max = 8200 },
    },
    {
        item = 'heist_hardware',
        label = 'Restricted Hardware',
        chance = 28,
        min = 1,
        max = 1,
        guaranteed = false,
        price = { min = 7000, max = 10500 },
    },
    {
        item = 'heist_manifest',
        label = 'Falsified Manifest',
        chance = 60,
        min = 1,
        max = 1,
        guaranteed = true,
        price = { min = 1800, max = 2600 },
    },
}

Config.Rewards = {
    --- cash | bank | crypto
    moneyType = 'cash',
    --- Flat bonus paid when the player finishes the sale.
    completionBonus = 1500,
    --- Reason string stored by qbx_core:AddMoney.
    reason = 'truck-heist-fence',
}

Config.Cleanup = {
    --- Remove leftover heist goods if the job fails or times out.
    removeContrabandOnFail = true,
    --- Delete the spawned cab and trailer on fail / complete / disconnect.
    deleteVehicles = true,
}

--- Optional server-side dispatch hook.
--- Return true if you handled the alert yourself.
Config.SendDispatch = function(source, coords, message)
    -- Example ps-dispatch:
    -- TriggerEvent('ps-dispatch:server:notify', {
    --     message = message,
    --     codeName = 'truckheist',
    --     code = '10-90',
    --     coords = coords,
    -- })

    -- Example cd_dispatch:
    -- TriggerClientEvent('cd_dispatch:AddNotification', -1, {
    --     job_table = Config.Police.jobs,
    --     coords = coords,
    --     title = '10-90 Truck Hijacking',
    --     message = message,
    --     flash = 0,
    --     unique_id = tostring(math.random(1000000, 9999999)),
    --     sound = 1,
    --     blip = {
    --         sprite = 477,
    --         scale = 1.0,
    --         colour = 1,
    --         flashes = true,
    --         text = 'Stolen Rig',
    --         time = 5,
    --         radius = 0,
    --     }
    -- })

    return false
end
