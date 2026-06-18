class_name ConstructionBoard
extends Control

signal place_building_requested(building_id: String, cell: Vector2i)
signal upgrade_building_requested(instance_id: String)

const CONSTRUCTION_MANAGER_SCRIPT := preload("res://scripts/management/construction_manager.gd")

@export var board_pixel_size := 420
@export var cell_texture: Texture2D

var state: Dictionary
var _selected_building_id := ""
var _selected_instance_id := ""
var _catalog_buttons: Dictionary = {}
var _cell_buttons: Array[Button] = []
var _hovered_instance_id := ""

@onready var _catalog_list: VBoxContainer = %CatalogList
@onready var _selection_title: Label = %SelectionTitle
@onready var _selection_info: Label = %SelectionInfo
@onready var _upgrade_button: Button = %UpgradeButton
@onready var _grid: GridContainer = %ConstructionGrid
@onready var _tooltip: PanelContainer = %BuildingTooltip
@onready var _tooltip_label: Label = %TooltipLabel
@onready var _map_area: Control = %MapArea


func setup(new_state: Dictionary) -> void:
	state = new_state
	if is_inside_tree():
		refresh()


func _ready() -> void:
	_upgrade_button.pressed.connect(_on_upgrade_pressed)
	_tooltip.visible = false
	refresh()


func _process(_delta: float) -> void:
	if not _tooltip.visible:
		return
	var desired := _map_area.get_local_mouse_position() + Vector2(14, 16)
	desired.x = min(desired.x, max(0.0, _map_area.size.x - _tooltip.size.x))
	desired.y = min(desired.y, max(0.0, _map_area.size.y - _tooltip.size.y))
	_tooltip.position = desired


func refresh() -> void:
	if state.is_empty() or not is_inside_tree():
		return
	_refresh_catalog()
	_rebuild_grid()
	_refresh_selection()


func _refresh_catalog() -> void:
	var definitions: Dictionary = state.get("building_definitions", {})
	for button: Button in _catalog_buttons.values():
		_catalog_list.remove_child(button)
		button.queue_free()
	_catalog_buttons.clear()

	var building_ids := definitions.keys()
	building_ids.sort()
	for building_id: String in building_ids:
		var definition: Dictionary = definitions[building_id]
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 52)
		button.toggle_mode = true
		button.text = "%s\n%s" % [definition["name"], _cost_text(definition.get("build_cost", {}))]
		button.tooltip_text = String(definition.get("description", ""))
		button.pressed.connect(_select_building_type.bind(building_id))
		_catalog_list.add_child(button)
		_catalog_buttons[building_id] = button
	_update_catalog_selection()


func _rebuild_grid() -> void:
	for button: Button in _cell_buttons:
		_grid.remove_child(button)
		button.queue_free()
	_cell_buttons.clear()

	var construction: Dictionary = state.get("construction", {})
	var width := int(construction.get("width", 5))
	var height := int(construction.get("height", 5))
	_grid.columns = width
	var cell_size := floori(float(board_pixel_size) / float(max(width, height)))
	_grid.custom_minimum_size = Vector2(cell_size * width, cell_size * height)

	for y: int in range(height):
		for x: int in range(width):
			var cell := Vector2i(x, y)
			var placement: Dictionary = CONSTRUCTION_MANAGER_SCRIPT.new().find_placement_at(construction, cell)
			var button := _create_cell_button(cell, placement, cell_size)
			_grid.add_child(button)
			_cell_buttons.append(button)


func _create_cell_button(cell: Vector2i, placement: Dictionary, cell_size: int) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(cell_size, cell_size)
	button.clip_contents = true
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(_on_cell_pressed.bind(cell))

	var tile := TextureRect.new()
	tile.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tile.texture = cell_texture
	tile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tile.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(tile)

	if placement.is_empty():
		return button

	var definition: Dictionary = state["building_definitions"].get(String(placement["building_id"]), {})
	var image := TextureRect.new()
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
	image.texture = load(String(definition.get("texture", "")))
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var level := int(placement.get("level", 1))
	image.modulate = Color(0.82 + level * 0.06, 0.84 + level * 0.05, 0.86 + level * 0.04, 1.0)
	button.add_child(image)
	button.mouse_entered.connect(_on_building_hovered.bind(String(placement["id"])))
	button.mouse_exited.connect(_on_building_unhovered.bind(String(placement["id"])))
	if String(placement["id"]) == _selected_instance_id:
		button.modulate = Color(1.0, 0.94, 0.68, 1.0)
	return button


