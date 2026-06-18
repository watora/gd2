extends SceneTree

# Headless smoke test for BattleManager timing, target selection, and level-up
# persistence. Run with Godot --headless --script from the project root.
const BattleManagerScript := preload("res://scripts/battle/battle_manager.gd")
const BattleDamageCalculatorScript := preload("res://scripts/battle/battle_damage_calculator.gd")


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
	_assert_exp_summary_lists_each_party_member()
	_assert_damage_calculator_formulas()
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


func _assert_exp_summary_lists_each_party_member() -> void:
	var manager: BattleManager = BattleManagerScript.new()
	manager.battle_party = [
		{
			"name": "Frontliner",
			"level": 1,
			"exp": 0,
			"next_exp": 20,
			"hp": 10,
			"max_hp": 10,
			"mp": 0,
			"max_mp": 0
		},
		{
			"name": "Downed Mage",
			"level": 1,
			"exp": 0,
			"next_exp": 20,
			"hp": 0,
			"max_hp": 10,
			"mp": 0,
			"max_mp": 0
		}
	]
	manager.defeated_enemy_exp_reward = 12
	var exp_summary := manager._award_battle_exp()
	if exp_summary.size() != 2:
		push_error("EXP settlement should include each battle party member.")
		manager.free()
		quit(1)
		return
	if int(exp_summary[0].get("gained_exp", 0)) != 12:
		push_error("Living character should receive the battle EXP reward.")
		manager.free()
		quit(1)
		return
	if int(exp_summary[1].get("gained_exp", 0)) != 0 or bool(exp_summary[1].get("alive", true)):
		push_error("Downed character should be listed with 0 EXP and alive=false.")
		manager.free()
		quit(1)
		return
	manager.free()


func _assert_damage_calculator_formulas() -> void:
	var calculator: RefCounted = BattleDamageCalculatorScript.new()
	var actor := {
		"strength": 4,
		"intelligence": 6
	}
	var skill := {
		"base_damage": 5,
		"scaling_stat": "intelligence",
		"power": 2
	}
	if calculator.basic_attack_damage(actor, "party") != 7:
		push_error("Party basic attack damage should be strength + 3.")
		quit(1)
		return
	if calculator.basic_attack_damage(actor, "enemy") != 6:
		push_error("Enemy basic attack damage should be strength + 2.")
		quit(1)
		return
	if calculator.skill_damage(actor, skill) != 17:
		push_error("Skill damage should be base_damage + scaling stat * power.")
		quit(1)
		return
	if calculator.guarded_damage(7) != 3:
		push_error("Guarded damage should preserve the current integer half-damage behavior.")
		quit(1)
		return
