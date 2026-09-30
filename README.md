# djfivem_truckheist

A Qbox truck-and-trailer heist for FiveM.

Players take a score from a contact ped, get GPS to a parked big rig, steal the cab and trailer, haul it to a quiet drop yard, search ox_target points around the truck, then take a set of custom heist goods to a marked fence ped and sell them for configurable cash.

The resource uses **Qbox**, **ox_lib**, **ox_target**, and **ox_inventory**. A live mission HUD shows percent complete for the whole job.

---

## Features

- Contact ped (ox_target) to start the job, plus an optional command
- Random truck spawn, drop yard, and fence each run
- Networked cab + trailer spawn (Phantom / Hauler / Packer + random trailer)
- Hotwire the rig with an ox_lib progress circle
- GPS waypoint + routed blip for every objective
- Abandoned-but-findable drop yards (scrap lots, quarry pads, sawmill rear, oil-field dirt lots)
- ox_target search spheres around the parked trailer
- Configurable regular loot **and** a custom contraband set that must be fenced
- Marked fence ped that only appears during the mission
- Configurable sell prices (rolled per item, stored on item metadata)
- On-screen mission progress bar (steal → haul → search → fence)
- Cooldown, timeout, max active heists, job blocks, optional min police
- Default LEO alert + blip when the truck is stolen (optional dispatch hook)
- Auto key give for `qbx_vehiclekeys` / `qb-vehiclekeys`
- Admin reset command

---

## Requirements

| Resource        | Why                                      |
|-----------------|------------------------------------------|
| `qbx_core`      | Players, jobs, money, notifications      |
| `ox_lib`        | Callbacks, progress, locale, notify      |
| `ox_target`     | Start ped, search points, fence ped      |
| `ox_inventory`  | Loot and custom heist items              |

Optional:

- `qbx_vehiclekeys` or `qb-vehiclekeys` — keys after the steal
- `ps-dispatch` / `cd_dispatch` — plug in `Config.SendDispatch`

---

## Install

1. Drop this folder into `resources` as `djfivem_truckheist`.
2. Merge the items in `install/ox_inventory_items.lua` into `ox_inventory/data/items.lua`.
3. Restart `ox_inventory` (or the server) so the new items exist.
4. Add this **below** ox_lib, ox_target, ox_inventory, and qbx_core:

```cfg
ensure ox_lib
ensure ox_target
ensure ox_inventory
ensure qbx_core
ensure djfivem_truckheist
```

5. Edit `config/shared.lua` (locations, vehicles, search points, HUD stages).
6. Edit `config/server.lua` (loot, contraband prices, police, cooldown).
7. Make sure every item name in `Config.Loot` exists on your server. Replace any that do not.

There is no SQL. Nothing is stored in the database.

---

## How a run works

1. Player targets the freight contact (or uses `/truckheist` if enabled).
2. GPS routes to a parked cab + trailer.
3. Player hotwires the cab. Keys are granted. LEO can be alerted.
4. GPS routes to a quiet drop yard.
5. Parking the heist truck in the yard unlocks search points around the trailer.
6. Each point is an ox_target zone. Searching uses a progress circle and can give:
   - regular configurable loot (keep it)
   - custom heist goods (must be sold)
7. After the required points are searched, GPS marks the fence ped.
8. Player sells the custom goods for the configured cash amount.
9. HUD hits 100% and the score ends. Cooldown starts.

---

## Configuration map

| File                 | What you change                                      |
|----------------------|------------------------------------------------------|
| `config/shared.lua`  | Peds, map locations, vehicles, search offsets, HUD, blips |
| `config/server.lua`  | Loot tables, fence prices, police, cooldown, dispatch |
| `locales/en.json`    | All player-facing text                               |
| `install/ox_inventory_items.lua` | Custom items to copy into ox_inventory     |

Full operator steps, testing checklist, and how to add locations or items are in **[INSTRUCTIONS.md](INSTRUCTIONS.md)**.

---

## Commands

| Command              | Who     | What                                      |
|----------------------|---------|-------------------------------------------|
| `/truckheist`        | Players | Start the heist (if `Config.Start.useCommand` is true) |
| `/canceltruckheist`  | Players | Cancel the active heist                   |
| `/resettruckheist [id]` | Admins (`group.admin`) | Force-clear a player's heist     |

The start ped also has **Ask about a truck score** and **Walk away from the job**.

---

## Custom items (must fence)

These are the default heist goods. Prices are rolled between min and max when the item is found, then stored on the item so the fence pays that amount.

| Item                 | Default price range | Guaranteed drop |
|----------------------|---------------------|-----------------|
| `heist_sealed_crate` | $3,200 – $4,800     | Yes             |
| `heist_electronics`  | $4,100 – $6,200     | Yes             |
| `heist_watches`      | $5,500 – $8,200     | No              |
| `heist_hardware`     | $7,000 – $10,500    | No              |
| `heist_manifest`     | $1,800 – $2,600     | Yes             |

Plus `Config.Rewards.completionBonus` (default $1,500) when the sale finishes.

---

## Mission progress HUD

A top-center bar shows percent complete and the current objective:

| Stage   | Default percent |
|---------|-----------------|
| Steal   | 8%              |
| Stolen / hauling | 25%    |
| Searching | 42% → 82%    |
| Fence   | 90%             |
| Sold    | 100%            |

Tune the numbers in `Config.Progress`.

---

## Security notes

Loot rolls, money, and stage changes are **server-side**. The client cannot choose items or prices. The server checks distance for steal, dump arrival, search, and sell. Cooldown is stored by citizenid for the session (resets on server restart).

---

## Support / edits

- Set `Config.Debug = true` to draw search zones and print start/finish logs.
- If the trailer does not sit on the cab, raise or lower `Config.Vehicles.trailerBackOffset`.
- If a drop yard z-coord is in the air or under the map, stand there in-game and copy `GetEntityCoords` into `Config.DumpLocations`.
- Dispatch: implement `Config.SendDispatch` in `config/server.lua` and return `true` so the built-in LEO notify is skipped.
