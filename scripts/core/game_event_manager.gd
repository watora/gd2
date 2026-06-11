class_name GameEventManager
extends Node

const TIMELINE_EVENTS_CONFIG := "res://data/config/timeline_events.json"

var _events: Array[Dictionary] = []


func load_data() -> void:
	_events.clear()
	var config := _load_json(TIMELINE_EVENTS_CONFIG)
	for event_data: Dictionary in config.get("events", []):
		if _is_valid_event(event_data):
			_events.append(event_data)


func due_events_for_day(day: int, triggered_event_ids: Array) -> Array[Dictionary]:
	var due_events: Array[Dictionary] = []
	for event_data: Dictionary in _events:
		if not event_data.has("day"):
			continue
		var event_id := String(event_data["id"])
		if int(event_data["day"]) == day and not triggered_event_ids.has(event_id):
			due_events.append(event_data.duplicate(true))
	return due_events


func event_by_id(event_id: String, triggered_event_ids: Array) -> Dictionary:
	if triggered_event_ids.has(event_id):
		return {}
	for event_data: Dictionary in _events:
		if String(event_data.get("id", "")) == event_id:
			return event_data.duplicate(true)
	return {}


func _is_valid_event(event_data: Dictionary) -> bool:
	if not event_data.has("id"):
		push_warning("Timeline event is missing id.")
		return false
	if not event_data.has("lines") or not (event_data["lines"] is Array):
		push_warning("Timeline event %s is missing dialogue lines." % event_data.get("id", "unknown"))
		return false
	return true


func _load_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	push_error("Failed to load JSON config: %s" % path)
	return {}
