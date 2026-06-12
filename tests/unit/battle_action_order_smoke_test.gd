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
	_assert_skill_targets_selected_enemy()
	_assert_level_up_grants_talent_point()
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


func _assert_skill_targets_selected_enemy() -> void:
	var manager: BattleManager = BattleManagerScript.new()
	var state := {
		"characters": [
			{
				"name": "Caster",
				"hp": 30,
				"max_hp": 30,
				"mp": 20,
				"max_mp": 20,
				"strength": 3,
				"agility": 1,
				"intelligence": 1,
				"speed": 250,
				"skills": ["test_strike"]
			}
		],
		"inventory": {},
		"items": {},
		"skills": {
			"test_strike": {
				"name": "Test Strike",
				"mp_cost": 1,
				"base_damage": 5,
				"scaling_stat": "strength",
				"power": 2
			}
		}
	}
	manager.start_battle(state, {"battle": {"enemies": ["shadow_wolf", "shadow_wolf"]}, "body": "Test battle."})
	var first_enemy_hp := int(manager.battle_enemies[0]["hp"])
	var second_enemy_hp := int(manager.battle_enemies[1]["hp"])
	var result := manager.use_skill("test_strike", 1)
	var events: Array = result.get("events", [])
	if events.size() < 2 or String(events[0].get("type", "")) != "attack_motion" or String(events[1].get("type", "")) != "damage":
		push_error("Skill target result did not include attack motion followed by damage events.")
		manager.free()
		quit(1)
		return
	if int(manager.battle_enemies[0]["hp"]) != first_enemy_hp:
		push_error("Skill damaged enemy 0 instead of preserving the unselected target.")
		manager.free()
		quit(1)
		return
	if int(manager.battle_enemies[1]["hp"]) >= second_enemy_hp:
		push_error("Skill did not damage selected enemy 1.")
		manager.free()
		quit(1)
		return
	manager.free()


func _assert_level_up_grants_talent_point() -> void:
	var manager: BattleManager = BattleManagerScript.new()
	var character := {
		"name": "Growth Tester",
		"level": 1,
		"exp": 20,
		"next_exp": 20,
		"hp": 10,
		"max_hp": 10,
		"mp": 5,
		"max_mp": 5,
		"strength": 1,
		"agility": 1,
		"intelligence": 1,
		"speed": 100,
		"talent_points": 0
	}
	manager._level_up_character(character)
	if int(character.get("level", 0)) != 2 or int(character.get("talent_points", 0)) != 1:
		push_error("Level up should increase level to 2 and grant 1 talent point.")
		manager.free()
		quit(1)
		return
	manager.free()
