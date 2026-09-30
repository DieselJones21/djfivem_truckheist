Config = {}

--- Draw ox_target zone sprites and print extra debug text.
Config.Debug = false

--- Default locale file in /locales. ox_lib also follows the player's language if that file exists.
Config.Locale = 'en'

--------------------------------------------------------------------------------
-- Contact who starts the job
--------------------------------------------------------------------------------
Config.Start = {
    --- ox_target ped that hands out the score.
    usePed = true,
    --- Optional chat/F8 command so staff can test without walking to the ped.
    useCommand = true,
    command = 'truckheist',
    --- Set to an ox_inventory item name to require it when starting (example: 'lockpick').
    requiredItem = nil,
    requiredItemCount = 1,
    --- Empty means any civilian job can start. Example: { 'unemployed', 'truckdriver' }
    requiredJobs = {},
    --- Jobs that can never start the heist.
    blockedJobs = {
        police = true,
        sheriff = true,
        ambulance = true,
    },
    ped = {
        model = 's_m_m_trucker_01',
        coords = vec4(1196.74, -3253.67, 7.09, 91.12),
        scenario = 'WORLD_HUMAN_SMOKING',
        label = 'Ask about a truck score',
        icon = 'fa-solid fa-truck-front',
        blip = {
            enabled = true,
            sprite = 477,
            color = 5,
            scale = 0.75,
            label = 'Freight Contact',
        },
    },
}

--------------------------------------------------------------------------------
-- Rig and trailer
--------------------------------------------------------------------------------
Config.Vehicles = {
    --- One of these cab models is chosen at random.
    trucks = { 'phantom', 'hauler', 'packer' },
    --- One of these trailers is chosen at random.
    trailers = { 'trailers', 'trailers2', 'trailers3', 'trailerlogs', 'docktrailer' },
    --- How far behind the cab the trailer is spawned (meters).
    trailerBackOffset = 8.5,
    --- Lock the doors until the player hotwires the cab.
    startLocked = true,
    --- Seconds the player must hold the hotwire progress circle.
    hotwireDuration = 6500,
}

--------------------------------------------------------------------------------
-- Places the parked rig can appear. These are ordinary map spots (ports, lots,
-- desert shoulders) so the truck is findable with GPS but not sitting in a
-- high-traffic city street.
--------------------------------------------------------------------------------
Config.TruckSpawns = {
    {
        label = 'Elysian Island freight lot',
        coords = vec4(155.18, -3092.41, 5.90, 269.40),
    },
    {
        label = 'Port of LS container yard',
        coords = vec4(1204.55, -3115.82, 5.54, 0.80),
    },
    {
        label = 'La Mesa industrial siding',
        coords = vec4(844.21, -2354.66, 30.33, 174.20),
    },
    {
        label = 'Sandy Shores airfield apron',
        coords = vec4(1734.62, 3309.55, 41.22, 195.10),
    },
    {
        label = 'Grapeseed farm access',
        coords = vec4(1989.44, 4976.12, 41.29, 205.60),
    },
    {
        label = 'Paleto Bay timber yard',
        coords = vec4(142.66, 6365.18, 31.27, 26.80),
    },
    {
        label = 'Route 68 truck pull-off',
        coords = vec4(2534.88, 2617.41, 37.95, 273.40),
    },
}

--------------------------------------------------------------------------------
-- Drop yards: abandoned or half-used lots that still sit on the map.
-- "Hidden but not hidden" — cover and space to work, GPS still finds them.
--------------------------------------------------------------------------------
Config.DumpLocations = {
    {
        label = 'Harmony scrap back lot',
        coords = vec3(1178.21, 2640.04, 37.75),
        heading = 0.0,
        radius = 28.0,
    },
    {
        label = 'Davis Quartz quarry pad',
        coords = vec3(2682.40, 2799.55, 40.45),
        heading = 95.0,
        radius = 32.0,
    },
    {
        label = 'Paleto sawmill rear',
        coords = vec3(-571.88, 5248.10, 70.47),
        heading = 155.0,
        radius = 28.0,
    },
    {
        label = 'El Burro oil-field dirt lot',
        coords = vec3(1509.40, -2123.22, 76.18),
        heading = 210.0,
        radius = 30.0,
    },
    {
        label = 'Cypress Flats warehouse yard',
        coords = vec3(969.12, -1934.55, 31.14),
        heading = 85.0,
        radius = 26.0,
    },
    {
        label = 'Grapeseed barn lot',
        coords = vec3(2441.55, 4984.20, 46.81),
        heading = 315.0,
        radius = 28.0,
    },
    {
        label = 'Senora empty farm pad',
        coords = vec3(1966.80, 3824.40, 32.40),
        heading = 30.0,
        radius = 26.0,
    },
}

