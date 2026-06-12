# GD2 Demo Handoff

Last updated: 2026-06-12

## Current State

This Godot 4.6 project has a playable 2D demo loop for a simulation-management plus dungeon-exploration game.
The main scene is:

```text
res://scenes/main/main.tscn
```

Static UI skeletons are implemented directly in scene files. Scripts update scene nodes and handle behavior.
As of 2026-06-05, the main gameplay scripts and rebuilt scene text use ASCII display strings to avoid corrupted string literals that previously prevented the project from running.
As of 2026-06-09, the project uses a 1152x648 base viewport with `canvas_items` stretch and `expand` aspect. Main UI overlays use anchors and containers so they can stay visible when the window changes size.

## Implemented Files

```text
res://
  scenes/
    main/main.tscn
    management/management_screen.tscn
    world/world_screen.tscn
    dungeon/dungeon_screen.tscn
    battle/battle_screen.tscn
    ui/event_dialog.tscn
    ui/character_status_panel.tscn
  scripts/
    core/main_controller.gd
    core/game_event_manager.gd
    core/character_manager.gd
    management/management_screen.gd
    world/world_screen.gd
    dungeon/dungeon_screen.gd
    dungeon/dungeon_manager.gd
    battle/battle_screen.gd
    battle/battle_manager.gd
    ui/event_dialog.gd
    ui/character_status_panel.gd
  data/
    config/buildings.json
    config/characters.json
    config/dungeon_events.json
    config/enemies.json
    config/items.json
    config/skills.json
    config/timeline_events.json
    config/world_map.json
    config/world_location_events.json
  tests/
    unit/battle_action_order_smoke_test.gd
  Assets/
    bg/bg_dungeon_old_capital_map_placeholder.png
    bg/bg_dungeon_crystal_cavern_map_placeholder.png
    bg/bg_world_map_placeholder.png
    bg/bg_frontier_city_placeholder.png
    bg/bg_moonlit_forest_placeholder.png
    bg/bg_red_waste_placeholder.png
    characters/char_silhouette_portrait_placeholder.png
    characters/char_chibi_adventurer_placeholder.png
    enemies/enemy_shadow_chibi_placeholder.png
    effects/fx_basic_attack_slash_placeholder.png
    effects/fx_power_strike_placeholder.png
    effects/fx_quick_cut_placeholder.png
    effects/fx_arcane_bolt_placeholder.png
    effects/fx_mana_spark_placeholder.png
```

Godot generated `.uid` files for the scripts. Keep them.
Lowercase target directories remain preferred for future new resource roots, but this placeholder is under the existing `Assets/` directory on Windows.

## Gameplay Loop

1. Start in the management base.
2. View day, gold, expected daily income, inventory, buildings, and character status.
3. Click `Travel` to enter the world map.
4. Select a world location, including city, forest, wasteland, or the old capital dungeon.
5. Click location map event points and choose event outcomes.
6. Some event choices grant items or gold directly.
7. Some event choices require party stats.
8. Some event choices start turn-based combat.
9. Some event choices trigger story dialogue events loaded from external text config.
10. Location rewards return to the base.
11. Dungeon materials can build or upgrade buildings.
12. Ending the day adds building income and refreshes dungeon entry.
13. Fixed-date timeline events can appear as bottom dialogue popups on the main scene.

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
- `triggered_timeline_events`
- `journal`
- `buildings`
- `items`

The current config files and scene labels use ASCII display text. Later iterations can move display strings into localization files.

## Timeline Events

Fixed-date story/demo events are loaded from:

```text
res://data/config/timeline_events.json
```

Runtime logic lives in:

```text
res://scripts/core/game_event_manager.gd
res://scripts/ui/event_dialog.gd
res://scenes/ui/event_dialog.tscn
```

`MainController` checks due events after initial setup and after `End Day` advances the date. Events whose `day` matches the current `game_state["day"]` are queued if their id is not already in `game_state["triggered_timeline_events"]`.

Current sample timeline events:

