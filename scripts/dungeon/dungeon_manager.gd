class_name DungeonManager
extends Node

const EVENTS_CONFIG := "res://data/config/dungeon_events.json"
const ENEMIES_CONFIG := "res://data/config/enemies.json"

const STAT_NAMES := {
	"hp": "HP",
	"mp": "MP",
	"strength": "STR",
	"agility": "AGI",
	"intelligence": "INT"
}

var state: Dictionary = {}
var dungeon_config: Dictionary = {}
var map_config: Dictionary = {}
var event_config: Dictionary = {}
var enemy_config: Dictionary = {}
var run_rewards: Dictionary = {"gold": 0}
var run_flags: Dictionary = {}
var run_summary: Array[String] = []
var resolved_events: Dictionary = {}
var current_map_id := ""


func start_run(new_state: Dictionary) -> void:
	state = new_state
	_load_configs()
	_initialize_run_rewards()
	_select_start_map()


func current_map() -> Dictionary:
	if map_config.has(current_map_id):
		return map_config[current_map_id]
	return {}


func current_event_points() -> Array:
	return current_map().get("event_points", [])


func has_event(event_id: String) -> bool:
	return event_config.has(event_id)


func event_data(event_id: String) -> Dictionary:
	return event_config.get(event_id, {})


func is_event_resolved(event_id: String) -> bool:
	return resolved_events.has(event_id)


func is_event_repeatable(event_id: String) -> bool:
	return bool(event_data(event_id).get("repeatable", false))


func choices_for_event(event_id: String) -> Array:
	var choices: Array = []
	for choice: Dictionary in event_data(event_id).get("choices", []):
		var prepared_choice := choice.duplicate(true)
		prepared_choice["event_id"] = event_id
		choices.append(prepared_choice)
	return choices


func resolve_choice(choice: Dictionary) -> Dictionary:
	var requirements: Dictionary = choice.get("requirements", {})
	if not meets_requirements(requirements):
		return {"ok": false, "message": "The party does not meet this requirement."}

	_mark_choice_event_resolved(choice)

	if choice.has("battle"):
		return {
			"ok": true,
			"battle": choice.get("battle", {}),
			"battle_rewards": choice.get("rewards", {}),
			"battle_summary": choice.get("summary", "Dungeon: won a battle."),
			"body": choice.get("result", "Enemies block the path.")
		}

	if choice.has("rewards"):
		add_run_rewards(choice["rewards"])
	if choice.has("flags"):
		for flag_name: String in choice["flags"]:
			run_flags[flag_name] = choice["flags"][flag_name]
	if choice.has("summary"):
		append_summary(choice["summary"])
	if choice.has("travel"):
		var travel_result := travel_to_map(choice["travel"])
		if not bool(travel_result.get("ok", false)):
			return travel_result
		return {"ok": true, "traveled": true}

	return {
		"ok": true,
		"title": "Investigation complete",
		"body": choice.get("result", "The party records this change.")
	}


func travel_to_map(travel_data: Dictionary) -> Dictionary:
	var target_map_id := String(travel_data.get("target_map", ""))
	if target_map_id == "" or not map_config.has(target_map_id):
		return {"ok": false, "message": "The route cannot be found."}
	current_map_id = target_map_id
	return {"ok": true}


func enemy_data(enemy_id: String) -> Dictionary:
	if enemy_config.has(enemy_id):
		return enemy_config[enemy_id].duplicate(true)
	return {}


func meets_requirements(requirements: Dictionary) -> bool:
	if requirements.is_empty():
		return true
	for stat_id: String in requirements:
		if _best_party_stat(stat_id) < int(requirements[stat_id]):
			return false
	return true


func requirements_text(requirements: Dictionary) -> String:
	if requirements.is_empty():
		return ""
	var parts: Array[String] = []
	for stat_id: String in requirements:
		parts.append("%s %d" % [STAT_NAMES.get(stat_id, stat_id), int(requirements[stat_id])])
	return "  [Need %s]" % " / ".join(parts)


func add_run_rewards(rewards: Dictionary) -> void:
	for reward_id: String in rewards:
		run_rewards[reward_id] = int(run_rewards.get(reward_id, 0)) + int(rewards[reward_id])


func append_summary(summary: String) -> void:
	if summary != "":
		run_summary.append(summary)


func finish_summary() -> Array[String]:
	if run_summary.is_empty():
		run_summary.append("Dungeon: the party withdrew carefully without new findings.")
	return run_summary


func _load_configs() -> void:
	dungeon_config = _load_json(EVENTS_CONFIG)
	map_config = dungeon_config.get("maps", {})
	event_config = dungeon_config.get("events", {})
	enemy_config = _load_json(ENEMIES_CONFIG).get("enemies", {})


func _initialize_run_rewards() -> void:
	run_rewards = {"gold": 0}
	for item_id: String in state.get("inventory", {}):
		run_rewards[item_id] = 0
	run_flags = {}
	run_summary = []
	resolved_events = {}


func _select_start_map() -> void:
	current_map_id = String(dungeon_config.get("start_map", ""))
	if current_map_id != "" and map_config.has(current_map_id):
		return
	var map_ids := map_config.keys()
	if not map_ids.is_empty():
		current_map_id = String(map_ids[0])


func _mark_choice_event_resolved(choice: Dictionary) -> void:
	var event_id := String(choice.get("event_id", ""))
	if event_id == "":
		return
	if not is_event_repeatable(event_id):
		resolved_events[event_id] = true


func _best_party_stat(stat_id: String) -> int:
	var best_value := 0
	for character: Dictionary in state.get("characters", []):
		best_value = max(best_value, int(character.get(stat_id, 0)))
	return best_value


func _load_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	push_error("Failed to load JSON config: %s" % path)
	return {}
