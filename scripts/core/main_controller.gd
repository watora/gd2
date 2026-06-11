class_name MainController
extends Control

const MANAGEMENT_SCREEN_SCENE := preload("res://scenes/management/management_screen.tscn")
const WORLD_SCREEN_SCENE := preload("res://scenes/world/world_screen.tscn")
const DUNGEON_SCREEN_SCENE := preload("res://scenes/dungeon/dungeon_screen.tscn")
const GAME_EVENT_MANAGER_SCRIPT := preload("res://scripts/core/game_event_manager.gd")

const BUILDINGS_CONFIG := "res://data/config/buildings.json"
const ITEMS_CONFIG := "res://data/config/items.json"

var game_state: Dictionary = {}
var _current_screen: Control
var _character_manager := CharacterManager.new()
var _game_event_manager: Node
var _timeline_event_queue: Array[Dictionary] = []

@onready var _event_dialog: Control = %EventDialog


func _ready() -> void:
	_character_manager.name = "CharacterManager"
	add_child(_character_manager)
	_game_event_manager = GAME_EVENT_MANAGER_SCRIPT.new()
	_game_event_manager.name = "GameEventManager"
	add_child(_game_event_manager)
	_game_event_manager.call("load_data")
	_event_dialog.connect("dialog_finished", Callable(self, "_on_event_dialog_finished"))
	_initialize_game_state()
	_show_management()
	_queue_timeline_events_for_day()


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
		"triggered_timeline_events": [],
		"journal": ["Day 1: The frontier base is ready. One dungeon run is available."],
		"buildings": building_config.get("buildings", {}).duplicate(true),
		"items": item_config.duplicate(true)
	}


func _show_management() -> void:
	_clear_screen()
	var screen: Control = MANAGEMENT_SCREEN_SCENE.instantiate()
	_current_screen = screen
	add_child(screen)
	_raise_event_dialog()
	screen.setup(game_state)
	screen.start_dungeon_requested.connect(_show_world)
	screen.next_day_requested.connect(_advance_day)
	screen.building_action_requested.connect(_handle_building_action)


func _show_world() -> void:
	_clear_screen()
	var screen: Control = WORLD_SCREEN_SCENE.instantiate()
	_current_screen = screen
	add_child(screen)
	_raise_event_dialog()
	screen.setup(game_state)
	screen.location_selected.connect(_show_location)
	screen.return_requested.connect(_show_management)


func _show_dungeon() -> void:
	_show_location({
		"name": "Old Capital Dungeon",
		"config_path": "res://data/config/dungeon_events.json",
		"start_map": "old_capital",
		"is_dungeon": true
	})


func _show_location(location_data: Dictionary) -> void:
	var is_dungeon := bool(location_data.get("is_dungeon", false))
	if game_state["dungeon_used_today"]:
		if is_dungeon:
			_add_journal("The dungeon has already been explored today.")
			_show_world()
			return

	_clear_screen()
	var screen: Control = DUNGEON_SCREEN_SCENE.instantiate()
	_current_screen = screen
	add_child(screen)
	_raise_event_dialog()
	screen.setup(
		game_state,
		String(location_data.get("config_path", "res://data/config/dungeon_events.json")),
		String(location_data.get("start_map", ""))
	)
	screen.run_finished.connect(_finish_location_run.bind(is_dungeon, String(location_data.get("name", "Location"))))


func _finish_dungeon_run(rewards: Dictionary, flags: Dictionary, summary: Array[String]) -> void:
	_finish_location_run(rewards, flags, summary, true, "Old Capital Dungeon")


func _finish_location_run(
	rewards: Dictionary,
	flags: Dictionary,
	summary: Array[String],
	is_dungeon: bool,
	location_name: String
) -> void:
	if is_dungeon:
		game_state["dungeon_used_today"] = true
	_add_rewards(rewards)
	for flag_name: String in flags:
		game_state["flags"][flag_name] = flags[flag_name]
	for line: String in summary:
		_add_journal(line)
	if not is_dungeon:
		_add_journal("Travel: returned from %s." % location_name)
	_show_management()
	_queue_triggered_events_from_flags(flags)


func _advance_day() -> void:
	var income: int = _calculate_daily_income()
	game_state["gold"] += income
	game_state["day"] += 1
	game_state["dungeon_used_today"] = false
	_add_journal("Day %d settlement: base buildings produced %d gold." % [game_state["day"] - 1, income])
	_add_journal("Day %d begins: dungeon entry has refreshed." % game_state["day"])
	_show_management()
	_queue_timeline_events_for_day()


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


func _queue_timeline_events_for_day() -> void:
	var triggered_events: Array = game_state.get("triggered_timeline_events", [])
	var due_events: Array = _game_event_manager.call("due_events_for_day", int(game_state["day"]), triggered_events)
	for event_data: Dictionary in due_events:
		var event_id := String(event_data["id"])
		triggered_events.append(event_id)
		_timeline_event_queue.append(event_data)
		_add_journal("Day %d event: %s" % [game_state["day"], event_data.get("title", event_id)])
	game_state["triggered_timeline_events"] = triggered_events
	_show_next_timeline_event()


func _show_next_timeline_event() -> void:
	if bool(_event_dialog.call("is_dialog_open")) or _timeline_event_queue.is_empty():
		return
	var event_data: Dictionary = _timeline_event_queue.pop_front()
	_event_dialog.call("show_event", event_data)
	_raise_event_dialog()


func _on_event_dialog_finished(_event_id: String) -> void:
	_show_next_timeline_event()


func _queue_triggered_events_from_flags(flags: Dictionary) -> void:
	for flag_name: String in flags:
		if not flag_name.begins_with("trigger_event:"):
			continue
		_queue_timeline_event_by_id(flag_name.substr("trigger_event:".length()))


func _queue_timeline_event_by_id(event_id: String) -> void:
	var triggered_events: Array = game_state.get("triggered_timeline_events", [])
	var event_data: Dictionary = _game_event_manager.call("event_by_id", event_id, triggered_events)
	if event_data.is_empty():
		return
	triggered_events.append(event_id)
	_timeline_event_queue.append(event_data)
	_add_journal("Story event: %s" % event_data.get("title", event_id))
	game_state["triggered_timeline_events"] = triggered_events
	_show_next_timeline_event()


func _raise_event_dialog() -> void:
	if is_instance_valid(_event_dialog):
		move_child(_event_dialog, get_child_count() - 1)


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
