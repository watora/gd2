class_name EventDialog
extends Control

# Modal dialogue player for timeline and story events. It is kept above the
# current screen by MainController and emits when all configured lines are done.
signal dialog_finished(event_id: String)

@export var default_portrait: Texture2D

var _event_data: Dictionary = {}
var _lines: Array = []
var _line_index := 0

@onready var _title_label: Label = %EventTitleLabel
@onready var _speaker_name_label: Label = %SpeakerNameLabel
@onready var _dialogue_label: Label = %DialogueLabel
@onready var _left_portrait: TextureRect = %LeftPortrait
@onready var _right_portrait: TextureRect = %RightPortrait
@onready var _next_button: Button = %EventNextButton
@onready var _close_button: Button = %EventCloseButton


func _ready() -> void:
	_next_button.pressed.connect(_advance_line)
	_close_button.pressed.connect(_finish_dialog)


func show_event(event_data: Dictionary) -> void:
	# Event data comes from timeline_events.json and is duplicated by
	# GameEventManager before reaching this UI.
	_event_data = event_data
	_lines = event_data.get("lines", [])
	_line_index = 0
	_title_label.text = String(event_data.get("title", "Event"))
	_apply_portraits(event_data)
	visible = true
	_refresh_line()


func is_dialog_open() -> bool:
	return visible


func _advance_line() -> void:
	if _line_index >= _lines.size() - 1:
		_finish_dialog()
		return
	_line_index += 1
	_refresh_line()


func _finish_dialog() -> void:
	var event_id := String(_event_data.get("id", ""))
	visible = false
	_event_data = {}
	_lines = []
	_line_index = 0
	dialog_finished.emit(event_id)


func _refresh_line() -> void:
	if _lines.is_empty():
		_speaker_name_label.text = ""
		_dialogue_label.text = ""
		_next_button.text = "Close"
		return

	var line: Dictionary = _lines[_line_index]
	_speaker_name_label.text = String(line.get("speaker", "Narrator"))
	_dialogue_label.text = String(line.get("text", ""))
	_next_button.text = "Close" if _line_index >= _lines.size() - 1 else "Next"
	_refresh_active_portrait(String(line.get("side", "left")))


func _apply_portraits(event_data: Dictionary) -> void:
	_left_portrait.texture = _portrait_from_path(String(event_data.get("left_portrait", "")))
	_right_portrait.texture = _portrait_from_path(String(event_data.get("right_portrait", "")))


func _portrait_from_path(path: String) -> Texture2D:
	if not path.is_empty():
		var resource := load(path)
		if resource is Texture2D:
			return resource
	return default_portrait


func _refresh_active_portrait(active_side: String) -> void:
	var active_color := Color(1, 1, 1, 1)
	var inactive_color := Color(0.45, 0.48, 0.55, 1)
	_left_portrait.modulate = active_color if active_side == "left" else inactive_color
	_right_portrait.modulate = active_color if active_side == "right" else inactive_color