- Day 1: `day_1_opening`
- Day 3: `day_3_supply_report`
- Day 5: `day_5_crystal_rumor`
- Triggered by city notice board: `city_notice_request`
- Triggered by forest herb study: `forest_spirit_trace`
- Triggered by wasteland courier tag: `waste_courier_tag`

The dialogue box appears at the bottom of the main scene. It displays the event title, current speaker name in the upper-left area of the dialogue panel, dialogue text, and left/right portrait images. Current sample events use:

```text
res://Assets/characters/char_silhouette_portrait_placeholder.png
```

Location event choices can set `trigger_event` to queue a story dialogue event by id after returning to the base. `DungeonManager` stores this as a `trigger_event:<event_id>` flag, and `MainController` resolves it through `GameEventManager.event_by_id()`.

## World Map

World map scene:

```text
res://scenes/world/world_screen.tscn
```

Script and config:

```text
res://scripts/world/world_screen.gd
res://data/config/world_map.json
res://data/config/world_location_events.json
```

The management screen's main outing button is now `Travel`. It opens the world map instead of directly entering the dungeon.

`world_map.json` defines:

- `background_texture`: `res://Assets/bg/bg_world_map_placeholder.png`
- `locations`: world-map buttons with id, name, description, config path, start map, and normalized-at-runtime button positions.

Current world locations:

- `frontier_city`: uses `world_location_events.json`, start map `frontier_city`, background `res://Assets/bg/bg_frontier_city_placeholder.png`
- `moonlit_forest`: uses `world_location_events.json`, start map `moonlit_forest`, background `res://Assets/bg/bg_moonlit_forest_placeholder.png`
- `red_waste`: uses `world_location_events.json`, start map `red_waste`, background `res://Assets/bg/bg_red_waste_placeholder.png`
- `old_capital_dungeon`: uses `dungeon_events.json`, start map `old_capital`, marked `is_dungeon`

`WorldScreen` creates destination buttons at runtime with anchors normalized against the 1152x648 world layout size. Selecting a destination updates the info panel; clicking `Enter Location` sends the chosen config and start map to `MainController`.

World locations reuse `DungeonScreen` and `DungeonManager` for now. `DungeonManager.start_run()` now accepts an optional config path and start map id, so city/forest/wasteland maps can use the same event resolution, rewards, requirements, battles, and map button logic as the dungeon.

## Location Shops

`DungeonScreen` also owns a reusable shop panel for world-location events that define a `shop` block.
Clicking `Frontier City` -> `Market` opens this shop panel directly instead of the normal event choice panel.

The shop panel shows purchasable goods on the left and item details plus a buy button on the right. Purchases immediately subtract `game_state["gold"]`, add the configured item quantity to `game_state["inventory"]`, refresh the shop gold label, and append a return-summary journal line.

Current market goods are configured in:

```text
res://data/config/world_location_events.json
```

Current `city_market` goods:

- `healing_potion` x1 for 12 gold
- `iron_ore` x2 for 10 gold
- `glowing_moss` x2 for 14 gold
- `machine_gear` x1 for 24 gold

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
- `speed`
- `skills`: an array of skill ids loaded from `data/config/characters.json`
- `talent_points`
- `learned_talents`
- `talents`: per-character talent tree nodes loaded from `data/config/characters.json`

The management screen, world map, and dungeon/location screen each have a top `Character Status` button for non-battle viewing.
All three screens instantiate `res://scenes/ui/character_status_panel.tscn`.
The reusable character status panel lists party members on the left. Clicking a member opens the detail view on the right with current stats, EXP, skill names/descriptions/MP costs, and current inventory item counts.
The detail view has a `Talent Tree` button. The tree view draws each configured talent node as a button with connector lines based on each node's `position` and `requires` fields.
Learning a talent spends 1 `talent_points`, appends the node id to `learned_talents`, applies its demo `stat_bonus`, and unlocks child talents whose requirements are now learned.
`DungeonScreen` closes and disables the character status panel when a battle starts, then re-enables it after victory returns to the map.

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
- `effect_texture`
- `effect_size`
- `description`

