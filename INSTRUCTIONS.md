# Truck Heist — Instructional Sheet

This sheet is for **server owners** (how to install, tune, and operate the resource) and **players** (how a score is played). Read the player section first if you only need to run the job in-game.

---

## 1. Player walkthrough

### Starting the score

1. Go to the **Freight Contact** blip (default: LS docks warehouse area).
2. Aim ox_target at the trucker ped.
3. Choose **Ask about a truck score**.
4. If your server enabled the command, you can also type `/truckheist`.

The mission HUD appears at the top of the screen. GPS sets a route to the parked rig.

You cannot start if:

- you already have a score running
- you are still on cooldown
- your job is blocked (police / sheriff / ambulance by default)
- not enough officers are on duty (only if the owner raised `minOnDuty`)
- the server is already at max active heists

### Stealing the rig

1. Follow GPS to the parked **cab + trailer**.
2. Target the cab and choose **Hotwire the rig**.
3. Wait out the progress circle. Do not move or cancel.
4. Get in and drive. Keys are given automatically when vehicle-key resources are present.

GPS switches to a quiet drop yard. The HUD moves to the haul stage.

### The drop yard

The yard is an ordinary map lot — scrap back lots, quarry pads, sawmill rear, oil-field dirt. It is not an interior and not invisible. GPS takes you there.

1. Drive the **heist truck** into the marked radius.
2. Park. If the owner enabled `requireEngineOff`, turn the engine off.
3. Search points spawn around the trailer.

### Searching the trailer

Yellow ox_target spheres sit around the truck (rear doors, both sides, tail gate, cab stash).

1. Target a point.
2. Choose **Search …**.
3. Hold still through the progress circle.

You can receive:

- **Regular loot** (lockpicks, repair kits, materials, etc.) — keep these
- **Custom heist goods** (sealed crate, electronics, watches, hardware, manifest) — these are the items you must take to the fence

Search every required point. The HUD percentage climbs as you clear them.

### Selling to the fence

1. When the trailer is stripped, GPS marks the **fence**.
2. A ped appears only for this mission.
3. Target the ped and choose **Sell heist goods**.
4. You are paid cash for every custom heist item you are carrying, plus a completion bonus.

The HUD hits 100% and the score ends.

### Cancelling

- Target the contact again and choose **Walk away from the job**, or
- Type `/canceltruckheist`

Cancelling (or failing) can remove leftover heist goods and puts you on cooldown.

---

## 2. Owner install checklist

Do these in order.

1. Confirm `ox_lib`, `ox_target`, `ox_inventory`, and `qbx_core` start without errors.
2. Place this folder at `resources/[standalone]/djfivem_truckheist` (or any folder you `ensure`).
3. Open `install/ox_inventory_items.lua` and copy every item into `ox_inventory/data/items.lua`.
4. Optional: add icons named `heist_sealed_crate.png`, `heist_electronics.png`, `heist_watches.png`, `heist_hardware.png`, `heist_manifest.png` to `ox_inventory/web/images/`.
5. Restart `ox_inventory`.
6. Put `ensure djfivem_truckheist` **after** the four dependencies in `server.cfg`.
7. `refresh` then `ensure djfivem_truckheist`, or restart the server.
8. In-game, walk to the contact and start a test run with `minOnDuty = 0`.

If the resource will not start, F8 / server console will name the missing dependency.

---

## 3. How to operate the script

### Daily operation

- The contact ped is always spawned for every client. No cron or restart is required between heists.
- Each start picks a **different** truck spawn, dump yard, and fence when possible, then recycles the lists.
- Vehicles are deleted when the job completes, fails, times out, the player drops, or an admin resets.
- Cooldown is memory-only (citizenid). A server restart clears cooldowns.

### Commands you will use

| Command | Ace / group | Use |
|---------|-------------|-----|
| `/truckheist` | anyone (if enabled) | Staff testing without walking to the ped |
| `/canceltruckheist` | the player | Abort their own score |
| `/resettruckheist` | `group.admin` | Reset your own heist |
| `/resettruckheist 12` | `group.admin` | Reset server id 12 and delete their rig |

Disable the player start command in production:

```lua
Config.Start.useCommand = false
```

### Live tuning (most common)

Open `config/server.lua` for economy and abuse controls. Open `config/shared.lua` for anything players see on the map.

**Make the job rarer**

```lua
Config.Police.minOnDuty = 3
Config.Limits.cooldown = 45 * 60
Config.Limits.maxActive = 2
```

**Pay more / less**

Edit each `Config.Contraband` `price.min` / `price.max`.  
Edit `Config.Rewards.completionBonus`.  
Change `Config.Rewards.moneyType` to `'bank'` if you do not want dirty cash in pockets.

**Fewer or more search points**

Edit `Config.Search.offsets`.  
If you add or remove offsets, `requiredSearches` / `requireAllPoints` should still make sense.

**Stop police jobs from playing**

```lua
Config.Start.blockedJobs = {
    police = true,
    sheriff = true,
    ambulance = true,
}
```

**Require a start item** (example: a burner phone or lockpick)

```lua
Config.Start.requiredItem = 'lockpick'
Config.Start.requiredItemCount = 1
```

**Silent heist (no LEO ping)**

```lua
Config.Dispatch.enabled = false
```

### Hooking your dispatch script

In `config/server.lua`, fill in `Config.SendDispatch` and `return true` so the built-in notify+blip is not also sent.

```lua
Config.SendDispatch = function(source, coords, message)
    -- trigger your dispatch export here
    return true
end
```

`source` is the thief, `coords` is the truck, `message` is already localized.

### Vehicle keys

If players cannot drive after hotwire:

1. Confirm `qbx_vehiclekeys` or `qb-vehiclekeys` is started.
2. Leave `Config.VehicleKeys.autoGive = true`.
3. The client also fires the common `qb-vehiclekeys:client:AddKeys` / `SetOwner` events.

If you use a custom key script, add your export next to the existing `pcall` blocks in `server/main.lua` (`giveKeys`) and `client/main.lua` (`giveLocalKeys`).

---

## 4. Adding or moving locations

All map lists are in `config/shared.lua`.

### Stand in the spot in-game

Use any coord tool, or in F8:

```
/lua GetEntityCoords(PlayerPedId())
/lua GetEntityHeading(PlayerPedId())
```

### Truck spawn (`Config.TruckSpawns`)

Needs room for a cab **and** a trailer behind it. Use `vec4(x, y, z, heading)`.

```lua
{
    label = 'My new lot',
    coords = vec4(100.0, 200.0, 30.0, 90.0),
},
```

### Drop yard (`Config.DumpLocations`)

Needs a flat lot the semi can enter. Use `vec3` plus a heading and radius.

```lua
{
    label = 'Quiet construction pad',
    coords = vec3(100.0, 200.0, 30.0),
    heading = 90.0,
    radius = 28.0,
},
```

Keep these “hidden but not hidden”: off the main road, with some cover, still a real outdoor place GPS can find.

### Fence (`Config.Fences`)

A sidewalk or alley where a ped can stand. Use `vec4`.

```lua
{
    label = 'Back-alley buyer',
    model = 'g_m_y_mexgoon_02',
    coords = vec4(100.0, 200.0, 30.0, 180.0),
    scenario = 'WORLD_HUMAN_SMOKING',
},
```

### Contact ped

`Config.Start.ped.coords` is `vec4`. Set `blip.enabled = false` if you want players to learn the location instead of seeing a map icon.

---

## 5. Adding or changing items

### Regular loot (players keep it)

`config/server.lua` → `Config.Loot`

```lua
{ item = 'lockpick', chance = 35, min = 1, max = 2 },
```

`chance` is 0–100 per search point. The item **must** already exist in ox_inventory.

### Custom heist goods (must be fenced)

`config/server.lua` → `Config.Contraband`

```lua
{
    item = 'heist_gold_bar',
    label = 'Gold Bar',
    chance = 15,
    min = 1,
    max = 1,
    guaranteed = false,
    price = { min = 8000, max = 12000 },
},
```

Then add the same item to ox_inventory (copy the style in `install/ox_inventory_items.lua`).

- `guaranteed = true` forces at least one of that item to appear during the heist.
- The rolled `price` is written to item metadata as `value`. The fence pays that number.

### If a search says inventory is full

The point is **not** consumed. The player must drop weight and search again.

---

## 6. Mission HUD and GPS

HUD copy lives in `locales/en.json` (`hud_*` keys).  
Percents live in `Config.Progress`.  
Blip sprites / colors / route colors live in `Config.Blips`.

GPS is a waypoint **and** a routed blip. It updates when the stage changes:

1. Truck
2. Drop yard
3. Fence

---

## 7. Locales

Default language is `locales/en.json`.

1. Copy `en.json` to `locales/es.json` (or `fr`, `de`, …).
2. Translate the values. Keep the `%s` placeholders.
3. ox_lib will pick the client language when that file exists.
4. `Config.Locale = 'en'` is the fallback.

---

## 8. Testing checklist

Use a test character. Keep `Config.Police.minOnDuty = 0` and `Config.Start.useCommand = true`.

- [ ] Resource starts with no console errors
- [ ] Contact ped is visible and targetable
- [ ] Starting sets GPS and shows the HUD at a low percent
- [ ] Cab and trailer exist at the ping
- [ ] Hotwire unlocks the cab and you can drive
- [ ] GPS updates to the drop yard
- [ ] Parking in the radius creates several search spheres
- [ ] Each search gives items or a clean “empty” message
- [ ] At least one guaranteed contraband item appears
- [ ] After required searches, GPS and a fence ped appear
- [ ] Selling removes heist goods and adds cash
- [ ] HUD reaches 100% and disappears
- [ ] `/truckheist` is blocked by cooldown
- [ ] `/canceltruckheist` and `/resettruckheist` clean vehicles
- [ ] Disconnect during a heist deletes the spawned rig

Turn `Config.Debug = true` if search zones are hard to see.

---

## 9. Common problems

| Symptom | Fix |
|---------|-----|
| Resource will not start | Start ox_lib, ox_target, ox_inventory, qbx_core first |
| “invalid_item” in console / no loot | Item name missing from ox_inventory |
| Cannot enter the truck | Key resource not running, or `autoGive` is false |
| Trailer detached / overlapping | Change `trailerBackOffset` (try 7.5–10.0) |
| Search points under the map | Drop-yard z is wrong; recapture coords |
| Fence ped floating | Recapture fence `vec4` on the sidewalk |
| Police get two alerts | Your `SendDispatch` should `return true` |
| Nobody can start | `minOnDuty` is higher than on-duty LEO |
| HUD never appears | NUI files missing; confirm `web/` is in the resource |

---

## 10. File map

```
djfivem_truckheist/
├── fxmanifest.lua
├── README.md
├── INSTRUCTIONS.md
├── config/shared.lua      map, peds, vehicles, HUD
├── config/server.lua      loot, money, police, cooldown
├── client/main.lua        peds, steal, search, fence
├── client/gps.lua         waypoint + routed blip
├── client/hud.lua         NUI progress bar
├── server/main.lua        validation, loot, payout
├── locales/en.json
├── web/                   mission HUD
└── install/ox_inventory_items.lua
```

Do not edit `server/main.lua` for payout numbers. Those belong in `config/server.lua`.
