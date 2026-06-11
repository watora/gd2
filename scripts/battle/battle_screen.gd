class_name BattleScreen
extends Control

signal battle_finished(result: Dictionary)

const BattleManagerScript := preload("res://scripts/battle/battle_manager.gd")

var _manager: Variant = BattleManagerScript.new()
var _skill_choice_buttons: Array[Button] = []
var _party_slots: Array[Control] = []
var _enemy_slots: Array[Control] = []
var _party_hp_bars: Array[ProgressBar] = []
var _enemy_hp_bars: Array[ProgressBar] = []
var _party_name_labels: Array[Label] = []
var _enemy_name_labels: Array[Label] = []
var _party_stat_labels: Array[Label] = []
var _enemy_stat_labels: Array[Label] = []
var _party_damage_labels: Array[Label] = []
var _enemy_damage_labels: Array[Label] = []
var _target_selecting_attack := false
var _selected_enemy_index := -1

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
	_party_slots = [%PartySlot0, %PartySlot1, %PartySlot2, %PartySlot3]
	_enemy_slots = [%EnemySlot0, %EnemySlot1, %EnemySlot2, %EnemySlot3]
	_party_hp_bars = [%PartyHpBar0, %PartyHpBar1, %PartyHpBar2, %PartyHpBar3]
	_enemy_hp_bars = [%EnemyHpBar0, %EnemyHpBar1, %EnemyHpBar2, %EnemyHpBar3]
	_party_name_labels = [%PartyNameLabel0, %PartyNameLabel1, %PartyNameLabel2, %PartyNameLabel3]
	_enemy_name_labels = [%EnemyNameLabel0, %EnemyNameLabel1, %EnemyNameLabel2, %EnemyNameLabel3]
	_party_stat_labels = [%PartyStatsLabel0, %PartyStatsLabel1, %PartyStatsLabel2, %PartyStatsLabel3]
	_enemy_stat_labels = [%EnemyStatsLabel0, %EnemyStatsLabel1, %EnemyStatsLabel2, %EnemyStatsLabel3]
	_party_damage_labels = [%PartyDamageLabel0, %PartyDamageLabel1, %PartyDamageLabel2, %PartyDamageLabel3]
	_enemy_damage_labels = [%EnemyDamageLabel0, %EnemyDamageLabel1, %EnemyDamageLabel2, %EnemyDamageLabel3]
	for index: int in range(_enemy_slots.size()):
		_enemy_slots[index].mouse_filter = Control.MOUSE_FILTER_STOP
		_enemy_slots[index].gui_input.connect(_on_enemy_slot_gui_input.bind(index))


func _on_attack_button_pressed() -> void:
	_hide_command_subpanels()
	if not _manager.active_actor_ready():
		return
	_begin_attack_targeting()


func _on_skill_button_pressed() -> void:
	_end_attack_targeting()
	_show_battle_skills()


func _on_defend_button_pressed() -> void:
	_end_attack_targeting()
	_hide_command_subpanels()
	_handle_action_result(_manager.defend())


func _on_item_button_pressed() -> void:
	_end_attack_targeting()
	_show_battle_items()


func _on_potion_button_pressed() -> void:
	_end_attack_targeting()
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


func _on_enemy_slot_gui_input(event: InputEvent, index: int) -> void:
	if not _target_selecting_attack:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
			return
		_select_enemy_for_attack(index)


