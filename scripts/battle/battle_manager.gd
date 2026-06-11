class_name BattleManager
extends Node

const ENEMIES_CONFIG := "res://data/config/enemies.json"
const ACTION_VALUE_BASE := 10000
const DEFAULT_SPEED := 100
const MAX_ACTION_ORDER_PREVIEW := 10
const MAX_PARTY_MEMBERS := 4
const MAX_ACTIVE_ENEMIES := 4

var state: Dictionary = {}
var enemy_config: Dictionary = {}
var battle_rewards: Dictionary = {}
var battle_summary := ""
var battle_party: Array[Dictionary] = []
var battle_enemies: Array[Dictionary] = []
var enemy_reserves: Array[Dictionary] = []
var defeated_enemy_exp_reward := 0
var active_actor_index := 0
var active_actor_side := "party"
var action_queue: Array[Dictionary] = []
var guarding: Dictionary = {}
var battle_log := ""
var pending_battle_result: Dictionary = {}
var recent_events: Array[Dictionary] = []


func start_battle(new_state: Dictionary, battle_result: Dictionary) -> void:
	state = new_state
	enemy_config = _load_json(ENEMIES_CONFIG).get("enemies", {})
	battle_rewards = battle_result.get("battle_rewards", {})
	battle_summary = battle_result.get("battle_summary", "Dungeon: won a battle.")
	battle_party = []
	battle_enemies = []
	enemy_reserves = []
	defeated_enemy_exp_reward = 0
	guarding = {}
	recent_events = []
	active_actor_index = 0
	active_actor_side = "party"
	action_queue = []
	pending_battle_result = {}

	for character: Dictionary in state["characters"]:
		if battle_party.size() >= MAX_PARTY_MEMBERS:
			break
		_prepare_character_growth_fields(character)
		_prepare_combatant_speed(character)
		battle_party.append(character)

	var enemy_ids: Array = battle_result.get("battle", {}).get("enemies", [])
	for enemy_id: String in enemy_ids:
		if enemy_config.has(enemy_id):
			var enemy: Dictionary = enemy_config[enemy_id].duplicate(true)
			_prepare_combatant_speed(enemy)
			if battle_enemies.size() < MAX_ACTIVE_ENEMIES:
				battle_enemies.append(enemy)
			else:
				enemy_reserves.append(enemy)

	battle_log = battle_result.get("body", "Enemies block the path.")
	_reset_action_queue()
	pending_battle_result = _resolve_enemy_actions_until_player_ready()
	if String(pending_battle_result.get("status", "running")) == "running":
		pending_battle_result = {}


func active_actor() -> Dictionary:
	if active_actor_side != "party" or battle_party.is_empty():
		return {}
	return battle_party[active_actor_index]


func active_actor_ready() -> bool:
	return active_actor_side == "party" and _is_character_alive(active_actor()) and not is_battle_over()


func active_actor_skill_ids() -> Array:
	return active_actor().get("skills", [])


func attack(target_index: int = -1) -> Dictionary:
	recent_events = []
	var actor := active_actor()
	if actor.is_empty():
		return {"status": "running", "log": battle_log}
	guarding.erase(actor["name"])
	if target_index < 0:
		target_index = _first_alive_enemy_index()
	var target := _alive_enemy_at_index(target_index)
	if target.is_empty():
		battle_log = "Choose a valid enemy target."
		return {"status": "running", "log": battle_log}
	var damage: int = max(1, int(actor["strength"]) + 3)
	target["hp"] -= damage
	_add_damage_event("enemy", target_index, damage)
	battle_log = "%s attacks %s for %d damage." % [actor["name"], target["name"], damage]
	return _after_player_action()


func defend() -> Dictionary:
	recent_events = []
	var actor := active_actor()
	if actor.is_empty():
		return {"status": "running", "log": battle_log}
	guarding[actor["name"]] = true
	battle_log = "%s defends." % actor["name"]
	return _after_player_action()


