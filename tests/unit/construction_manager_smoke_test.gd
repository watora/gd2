extends SceneTree

const ConstructionManagerScript := preload("res://scripts/management/construction_manager.gd")


func _init() -> void:
	var manager = ConstructionManagerScript.new()
	var state := {
		"building_definitions": {
			"workshop": {
				"name": "Workshop",
				"max_level": 2,
				"income_gold": 10,
				"build_cost": {"ore": 1},
				"upgrade_costs": {"1": {"ore": 1}}
			}
		},
		"construction": {
			"width": 5,
			"height": 5,
			"next_instance_id": 1,
			"placements": []
		},
		"inventory": {"ore": 4}
	}

	_assert_ok(manager.place_building(state, "workshop", Vector2i(0, 0)))
	_assert_ok(manager.place_building(state, "workshop", Vector2i(1, 0)))
	if state["construction"]["placements"].size() != 2:
		_fail("The same building type should be placeable more than once.")
		return
	if bool(manager.place_building(state, "workshop", Vector2i(1, 0)).get("ok", false)):
		_fail("An occupied cell accepted another building.")
		return

	var first_id: String = state["construction"]["placements"][0]["id"]
	_assert_ok(manager.upgrade_building(state, first_id))
	if int(state["construction"]["placements"][0]["level"]) != 2:
		_fail("Upgrade did not change the selected instance level.")
		return
	if manager.calculate_daily_income(state) != 30:
		_fail("Daily income should include every placed building instance and level.")
		return
	if not manager.set_grid_size(state["construction"], 6, 6):
		_fail("A populated 5x5 map should expand to 6x6.")
		return
	if int(state["construction"]["width"]) != 6 or int(state["construction"]["height"]) != 6:
		_fail("Dynamic grid dimensions were not stored.")
		return
	quit()


func _assert_ok(result: Dictionary) -> void:
	if not bool(result.get("ok", false)):
		_fail(String(result.get("message", "Construction action failed.")))


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
