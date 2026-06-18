class_name BattleScreen
extends Control

# Battle UI and animation bridge. It forwards player commands to BattleManager,
# renders manager state, and plays lightweight effects described by manager
# event dictionaries.
signal battle_finished(result: Dictionary)

const BattleManagerScript := preload("res://scripts/battle/battle_manager.gd")
const ATTACK_LUNGE_OFFSET := 22.0
const ATTACK_LUNGE_OUT_DURATION := 0.08
const ATTACK_LUNGE_BACK_DURATION := 0.10
const HIT_SHAKE_OFFSET := 8.0
const HIT_SHAKE_STEP_DURATION := 0.045
const BATTLE_EVENT_GAP := 0.04
const EFFECT_FADE_IN_DURATION := 0.06
const EFFECT_HOLD_DURATION := 0.12
const EFFECT_FADE_OUT_DURATION := 0.10

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
var _target_selection_mode := ""
var _pending_skill_id := ""
var _selected_enemy_index := -1
var _pending_finished_result: Dictionary = {}

@export var basic_attack_effect_texture: Texture2D = preload("res://Assets/effects/fx_basic_attack_slash_placeholder.png")
@export var basic_attack_effect_size := 170.0

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
@onready var _settlement_panel: PanelContainer = %SettlementPanel
@onready var _settlement_title: Label = %SettlementTitle
@onready var _exp_summary_label: Label = %ExpSummaryLabel
@onready var _loot_summary_label: Label = %LootSummaryLabel
@onready var _settlement_continue_button: Button = %SettlementContinueButton


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
	_settlement_panel.visible = false
	if not _manager.state.is_empty():
		_refresh_battle()
		_handle_pending_start_result()


func _cache_scene_nodes() -> void:
	# Enemy slots double as target buttons. They stay regular Control nodes so
	# the scene can keep its layout while this script adds click/hover behavior.
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
		_enemy_slots[index].mouse_entered.connect(_on_enemy_slot_mouse_entered.bind(index))
		_enemy_slots[index].mouse_exited.connect(_on_enemy_slot_mouse_exited.bind(index))


func _on_attack_button_pressed() -> void:
	_hide_command_subpanels()
	if not _manager.active_actor_ready():
		return
	_begin_enemy_targeting("attack")


func _on_skill_button_pressed() -> void:
	_end_enemy_targeting()
	_show_battle_skills()


func _on_defend_button_pressed() -> void:
	_end_enemy_targeting()
	_hide_command_subpanels()
	_handle_action_result(_manager.defend())


func _on_item_button_pressed() -> void:
	_end_enemy_targeting()
	_show_battle_items()


func _on_potion_button_pressed() -> void:
	_end_enemy_targeting()
	_hide_command_subpanels()
	_handle_action_result(_manager.use_healing_potion())


func _on_settlement_continue_button_pressed() -> void:
	if _pending_finished_result.is_empty():
		return
	var result := _pending_finished_result
	_pending_finished_result = {}
	battle_finished.emit(result)


func _on_skill_choice_button_0_pressed() -> void:
	_use_skill_index(0)


func _on_skill_choice_button_1_pressed() -> void:
	_use_skill_index(1)


func _on_skill_choice_button_2_pressed() -> void:
	_use_skill_index(2)


func _on_skill_choice_button_3_pressed() -> void:
	_use_skill_index(3)


func _on_enemy_slot_gui_input(event: InputEvent, index: int) -> void:
	if not _is_enemy_targeting():
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
			return
		_select_enemy_target(index)


func _on_enemy_slot_mouse_entered(index: int) -> void:
	if not _is_enemy_targeting() or not _is_enemy_selectable(index):
		return
	_selected_enemy_index = index
	_refresh_enemy_target_cues()


