class_name DungeonScreen
extends Control

signal run_finished(rewards: Dictionary, flags: Dictionary, summary: Array[String])

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
var event_config: Dictionary = {}
var enemy_config: Dictionary = {}
var run_rewards: Dictionary = {"gold": 0}
var run_flags: Dictionary = {}
var run_summary: Array[String] = []
var resolved_events: Dictionary = {}
var current_choices: Array = []

var battle_rewards: Dictionary = {}
var battle_summary := ""
var battle_party: Array[Dictionary] = []
var battle_enemies: Array[Dictionary] = []
var active_actor_index := 0
var guarding: Dictionary = {}

@onready var _map_layer: Control = %MapLayer
@onready var _reward_label: Label = %RewardLabel
@onready var _finish_button: Button = %FinishButton
@onready var _event_panel: PanelContainer = %EventPanel
@onready var _event_title: Label = %EventTitle
@onready var _event_body: Label = %EventBody
@onready var _battle_layer: PanelContainer = %BattleLayer
@onready var _battle_log: Label = %BattleLog
@onready var _choice_button_0: Button = %ChoiceButton0
@onready var _choice_button_1: Button = %ChoiceButton1
@onready var _choice_button_2: Button = %ChoiceButton2
@onready var _choice_button_3: Button = %ChoiceButton3
@onready var _choice_button_4: Button = %ChoiceButton4
@onready var _attack_button: Button = %AttackButton
@onready var _skill_button: Button = %SkillButton
@onready var _defend_button: Button = %DefendButton
@onready var _item_button: Button = %ItemButton
@onready var _item_panel: VBoxContainer = %ItemPanel
@onready var _potion_button: Button = %PotionButton
@onready var _potion_hint: Label = %PotionHint

var _choice_buttons: Array[Button] = []
var _party_labels: Array[Label] = []
var _enemy_labels: Array[Label] = []


func setup(new_state: Dictionary) -> void:
	state = new_state
	_initialize_run_rewards()
	if is_inside_tree():
		_update_reward_label()


func _ready() -> void:
	event_config = _load_json(EVENTS_CONFIG).get("events", {})
	enemy_config = _load_json(ENEMIES_CONFIG).get("enemies", {})
	_cache_scene_nodes()
	_event_panel.visible = false
	_battle_layer.visible = false
	_item_panel.visible = false
	_set_battle_buttons_enabled(false)
	_update_reward_label()


func _cache_scene_nodes() -> void:
	_choice_buttons = [
		_choice_button_0,
		_choice_button_1,
		_choice_button_2,
		_choice_button_3,
		_choice_button_4
	]
	_party_labels = [%PartyLabel0, %PartyLabel1]
	_enemy_labels = [%EnemyLabel0, %EnemyLabel1, %EnemyLabel2]


func _initialize_run_rewards() -> void:
	run_rewards = {"gold": 0}
	for item_id: String in state.get("inventory", {}):
		run_rewards[item_id] = 0


func _on_sunken_well_button_pressed() -> void:
	_open_event("sunken_well")


func _on_collapsed_mine_button_pressed() -> void:
	_open_event("collapsed_mine")


func _on_sealed_gate_button_pressed() -> void:
	_open_event("sealed_gate")


func _on_shadow_patrol_button_pressed() -> void:
	_open_event("shadow_patrol")


func _on_old_shrine_button_pressed() -> void:
	_open_event("old_shrine")


func _on_finish_button_pressed() -> void:
	_finish_run()


func _on_choice_button_0_pressed() -> void:
	_resolve_choice_index(0)


func _on_choice_button_1_pressed() -> void:
	_resolve_choice_index(1)


func _on_choice_button_2_pressed() -> void:
	_resolve_choice_index(2)


func _on_choice_button_3_pressed() -> void:
	_resolve_choice_index(3)


func _on_choice_button_4_pressed() -> void:
	_resolve_choice_index(4)


func _on_attack_button_pressed() -> void:
	_battle_attack()


func _on_skill_button_pressed() -> void:
	_battle_skill()


func _on_defend_button_pressed() -> void:
	_battle_defend()


func _on_item_button_pressed() -> void:
	_show_battle_items()


func _on_potion_button_pressed() -> void:
	_use_healing_potion()


func _open_event(event_id: String) -> void:
	var event_data: Dictionary = event_config[event_id]
	if resolved_events.has(event_id):
		_event_title.text = "Already searched"
		_event_body.text = event_data.get("resolved_body", "There are no new clues here.")
		_set_choices([{"text": "Close", "method": "_close_event"}])
		_event_panel.visible = true
		return

	_event_title.text = event_data["title"]
	_event_body.text = event_data["body"]
	var choices: Array = []
	for choice: Dictionary in event_data.get("choices", []):
		var prepared_choice := choice.duplicate(true)
		prepared_choice["event_id"] = event_id
		choices.append(prepared_choice)
	_set_choices(choices)
	_event_panel.visible = true