func use_skill(skill_id: String) -> Dictionary:
	recent_events = []
	var actor := active_actor()
	if actor.is_empty():
		return {"status": "running", "log": battle_log}
	var target := _first_alive_enemy()
	if target.is_empty():
		return {"status": "running", "log": battle_log}
	var skill := _skill_data(skill_id)
	if skill.is_empty():
		battle_log = "Skill data is missing: %s." % skill_id
		return {"status": "running", "log": battle_log}
	var mp_cost := int(skill.get("mp_cost", 0))
	if int(actor.get("mp", 0)) < mp_cost:
		battle_log = "%s does not have enough MP." % actor.get("name", "Actor")
		return {"status": "running", "log": battle_log}

	guarding.erase(actor["name"])
	actor["mp"] = max(0, int(actor["mp"]) - mp_cost)
	var damage := _skill_damage(actor, skill)
	target["hp"] -= damage
	_add_damage_event("enemy", battle_enemies.find(target), damage)
	battle_log = "%s uses %s on %s for %d damage." % [
		actor["name"],
		skill.get("name", skill_id),
		target["name"],
		damage
	]
	return _after_player_action()


func use_healing_potion() -> Dictionary:
	recent_events = []
	var potion_count := int(state["inventory"].get("healing_potion", 0))
	if potion_count <= 0:
		battle_log = "No healing potions remain."
		return {"status": "running", "log": battle_log}
	var heal_hp := int(state.get("items", {}).get("healing_potion", {}).get("heal_hp", 20))
	var actor := active_actor()
	if actor.is_empty():
		return {"status": "running", "log": battle_log}
	guarding.erase(actor["name"])
	state["inventory"]["healing_potion"] = potion_count - 1
	actor["hp"] = min(int(actor["max_hp"]), int(actor["hp"]) + heal_hp)
	battle_log = "%s uses a healing potion and recovers to %d HP." % [actor["name"], actor["hp"]]
	return _after_player_action()


func is_battle_over() -> bool:
	return _all_enemies_defeated() or _all_party_defeated()


func skill_data(skill_id: String) -> Dictionary:
	return _skill_data(skill_id)


func potion_count() -> int:
	return int(state.get("inventory", {}).get("healing_potion", 0))


func potion_heal_hp() -> int:
	return int(state.get("items", {}).get("healing_potion", {}).get("heal_hp", 20))


func consume_pending_battle_result() -> Dictionary:
	var result: Dictionary = pending_battle_result
	pending_battle_result = {}
	return result


func action_order_preview() -> Array[Dictionary]:
	var simulated_queue: Array[Dictionary] = []
	for entry: Dictionary in action_queue:
		if not _is_action_entry_alive(entry):
			continue
		simulated_queue.append({
			"side": entry["side"],
			"index": entry["index"],
			"action_value": entry["action_value"],
			"delay": _action_delay(_entry_combatant(entry))
		})
	simulated_queue.sort_custom(_is_action_entry_before)

	var preview: Array[Dictionary] = []
	while preview.size() < MAX_ACTION_ORDER_PREVIEW and not simulated_queue.is_empty():
		simulated_queue.sort_custom(_is_action_entry_before)
		var entry: Dictionary = simulated_queue[0]
		var combatant: Dictionary = _entry_combatant(entry)
		if combatant.is_empty():
			simulated_queue.remove_at(0)
			continue
		preview.append({
			"name": combatant.get("name", "Actor"),
			"side": entry["side"],
			"action_value": int(entry["action_value"])
		})
		entry["action_value"] = int(entry["action_value"]) + int(entry["delay"])
	return preview