func _on_enemy_slot_mouse_exited(index: int) -> void:
	if not _is_enemy_targeting() or _selected_enemy_index != index:
		return
	_selected_enemy_index = -1
	_refresh_enemy_target_cues()


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
	_attack_button.text = "Choose Target" if _target_selection_mode == "attack" else "Attack"
	_skill_button.disabled = not (actor_ready and not _manager.active_actor_skill_ids().is_empty())
	_defend_button.disabled = not actor_ready
	_item_button.disabled = not actor_ready
	_refresh_enemy_target_cues()


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
	_pending_skill_id = String(skill_ids[index])
	_begin_enemy_targeting("skill")


func _show_battle_items() -> void:
	_skill_panel.visible = false
	_potion_button.text = "Use Healing Potion x%d" % _manager.potion_count()
	_potion_button.disabled = _manager.potion_count() <= 0
	_potion_hint.text = "Healing Potion: restore %d HP to the active character." % _manager.potion_heal_hp()
	_item_panel.visible = true


func _handle_action_result(result: Dictionary) -> void:
	_end_enemy_targeting()
	_battle_log.text = result.get("log", _manager.battle_log)
	_refresh_battle()
	# Manager events are deliberately presentation-neutral; this screen maps them
	# to damage labels, lunges, shakes, and optional skill textures.
	_play_battle_event_effects(result.get("events", []))
	_show_battle_events(result.get("events", []))
	var status := String(result.get("status", "running"))
	if status == "running":
		return
	_set_battle_buttons_enabled(false)
	_show_battle_settlement(result)


func _set_battle_buttons_enabled(enabled: bool) -> void:
	_attack_button.disabled = not enabled
	_skill_button.disabled = not enabled
	_defend_button.disabled = not enabled
	_item_button.disabled = not enabled


func _show_battle_settlement(result: Dictionary) -> void:
	_pending_finished_result = result
	_end_enemy_targeting()
	_hide_command_subpanels()
	_settlement_title.text = "Victory Settlement" if String(result.get("status", "")) == "victory" else "Battle Result"
	_exp_summary_label.text = _format_exp_summary(result.get("exp_summary", []))
	_loot_summary_label.text = _format_loot_summary(result.get("rewards", {}))
	_settlement_continue_button.text = "Return to Dungeon" if String(result.get("status", "")) == "victory" else "Return to Base"
	_settlement_panel.visible = true


func _format_exp_summary(exp_summary: Array) -> String:
	if exp_summary.is_empty():
		return "EXP\nNo EXP gained."
	var rows: Array[String] = ["EXP"]
	for entry: Dictionary in exp_summary:
		var character_name: String = String(entry.get("name", "Character"))
		var gained_exp: int = int(entry.get("gained_exp", 0))
		var level_before: int = int(entry.get("level_before", 1))
		var level_after: int = int(entry.get("level_after", level_before))
		var current_exp: int = int(entry.get("exp", 0))
		var next_exp: int = max(1, int(entry.get("next_exp", 20)))
		var row: String = "%s: +%d EXP  Lv.%d" % [character_name, gained_exp, level_after]
		if level_after > level_before:
			row += " (Lv.%d -> Lv.%d)" % [level_before, level_after]
		row += "  %d/%d" % [current_exp, next_exp]
		if not bool(entry.get("alive", true)) and gained_exp <= 0:
			row += "  Down"
		rows.append(row)
	return "\n".join(rows)


func _format_loot_summary(rewards: Dictionary) -> String:
	var rows: Array[String] = ["Loot"]
	if rewards.is_empty():
		rows.append("No item drops.")
		return "\n".join(rows)
	if int(rewards.get("gold", 0)) > 0:
		rows.append("Gold x%d" % int(rewards["gold"]))
	for reward_id: String in rewards:
		if reward_id == "gold":
			continue
		var quantity: int = int(rewards.get(reward_id, 0))
		if quantity <= 0:
			continue
		rows.append("%s x%d" % [_item_name(reward_id), quantity])
	if rows.size() == 1:
		rows.append("No item drops.")
	return "\n".join(rows)


