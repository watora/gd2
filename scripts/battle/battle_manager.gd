class_name BattleManager
extends Node

const ENEMIES_CONFIG := "res://data/config/enemies.json"

var state: Dictionary = {}
var enemy_config: Dictionary = {}
var battle_rewards: Dictionary = {}
var battle_summary := ""
var battle_party: Array[Dictionary] = []
var battle_enemies: Array[Dictionary] = []
var active_actor_index := 0
var guarding: Dictionary = {}
var battle_log := ""


func start_battle(new_state: Dictionary, battle_result: Dictionary) -> void:
	state = new_state
	enemy_config = _load_json(ENEMIES_CONFIG).get("enemies", {})
	battle_rewards = battle_result.get("battle_rewards", {})
	battle_summary = battle_result.get("battle_summary", "Dungeon: won a battle.")
	battle_party = []
	battle_enemies = []
	guarding = {}
	active_actor_index = 0

	for character: Dictionary in state["characters"]:
		_prepare_character_growth_fields(character)
		battle_party.append(character)

	var enemy_ids: Array = battle_result.get("battle", {}).get("enemies", [])
	for enemy_id: String in enemy_ids:
		if enemy_config.has(enemy_id):
			battle_enemies.append(enemy_config[enemy_id].duplicate(true))

	battle_log = battle_result.get("body", "Enemies block the path.")


func active_actor() -> Dictionary:
	if battle_party.is_empty():
		return {}
	return battle_party[active_actor_index]


func active_actor_ready() -> bool:
	return _is_character_alive(active_actor()) and not is_battle_over()


func active_actor_skill_ids() -> Array:
	return active_actor().get("skills", [])


func attack() -> Dictionary:
	var actor := active_actor()
	var target := _first_alive_enemy()
	if target.is_empty():
		return {"status": "running", "log": battle_log}
	var damage: int = max(1, int(actor["strength"]) + 3)
	target["hp"] -= damage
	battle_log = "%s attacks %s for %d damage." % [actor["name"], target["name"], damage]
	return _after_player_action()


func defend() -> Dictionary:
	var actor := active_actor()
	guarding[actor["name"]] = true
	battle_log = "%s defends." % actor["name"]
	return _after_player_action()


func use_skill(skill_id: String) -> Dictionary:
	var actor := active_actor()
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

	actor["mp"] = max(0, int(actor["mp"]) - mp_cost)
	var damage := _skill_damage(actor, skill)
	target["hp"] -= damage
	battle_log = "%s uses %s on %s for %d damage." % [
		actor["name"],
		skill.get("name", skill_id),
		target["name"],
		damage
	]
	return _after_player_action()


func use_healing_potion() -> Dictionary:
	var potion_count := int(state["inventory"].get("healing_potion", 0))
	if potion_count <= 0:
		battle_log = "No healing potions remain."
		return {"status": "running", "log": battle_log}
	var heal_hp := int(state.get("items", {}).get("healing_potion", {}).get("heal_hp", 20))
	var actor := active_actor()
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


func _after_player_action() -> Dictionary:
	var result := _check_battle_result()
	if result["status"] != "running":
		return result
	active_actor_index = _next_living_party_index(active_actor_index + 1)
	if active_actor_index == 0:
		_enemy_turn()
		result = _check_battle_result()
		if result["status"] != "running":
			return result
		active_actor_index = _next_living_party_index(0)
	return {"status": "running", "log": battle_log}


func _enemy_turn() -> void:
	var logs: Array[String] = []
	for enemy: Dictionary in battle_enemies:
		if int(enemy["hp"]) <= 0:
			continue
		var target_index := _first_living_party_index()
		if target_index < 0:
			break
		var target: Dictionary = battle_party[target_index]
		var damage: int = max(1, int(enemy["strength"]) + 2)
		if bool(guarding.get(target["name"], false)):
			damage = max(1, int(float(damage) / 2.0))
		target["hp"] -= damage
		logs.append("%s attacks %s for %d damage." % [enemy["name"], target["name"], damage])
	guarding.clear()
	if not logs.is_empty():
		battle_log += "\n" + "\n".join(logs)


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
	var total := 0
	for enemy: Dictionary in battle_enemies:
		total += int(enemy.get("exp", 0))
	return total


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


func _level_up_character(character: Dictionary) -> String:
	character["exp"] = int(character["exp"]) - int(character["next_exp"])
	character["level"] = int(character["level"]) + 1
	character["next_exp"] = 20 + (int(character["level"]) - 1) * 15
	character["max_hp"] = int(character["max_hp"]) + 6
	character["max_mp"] = int(character["max_mp"]) + 3
	character["strength"] = int(character["strength"]) + 1
	character["agility"] = int(character["agility"]) + 1
	character["intelligence"] = int(character["intelligence"]) + 1
	character["hp"] = int(character["max_hp"])
	character["mp"] = int(character["max_mp"])
	return "%s reaches Lv.%d and grows stronger." % [character["name"], character["level"]]


func _first_alive_enemy() -> Dictionary:
	for enemy: Dictionary in battle_enemies:
		if int(enemy["hp"]) > 0:
			return enemy
	return {}


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


func _all_enemies_defeated() -> bool:
	for enemy: Dictionary in battle_enemies:
		if int(enemy["hp"]) > 0:
			return false
	return true


func _all_party_defeated() -> bool:
	for character: Dictionary in battle_party:
		if _is_character_alive(character):
			return false
	return true


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
