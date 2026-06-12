class_name DungeonScreen
extends Control

# Presentation layer for map exploration. It builds buttons from location config
# and delegates rule decisions to DungeonManager; completed runs emit rewards and
# flags back to MainController.
signal run_finished(rewards: Dictionary, flags: Dictionary, summary: Array[String])

const BATTLE_SCREEN_SCENE := preload("res://scenes/battle/battle_screen.tscn")
const MAP_LAYOUT_SIZE := Vector2(1152.0, 648.0)
const CHARACTER_STATUS_PANEL_SCENE := preload("res://scenes/ui/character_status_panel.tscn")

var state: Dictionary = {}
var current_choices: Array = []
var current_shop_goods: Array = []
var selected_shop_index := -1

@onready var _map_layer: Control = %MapLayer
@onready var _title_label: Label = %TitleLabel
@onready var _reward_label: Label = %RewardLabel
@onready var _character_button: Button = %CharacterButton
@onready var _finish_button: Button = %FinishButton
@onready var _event_panel: PanelContainer = %EventPanel
@onready var _event_title: Label = %EventTitle
@onready var _event_body: Label = %EventBody
@onready var _choice_button_0: Button = %ChoiceButton0
@onready var _choice_button_1: Button = %ChoiceButton1
@onready var _choice_button_2: Button = %ChoiceButton2
@onready var _choice_button_3: Button = %ChoiceButton3
@onready var _choice_button_4: Button = %ChoiceButton4
@onready var _shop_panel: PanelContainer = %ShopPanel
@onready var _shop_title: Label = %ShopTitle
@onready var _shop_gold_label: Label = %ShopGoldLabel
@onready var _shop_info_label: Label = %ShopInfoLabel
@onready var _buy_button: Button = %BuyButton

var _choice_buttons: Array[Button] = []
var _shop_item_buttons: Array[Button] = []
var _event_buttons: Dictionary = {}
var _map_textures: Dictionary = {}
var _map_image: TextureRect
var _manager := DungeonManager.new()
var _battle_screen: Control
var _character_status_panel: Variant


func setup(new_state: Dictionary, config_path := DungeonManager.EVENTS_CONFIG, start_map_id := "") -> void:
	state = new_state
	_manager.start_run(state, config_path, start_map_id)
	if is_inside_tree():
		_setup_character_status_panel()
		_apply_current_map()
		_update_reward_label()