func _on_cell_pressed(cell: Vector2i) -> void:
	var placement: Dictionary = CONSTRUCTION_MANAGER_SCRIPT.new().find_placement_at(
		state["construction"],
		cell
	)
	if not placement.is_empty():
		_selected_instance_id = String(placement["id"])
		_selected_building_id = ""
		_update_catalog_selection()
		_rebuild_grid()
		_refresh_selection()
		return
	if _selected_building_id.is_empty():
		_selection_title.text = "Select a building"
		_selection_info.text = "Choose a building type from the list, then click an empty cell."
		return
	place_building_requested.emit(_selected_building_id, cell)


func _select_building_type(building_id: String) -> void:
	_selected_building_id = building_id
	_selected_instance_id = ""
	_update_catalog_selection()
	_rebuild_grid()
	_refresh_selection()


func _on_upgrade_pressed() -> void:
	if not _selected_instance_id.is_empty():
		upgrade_building_requested.emit(_selected_instance_id)


func _refresh_selection() -> void:
	_upgrade_button.visible = false
	if not _selected_instance_id.is_empty():
		var placement: Dictionary = CONSTRUCTION_MANAGER_SCRIPT.new().find_placement_by_id(
			state.get("construction", {}),
			_selected_instance_id
		)
		if placement.is_empty():
			_selected_instance_id = ""
		else:
			var definition: Dictionary = state["building_definitions"][placement["building_id"]]
			var level := int(placement["level"])
			_selection_title.text = String(definition["name"])
			_selection_info.text = "Lv.%d/%d\nIncome: %d gold/day\n%s" % [
				level,
				int(definition["max_level"]),
				int(definition["income_gold"]) * level,
				_upgrade_cost_text(definition, level)
			]
			_upgrade_button.visible = true
			_upgrade_button.disabled = level >= int(definition["max_level"])
			return

	if not _selected_building_id.is_empty():
		var definition: Dictionary = state["building_definitions"][_selected_building_id]
		_selection_title.text = "Place %s" % definition["name"]
		_selection_info.text = "%s\nBuild cost: %s" % [
			definition.get("description", ""),
			_cost_text(definition.get("build_cost", {}))
		]
		return

	_selection_title.text = "Construction"
	_selection_info.text = "Select a building type or click an existing building."


func _update_catalog_selection() -> void:
	for building_id: String in _catalog_buttons:
		var button: Button = _catalog_buttons[building_id]
		button.button_pressed = building_id == _selected_building_id


func _on_building_hovered(instance_id: String) -> void:
	var placement: Dictionary = CONSTRUCTION_MANAGER_SCRIPT.new().find_placement_by_id(
		state["construction"],
		instance_id
	)
	if placement.is_empty():
		return
	var definition: Dictionary = state["building_definitions"][placement["building_id"]]
	_hovered_instance_id = instance_id
	_tooltip_label.text = String(definition["name"])
	_tooltip.visible = true
	_tooltip.move_to_front()


func _on_building_unhovered(instance_id: String) -> void:
	if _hovered_instance_id != instance_id:
		return
	_hovered_instance_id = ""
	_tooltip.visible = false


func _upgrade_cost_text(definition: Dictionary, level: int) -> String:
	if level >= int(definition["max_level"]):
		return "Max level"
	return "Upgrade cost: %s" % _cost_text(definition.get("upgrade_costs", {}).get(str(level), {}))


func _cost_text(cost: Dictionary) -> String:
	if cost.is_empty():
		return "Free"
	var parts: Array[String] = []
	for item_id: String in cost:
		var item_name: String = state.get("items", {}).get(item_id, {}).get("name", item_id)
		parts.append("%s x%d" % [item_name, int(cost[item_id])])
	return ", ".join(parts)
