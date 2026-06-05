class_name DungeonScreen
extends Control

signal run_finished(rewards: Dictionary, flags: Dictionary, summary: Array[String])

const BATTLE_SCREEN_SCENE := preload("res://scenes/battle/battle_screen.tscn")

var state: Dictionary = {}
var current_choices: Array = []

@onready var _map_layer: Control = %MapLayer
@onready var _title_label: Label = %TitleLabel
@onready var _reward_label: Label = %RewardLabel
@onready var _finish_button: Button = %FinishButton
@onready var _event_panel: PanelContainer = %EventPanel
@onready var _event_title: Label = %EventTitle
@onready var _event_body: Label = %EventBody
@onready var _choice_button_0: Button = %ChoiceButton0
@onready var _choice_button_1: Button = %ChoiceButton1
@onready var _choice_button_2: Button = %ChoiceButton2
@onready var _choice_button_3: Button = %ChoiceButton3
@onready var _choice_button_4: Button = %ChoiceButton4

var _choice_buttons: Array[Button] = []
var _event_buttons: Dictionary = {}
var _map_textures: Dictionary = {}
var _map_image: TextureRect
var _manager := DungeonManager.new()
var _battle_screen: Control


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
	_finish_button.disabled = true
	_clear_battle_screen()
	_battle_screen = BATTLE_SCREEN_SCENE.instantiate() as Control
	add_child(_battle_screen)
	_battle_screen.battle_finished.connect(_on_battle_finished)
	_battle_screen.setup(state, battle_result)


func _on_battle_finished(result: Dictionary) -> void:
	_clear_battle_screen()
	for summary: String in result.get("summary", []):
		_manager.append_summary(summary)
	if String(result.get("status", "")) == "victory":
		_manager.add_run_rewards(result.get("rewards", {}))
		_map_layer.visible = true
		_finish_button.disabled = false
		_update_reward_label()
		return
	_finish_run()


func _clear_battle_screen() -> void:
	if _battle_screen == null:
		return
	_battle_screen.queue_free()
	_battle_screen = null


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
	_clear_battle_screen()
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