func _set_choices(choices: Array) -> void:
	current_choices = choices
	for index: int in range(_choice_buttons.size()):
		var button := _choice_buttons[index]
		if index >= choices.size():
			button.visible = false
			button.disabled = true
			button.text = ""
			continue
		var choice: Dictionary = choices[index]
		var requirements: Dictionary = choice.get("requirements", {})
		button.visible = true
		button.text = choice["text"] + _requirements_text(requirements)
		button.disabled = not _meets_requirements(requirements)


func _resolve_choice_index(index: int) -> void:
	if index < 0 or index >= current_choices.size():
		return
	_resolve_choice(current_choices[index])


func _resolve_choice(choice: Dictionary) -> void:
	if choice.has("method"):
		call(choice["method"])
		return

	var requirements: Dictionary = choice.get("requirements", {})
	if not _meets_requirements(requirements):
		_event_body.text = "The party does not meet this requirement."
		return

	if choice.has("battle"):
		resolved_events[choice["event_id"]] = true
		_start_battle(choice)
		return

	resolved_events[choice["event_id"]] = true
	if choice.has("rewards"):
		_add_run_rewards(choice["rewards"])
	if choice.has("flags"):
		for flag_name: String in choice["flags"]:
			run_flags[flag_name] = choice["flags"][flag_name]
	if choice.has("summary"):
		run_summary.append(choice["summary"])
	_event_title.text = "Investigation complete"
	_event_body.text = choice.get("result", "The party records this change.")
	_set_choices([{"text": "Continue exploring", "method": "_close_event"}])
	_update_reward_label()


func _meets_requirements(requirements: Dictionary) -> bool:
	if requirements.is_empty():
		return true
	for stat_id: String in requirements:
		if _best_party_stat(stat_id) < int(requirements[stat_id]):
			return false
	return true


func _best_party_stat(stat_id: String) -> int:
	var best_value := 0
	for character: Dictionary in state.get("characters", []):
		best_value = max(best_value, int(character.get(stat_id, 0)))
	return best_value


func _requirements_text(requirements: Dictionary) -> String:
	if requirements.is_empty():
		return ""
	var parts: Array[String] = []
	for stat_id: String in requirements:
		parts.append("%s %d" % [STAT_NAMES.get(stat_id, stat_id), int(requirements[stat_id])])
	return "  [Need %s]" % " / ".join(parts)


func _start_battle(choice: Dictionary) -> void:
	_event_panel.visible = false
	_map_layer.visible = false
	_battle_layer.visible = true
	_finish_button.disabled = true
	_item_panel.visible = false
	battle_rewards = choice.get("rewards", {})
	battle_summary = choice.get("summary", "Dungeon: won a battle.")
	battle_party = []
	battle_enemies = []
	guarding = {}
	active_actor_index = 0

	for character: Dictionary in state["characters"]:
		_prepare_character_growth_fields(character)
		battle_party.append(character)

	var enemy_ids: Array = choice.get("battle", {}).get("enemies", [])
	for enemy_id: String in enemy_ids:
		if enemy_config.has(enemy_id):
			battle_enemies.append(enemy_config[enemy_id].duplicate(true))

	_battle_log.text = choice.get("result", "Enemies block the path.")
	_refresh_battle()


func _refresh_battle() -> void:
	for index: int in range(_party_labels.size()):
		var label := _party_labels[index]
		if index >= battle_party.size():
			label.text = ""
			continue
		var character: Dictionary = battle_party[index]
		label.text = "%s%s\nHP %d/%d  MP %d/%d\nSTR %d  AGI %d  INT %d" % [
			"> " if index == active_actor_index and _is_character_alive(character) else "",
			character["name"],
			max(0, int(character["hp"])),
			int(character["max_hp"]),
			max(0, int(character["mp"])),
			int(character["max_mp"]),
			int(character["strength"]),
			int(character["agility"]),
			int(character["intelligence"])
		]

	for index: int in range(_enemy_labels.size()):
		var label := _enemy_labels[index]
		if index >= battle_enemies.size():
			label.text = ""
			continue
		var enemy: Dictionary = battle_enemies[index]
		label.text = "%s\nHP %d/%d" % [enemy["name"], max(0, int(enemy["hp"])), int(enemy["max_hp"])]

	if _is_battle_over():
		_set_battle_buttons_enabled(false)
		return

	var actor: Dictionary = _active_actor()
	var actor_ready := _is_character_alive(actor)
	_attack_button.disabled = not actor_ready
	_skill_button.disabled = not (actor_ready and int(actor["mp"]) >= 5)
	_defend_button.disabled = not actor_ready
	_item_button.disabled = not actor_ready


func _set_battle_buttons_enabled(enabled: bool) -> void:
	_attack_button.disabled = not enabled
	_skill_button.disabled = not enabled
	_defend_button.disabled = not enabled
	_item_button.disabled = not enabled


func _battle_attack() -> void:
	var actor: Dictionary = _active_actor()
	var target: Dictionary = _first_alive_enemy()
	if target.is_empty():
		return
	var damage: int = max(1, int(actor["strength"]) + 3)
	target["hp"] -= damage
	_battle_log.text = "%s attacks %s for %d damage." % [actor["name"], target["name"], damage]
	_after_player_action()


