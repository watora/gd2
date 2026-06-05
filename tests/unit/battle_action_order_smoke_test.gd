extends SceneTree

const BattleManagerScript := preload("res://scripts/battle/battle_manager.gd")


func _init() -> void:
	var manager: BattleManager = BattleManagerScript.new()
	var state := {
		"characters": [
			{
				"name": "A",
				"hp": 10,
				"max_hp": 10,
				"mp": 0,
				"max_mp": 0,
				"strength": 1,
				"agility": 1,
				"intelligence": 1,
				"speed": 100,
				"skills": []
			},
			{
				"name": "B",
				"hp": 10,
				"max_hp": 10,
				"mp": 0,
				"max_mp": 0,
				"strength": 1,
				"agility": 1,
				"intelligence": 1,
				"speed": 150,
				"skills": []
			}
		],
		"inventory": {},
		"items": {},
		"skills": {}
	}
	manager.start_battle(state, {"battle": {"enemies": []}, "body": "Test battle."})
	var preview: Array[Dictionary] = manager.action_order_preview()
	_assert_order(preview, 0, "B", 66)
	_assert_order(preview, 1, "A", 100)
	_assert_order(preview, 2, "B", 132)
	_assert_order(preview, 3, "B", 198)
	_assert_order(preview, 4, "A", 200)

	manager._advance_action_queue_after_current_actor()
	preview = manager.action_order_preview()
	_assert_order(preview, 0, "A", 34)
	_assert_order(preview, 1, "B", 66)
	_assert_order(preview, 2, "B", 132)
	_assert_order(preview, 3, "A", 134)
	manager.free()
	quit()


func _assert_order(preview: Array[Dictionary], index: int, expected_name: String, expected_value: int) -> void:
	if index >= preview.size():
		push_error("Missing action order entry at index %d." % index)
		quit(1)
		return
	var entry: Dictionary = preview[index]
	if String(entry["name"]) != expected_name or int(entry["action_value"]) != expected_value:
		push_error("Expected %s(%d), got %s(%d)." % [
			expected_name,
			expected_value,
			String(entry["name"]),
			int(entry["action_value"])
		])
		quit(1)
