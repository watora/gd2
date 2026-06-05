class_name DungeonScreen
extends Control

signal run_finished(rewards: Dictionary, flags: Dictionary, summary: Array[String])

var state: Dictionary = {}
var current_choices: Array = []

var battle_rewards: Dictionary = {}
var battle_summary := ""
var battle_party: Array[Dictionary] = []
var battle_enemies: Array[Dictionary] = []
var active_actor_index := 0
var guarding: Dictionary = {}

@onready var _map_layer: Control = %MapLayer
@onready var _title_label: Label = %TitleLabel
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
@onready var _skill_panel: PanelContainer = %SkillPanel
@onready var _skill_choice_button_0: Button = %SkillChoiceButton0
@onready var _skill_choice_button_1: Button = %SkillChoiceButton1
@onready var _skill_choice_button_2: Button = %SkillChoiceButton2
@onready var _skill_choice_button_3: Button = %SkillChoiceButton3
@onready var _skill_hint: Label = %SkillHint
@onready var _item_panel: PanelContainer = %ItemPanel
@onready var _potion_button: Button = %PotionButton
@onready var _potion_hint: Label = %PotionHint

var _choice_buttons: Array[Button] = []
var _skill_choice_buttons: Array[Button] = []
var _party_labels: Array[Label] = []
var _enemy_labels: Array[Label] = []
var _event_buttons: Dictionary = {}
var _map_textures: Dictionary = {}
var _map_image: TextureRect
var _manager := DungeonManager.new()


func setup(new_state: Dictionary) -> void:
	state = new_state
	_manager.start_run(state)
	if is_inside_tree():
		_apply_current_map()
		_update_reward_label()


func _ready() -> void:
	_manager.name = "DungeonManager"
	add_child(_manager)
	_cache_scene_nodes()
	_event_panel.visible = false
	_battle_layer.visible = false
	_skill_panel.visible = false
	_item_panel.visible = false
	_set_battle_buttons_enabled(false)
	if not state.is_empty():
		_apply_current_map()
		_update_reward_label()


func _cache_scene_nodes() -> void:
	_choice_buttons = [
		_choice_button_0,
		_choice_button_1,
		_choice_button_2,
		_choice_button_3,
		_choice_button_4
	]
	_skill_choice_buttons = [
		_skill_choice_button_0,
		_skill_choice_button_1,
		_skill_choice_button_2,
		_skill_choice_button_3
	]
	_party_labels = [%PartyLabel0, %PartyLabel1]
	_enemy_labels = [%EnemyLabel0, %EnemyLabel1, %EnemyLabel2]
	_map_image = %MapImage


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
	_show_battle_skills()


func _on_defend_button_pressed() -> void:
	_battle_defend()


func _on_item_button_pressed() -> void:
	_show_battle_items()


func _on_potion_button_pressed() -> void:
	_use_healing_potion()


func _on_skill_choice_button_0_pressed() -> void:
	_use_skill_index(0)


func _on_skill_choice_button_1_pressed() -> void:
	_use_skill_index(1)


func _on_skill_choice_button_2_pressed() -> void:
	_use_skill_index(2)


func _on_skill_choice_button_3_pressed() -> void:
	_use_skill_index(3)


func _apply_current_map() -> void:
	var map_data := _manager.current_map()
	if map_data.is_empty():
		return

	_title_label.text = map_data.get("title", "Dungeon Map")
	_map_image.texture = _map_texture(map_data)
	_rebuild_event_buttons(_manager.current_event_points())


func _rebuild_event_buttons(event_points: Array) -> void:
	for button: Button in _event_buttons.values():
		button.queue_free()
	_event_buttons.clear()

	for point: Dictionary in event_points:
		var event_id := String(point.get("event_id", ""))
		if event_id == "" or not _manager.has_event(event_id):
			continue
		var event_data := _manager.event_data(event_id)
		var button := Button.new()
		button.name = "%s_button" % event_id
		button.text = point.get("text", event_data.get("title", event_id))
		button.position = _vector2_from_config(point.get("position", [0, 0]))
		button.size = _vector2_from_config(point.get("size", [140, 42]))
		button.pressed.connect(_on_event_button_pressed.bind(event_id))
		_map_layer.add_child(button)
		_event_buttons[event_id] = button