func _after_player_action() -> Dictionary:
	_fill_enemy_reinforcements()
	var result: Dictionary = _check_battle_result()
	if result["status"] != "running":
		return _with_recent_events(result)
	_advance_action_queue_after_current_actor()
	result = _check_battle_result()
	if result["status"] != "running":
		return _with_recent_events(result)
	result = _resolve_enemy_actions_until_player_ready()
	if result["status"] != "running":
		return _with_recent_events(result)
	return _with_recent_events({"status": "running", "log": battle_log})


func _resolve_enemy_actions_until_player_ready() -> Dictionary:
	var result: Dictionary = _check_battle_result()
	while result["status"] == "running" and active_actor_side == "enemy":
		_enemy_action()
		result = _check_battle_result()
		if result["status"] != "running":
			return result
		_advance_action_queue_after_current_actor()
		result = _check_battle_result()
	return result


func _enemy_action() -> void:
	var enemy: Dictionary = _active_enemy()
	if enemy.is_empty() or int(enemy["hp"]) <= 0:
		return
	var target_index := _first_living_party_index()
	if target_index < 0:
		return
	var target: Dictionary = battle_party[target_index]
	var damage: int = max(1, int(enemy["strength"]) + 2)
	if bool(guarding.get(target["name"], false)):
		damage = max(1, int(float(damage) / 2.0))
		guarding.erase(target["name"])
	target["hp"] -= damage
	_add_damage_event("party", target_index, damage)
	battle_log += "\n%s attacks %s for %d damage." % [enemy["name"], target["name"], damage]


func _check_battle_result() -> Dictionary:
	if _all_enemies_defeated():
		var summary := [battle_summary]
		summary.append_array(_award_battle_exp())
		battle_log += "\nVictory."
		return {
			"status": "victory",
			"log": battle_log,
			"rewards": battle_rewards,
			"summary": summary
		}
	if _all_party_defeated():
		var summary := ["Dungeon: the party was defeated and forced back to base."]
		battle_log += "\nDefeat. Exploration ends."
		return {"status": "defeat", "log": battle_log, "summary": summary}
	return {"status": "running", "log": battle_log}


func _add_damage_event(target_side: String, target_index: int, amount: int) -> void:
	if target_index < 0:
		return
	recent_events.append({
		"type": "damage",
		"target_side": target_side,
		"target_index": target_index,
		"amount": amount
	})


func _with_recent_events(result: Dictionary) -> Dictionary:
	result["events"] = recent_events.duplicate(true)
	return result


func _award_battle_exp() -> Array[String]:
	var summary: Array[String] = []
	var exp_reward := _battle_exp_reward()
	if exp_reward <= 0:
		return summary
	for character: Dictionary in battle_party:
		if not _is_character_alive(character):
			continue
		_prepare_character_growth_fields(character)
		character["exp"] = int(character["exp"]) + exp_reward
		summary.append("%s gains %d EXP." % [character["name"], exp_reward])
		while int(character["exp"]) >= int(character["next_exp"]):
			summary.append(_level_up_character(character))
	return summary


func _battle_exp_reward() -> int:
	return defeated_enemy_exp_reward


func _prepare_character_growth_fields(character: Dictionary) -> void:
	if not character.has("level"):
		character["level"] = 1
	if not character.has("exp"):
		character["exp"] = 0
	if not character.has("next_exp"):
		character["next_exp"] = 20
	if not character.has("max_hp"):
		character["max_hp"] = character["hp"]
	if not character.has("max_mp"):
		character["max_mp"] = character["mp"]


func _prepare_combatant_speed(combatant: Dictionary) -> void:
	if not combatant.has("speed"):
		combatant["speed"] = DEFAULT_SPEED
	combatant["speed"] = max(1, int(combatant["speed"]))


