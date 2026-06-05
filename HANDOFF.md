# GD2 Demo Handoff

Last updated: 2026-06-05

## Current State

This Godot 4.6 project has a playable 2D demo loop for a simulation-management plus dungeon-exploration game.
The main scene is:

```text
res://scenes/main/main.tscn
```

Static UI skeletons are implemented directly in scene files. Scripts update scene nodes and handle behavior.
As of 2026-06-05, the main gameplay scripts and rebuilt scene text use ASCII display strings to avoid corrupted string literals that previously prevented the project from running.

## Implemented Files

```text
res://
  scenes/
    main/main.tscn
    management/management_screen.tscn
    dungeon/dungeon_screen.tscn
  scripts/
    core/main_controller.gd
    management/management_screen.gd
    dungeon/dungeon_screen.gd
  data/
    config/buildings.json
    config/characters.json
    config/dungeon_events.json
    config/enemies.json
    config/items.json
```

Godot generated `.uid` files for the scripts. Keep them.

## Gameplay Loop

1. Start in the management base.
2. View day, gold, expected daily income, inventory, buildings, and character status.
3. Enter the dungeon once per day.
4. Click dungeon map event points and choose event outcomes.
5. Some event choices grant items or gold directly.
6. Some event choices require party stats.
7. Some event choices start turn-based combat.
8. Dungeon rewards return to the base.
9. Dungeon materials can build or upgrade buildings.
10. Ending the day adds building income and refreshes dungeon entry.

## State Model

Runtime state lives in `scripts/core/main_controller.gd` in `game_state`.
Initial static data is loaded from `data/config/*.json`.

Current state categories:

- `day`
- `gold`
- `dungeon_used_today`
- `characters`
- `inventory`
- `flags`
- `journal`
- `buildings`
- `items`

The current config files and scene labels use ASCII display text. Later iterations can move display strings into localization files.

## Characters

Initial characters are loaded from `res://data/config/characters.json`.

- Aki Hoshino / Trainee Explorer
- Mio Kirishima / Ruins Mage

Characters currently have:

- `level`
- `exp`
- `next_exp`
- `hp`
- `max_hp`
- `mp`
- `max_mp`
- `strength`
- `agility`
- `intelligence`

The management screen has a `Character Status` button that opens a character status panel.

Level-up behavior:

- Battle victory grants each living party member the total enemy EXP.
- If `exp >= next_exp`, the character levels up.
- Each level up increases `max_hp`, `max_mp`, `strength`, `agility`, and `intelligence`.
- HP and MP are restored to the new maximum after level up.
- Next level requirement is `20 + (level - 1) * 15`.

## Inventory

Item names and item metadata are loaded from `res://data/config/items.json`.

Current inventory item ids:

- `ancient_shard`
- `iron_ore`
- `glowing_moss`
- `machine_gear`
- `healing_potion`

`healing_potion` is used in battle from the item command and restores 20 HP to the active party member.

## Buildings

Building definitions are loaded from `res://data/config/buildings.json`.

Current buildings:

- `guild_hall`: built at start, provides daily gold income, can be upgraded.
- `workshop`: not built at start, requires `machine_gear` and `iron_ore`.
- `herb_garden`: not built at start, requires `glowing_moss`.

## Dungeon

Dungeon scene:

```text
res://scenes/dungeon/dungeon_screen.tscn
```

Script:

```text
res://scripts/dungeon/dungeon_screen.gd
```

The dungeon map, event buttons, event panel, choice buttons, battle panel, battle commands, and item button are defined in the scene file.
Dungeon event definitions are loaded from `res://data/config/dungeon_events.json`.
Enemy definitions are loaded from `res://data/config/enemies.json`.

Current event points:

- `sunken_well`
- `collapsed_mine`
- `sealed_gate`
- `shadow_patrol`
- `old_shrine`

Event choices can define:

- `rewards`
- `flags`
- `requirements`
- `battle`
- `summary`
- `result`

Stat-gated choices use `requirements`, for example:

```gdscript
"requirements": {"agility": 8}
```

The current requirement check uses the best party member stat for each requested stat.

## Battle

Battle is currently implemented as an overlay inside `DungeonScreen`, not as a separate battle scene.

Battle flow:

1. Dungeon event choice includes a `battle` dictionary.
2. Selecting the choice hides the event panel and shows the battle overlay.
3. Left side shows party members.
4. Right side shows enemies.
5. Active party member chooses one of `Attack`, `Skill`, `Defend`, or `Item`.
6. Enemy turn runs after all living party members act.
7. Victory adds battle rewards and EXP, then returns to dungeon map.
8. Defeat ends the dungeon run and returns to base.

Current battle choices:

- `Fight the shadow patrol`
- `Challenge the shrine guardian`

During battle, the top `Return to Base` button is disabled to prevent leaving before combat resolves.

## Verified Flows

The following flows were verified through Godot MCP CLI on 2026-06-05:

- `project info` connected successfully through a temporary MCP port and reported Godot 4.6.1, project `GD2`, and main scene `res://scenes/main/main.tscn`.
- `scene play --mode main` returned `playing: true`.
- `editor errors` returned no errors immediately after startup.
- Runtime UI inspection confirmed the management screen shows day, gold, dungeon availability, income, inventory, and building controls.
- Clicking `Enter Dungeon` transitioned to `DungeonScreen`.
- Runtime UI inspection confirmed dungeon event buttons are visible.
- Clicking `Sunken Well` opened the event panel.
- The event panel displayed config-driven choices, including a stat requirement label.

Older validation before the string-corruption fix also covered battle victory rewards, EXP gain, potion use, and returning dungeon rewards to base.

## MCP Notes

The Godot MCP Pro plugin starts successfully in Godot and connects to the Node backend:

```text
[MCP] Godot MCP Pro v1.14.1 started (ports 6505-6514)
[MCP] Registered 171 commands
```

In this Codex session, long-lived `mcp__godot_mcp_pro` tool calls still report `Godot editor is not connected` even while TCP shows Godot connected to port 6505.
The MCP CLI path works and can be used as a fallback:

```powershell
node C:\Users\admin\Desktop\godot-mcp-pro-v1.14.1\server\build\cli.js project info
```

## Known Technical Debt

- Config is JSON, not typed Godot Resources yet.
- Some earlier handoff text and git history contain mojibake from prior Chinese display strings; current runtime UI strings are ASCII.
- Battle is embedded in `DungeonScreen`; it should eventually move to `scenes/battle/` and `scripts/battle/`.
- UI uses static scene nodes but still placeholder panels/colors.
- No save/load system exists yet.
- No formal automated tests exist yet.
- The long-lived MCP wrapper connection state needs investigation; CLI temporary-port connections are currently reliable.

## Suggested Next Steps

1. Convert JSON configs into typed Godot Resources or add schema validation.
2. Move battle logic into a dedicated battle scene/controller.
3. Add proper target selection for attacks, skills, and items.
4. Add skill definitions instead of one hardcoded skill action.
5. Add HP/MP recovery rules when ending a day.
6. Add save/load.
7. Replace placeholder map and UI visuals with project-style assets.
8. Add smoke-test scenes or automated test helpers for the main loop.
9. Investigate why the long-lived MCP wrapper does not refresh its connection state even though the Godot plugin connects to port 6505 and the CLI can connect through temporary ports.