func _ready() -> void:
	_manager.name = "DungeonManager"
	add_child(_manager)
	_cache_scene_nodes()
	_character_button.pressed.connect(_open_character_status)
	_create_character_status_panel()
	_event_panel.visible = false
	_shop_panel.visible = false
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
	_shop_item_buttons = [
		%ShopItemButton0,
		%ShopItemButton1,
		%ShopItemButton2,
		%ShopItemButton3,
		%ShopItemButton4
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


func _on_shop_item_button_0_pressed() -> void:
	_select_shop_item(0)


func _on_shop_item_button_1_pressed() -> void:
	_select_shop_item(1)


func _on_shop_item_button_2_pressed() -> void:
	_select_shop_item(2)


func _on_shop_item_button_3_pressed() -> void:
	_select_shop_item(3)


func _on_shop_item_button_4_pressed() -> void:
	_select_shop_item(4)


func _on_buy_button_pressed() -> void:
	_buy_selected_shop_item()


func _on_close_shop_button_pressed() -> void:
	_close_shop()


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

	# Event point positions are authored against MAP_LAYOUT_SIZE in JSON, then
	# converted to anchors so the map stays responsive with the UI layout.
	for point: Dictionary in event_points:
		var event_id := String(point.get("event_id", ""))
		if event_id == "" or not _manager.has_event(event_id):
			continue
		var event_data := _manager.event_data(event_id)
		var button := Button.new()
		button.name = "%s_button" % event_id
		button.text = point.get("text", event_data.get("title", event_id))
		_apply_event_button_anchors(button, point)
		button.pressed.connect(_on_event_button_pressed.bind(event_id))
		_map_layer.add_child(button, true)
		_event_buttons[event_id] = button


func _on_event_button_pressed(event_id: String) -> void:
	_open_event(event_id)


func _open_event(event_id: String) -> void:
	if not _manager.has_event(event_id):
		return
	var event_data := _manager.event_data(event_id)
	if event_data.has("shop"):
		_open_shop(event_data)
		return
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

	# Manager returns a small result dictionary describing which presentation path
	# to take: show text, start battle, move maps, or display an error.
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
	if _character_status_panel != null:
		_character_status_panel.close()
	# Battle temporarily replaces map interaction, but DungeonManager keeps the
	# run rewards and summary until the final run_finished signal.
	_map_layer.visible = false
	_character_button.disabled = true
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
		_character_button.disabled = false
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
	if _character_status_panel != null:
		_character_status_panel.refresh()


func _open_character_status() -> void:
	_setup_character_status_panel()
	_character_status_panel.open()


func _create_character_status_panel() -> void:
	if _character_status_panel != null:
		return
	_character_status_panel = CHARACTER_STATUS_PANEL_SCENE.instantiate()
	add_child(_character_status_panel)
	_setup_character_status_panel()


func _setup_character_status_panel() -> void:
	if _character_status_panel == null or state.is_empty():
		return
	_character_status_panel.setup(state)


func _finish_run() -> void:
	_clear_battle_screen()
	run_finished.emit(_manager.run_rewards, _manager.run_flags, _manager.finish_summary())


func _close_event() -> void:
	_event_panel.visible = false


func _open_shop(event_data: Dictionary) -> void:
	_event_panel.visible = false
	_shop_panel.visible = true
	_shop_title.text = event_data.get("title", "Market")
	var shop_data: Dictionary = event_data.get("shop", {})
	current_shop_goods = shop_data.get("goods", [])
	selected_shop_index = -1
	_shop_info_label.text = shop_data.get("body", event_data.get("body", "Select an item."))
	_buy_button.disabled = true
	_refresh_shop()
	if not current_shop_goods.is_empty():
		_select_shop_item(0)


func _refresh_shop() -> void:
	_shop_gold_label.text = "Gold: %d" % int(state.get("gold", 0))
	for index: int in range(_shop_item_buttons.size()):
		var button := _shop_item_buttons[index]
		if index >= current_shop_goods.size():
			button.visible = false
			button.disabled = true
			button.text = ""
			continue
		var item: Dictionary = current_shop_goods[index]
		var item_id := String(item.get("item_id", ""))
		var quantity: int = max(1, int(item.get("quantity", 1)))
		var price: int = max(0, int(item.get("price", 0)))
		button.visible = true
		button.disabled = item_id == ""
		button.text = "%s x%d - %d gold" % [_item_name(item_id), quantity, price]


func _select_shop_item(index: int) -> void:
	if index < 0 or index >= current_shop_goods.size():
		selected_shop_index = -1
		_buy_button.disabled = true
		return
	selected_shop_index = index
	var item: Dictionary = current_shop_goods[index]
	var item_id := String(item.get("item_id", ""))
	var quantity: int = max(1, int(item.get("quantity", 1)))
	var price: int = max(0, int(item.get("price", 0)))
	var owned: int = int(state.get("inventory", {}).get(item_id, 0))
	var description := String(item.get("description", "A useful market good."))
	_shop_info_label.text = "%s x%d\nPrice: %d gold\nOwned: %d\n\n%s" % [
		_item_name(item_id),
		quantity,
		price,
		owned,
		description
	]
	_buy_button.text = "Buy for %d gold" % price
	_buy_button.disabled = item_id == "" or int(state.get("gold", 0)) < price


func _buy_selected_shop_item() -> void:
	if selected_shop_index < 0 or selected_shop_index >= current_shop_goods.size():
		return
	var item: Dictionary = current_shop_goods[selected_shop_index]
	var item_id := String(item.get("item_id", ""))
	var quantity: int = max(1, int(item.get("quantity", 1)))
	var price: int = max(0, int(item.get("price", 0)))
	if item_id == "":
		return
	if int(state.get("gold", 0)) < price:
		_shop_info_label.text = "Not enough gold."
		_buy_button.disabled = true
		return
	# Shops spend from global gold immediately because the player is visiting a
	# safe city/location, not collecting delayed dungeon-run rewards.
	state["gold"] = int(state.get("gold", 0)) - price
	if not state["inventory"].has(item_id):
		state["inventory"][item_id] = 0
	state["inventory"][item_id] = int(state["inventory"].get(item_id, 0)) + quantity
	_manager.append_summary("City: bought %s x%d at the market for %d gold." % [_item_name(item_id), quantity, price])
	_refresh_shop()
	_select_shop_item(selected_shop_index)


func _close_shop() -> void:
	_shop_panel.visible = false


func _item_name(item_id: String) -> String:
	return state.get("items", {}).get(item_id, {}).get("name", item_id)


func _vector2_from_config(value: Variant) -> Vector2:
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO


func _apply_event_button_anchors(button: Button, point: Dictionary) -> void:
	var point_position := _vector2_from_config(point.get("position", [0, 0]))
	var point_size := _vector2_from_config(point.get("size", [140, 42]))
	button.anchor_left = clampf(point_position.x / MAP_LAYOUT_SIZE.x, 0.0, 1.0)
	button.anchor_top = clampf(point_position.y / MAP_LAYOUT_SIZE.y, 0.0, 1.0)
	button.anchor_right = clampf((point_position.x + point_size.x) / MAP_LAYOUT_SIZE.x, 0.0, 1.0)
	button.anchor_bottom = clampf((point_position.y + point_size.y) / MAP_LAYOUT_SIZE.y, 0.0, 1.0)
	button.offset_left = 0.0
	button.offset_top = 0.0
	button.offset_right = 0.0
	button.offset_bottom = 0.0


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