func _level_up_character(character: Dictionary) -> String:
	character["exp"] = int(character["exp"]) - int(character["next_exp"])
	character["level"] = int(character["level"]) + 1
	character["next_exp"] = 20 + (int(character["level"]) - 1) * 15
	character["max_hp"] = int(character["max_hp"]) + 6
	character["max_mp"] = int(character["max_mp"]) + 3
	character["strength"] = int(character["strength"]) + 1
	character["agility"] = int(character["agility"]) + 1
	character["intelligence"] = int(character["intelligence"]) + 1
	character["speed"] = int(character.get("speed", DEFAULT_SPEED)) + 2
	character["hp"] = int(character["max_hp"])
	character["mp"] = int(character["max_mp"])
	return "%s reaches Lv.%d and grows stronger." % [character["name"], character["level"]]


func _first_alive_enemy() -> Dictionary:
	for enemy: Dictionary in battle_enemies:
		if int(enemy["hp"]) > 0:
			return enemy
	return {}


func _first_alive_enemy_index() -> int:
	for index: int in range(battle_enemies.size()):
		if int(battle_enemies[index].get("hp", 0)) > 0:
			return index
	return -1


func _alive_enemy_at_index(index: int) -> Dictionary:
	if index < 0 or index >= battle_enemies.size():
		return {}
	var enemy: Dictionary = battle_enemies[index]
	if int(enemy.get("hp", 0)) <= 0:
		return {}
	return enemy


func _is_character_alive(character: Dictionary) -> bool:
	return int(character.get("hp", 0)) > 0


func _next_living_party_index(start_index: int) -> int:
	for offset: int in range(battle_party.size()):
		var index := (start_index + offset) % battle_party.size()
		if _is_character_alive(battle_party[index]):
			return index
	return 0


func _first_living_party_index() -> int:
	for index: int in range(battle_party.size()):
		if _is_character_alive(battle_party[index]):
			return index
	return -1


func _active_enemy() -> Dictionary:
	if active_actor_side != "enemy" or active_actor_index < 0 or active_actor_index >= battle_enemies.size():
		return {}
	return battle_enemies[active_actor_index]


func _all_enemies_defeated() -> bool:
	if not enemy_reserves.is_empty():
		return false
	for enemy: Dictionary in battle_enemies:
		if int(enemy["hp"]) > 0:
			return false
	return true


func _all_party_defeated() -> bool:
	for character: Dictionary in battle_party:
		if _is_character_alive(character):
			return false
	return true


func _reset_action_queue() -> void:
	action_queue = []
	for index: int in range(battle_party.size()):
		if _is_character_alive(battle_party[index]):
			action_queue.append(_make_action_entry("party", index, _action_delay(battle_party[index])))
	for index: int in range(battle_enemies.size()):
		if int(battle_enemies[index].get("hp", 0)) > 0:
			action_queue.append(_make_action_entry("enemy", index, _action_delay(battle_enemies[index])))
	_sort_action_queue()
	_sync_active_actor_from_queue()


func _make_action_entry(side: String, index: int, action_value: int) -> Dictionary:
	return {
		"side": side,
		"index": index,
		"action_value": max(0, action_value)
	}


func _advance_action_queue_after_current_actor() -> void:
	if action_queue.is_empty():
		return
	var current_entry: Dictionary = action_queue[0]
	var elapsed := int(current_entry["action_value"])
	for entry: Dictionary in action_queue:
		entry["action_value"] = max(0, int(entry["action_value"]) - elapsed)

	if _is_action_entry_alive(current_entry):
		current_entry["action_value"] = int(current_entry["action_value"]) + _action_delay(_entry_combatant(current_entry))

	_prune_action_queue()
	_sort_action_queue()
	_sync_active_actor_from_queue()


func _prune_action_queue() -> void:
	var living_entries: Array[Dictionary] = []
	for entry: Dictionary in action_queue:
		if _is_action_entry_alive(entry):
			living_entries.append(entry)
	action_queue = living_entries