func _battle_skill() -> void:
	var actor: Dictionary = _active_actor()
	var target: Dictionary = _first_alive_enemy()
	if target.is_empty():
		return
	actor["mp"] = max(0, int(actor["mp"]) - 5)
	var damage: int = max(2, int(actor["intelligence"]) * 2)
	target["hp"] -= damage
	_battle_log.text = "%s casts a skill on %s for %d damage." % [actor["name"], target["name"], damage]
	_after_player_action()


func _battle_defend() -> void:
	var actor: Dictionary = _active_actor()
	guarding[actor["name"]] = true
	_battle_log.text = "%s defends." % actor["name"]
	_after_player_action()


func _show_battle_items() -> void:
	var potion_count := int(state["inventory"].get("healing_potion", 0))
	var heal_hp := int(state.get("items", {}).get("healing_potion", {}).get("heal_hp", 20))
	_potion_button.text = "Use Healing Potion x%d" % potion_count
	_potion_button.disabled = potion_count <= 0
	_potion_hint.text = "Healing Potion: restore %d HP to the active character." % heal_hp
	_item_panel.visible = true


func _use_healing_potion() -> void:
	var potion_count := int(state["inventory"].get("healing_potion", 0))
	if potion_count <= 0:
		_battle_log.text = "No healing potions remain."
		return
	var heal_hp := int(state.get("items", {}).get("healing_potion", {}).get("heal_hp", 20))
	var actor: Dictionary = _active_actor()
	state["inventory"]["healing_potion"] = potion_count - 1
	actor["hp"] = min(int(actor["max_hp"]), int(actor["hp"]) + heal_hp)
	_battle_log.text = "%s uses a healing potion and recovers to %d HP." % [actor["name"], actor["hp"]]
	_item_panel.visible = false
	_after_player_action()


func _after_player_action() -> void:
	if _check_battle_result():
		return
	active_actor_index = _next_living_party_index(active_actor_index + 1)
	if active_actor_index == 0:
		_enemy_turn()
		if _check_battle_result():
			return
		active_actor_index = _next_living_party_index(0)
	_item_panel.visible = false
	_refresh_battle()


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
		_battle_log.text += "\n" + "\n".join(logs)


func _check_battle_result() -> bool:
	if _all_enemies_defeated():
		_add_run_rewards(battle_rewards)
		run_summary.append(battle_summary)
		_award_battle_exp()
		_battle_log.text += "\nVictory."
		_end_battle()
		return true
	if _all_party_defeated():
		run_summary.append("Dungeon: the party was defeated and forced back to base.")
		_battle_log.text += "\nDefeat. Exploration ends."
		_finish_run()
		return true
	return false


func _end_battle() -> void:
	_battle_layer.visible = false
	_map_layer.visible = true
	_finish_button.disabled = false
	_update_reward_label()


func _is_battle_over() -> bool:
	return _all_enemies_defeated() or _all_party_defeated()


func _active_actor() -> Dictionary:
	if battle_party.is_empty():
		return {}
	return battle_party[active_actor_index]


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


func _award_battle_exp() -> void:
	var exp_reward := _battle_exp_reward()
	if exp_reward <= 0:
		return
	for character: Dictionary in battle_party:
		if not _is_character_alive(character):
			continue
		_prepare_character_growth_fields(character)
		character["exp"] = int(character["exp"]) + exp_reward
		run_summary.append("%s gains %d EXP." % [character["name"], exp_reward])
		while int(character["exp"]) >= int(character["next_exp"]):
			_level_up_character(character)


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


func _level_up_character(character: Dictionary) -> void:
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
	run_summary.append("%s reaches Lv.%d and grows stronger." % [character["name"], character["level"]])


func _add_run_rewards(rewards: Dictionary) -> void:
	for reward_id: String in rewards:
		run_rewards[reward_id] = int(run_rewards.get(reward_id, 0)) + int(rewards[reward_id])


func _update_reward_label() -> void:
	if _reward_label == null:
		return
	var parts: Array[String] = []
	if int(run_rewards.get("gold", 0)) > 0:
		parts.append("Gold x%d" % run_rewards["gold"])
	for item_id: String in state.get("inventory", {}):
		if int(run_rewards.get(item_id, 0)) > 0:
			parts.append("%s x%d" % [_item_name(item_id), run_rewards.get(item_id, 0)])
	_reward_label.text = "Run rewards: " + ("None" if parts.is_empty() else ", ".join(parts))


func _finish_run() -> void:
	if run_summary.is_empty():
		run_summary.append("Dungeon: the party withdrew carefully without new findings.")
	run_finished.emit(run_rewards, run_flags, run_summary)


func _close_event() -> void:
	_event_panel.visible = false


func _item_name(item_id: String) -> String:
	return state.get("items", {}).get(item_id, {}).get("name", item_id)


func _load_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	push_error("Failed to load JSON config: %s" % path)
	return {}
