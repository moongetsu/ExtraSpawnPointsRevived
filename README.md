<h1 align="center">
  <img src="https://images.gamebanana.com/img/ico/sprays/naruto.gif" width="64" alt="Extra Spawn Points Revived"/>
  <br />
  Extra Spawn Points (Revived)
</h1>

<p align="center">
  <b>Modern, safe and flexible extra spawn-point manager for CS:GO servers.</b><br>
  <i>Scale your player slots without breaking spawns.</i>
</p>

---

## 🧩 About

**Extra Spawn Points (Revived)** is a modernized fork of Christian "gamemann" Deacon’s original [Extra Spawn Points](https://github.com/gamemann/Extra-Spawn-Points) plugin.

It enforces a minimum (or exact) number of CT/T spawns on any map, with extra safeguards to avoid bad positions, plus tools that make debugging and tuning spawns much easier.

---

## 🚀 Features

- **Configurable spawn enforcement**
  - Enforce a **minimum** number of spawns per team, or
  - Enable **replace mode** to enforce an **exact** spawn count (may remove some map spawns).

- **Safety‑aware spawn placement**
  - Optional **hull trace** to avoid stuck/inside‑wall positions.
  - Optional **maximum distance** from each team’s spawn centroid to avoid weird far‑away spawns.
  - Optional Z‑offset to lift spawns slightly off the ground.

- **Auto‑regeneration**
  - When enabled, changing key ConVars automatically removes plugin‑created spawns and rebuilds them.

- **Admin tools**
  - Commands to **enable/disable** plugin logic without unloading the plugin.
  - Command to **reload** spawns on demand.
  - Command to **draw/visualize** all spawns via glow sprites.

- **Per‑map configuration**
  - Global config file plus optional per‑map overrides (e.g. tweak counts for `de_inferno` only).

---

## 🛠 Requirements

- **Game:** CS:GO / CS:S style games with `info_player_terrorist` / `info_player_counterterrorist` spawns.
- **SourceMod:** 1.10+ recommended.
- **Extensions:** Uses built‑in `sdktools`, `sdktools_tempents`, and `sdktools_trace`.

No third‑party extensions are required.

---

## 📦 Installation

1. **Copy plugin**
   - Place `ExtraSpawnPointsRevived.smx` into:
     - `addons/sourcemod/plugins/`

2. **Configs**
   - Global config (auto‑created on first run):
     - `cfg/sourcemod/esp/plugin.ESP.cfg`
   - Optional per‑map overrides (executed after the global config):
     - `cfg/sourcemod/esp/plugin.ESP_<mapname>.cfg`  
       Example: `cfg/sourcemod/esp/plugin.ESP_de_inferno.cfg`

3. **Load plugin**
   - Restart your server, or run from console:
     ```
     sm plugins load ExtraSpawnPointsRevived
     ```

4. **Tune ConVars** in the config files (see below).

---

## 🧠 Core ConVars

| ConVar              | Description                                                                 | Default |
|---------------------|-----------------------------------------------------------------------------|:-------:|
| `sm_ESP_enabled`    | Master switch: `0` = disable logic & remove extra spawns, `1` = enable.     |   1     |
| `sm_ESP_spawns_t`   | Target number of **T** spawns to enforce.                                   |   32    |
| `sm_ESP_spawns_ct`  | Target number of **CT** spawns to enforce.                                  |   32    |
| `sm_ESP_teams`      | Which teams to affect: `0`=off, `1`=both, `2`=T only, `3`=CT only.          |   1     |
| `sm_ESP_replace`    | `0`=add extras (minimum), `1`=enforce exact counts (may remove map spawns). |   0     |
| `sm_ESP_course`     | If one side has 0 spawns and the other >0, double that team’s target.       |   1     |

---

## 🛡 Safety & Placement ConVars

| ConVar               | Description                                                                                         | Default |
|----------------------|-----------------------------------------------------------------------------------------------------|:-------:|
| `sm_ESP_maxdist`     | Max distance from team spawn centroid allowed for duplicates. `0.0` = disabled.                    |  0.0    |
| `sm_ESP_zaxis`       | Extra Z‑offset applied to all stored positions for new spawns.                                     |  16.0   |
| `sm_ESP_safetytrace` | `1` = run a hull trace to avoid stuck/invalid locations, `0` = skip safety checks.                 |   1     |

The plugin:

- Collects all existing T/CT spawns and computes a simple **centroid** per team.
- When adding extra spawns, it:
  - Samples random existing spawns.
  - Rejects positions beyond `sm_ESP_maxdist` (if > 0).
  - Rejects positions where a player‑sized hull hits world geometry.

---

## ⏱ Automation & Debugging ConVars

| ConVar                  | Description                                                                | Default |
|-------------------------|----------------------------------------------------------------------------|:-------:|
| `sm_ESP_min_interval`   | Minimum seconds between spawn rebuilds. `0.0` = no rate limit.            |  1.0    |
| `sm_ESP_mapstart_delay` | Delay before first automatic spawn build after map start.                 |  1.0    |
| `sm_ESP_auto`           | `1` = automatically rebuild when relevant ConVars change.                 |   0     |
| `sm_ESP_debug`          | Debug level: `0`=off, `1`=normal logs, `2`=very verbose.                  |   0     |
| `sm_ESP_draw_duration`  | Duration (seconds) for glow markers used by `sm_esp_drawspawns`.          |  5.0    |

---

## 🔧 Admin Commands

| Command             | Description                                                                                 |
|---------------------|---------------------------------------------------------------------------------------------|
| `sm_addspawns`      | Manually rebuilds spawns according to current ConVars. Root flag required.                 |
| `sm_getspawncount`  | Prints current T/CT spawn counts.                                                           |
| `sm_listspawns`     | Lists all T/CT spawn positions and angles to the caller’s console.                          |
| `sm_esp_enable`     | Sets `sm_ESP_enabled 1`, rebuilds spawns if the map is already started.                     |
| `sm_esp_disable`    | Sets `sm_ESP_enabled 0` and removes all extra spawns created by the plugin.                 |
| `sm_esp_reload`     | Rebuilds spawns on demand (respects rate‑limiting).                                        |
| `sm_esp_drawspawns` | Draws glow sprites at all T/CT spawn points for the calling player (for visual debugging). |

---

## 📂 Per‑Map Configuration

The plugin automatically loads:

- Global config: `cfg/sourcemod/esp/plugin.ESP.cfg`
- Then (if it exists) a map‑specific config:  
  - `cfg/sourcemod/esp/plugin.ESP_<mapname>.cfg`

---

<p align="center">
  <img src="https://badgen.net/badge/Optimized%20for/CS:GO/green?icon=sourceengine" alt="CSGO Optimized" />
  <img src="https://badgen.net/badge/Language/SourcePawn/orange" alt="SourcePawn" />
</p>