func _fill_enemy_reinforcements() -> void:
	var changed := false
	for index: int in range(battle_enemies.size()):
		var enemy: Dictionary = battle_enemies[index]
		if enemy.is_empty() or int(enemy.get("hp", 0)) > 0:
			continue
		_record_defeated_enemy(enemy)
		_remove_action_entries("enemy", index)
		if enemy_reserves.is_empty():
			continue
		var replacement: Dictionary = enemy_reserves.pop_front()
		_prepare_combatant_speed(replacement)
		battle_enemies[index] = replacement
		action_queue.append(_make_action_entry("enemy", index, _action_delay(replacement)))
		battle_log += "\n%s steps in as reinforcement." % replacement.get("name", "Enemy")
		changed = true
	if changed:
		_sort_action_queue()
		_sync_active_actor_from_queue()


func _record_defeated_enemy(enemy: Dictionary) -> void:
	if bool(enemy.get("_defeat_recorded", false)):
		return
	defeated_enemy_exp_reward += int(enemy.get("exp", 0))
	enemy["_defeat_recorded"] = true


func _remove_action_entries(side: String, index: int) -> void:
	var kept_entries: Array[Dictionary] = []
	for entry: Dictionary in action_queue:
		if String(entry.get("side", "")) == side and int(entry.get("index", -1)) == index:
			continue
		kept_entries.append(entry)
	action_queue = kept_entries


func _sort_action_queue() -> void:
	action_queue.sort_custom(_is_action_entry_before)


func _sync_active_actor_from_queue() -> void:
	_prune_action_queue()
	if action_queue.is_empty():
		active_actor_side = "party"
		active_actor_index = 0
		return
	_sort_action_queue()
	var entry: Dictionary = action_queue[0]
	active_actor_side = String(entry["side"])
	active_actor_index = int(entry["index"])


func _is_action_entry_before(left: Dictionary, right: Dictionary) -> bool:
	var left_value := int(left["action_value"])
	var right_value := int(right["action_value"])
	if left_value != right_value:
		return left_value < right_value
	var left_priority := _action_side_priority(String(left["side"]))
	var right_priority := _action_side_priority(String(right["side"]))
	if left_priority != right_priority:
		return left_priority < right_priority
	return int(left["index"]) < int(right["index"])


func _action_side_priority(side: String) -> int:
	return 0 if side == "party" else 1


func _action_delay(combatant: Dictionary) -> int:
	var speed: int = max(1, int(combatant.get("speed", DEFAULT_SPEED)))
	return max(1, int(float(ACTION_VALUE_BASE) / float(speed)))


func _is_action_entry_alive(entry: Dictionary) -> bool:
	if String(entry.get("side", "")) == "party":
		var party_index := int(entry.get("index", -1))
		return party_index >= 0 and party_index < battle_party.size() and _is_character_alive(battle_party[party_index])
	if String(entry.get("side", "")) == "enemy":
		var enemy_index := int(entry.get("index", -1))
		return enemy_index >= 0 and enemy_index < battle_enemies.size() and int(battle_enemies[enemy_index].get("hp", 0)) > 0
	return false


func _entry_combatant(entry: Dictionary) -> Dictionary:
	if String(entry.get("side", "")) == "party":
		var party_index := int(entry.get("index", -1))
		if party_index >= 0 and party_index < battle_party.size():
			return battle_party[party_index]
	if String(entry.get("side", "")) == "enemy":
		var enemy_index := int(entry.get("index", -1))
		if enemy_index >= 0 and enemy_index < battle_enemies.size():
			return battle_enemies[enemy_index]
	return {}


func _skill_data(skill_id: String) -> Dictionary:
	return state.get("skills", {}).get(skill_id, {})


func _skill_damage(actor: Dictionary, skill: Dictionary) -> int:
	var stat_id := String(skill.get("scaling_stat", "intelligence"))
	var stat_value := int(actor.get(stat_id, 0))
	var base_damage := int(skill.get("base_damage", 0))
	var power := int(skill.get("power", 1))
	return max(1, base_damage + stat_value * power)


func _load_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	push_error("Failed to load JSON config: %s" % path)
	return {}