func _item_name(item_id: String) -> String:
	return String(_manager.state.get("items", {}).get(item_id, {}).get("name", item_id))


func _handle_pending_start_result() -> void:
	var result: Dictionary = _manager.consume_pending_battle_result()
	if result.is_empty():
		return
	_handle_action_result(result)


func _hide_command_subpanels() -> void:
	_skill_panel.visible = false
	_item_panel.visible = false


func _begin_enemy_targeting(mode: String) -> void:
	# Attack and skill share the same targeting flow. _pending_skill_id tells the
	# final click whether to call attack() or use_skill().
	_target_selection_mode = mode
	_selected_enemy_index = -1
	if mode == "skill":
		var skill_name := _pending_skill_id
		var skill: Dictionary = _manager.skill_data(_pending_skill_id)
		if not skill.is_empty():
			skill_name = String(skill.get("name", _pending_skill_id))
		_battle_log.text = "Choose a target for %s." % skill_name
	else:
		_pending_skill_id = ""
		_battle_log.text = "Choose an enemy target."
	_refresh_battle()


func _select_enemy_target(index: int) -> void:
	if not _is_enemy_selectable(index):
		_battle_log.text = "Choose a living enemy target."
		return
	_selected_enemy_index = index
	_refresh_enemy_target_cues()
	var target_index := _selected_enemy_index
	var mode := _target_selection_mode
	var skill_id := _pending_skill_id
	_end_enemy_targeting()
	if mode == "skill":
		_handle_action_result(_manager.use_skill(skill_id, target_index))
	else:
		_handle_action_result(_manager.attack(target_index))


func _end_enemy_targeting() -> void:
	_target_selection_mode = ""
	_pending_skill_id = ""
	_selected_enemy_index = -1
	_attack_button.text = "Attack"
	_refresh_enemy_target_cues()


func _is_enemy_selectable(index: int) -> bool:
	if index < 0 or index >= _manager.battle_enemies.size():
		return false
	return int(_manager.battle_enemies[index].get("hp", 0)) > 0


func _enemy_name_prefix(index: int, enemy: Dictionary) -> String:
	if _is_enemy_targeting() and index == _selected_enemy_index and int(enemy.get("hp", 0)) > 0:
		return "* "
	if _manager.active_actor_side == "enemy" and index == _manager.active_actor_index and int(enemy.get("hp", 0)) > 0:
		return "> "
	return ""


func _is_enemy_targeting() -> bool:
	return _target_selection_mode != ""


func _refresh_enemy_target_cues() -> void:
	for index: int in range(_enemy_slots.size()):
		if index >= _manager.battle_enemies.size():
			continue
		var enemy: Dictionary = _manager.battle_enemies[index]
		_enemy_name_labels[index].text = "%s%s" % [
			_enemy_name_prefix(index, enemy),
			enemy["name"]
		]
	_refresh_target_highlight()


func _refresh_target_highlight() -> void:
	for index: int in range(_enemy_slots.size()):
		var slot := _enemy_slots[index]
		if _is_enemy_targeting() and index == _selected_enemy_index and _is_enemy_selectable(index):
			slot.modulate = Color(1.25, 1.18, 0.72, 1.0)
		elif _is_enemy_targeting() and _is_enemy_selectable(index):
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


func _play_battle_event_effects(events: Array) -> void:
	var event_delay := 0.0
	for event: Dictionary in events:
		var event_type := String(event.get("type", ""))
		if event_type == "attack_motion":
			var effect_texture := String(event.get("effect_texture", ""))
			var effect_size := float(event.get("effect_size", basic_attack_effect_size))
			_play_attack_lunge(
				String(event.get("source_side", "")),
				int(event.get("source_index", -1)),
				event_delay
			)
			_play_skill_effect(
				effect_texture,
				String(event.get("target_side", "")),
				int(event.get("target_index", -1)),
				effect_size,
				event_delay + ATTACK_LUNGE_OUT_DURATION
			)
		elif event_type == "damage":
			_play_hit_shake(
				String(event.get("target_side", "")),
				int(event.get("target_index", -1)),
				event_delay + ATTACK_LUNGE_OUT_DURATION
			)
			event_delay += ATTACK_LUNGE_OUT_DURATION + max(ATTACK_LUNGE_BACK_DURATION, HIT_SHAKE_STEP_DURATION * 4.0) + BATTLE_EVENT_GAP