func _refresh_battle() -> void:
	_battle_log.text = _manager.battle_log
	_refresh_action_order()
	for index: int in range(_party_slots.size()):
		var slot := _party_slots[index]
		if index >= _manager.battle_party.size():
			slot.visible = false
			continue
		slot.visible = true
		var character: Dictionary = _manager.battle_party[index]
		var party_hp: int = max(0, int(character["hp"]))
		var party_max_hp: int = max(1, int(character["max_hp"]))
		_party_hp_bars[index].max_value = party_max_hp
		_party_hp_bars[index].value = party_hp
		_party_name_labels[index].text = "%s%s" % [
			"> " if _manager.active_actor_side == "party" and index == _manager.active_actor_index and int(character.get("hp", 0)) > 0 else "",
			character["name"]
		]
		_party_stat_labels[index].text = "HP %d/%d\nMP %d/%d" % [
			party_hp,
			party_max_hp,
			max(0, int(character["mp"])),
			int(character["max_mp"])
		]

	for index: int in range(_enemy_slots.size()):
		var slot := _enemy_slots[index]
		if index >= _manager.battle_enemies.size():
			slot.visible = false
			continue
		slot.visible = true
		var enemy: Dictionary = _manager.battle_enemies[index]
		var enemy_hp: int = max(0, int(enemy["hp"]))
		var enemy_max_hp: int = max(1, int(enemy["max_hp"]))
		_enemy_hp_bars[index].max_value = enemy_max_hp
		_enemy_hp_bars[index].value = enemy_hp
		_enemy_name_labels[index].text = "%s%s" % [
			_enemy_name_prefix(index, enemy),
			enemy["name"]
		]
		_enemy_stat_labels[index].text = "HP %d/%d\nSPD %d" % [
			enemy_hp,
			enemy_max_hp,
			int(enemy.get("speed", 100))
		]

	var actor_ready: bool = _manager.active_actor_ready()
	_attack_button.disabled = not actor_ready
	_attack_button.text = "Choose Target" if _target_selecting_attack else "Attack"
	_skill_button.disabled = not (actor_ready and not _manager.active_actor_skill_ids().is_empty())
	_defend_button.disabled = not actor_ready
	_item_button.disabled = not actor_ready
	_refresh_target_highlight()


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
	_end_attack_targeting()
	_hide_command_subpanels()
	_handle_action_result(_manager.use_skill(String(skill_ids[index])))


func _show_battle_items() -> void:
	_skill_panel.visible = false
	_potion_button.text = "Use Healing Potion x%d" % _manager.potion_count()
	_potion_button.disabled = _manager.potion_count() <= 0
	_potion_hint.text = "Healing Potion: restore %d HP to the active character." % _manager.potion_heal_hp()
	_item_panel.visible = true


func _handle_action_result(result: Dictionary) -> void:
	_end_attack_targeting()
	_battle_log.text = result.get("log", _manager.battle_log)
	_refresh_battle()
	_show_battle_events(result.get("events", []))
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


func _begin_attack_targeting() -> void:
	_target_selecting_attack = true
	_selected_enemy_index = _first_selectable_enemy_index()
	_battle_log.text = "Choose an enemy target."
	_refresh_battle()


func _select_enemy_for_attack(index: int) -> void:
	if not _is_enemy_selectable(index):
		_battle_log.text = "Choose a living enemy target."
		return
	_selected_enemy_index = index
	_refresh_target_highlight()
	var target_index := _selected_enemy_index
	_end_attack_targeting()
	_handle_action_result(_manager.attack(target_index))


func _end_attack_targeting() -> void:
	_target_selecting_attack = false
	_selected_enemy_index = -1
	_attack_button.text = "Attack"
	_refresh_target_highlight()


func _first_selectable_enemy_index() -> int:
	for index: int in range(_enemy_slots.size()):
		if _is_enemy_selectable(index):
			return index
	return -1


func _is_enemy_selectable(index: int) -> bool:
	if index < 0 or index >= _manager.battle_enemies.size():
		return false
	return int(_manager.battle_enemies[index].get("hp", 0)) > 0


func _enemy_name_prefix(index: int, enemy: Dictionary) -> String:
	if _target_selecting_attack and index == _selected_enemy_index and int(enemy.get("hp", 0)) > 0:
		return "* "
	if _manager.active_actor_side == "enemy" and index == _manager.active_actor_index and int(enemy.get("hp", 0)) > 0:
		return "> "
	return ""


func _refresh_target_highlight() -> void:
	for index: int in range(_enemy_slots.size()):
		var slot := _enemy_slots[index]
		if _target_selecting_attack and index == _selected_enemy_index and _is_enemy_selectable(index):
			slot.modulate = Color(1.25, 1.18, 0.72, 1.0)
		elif _target_selecting_attack and _is_enemy_selectable(index):
			slot.modulate = Color(1.0, 1.0, 1.0, 1.0)
		elif not _is_enemy_selectable(index) and index < _manager.battle_enemies.size():
			slot.modulate = Color(0.55, 0.55, 0.55, 1.0)
		else:
			slot.modulate = Color(1.0, 1.0, 1.0, 1.0)


func _show_battle_events(events: Array) -> void:
	for event: Dictionary in events:
		if String(event.get("type", "")) != "damage":
			continue
		var labels := _party_damage_labels if String(event.get("target_side", "")) == "party" else _enemy_damage_labels
		var index := int(event.get("target_index", -1))
		if index < 0 or index >= labels.size():
			continue
		_show_damage_label(labels[index], int(event.get("amount", 0)))


func _show_damage_label(label: Label, amount: int) -> void:
	label.text = "-%d" % amount
	label.visible = true
	label.modulate = Color(1, 1, 1, 1)