func _on_event_button_pressed(event_id: String) -> void:
	_open_event(event_id)


func _open_event(event_id: String) -> void:
	if not _manager.has_event(event_id):
		return
	var event_data := _manager.event_data(event_id)
	if not _manager.is_event_repeatable(event_id) and _manager.is_event_resolved(event_id):
		_event_title.text = "Already searched"
		_event_body.text = event_data.get("resolved_body", "There are no new clues here.")
		_set_choices([{"text": "Close", "method": "_close_event"}])
		_event_panel.visible = true
		return

	_event_title.text = event_data["title"]
	_event_body.text = event_data["body"]
	_set_choices(_manager.choices_for_event(event_id))
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
		button.text = choice["text"] + _manager.requirements_text(requirements)
		button.disabled = not _manager.meets_requirements(requirements)


func _resolve_choice_index(index: int) -> void:
	if index < 0 or index >= current_choices.size():
		return
	_resolve_choice(current_choices[index])


func _resolve_choice(choice: Dictionary) -> void:
	if choice.has("method"):
		call(choice["method"])
		return

	var result := _manager.resolve_choice(choice)
	if not bool(result.get("ok", false)):
		_event_body.text = result.get("message", "The party cannot resolve this event.")
		return

	if result.has("battle"):
		_start_battle(result)
		return

	if bool(result.get("traveled", false)):
		_event_panel.visible = false
		_apply_current_map()
		_update_reward_label()
		return

	_event_title.text = result.get("title", "Investigation complete")
	_event_body.text = result.get("body", "The party records this change.")
	_set_choices([{"text": "Continue exploring", "method": "_close_event"}])
	_update_reward_label()


func _start_battle(battle_result: Dictionary) -> void:
	_event_panel.visible = false
	_map_layer.visible = false
	_battle_layer.visible = true
	_finish_button.disabled = true
	_skill_panel.visible = false
	_item_panel.visible = false
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
		var enemy := _manager.enemy_data(enemy_id)
		if not enemy.is_empty():
			battle_enemies.append(enemy)

	_battle_log.text = battle_result.get("body", "Enemies block the path.")
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
	_skill_button.disabled = not (actor_ready and not _character_skill_ids(actor).is_empty())
	_defend_button.disabled = not actor_ready
	_item_button.disabled = not actor_ready


func _set_battle_buttons_enabled(enabled: bool) -> void:
	_attack_button.disabled = not enabled
	_skill_button.disabled = not enabled
	_defend_button.disabled = not enabled
	_item_button.disabled = not enabled


func _battle_attack() -> void:
	_hide_command_subpanels()
	var actor: Dictionary = _active_actor()
	var target: Dictionary = _first_alive_enemy()
	if target.is_empty():
		return
	var damage: int = max(1, int(actor["strength"]) + 3)
	target["hp"] -= damage
	_battle_log.text = "%s attacks %s for %d damage." % [actor["name"], target["name"], damage]
	_after_player_action()


func _battle_defend() -> void:
	_hide_command_subpanels()
	var actor: Dictionary = _active_actor()
	guarding[actor["name"]] = true
	_battle_log.text = "%s defends." % actor["name"]
	_after_player_action()


func _show_battle_skills() -> void:
	var actor: Dictionary = _active_actor()
	var skill_ids := _character_skill_ids(actor)
	_item_panel.visible = false
	for index: int in range(_skill_choice_buttons.size()):
		var button := _skill_choice_buttons[index]
		if index >= skill_ids.size():
			button.visible = false
			button.disabled = true
			button.text = ""
			continue
		var skill_id := String(skill_ids[index])
		var skill := _skill_data(skill_id)
		var mp_cost := int(skill.get("mp_cost", 0))
		button.visible = true
		button.text = "%s  MP %d" % [skill.get("name", skill_id), mp_cost]
		button.disabled = int(actor.get("mp", 0)) < mp_cost
	_skill_hint.text = "Choose a skill for %s." % actor.get("name", "the active character")
	_skill_panel.visible = true


