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
    battle/battle_screen.tscn
  scripts/
    core/main_controller.gd
    core/character_manager.gd
    management/management_screen.gd
    dungeon/dungeon_screen.gd
    dungeon/dungeon_manager.gd
    battle/battle_screen.gd
    battle/battle_manager.gd
  data/
    config/buildings.json
    config/characters.json
    config/dungeon_events.json
    config/enemies.json
    config/items.json
    config/skills.json
  Assets/
    bg/bg_dungeon_old_capital_map_placeholder.png
    bg/bg_dungeon_crystal_cavern_map_placeholder.png
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
Character and skill data are loaded by `scripts/core/character_manager.gd`.

Current state categories:

- `day`
- `gold`
- `dungeon_used_today`
- `characters`
- `skills`
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
- `skills`: an array of skill ids loaded from `data/config/characters.json`

The management screen has a `Character Status` button that opens a character status panel.
The character status panel displays each character's current skill names.

`CharacterManager` loads and normalizes character data and skill data:

```text
res://scripts/core/character_manager.gd
res://data/config/characters.json
res://data/config/skills.json
```

Current configured character skills:

- Aki Hoshino: `power_strike`, `quick_cut`
- Mio Kirishima: `arcane_bolt`, `mana_spark`

Skill definitions currently support:

- `name`
- `mp_cost`
- `target`
- `effect`
- `base_damage`
- `scaling_stat`
- `power`
- `description`

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
res://scripts/dungeon/dungeon_manager.gd
```

The dungeon map, event buttons, event panel, and choice buttons are defined in the scene file.
`DungeonScreen` handles UI display, dynamic event buttons, map image presentation, starting battle encounters, and applying battle results.
`DungeonManager` handles dungeon config loading, current map state, event resolution state, requirements checks, map travel, run rewards, run flags, and run summary.
Click-open secondary panels now use explicit opaque `StyleBoxFlat` backgrounds in the scene files, including the management character panel, dungeon event panel, battle screen, and battle item panel.

Dungeon maps are config-driven:

- `start_map`: currently `old_capital`.
- `maps`: defines each map title, background texture, and event button positions.
- `events`: defines event text, choices, rewards, flags, requirements, battles, and map travel.

Each dungeon map uses a single PNG top-down placeholder background through `background_texture`; the scene displays it with `MapImage` (`TextureRect`) instead of assembling the map from UI `ColorRect` blocks.

Current maps:

- `old_capital`: original Old Capital Dungeon map.
- `crystal_cavern`: second dungeon map reached through the crystal gate.

Current `old_capital` event points:

- `sunken_well`
- `collapsed_mine`
- `sealed_gate`
- `shadow_patrol`
- `old_shrine`
- `crystal_ward_gate`

Current `crystal_cavern` event points:

- `cavern_return_gate`
- `crystal_garden`
- `mana_spring`
- `deep_crystal_nest`

Event choices can define:

- `rewards`
- `flags`
- `requirements`
- `battle`
- `travel`
- `summary`
- `result`

Stat-gated choices use `requirements`, for example:

```gdscript
"requirements": {"agility": 8}
```

The current requirement check uses the best party member stat for each requested stat.

Map travel is configured per event choice with:

```json
"travel": {"target_map": "crystal_cavern"}
```

The current repeatable travel events are:

- `crystal_ward_gate`: travels from `old_capital` to `crystal_cavern`.
- `cavern_return_gate`: travels from `crystal_cavern` to `old_capital`.

## Battle

Battle scene:

```text
res://scenes/battle/battle_screen.tscn
```

Scripts:

```text
res://scripts/battle/battle_screen.gd
res://scripts/battle/battle_manager.gd
```

`BattleScreen` owns battle UI display and input forwarding.
`BattleManager` owns battle calculation, enemy config loading, active actor rotation, skill use, item use, enemy turns, victory/defeat checks, rewards, and EXP growth.
`DungeonScreen` instantiates `BattleScreen` when a dungeon event choice returns a `battle` result, then listens for `battle_finished(result: Dictionary)`.

Battle flow:

1. Dungeon event choice includes a `battle` dictionary.
2. Selecting the choice hides the event panel and instantiates `BattleScreen`.
3. Left side shows party members.
4. Right side shows enemies.
5. Active party member chooses one of `Attack`, `Skill`, `Defend`, or `Item`.
6. `Skill` opens the active character's configured skill list; selecting a skill spends MP and applies the configured damage formula.
7. Enemy turn runs after all living party members act.
8. Victory emits battle rewards and EXP summary to `DungeonScreen`, then returns to the dungeon map.
9. Defeat emits a defeat result to `DungeonScreen`, ending the dungeon run and returning to base.

Current battle choices:

- `Fight the shadow patrol`
- `Challenge the shrine guardian`

During battle, the top `Return to Base` button is disabled to prevent leaving before combat resolves.

Current skill damage formula:

```text
damage = base_damage + actor[scaling_stat] * power
```

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
- Clicking `Crystal Gate` opened a config-driven travel event.
- Selecting `Enter the crystal cavern` switched the dungeon title to `Crystal Cavern` and replaced event buttons with the `crystal_cavern` map events.
- Clicking `Return Gate` and selecting `Return to the old capital` switched the dungeon title back to `Old Capital Dungeon`.
- Clicking `Sunken Well` after the map travel test still resolved a normal reward event and updated `Run rewards` to `Glowing Moss x2`.
- Runtime property inspection confirmed `MapImage.texture` loads `res://Assets/bg/bg_dungeon_old_capital_map_placeholder.png` on the old capital map and switches to `res://Assets/bg/bg_dungeon_crystal_cavern_map_placeholder.png` after traveling to the crystal cavern.
- Runtime scene-tree inspection confirmed `DungeonManager` is attached under `DungeonScreen` and uses `res://scripts/dungeon/dungeon_manager.gd`.
- After the `DungeonManager` extraction, traveling to `crystal_cavern`, resolving `Crystal Garden`, and returning to base were re-verified; base inventory showed `Glowing Moss x3` and the journal showed `Dungeon: harvested luminous moss in the crystal garden.`.
- Runtime scene-tree inspection confirmed `CharacterManager` is attached under `Main` and uses `res://scripts/core/character_manager.gd`.
- Character status displayed Aki's `Power Strike, Quick Cut` skills and Mio's `Arcane Bolt, Mana Spark` skills.
- In battle, clicking `Skill` for Aki displayed `Power Strike` and `Quick Cut`; selecting `Power Strike` spent 4 MP and dealt configured STR-scaling damage.
- On Mio's turn, clicking `Skill` displayed `Arcane Bolt` and `Mana Spark`; selecting `Arcane Bolt` spent 5 MP and dealt configured INT-scaling damage.
- Runtime scene-tree inspection confirmed `DungeonScreen` no longer contains the old `BattleLayer` subtree.
- Selecting `Fight the shadow patrol` instantiated `/root/Main/DungeonScreen/BattleScreen` with child `/root/Main/DungeonScreen/BattleScreen/BattleManager`.
- During the battle, the top `Return to Base` button was disabled.
- Aki used `Power Strike`, Mio used `Arcane Bolt`, and Aki finished the fight with `Attack`.
- After victory, `BattleScreen` was removed, `MapLayer` became visible again, `Return to Base` was re-enabled, and the reward label showed `Run rewards: Gold x24, Iron Ore x1`.

Older validation before the string-corruption fix also covered battle victory rewards, EXP gain, potion use, and returning dungeon rewards to base.

## Known Technical Debt

- Config is JSON, not typed Godot Resources yet.
- Some earlier handoff text and git history contain mojibake from prior Chinese display strings; current runtime UI strings are ASCII.
- UI uses static scene nodes but still placeholder panels/colors.
- No save/load system exists yet.
- No formal automated tests exist yet.

## Suggested Next Steps

1. Convert JSON configs into typed Godot Resources or add schema validation.
2. Add proper target selection for attacks, skills, and items.
3. Add more skill effects beyond direct damage.
4. Add HP/MP recovery rules when ending a day.
5. Add save/load.
6. Replace placeholder map and UI visuals with project-style assets.
7. Add smoke-test scenes or automated test helpers for the main loop.