Level-up behavior:

- Battle victory grants each living party member the total enemy EXP.
- If `exp >= next_exp`, the character levels up.
- Each level up increases `max_hp`, `max_mp`, `strength`, `agility`, and `intelligence`.
- Each level up also increases `speed` by 2.
- Each level up grants 1 `talent_points`.
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
Dungeon map event buttons are created at runtime with anchors normalized against the 1152x648 map layout size, instead of fixed pixel positions. This keeps event points aligned with the stretched map image.

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
`BattleManager` owns battle calculation, enemy config loading, speed-based action value ordering, skill use, item use, enemy actions, victory/defeat checks, rewards, and EXP growth.
`DungeonScreen` instantiates `BattleScreen` when a dungeon event choice returns a `battle` result, then listens for `battle_finished(result: Dictionary)`.

Characters and enemies have a `speed` field. The action value delay is:

```text
action_value = int(10000 / speed)
```

`BattleScreen` shows an `Action Order` panel on the left side of the battle field. It displays up to 10 upcoming entries as `Name(value)`. The preview simulates future action values and re-sorts after every simulated action. With speed 100 and 150, the smoke test verifies the preview starts as `B(66), A(100), B(132), B(198), A(200)`, then after B acts becomes `A(34), B(66), B(132), A(134)`.

Current battle layout:

- Left side: action order panel.
- Center/main stage: party slots are stacked vertically on the left and enemy slots are stacked vertically on the right.
- Each combatant slot is a compact fixed-size row with the chibi placeholder, HP bar, name/status text, and damage number.
- Party and enemy field slots are capped at 4 visible combatants per side.
- Each party/enemy slot uses a fixed 320x82 display size so combatant display size does not change between 1 and 4 visible combatants.
- Bottom area: battle log and action command buttons.
- After attacks, `BattleManager` returns damage events and `BattleScreen` displays `-N` damage text above the damaged combatant.
- Attacks and damage skills also emit attack motion events. `BattleScreen` plays these as a short forward lunge for the attacker, then a quick left-right shake on the damaged target.
- Attack motion events can also spawn a temporary skill-effect `TextureRect` over the target slot. Basic attacks use `fx_basic_attack_slash_placeholder.png`; configured skills read `effect_texture` and `effect_size` from `data/config/skills.json`.

Current battle placeholder images:

```text
res://Assets/characters/char_chibi_adventurer_placeholder.png
res://Assets/enemies/enemy_shadow_chibi_placeholder.png
```

Battle flow:

1. Dungeon event choice includes a `battle` dictionary.
2. Selecting the choice hides the event panel and instantiates `BattleScreen`.
3. Left side shows action order.
4. Middle-left shows up to 4 active party members.
5. Middle-right shows up to 4 active enemies.
6. Active party member chooses one of `Attack`, `Skill`, `Defend`, or `Item`.
7. `Attack` enters enemy target selection. Hovering a living enemy slot moves the highlight to that enemy; clicking the slot attacks that exact target.
8. `Skill` opens the active character's configured skill list. Selecting a damage skill enters the same enemy target selection flow, then spends MP and applies the configured damage formula to the clicked enemy.
9. Enemy actions auto-resolve whenever an enemy is the next actor in the speed queue.
10. If a battle config contains more than 4 enemies, only the first 4 enter the field and the rest are stored in `enemy_reserves`.
11. When an active enemy is defeated, its EXP is recorded and the next reserve enemy enters the same slot. Victory is not checked until active enemies and reserves are all defeated.
12. Victory emits battle rewards and EXP summary to `DungeonScreen`, then returns to the dungeon map.
13. Defeat emits a defeat result to `DungeonScreen`, ending the dungeon run and returning to base.

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
- Godot headless project load passed with `--headless --path . --quit`.
- Godot editor headless load passed with `--headless --path . --editor --quit`.
- Main scene short startup passed with `--headless --path . --quit-after 2`.
- `tests/unit/battle_action_order_smoke_test.gd` passed and verifies speed 100/150 action order preview values before and after the first action, including that `B(198)` sorts before `A(200)`.