--------------------------------------------------------------------------------
-- Fence peds. One is picked when the heist starts and marked on GPS after
-- the trailer has been searched.
--------------------------------------------------------------------------------
Config.Fences = {
    {
        label = 'La Mesa alley fence',
        model = 'g_m_m_chiboss_01',
        coords = vec4(887.41, -953.72, 38.28, 0.40),
        scenario = 'WORLD_HUMAN_STAND_IMPATIENT',
    },
    {
        label = 'Sandy Shores back-lot fence',
        model = 's_m_y_dealer_01',
        coords = vec4(1532.88, 3592.61, 34.95, 200.10),
        scenario = 'WORLD_HUMAN_SMOKING',
    },
    {
        label = 'Paleto side-street fence',
        model = 'g_m_y_mexgoon_02',
        coords = vec4(-107.90, 6468.05, 30.63, 134.20),
        scenario = 'WORLD_HUMAN_LEANING',
    },
    {
        label = 'Elysian warehouse fence',
        model = 's_m_y_construct_01',
        coords = vec4(-339.12, -2446.55, 6.00, 230.00),
        scenario = 'WORLD_HUMAN_CLIPBOARD',
    },
}

--------------------------------------------------------------------------------
-- ox_target search points generated around the parked trailer
--------------------------------------------------------------------------------
Config.Search = {
    --- Progress circle length when searching a point (ms).
    duration = 7500,
    --- How close the player must stand for the target option to show.
    targetDistance = 2.2,
    --- Sphere radius for each ox_target zone.
    zoneRadius = 1.15,
    --- Player must finish at least this many points before the fence GPS unlocks.
    requiredSearches = 6,
    --- If true the player must search every configured offset.
    requireAllPoints = true,
    --- Offsets are relative to the trailer (x = right, y = forward, z = up).
    offsets = {
        { x = 0.00, y = -6.20, z = 0.35, label = 'Rear doors' },
        { x = 1.35, y = -3.10, z = 0.35, label = 'Right mid crate' },
        { x = -1.35, y = -3.10, z = 0.35, label = 'Left mid crate' },
        { x = 1.35, y = -8.10, z = 0.35, label = 'Right rear crate' },
        { x = -1.35, y = -8.10, z = 0.35, label = 'Left rear crate' },
        { x = 0.00, y = -10.40, z = 0.20, label = 'Tail gate' },
        { x = 0.15, y = 1.80, z = 0.85, label = 'Cab stash' },
    },
}

--------------------------------------------------------------------------------
-- Live mission HUD (percent complete)
--------------------------------------------------------------------------------
Config.Progress = {
    locate = 8,
    stolen = 25,
    deliver = 42,
    --- Search fills from searchMin to searchMax as points are cleared.
    searchMin = 42,
    searchMax = 82,
    fence = 90,
    complete = 100,
}

--------------------------------------------------------------------------------
-- Map GPS / blips
--------------------------------------------------------------------------------
Config.Blips = {
    truck = { sprite = 477, color = 1, scale = 0.85, routeColor = 1, label = 'Target Rig' },
    dump = { sprite = 50, color = 5, scale = 0.80, routeColor = 5, label = 'Quiet Drop Yard' },
    fence = { sprite = 280, color = 2, scale = 0.85, routeColor = 2, label = 'Fence' },
}

--------------------------------------------------------------------------------
-- Mission rules the client also needs
--------------------------------------------------------------------------------
Config.Mission = {
    --- Fail if the cab is destroyed.
    failOnTruckDestroyed = true,
    --- Fail if the player dies.
    failOnDeath = false,
    --- Must be driving the heist cab to count as "arrived" at the dump.
    requireTruckAtDump = true,
    --- Optional: engine must be off before search points spawn.
    requireEngineOff = false,
    --- How often (ms) the client checks truck / dump / death state.
    tickMs = 1000,
}

--------------------------------------------------------------------------------
-- Keys / dispatch hooks (client-safe names only)
--------------------------------------------------------------------------------
Config.VehicleKeys = {
    --- Auto-detect qbx_vehiclekeys or qb-vehiclekeys when the truck is stolen.
    autoGive = true,
}

Config.Dispatch = {
    --- Tell on-duty LEO when the rig is stolen. Set false to stay silent.
    enabled = true,
    blipDuration = 60,
}