func _play_attack_lunge(source_side: String, source_index: int, delay: float = 0.0) -> void:
	var slot := _slot_for_side(source_side, source_index)
	if slot == null or not slot.visible:
		return
	var direction := 1.0 if source_side == "party" else -1.0
	var start_position := slot.position
	var lunge_position := start_position + Vector2(ATTACK_LUNGE_OFFSET * direction, 0.0)
	var tween := create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(slot, "position", lunge_position, ATTACK_LUNGE_OUT_DURATION)
	tween.tween_property(slot, "position", start_position, ATTACK_LUNGE_BACK_DURATION)


func _play_skill_effect(texture_path: String, target_side: String, target_index: int, effect_size: float, delay: float = 0.0) -> void:
	var slot := _slot_for_side(target_side, target_index)
	if slot == null or not slot.visible:
		return
	var texture := _effect_texture(texture_path)
	if texture == null:
		return
	var effect := TextureRect.new()
	effect.texture = texture
	effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effect.size = Vector2(effect_size, effect_size)
	effect.pivot_offset = effect.size * 0.5
	effect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	effect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	effect.modulate = Color(1.0, 1.0, 1.0, 0.0)
	effect.scale = Vector2(0.85, 0.85)
	# Effects are added to the battle root and positioned from the target slot's
	# global center so they line up even when containers resize the layout.
	var slot_center := slot.get_global_rect().get_center()
	var local_center := slot_center - get_global_rect().position
	effect.position = local_center - effect.size * 0.5
	add_child(effect)

	var tween := create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(effect, "modulate:a", 1.0, EFFECT_FADE_IN_DURATION)
	tween.parallel().tween_property(effect, "scale", Vector2(1.0, 1.0), EFFECT_FADE_IN_DURATION)
	tween.tween_interval(EFFECT_HOLD_DURATION)
	tween.tween_property(effect, "modulate:a", 0.0, EFFECT_FADE_OUT_DURATION)
	tween.parallel().tween_property(effect, "scale", Vector2(1.08, 1.08), EFFECT_FADE_OUT_DURATION)
	tween.tween_callback(effect.queue_free)


func _effect_texture(texture_path: String) -> Texture2D:
	if texture_path == "":
		return basic_attack_effect_texture
	var loaded := load(texture_path)
	if loaded is Texture2D:
		return loaded
	return basic_attack_effect_texture


func _play_hit_shake(target_side: String, target_index: int, delay: float = 0.0) -> void:
	var slot := _slot_for_side(target_side, target_index)
	if slot == null or not slot.visible:
		return
	var start_position := slot.position
	var left_position := start_position + Vector2(-HIT_SHAKE_OFFSET, 0.0)
	var right_position := start_position + Vector2(HIT_SHAKE_OFFSET, 0.0)
	var tween := create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(slot, "position", left_position, HIT_SHAKE_STEP_DURATION)
	tween.tween_property(slot, "position", right_position, HIT_SHAKE_STEP_DURATION)
	tween.tween_property(slot, "position", left_position, HIT_SHAKE_STEP_DURATION)
	tween.tween_property(slot, "position", start_position, HIT_SHAKE_STEP_DURATION)


func _slot_for_side(side: String, index: int) -> Control:
	if side == "party" and index >= 0 and index < _party_slots.size():
		return _party_slots[index]
	if side == "enemy" and index >= 0 and index < _enemy_slots.size():
		return _enemy_slots[index]
	return null