Additional verification on 2026-06-09:

- Godot editor headless import passed with `--headless --path . --editor --quit` after adding the placeholder portrait.
- Main scene short startup passed with `--headless --path . --quit-after 2`.
- MCP runtime inspection confirmed `/root/Main/EventDialog.visible` is `true` on Day 1.
- MCP screen assertions confirmed `First Morning Briefing`, the first Aki line, and the second Mio line appear in the bottom dialogue popup.
- MCP runtime property inspection confirmed the right portrait uses `res://Assets/characters/char_silhouette_portrait_placeholder.png`.
- Closing the dialogue popup returns to the management screen with `Enter Dungeon` visible.
- After closing the Day 1 event and clicking `End Day` twice, MCP screen assertions confirmed the Day 3 `Supply Report` event appears with its configured text.
- `tests/unit/battle_action_order_smoke_test.gd` still passes after the event system changes.
- Project window settings were set through the Godot project setting API to viewport 1152x648, stretch mode `canvas_items`, and stretch aspect `expand`.
- MCP runtime rectangle checks confirmed the management body, `Enter Dungeon` button, and Day 1 dialogue panel remain inside the visible viewport under the stretch setup.
- MCP runtime property inspection confirmed dungeon event buttons now have normalized anchors with zero offsets, and the dungeon event panel uses relative anchors with zero offsets.
- MCP runtime assertions confirmed `Travel` opens `WorldScreen`, the generated world map texture loads from `res://Assets/bg/bg_world_map_placeholder.png`, and world locations including `Frontier City` and `Old Capital Dungeon` are visible.
- MCP runtime flow verified selecting `Frontier City`, entering the location, opening `Notice Board`, choosing `Read the sealed notice`, returning to base, and showing the triggered `Notice Board Request` dialogue.
- MCP runtime flow verified selecting `Old Capital Dungeon` from the world map enters the existing old capital dungeon map and shows the `Sunken Well` event point.
- MCP runtime property inspection confirmed `Frontier City`, `Moonlit Forest`, and `Red Waste` each load their generated placeholder background textures.
- MCP runtime battle verification confirmed the updated battle layout has the left action-order panel, bottom command buttons, party/enemy chibi placeholder textures, HP bars, and persistent damage labels after an attack.

Additional verification on 2026-06-10:

- Main scene short startup passed with `--headless --path . --quit-after 2`.
- `tests/unit/battle_action_order_smoke_test.gd` passed after the battle field limit changes.
- `git diff --check` passed.
- MCP runtime battle setup with 5 `shadow_wolf` enemies confirmed 4 active enemies, 1 reserve enemy, and 2 visible party members.
- MCP runtime slot inspection confirmed 1-enemy and 4-enemy battle displays both keep active party/enemy slot sizes at `(110.0, 147.0)`.
- MCP runtime combat inspection confirmed defeating enemy slot 0 records 12 EXP, removes one reserve, and inserts the replacement enemy into slot 0 with full HP while keeping 4 active enemies.
- Main scene short startup, `tests/unit/battle_action_order_smoke_test.gd`, and `git diff --check` passed after adding the Frontier City market shop panel.
- MCP runtime flow verified opening `Frontier City` -> `Market` shows the shop panel, the first left-side item button reads `Healing Potion x1 - 12 gold`, and buying it changes gold `40 -> 28` and healing potions `2 -> 3`.
- Main scene short startup, `tests/unit/battle_action_order_smoke_test.gd`, and `git diff --check` passed after changing the battle field to vertical side columns and targeted attacks.
- MCP runtime slot inspection confirmed 4 party slots and 4 enemy slots stack vertically at y positions `147/235/323/411` with fixed `(320.0, 82.0)` slot size.
- MCP runtime combat inspection confirmed entering Attack target selection highlights the default enemy slot, selecting enemy slot 2 attacks only that enemy, and enemy slot 0 HP remains unchanged.

Additional verification on 2026-06-11:

- Main scene short startup passed with `--headless --path . --quit-after 2`.
- `tests/unit/battle_action_order_smoke_test.gd` passed after adding a targeted skill regression check.
- `git diff --check` passed.
- MCP runtime script instantiated `BattleScreen`, entered Attack target selection, hovered enemy slot 2 and then enemy slot 1, and confirmed the highlight moved from slot 2 to slot 1.
- MCP runtime script instantiated `BattleScreen`, selected a skill, clicked enemy slot 1, and confirmed enemy slot 1 HP changed `18 -> 3` while enemy slot 0 stayed `18 -> 18`.
- Main scene short startup, `tests/unit/battle_action_order_smoke_test.gd`, and `git diff --check` passed after adding attack lunge and hit-shake battle event effects.
- The battle unit smoke test now asserts that targeted skills return an `attack_motion` event followed by a `damage` event.
- MCP runtime script instantiated `BattleScreen`, triggered an attack result, and confirmed the result event stream contains `attack_motion` and `damage` events for both the player attack and the auto-resolved enemy response.
- Five image-gen VFX placeholders were generated with chroma-key backgrounds, converted to alpha PNGs, and saved under `Assets/effects/`.
- Main scene short startup, `tests/unit/battle_action_order_smoke_test.gd`, and `git diff --check` passed after wiring skill effect textures through `data/config/skills.json`.
- MCP runtime script instantiated `BattleScreen`, selected `Power Strike`, clicked an enemy target, and confirmed temporary effect nodes used `res://Assets/effects/fx_power_strike_placeholder.png` for the skill and `res://Assets/effects/fx_basic_attack_slash_placeholder.png` for the enemy auto-attack.

Additional verification on 2026-06-12:

- Main scene short startup passed with `--headless --path . --quit-after 2`.
- `tests/unit/battle_action_order_smoke_test.gd` passed.
- `git diff --check` passed.
- MCP runtime script opened `Character Status` on the management screen, selected Aki, and confirmed the detail text includes `Stats`, `Skills`, and `Items`.
- MCP runtime script switched to the world map, opened `Character Status`, selected Mio, and confirmed the detail text includes `Stats`, `Skills`, and `Items`.
- MCP runtime script switched to the old capital dungeon map, opened `Character Status`, selected Aki, and confirmed the detail text includes `Stats`, `Skills`, and `Items`.
- MCP runtime script started a battle from `DungeonScreen` and confirmed the character status panel closes and the top `Character Status` button becomes disabled during battle.
- Main scene short startup, `tests/unit/battle_action_order_smoke_test.gd`, and `git diff --check` passed after adding per-character talent trees.
- The battle unit smoke test now asserts that `_level_up_character()` grants 1 talent point.
- MCP runtime script opened Aki's talent tree, confirmed it shows 6 talent buttons, learned the root `aki_battle_instinct` talent, and confirmed talent points changed `1 -> 0`, `learned_talents` contains the root id, and STR changed `7 -> 8`.
- MCP runtime script then added 1 point after learning the root and confirmed the next branch talents `aki_blade_focus` and `aki_light_step` are learnable while deeper `aki_guard_break` remains locked.

Older validation before the string-corruption fix also covered battle victory rewards, EXP gain, potion use, and returning dungeon rewards to base.

## Known Technical Debt

- Config is JSON, not typed Godot Resources yet.
- Some earlier handoff text and git history contain mojibake from prior Chinese display strings; current runtime UI strings are ASCII.
- UI uses static scene nodes but still placeholder panels/colors.
- No save/load system exists yet.
- Timeline event portraits currently use one generated silhouette placeholder on both sides.
- Automated coverage is still minimal; only focused smoke tests exist.

## Suggested Next Steps

1. Convert JSON configs into typed Godot Resources or add schema validation.
2. Add ally target selection for battle items and future support skills.
3. Add more skill effects beyond direct damage.
4. Add HP/MP recovery rules when ending a day.
5. Add save/load.
6. Replace placeholder map and UI visuals with project-style assets.
7. Add smoke-test scenes or automated test helpers for the main loop.