func _use_skill_index(index: int) -> void:
	var actor: Dictionary = _active_actor()
	var skill_ids := _character_skill_ids(actor)
	if index < 0 or index >= skill_ids.size():
		return
	_use_skill(String(skill_ids[index]))


func _use_skill(skill_id: String) -> void:
	var actor: Dictionary = _active_actor()
	var target: Dictionary = _first_alive_enemy()
	if target.is_empty():
		return
	var skill := _skill_data(skill_id)
	if skill.is_empty():
		_battle_log.text = "Skill data is missing: %s." % skill_id
		return
	var mp_cost := int(skill.get("mp_cost", 0))
	if int(actor.get("mp", 0)) < mp_cost:
		_battle_log.text = "%s does not have enough MP." % actor.get("name", "Actor")
		return

	actor["mp"] = max(0, int(actor["mp"]) - mp_cost)
	var damage := _skill_damage(actor, skill)
	target["hp"] -= damage
	_battle_log.text = "%s uses %s on %s for %d damage." % [
		actor["name"],
		skill.get("name", skill_id),
		target["name"],
		damage
	]
	_hide_command_subpanels()
	_after_player_action()


func _show_battle_items() -> void:
	_skill_panel.visible = false
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
	_hide_command_subpanels()
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
	_hide_command_subpanels()
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
		_manager.add_run_rewards(battle_rewards)
		_manager.append_summary(battle_summary)
		_award_battle_exp()
		_battle_log.text += "\nVictory."
		_end_battle()
		return true
	if _all_party_defeated():
		_manager.append_summary("Dungeon: the party was defeated and forced back to base.")
		_battle_log.text += "\nDefeat. Exploration ends."
		_finish_run()
		return true
	return false


func _end_battle() -> void:
	_battle_layer.visible = false
	_map_layer.visible = true
	_finish_button.disabled = false
	_hide_command_subpanels()
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


func _character_skill_ids(character: Dictionary) -> Array:
	return character.get("skills", [])


func _skill_data(skill_id: String) -> Dictionary:
	return state.get("skills", {}).get(skill_id, {})


func _skill_damage(actor: Dictionary, skill: Dictionary) -> int:
	var stat_id := String(skill.get("scaling_stat", "intelligence"))
	var stat_value := int(actor.get(stat_id, 0))
	var base_damage := int(skill.get("base_damage", 0))
	var power := int(skill.get("power", 1))
	return max(1, base_damage + stat_value * power)


func _hide_command_subpanels() -> void:
	_skill_panel.visible = false
	_item_panel.visible = false


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
		_manager.append_summary("%s gains %d EXP." % [character["name"], exp_reward])
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
	_manager.append_summary("%s reaches Lv.%d and grows stronger." % [character["name"], character["level"]])


func _update_reward_label() -> void:
	if _reward_label == null:
		return
	var parts: Array[String] = []
	if int(_manager.run_rewards.get("gold", 0)) > 0:
		parts.append("Gold x%d" % _manager.run_rewards["gold"])
	for item_id: String in state.get("inventory", {}):
		if int(_manager.run_rewards.get(item_id, 0)) > 0:
			parts.append("%s x%d" % [_item_name(item_id), _manager.run_rewards.get(item_id, 0)])
	_reward_label.text = "Run rewards: " + ("None" if parts.is_empty() else ", ".join(parts))


func _finish_run() -> void:
	run_finished.emit(_manager.run_rewards, _manager.run_flags, _manager.finish_summary())


func _close_event() -> void:
	_event_panel.visible = false


func _item_name(item_id: String) -> String:
	return state.get("items", {}).get(item_id, {}).get("name", item_id)


func _vector2_from_config(value: Variant) -> Vector2:
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO


func _map_texture(map_data: Dictionary) -> Texture2D:
	var texture_path := String(map_data.get("background_texture", ""))
	if texture_path == "":
		return null
	if _map_textures.has(texture_path):
		return _map_textures[texture_path]
	var texture := load(texture_path)
	if texture is Texture2D:
		_map_textures[texture_path] = texture
		return texture
	push_error("Failed to load dungeon map texture: %s" % texture_path)
	return null
