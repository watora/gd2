class_name MainController
extends Control

const MANAGEMENT_SCREEN_SCENE := preload("res://scenes/management/management_screen.tscn")
const DUNGEON_SCREEN_SCENE := preload("res://scenes/dungeon/dungeon_screen.tscn")

const BUILDINGS_CONFIG := "res://data/config/buildings.json"
const ITEMS_CONFIG := "res://data/config/items.json"

var game_state: Dictionary = {}
var _current_screen: Control
var _character_manager := CharacterManager.new()


func _ready() -> void:
	_character_manager.name = "CharacterManager"
	add_child(_character_manager)
	_initialize_game_state()
	_show_management()


func _initialize_game_state() -> void:
	var item_config := _load_json(ITEMS_CONFIG)
	var building_config := _load_json(BUILDINGS_CONFIG)
	_character_manager.load_data()

	var inventory := {}
	for item_id: String in item_config.keys():
		inventory[item_id] = 0
	inventory["healing_potion"] = 2

	game_state = {
		"day": 1,
		"gold": 40,
		"dungeon_used_today": false,
		"characters": _character_manager.initial_characters(),
		"skills": _character_manager.skills(),
		"inventory": inventory,
		"flags": {},
		"journal": ["Day 1: The frontier base is ready. One dungeon run is available."],
		"buildings": building_config.get("buildings", {}).duplicate(true),
		"items": item_config.duplicate(true)
	}


func _show_management() -> void:
	_clear_screen()
	var screen: Control = MANAGEMENT_SCREEN_SCENE.instantiate()
	_current_screen = screen
	add_child(screen)
	screen.setup(game_state)
	screen.start_dungeon_requested.connect(_show_dungeon)
	screen.next_day_requested.connect(_advance_day)
	screen.building_action_requested.connect(_handle_building_action)


func _show_dungeon() -> void:
	if game_state["dungeon_used_today"]:
		_add_journal("The dungeon has already been explored today.")
		_show_management()
		return

	_clear_screen()
	var screen: Control = DUNGEON_SCREEN_SCENE.instantiate()
	_current_screen = screen
	add_child(screen)
	screen.setup(game_state)
	screen.run_finished.connect(_finish_dungeon_run)


func _finish_dungeon_run(rewards: Dictionary, flags: Dictionary, summary: Array[String]) -> void:
	game_state["dungeon_used_today"] = true
	_add_rewards(rewards)
	for flag_name: String in flags:
		game_state["flags"][flag_name] = flags[flag_name]
	for line: String in summary:
		_add_journal(line)
	_show_management()


func _advance_day() -> void:
	var income: int = _calculate_daily_income()
	game_state["gold"] += income
	game_state["day"] += 1
	game_state["dungeon_used_today"] = false
	_add_journal("Day %d settlement: base buildings produced %d gold." % [game_state["day"] - 1, income])
	_add_journal("Day %d begins: dungeon entry has refreshed." % game_state["day"])
	_show_management()


func _handle_building_action(building_id: String) -> void:
	var building: Dictionary = game_state["buildings"][building_id]
	var cost := _building_action_cost(building)
	var action_name := "Build" if not bool(building["built"]) else "Upgrade"

	if _is_building_done(building):
		_add_journal("%s is already at max level." % building["name"])
		_show_management()
		return

	if not _has_items(cost):
		_add_journal("%s %s failed: dungeon materials are not enough." % [action_name, building["name"]])
		_show_management()
		return

	_pay_items(cost)
	if not bool(building["built"]):
		building["built"] = true
		building["level"] = 1
	else:
		building["level"] = int(building["level"]) + 1

	_add_journal("%s %s complete. Current level: Lv.%d." % [action_name, building["name"], building["level"]])
	_show_management()


func _building_action_cost(building: Dictionary) -> Dictionary:
	if not bool(building["built"]):
		return building.get("build_cost", {})
	return building.get("upgrade_costs", {}).get(str(building["level"]), {})


func _is_building_done(building: Dictionary) -> bool:
	return bool(building["built"]) and int(building["level"]) >= int(building["max_level"])


func _calculate_daily_income() -> int:
	var total := 0
	for building_id: String in game_state["buildings"]:
		var building: Dictionary = game_state["buildings"][building_id]
		if bool(building["built"]):
			total += int(building["income_gold"]) * int(building["level"])
	return total


func _add_rewards(rewards: Dictionary) -> void:
	if rewards.has("gold"):
		game_state["gold"] += int(rewards["gold"])
	for reward_id: String in rewards:
		if reward_id == "gold":
			continue
		if not game_state["inventory"].has(reward_id):
			game_state["inventory"][reward_id] = 0
		game_state["inventory"][reward_id] += int(rewards[reward_id])


func _has_items(cost: Dictionary) -> bool:
	for item_id: String in cost:
		if int(game_state["inventory"].get(item_id, 0)) < int(cost[item_id]):
			return false
	return true


func _pay_items(cost: Dictionary) -> void:
	for item_id: String in cost:
		game_state["inventory"][item_id] -= int(cost[item_id])


func _add_journal(text: String) -> void:
	game_state["journal"].push_front(text)
	if game_state["journal"].size() > 8:
		game_state["journal"].resize(8)


func _clear_screen() -> void:
	if is_instance_valid(_current_screen):
		var old_screen := _current_screen
		_current_screen = null
		remove_child(old_screen)
		old_screen.queue_free()


func _load_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	push_error("Failed to load JSON config: %s" % path)
	return {}
