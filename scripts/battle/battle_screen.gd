class_name BattleScreen
extends Control

signal battle_finished(result: Dictionary)

const BattleManagerScript := preload("res://scripts/battle/battle_manager.gd")

var _manager: Variant = BattleManagerScript.new()
var _skill_choice_buttons: Array[Button] = []
var _party_labels: Array[Label] = []
var _enemy_labels: Array[Label] = []

@onready var _battle_log: Label = %BattleLog
@onready var _action_order_label: Label = %ActionOrderLabel
@onready var _attack_button: Button = %AttackButton
@onready var _skill_button: Button = %SkillButton
@onready var _defend_button: Button = %DefendButton
@onready var _item_button: Button = %ItemButton
@onready var _skill_panel: PanelContainer = %SkillPanel
@onready var _skill_hint: Label = %SkillHint
@onready var _item_panel: PanelContainer = %ItemPanel
@onready var _potion_button: Button = %PotionButton
@onready var _potion_hint: Label = %PotionHint


func setup(state: Dictionary, battle_result: Dictionary) -> void:
	_manager.start_battle(state, battle_result)
	if is_inside_tree():
		_refresh_battle()
		_handle_pending_start_result()


func _ready() -> void:
	_manager.name = "BattleManager"
	add_child(_manager)
	_cache_scene_nodes()
	_hide_command_subpanels()
	if not _manager.state.is_empty():
		_refresh_battle()
		_handle_pending_start_result()


func _cache_scene_nodes() -> void:
	_skill_choice_buttons = [
		%SkillChoiceButton0,
		%SkillChoiceButton1,
		%SkillChoiceButton2,
		%SkillChoiceButton3
	]
	_party_labels = [%PartyLabel0, %PartyLabel1]
	_enemy_labels = [%EnemyLabel0, %EnemyLabel1, %EnemyLabel2]


func _on_attack_button_pressed() -> void:
	_hide_command_subpanels()
	_handle_action_result(_manager.attack())


func _on_skill_button_pressed() -> void:
	_show_battle_skills()


func _on_defend_button_pressed() -> void:
	_hide_command_subpanels()
	_handle_action_result(_manager.defend())


func _on_item_button_pressed() -> void:
	_show_battle_items()


func _on_potion_button_pressed() -> void:
	_hide_command_subpanels()
	_handle_action_result(_manager.use_healing_potion())


func _on_skill_choice_button_0_pressed() -> void:
	_use_skill_index(0)


func _on_skill_choice_button_1_pressed() -> void:
	_use_skill_index(1)


func _on_skill_choice_button_2_pressed() -> void:
	_use_skill_index(2)


func _on_skill_choice_button_3_pressed() -> void:
	_use_skill_index(3)


func _refresh_battle() -> void:
	_battle_log.text = _manager.battle_log
	_refresh_action_order()
	for index: int in range(_party_labels.size()):
		var label := _party_labels[index]
		if index >= _manager.battle_party.size():
			label.text = ""
			continue
		var character: Dictionary = _manager.battle_party[index]
		label.text = "%s%s\nHP %d/%d  MP %d/%d\nSTR %d  AGI %d  INT %d  SPD %d" % [
			"> " if _manager.active_actor_side == "party" and index == _manager.active_actor_index and int(character.get("hp", 0)) > 0 else "",
			character["name"],
			max(0, int(character["hp"])),
			int(character["max_hp"]),
			max(0, int(character["mp"])),
			int(character["max_mp"]),
			int(character["strength"]),
			int(character["agility"]),
			int(character["intelligence"]),
			int(character.get("speed", 100))
		]

	for index: int in range(_enemy_labels.size()):
		var label := _enemy_labels[index]
		if index >= _manager.battle_enemies.size():
			label.text = ""
			continue
		var enemy: Dictionary = _manager.battle_enemies[index]
		label.text = "%s%s\nHP %d/%d  SPD %d" % [
			"> " if _manager.active_actor_side == "enemy" and index == _manager.active_actor_index and int(enemy.get("hp", 0)) > 0 else "",
			enemy["name"],
			max(0, int(enemy["hp"])),
			int(enemy["max_hp"]),
			int(enemy.get("speed", 100))
		]

	var actor_ready: bool = _manager.active_actor_ready()
	_attack_button.disabled = not actor_ready
	_skill_button.disabled = not (actor_ready and not _manager.active_actor_skill_ids().is_empty())
	_defend_button.disabled = not actor_ready
	_item_button.disabled = not actor_ready


func _refresh_action_order() -> void:
	var rows: Array[String] = []
	for entry: Dictionary in _manager.action_order_preview():
		rows.append("%s(%d)" % [entry.get("name", "Actor"), int(entry.get("action_value", 0))])
	_action_order_label.text = "\n".join(rows)


func _show_battle_skills() -> void:
	var actor: Dictionary = _manager.active_actor()
	var skill_ids: Array = _manager.active_actor_skill_ids()
	_item_panel.visible = false
	for index: int in range(_skill_choice_buttons.size()):
		var button := _skill_choice_buttons[index]
		if index >= skill_ids.size():
			button.visible = false
			button.disabled = true
			button.text = ""
			continue
		var skill_id := String(skill_ids[index])
		var skill: Dictionary = _manager.skill_data(skill_id)
		var mp_cost := int(skill.get("mp_cost", 0))
		button.visible = true
		button.text = "%s  MP %d" % [skill.get("name", skill_id), mp_cost]
		button.disabled = int(actor.get("mp", 0)) < mp_cost
	_skill_hint.text = "Choose a skill for %s." % actor.get("name", "the active character")
	_skill_panel.visible = true


func _use_skill_index(index: int) -> void:
	var skill_ids: Array = _manager.active_actor_skill_ids()
	if index < 0 or index >= skill_ids.size():
		return
	_hide_command_subpanels()
	_handle_action_result(_manager.use_skill(String(skill_ids[index])))


func _show_battle_items() -> void:
	_skill_panel.visible = false
	_potion_button.text = "Use Healing Potion x%d" % _manager.potion_count()
	_potion_button.disabled = _manager.potion_count() <= 0
	_potion_hint.text = "Healing Potion: restore %d HP to the active character." % _manager.potion_heal_hp()
	_item_panel.visible = true


func _handle_action_result(result: Dictionary) -> void:
	_battle_log.text = result.get("log", _manager.battle_log)
	_refresh_battle()
	var status := String(result.get("status", "running"))
	if status == "running":
		return
	_set_battle_buttons_enabled(false)
	battle_finished.emit(result)


func _set_battle_buttons_enabled(enabled: bool) -> void:
	_attack_button.disabled = not enabled
	_skill_button.disabled = not enabled
	_defend_button.disabled = not enabled
	_item_button.disabled = not enabled


func _handle_pending_start_result() -> void:
	var result: Dictionary = _manager.consume_pending_battle_result()
	if result.is_empty():
		return
	_handle_action_result(result)


func _hide_command_subpanels() -> void:
	_skill_panel.visible = false
	_item_panel.visible = false
