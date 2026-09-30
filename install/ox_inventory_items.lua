--[[
    Copy these entries into ox_inventory/data/items.lua
    (or merge them into whatever items file your server uses).

    After adding them, restart ox_inventory.
    Optional: drop PNG icons named after each item into ox_inventory/web/images/
]]

return {
    ['heist_sealed_crate'] = {
        label = 'Sealed Freight Crate',
        weight = 2500,
        stack = true,
        close = true,
        description = 'A crate pulled from a hijacked trailer. Too hot to keep.',
    },

    ['heist_electronics'] = {
        label = 'Stolen Electronics Pallet',
        weight = 3000,
        stack = true,
        close = true,
        description = 'Factory-sealed consumer electronics. The fence will want these.',
    },

    ['heist_watches'] = {
        label = 'Luxury Watch Case',
        weight = 1200,
        stack = true,
        close = true,
        description = 'A travel case of high-end watches from the trailer office box.',
    },

    ['heist_hardware'] = {
        label = 'Restricted Hardware',
        weight = 2800,
        stack = true,
        close = true,
        description = 'Marked industrial hardware that should not be on a civilian freight load.',
    },

    ['heist_manifest'] = {
        label = 'Falsified Manifest',
        weight = 100,
        stack = true,
        close = true,
        description = 'Paperwork that proves the load was never meant to be logged.',
    },
}
