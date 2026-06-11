class_name WorldScreen
extends Control

signal location_selected(location_data: Dictionary)
signal return_requested

const WORLD_MAP_CONFIG := "res://data/config/world_map.json"
const WORLD_LAYOUT_SIZE := Vector2(1152.0, 648.0)

var _config: Dictionary = {}
var _locations: Dictionary = {}
var _selected_location: Dictionary = {}
var _location_buttons: Dictionary = {}
var _background_texture: Texture2D

@onready var _map_layer: Control = %MapLayer
@onready var _map_image: TextureRect = %MapImage
@onready var _title_label: Label = %TitleLabel
@onready var _description_label: Label = %DescriptionLabel
@onready var _enter_button: Button = %EnterLocationButton
@onready var _return_button: Button = %ReturnBaseButton


func setup(_state: Dictionary) -> void:
	if is_inside_tree():
		_load_world_map()
		_refresh()


func _ready() -> void:
	_enter_button.pressed.connect(_enter_selected_location)
	_return_button.pressed.connect(func() -> void: return_requested.emit())
	_load_world_map()
	_refresh()


func _load_world_map() -> void:
	_config = _load_json(WORLD_MAP_CONFIG)
	_locations.clear()
	for location_data: Dictionary in _config.get("locations", []):
		var location_id := String(location_data.get("id", ""))
		if location_id != "":
			_locations[location_id] = location_data
	_background_texture = _texture_from_path(String(_config.get("background_texture", "")))


func _refresh() -> void:
	_title_label.text = String(_config.get("title", "World Map"))
	_map_image.texture = _background_texture
	_description_label.text = "Choose a destination."
	_enter_button.disabled = true
	_rebuild_location_buttons()


func _rebuild_location_buttons() -> void:
	for button: Button in _location_buttons.values():
		button.queue_free()
	_location_buttons.clear()

	for location_id: String in _locations:
		var location_data: Dictionary = _locations[location_id]
		var button := Button.new()
		button.name = "%s_button" % location_id
		button.text = String(location_data.get("name", location_id))
		_apply_location_button_anchors(button, location_data)
		button.pressed.connect(_select_location.bind(location_id))
		_map_layer.add_child(button, true)
		_location_buttons[location_id] = button


func _select_location(location_id: String) -> void:
	_selected_location = _locations.get(location_id, {})
	if _selected_location.is_empty():
		_description_label.text = "Choose a destination."
		_enter_button.disabled = true
		return
	_description_label.text = "%s: %s" % [
		_selected_location.get("name", location_id),
		_selected_location.get("description", "No destination notes.")
	]
	_enter_button.disabled = false


func _enter_selected_location() -> void:
	if _selected_location.is_empty():
		return
	location_selected.emit(_selected_location.duplicate(true))


func _apply_location_button_anchors(button: Button, location_data: Dictionary) -> void:
	var point_position := _vector2_from_config(location_data.get("position", [0, 0]))
	var point_size := _vector2_from_config(location_data.get("size", [150, 44]))
	button.anchor_left = clampf(point_position.x / WORLD_LAYOUT_SIZE.x, 0.0, 1.0)
	button.anchor_top = clampf(point_position.y / WORLD_LAYOUT_SIZE.y, 0.0, 1.0)
	button.anchor_right = clampf((point_position.x + point_size.x) / WORLD_LAYOUT_SIZE.x, 0.0, 1.0)
	button.anchor_bottom = clampf((point_position.y + point_size.y) / WORLD_LAYOUT_SIZE.y, 0.0, 1.0)
	button.offset_left = 0.0
	button.offset_top = 0.0
	button.offset_right = 0.0
	button.offset_bottom = 0.0


func _vector2_from_config(value: Variant) -> Vector2:
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO


func _texture_from_path(path: String) -> Texture2D:
	if path == "":
		return null
	var texture := load(path)
	if texture is Texture2D:
		return texture
	push_error("Failed to load world map texture: %s" % path)
	return null


func _load_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	push_error("Failed to load JSON config: %s" % path)
	return {}
