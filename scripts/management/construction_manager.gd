class_name ConstructionManager
extends RefCounted

const MIN_GRID_SIZE := 1
const MAX_GRID_SIZE := 10


func create_state(config: Dictionary) -> Dictionary:
	var grid: Dictionary = config.get("grid", {})
	var placements: Array = config.get("initial_placements", []).duplicate(true)
	var next_instance_id := 1
	for placement: Dictionary in placements:
		var instance_id := String(placement.get("id", ""))
		if instance_id.begins_with("building_"):
			next_instance_id = max(next_instance_id, int(instance_id.trim_prefix("building_")) + 1)
	return {
		"width": clampi(int(grid.get("width", 5)), MIN_GRID_SIZE, MAX_GRID_SIZE),
		"height": clampi(int(grid.get("height", 5)), MIN_GRID_SIZE, MAX_GRID_SIZE),
		"next_instance_id": next_instance_id,
		"placements": placements
	}


func place_building(game_state: Dictionary, building_id: String, cell: Vector2i) -> Dictionary:
	var definitions: Dictionary = game_state.get("building_definitions", {})
	var construction: Dictionary = game_state.get("construction", {})
	if not definitions.has(building_id):
		return _failure("Unknown building type.")
	if not _is_cell_in_bounds(construction, cell):
		return _failure("The selected construction cell is outside the map.")
	if not find_placement_at(construction, cell).is_empty():
		return _failure("That construction cell is already occupied.")

	var definition: Dictionary = definitions[building_id]
	var cost: Dictionary = definition.get("build_cost", {})
	var inventory: Dictionary = game_state.get("inventory", {})
	if not _has_items(inventory, cost):
		return _failure("Build %s failed: dungeon materials are not enough." % definition["name"])

	_pay_items(inventory, cost)
	var instance_id := "building_%d" % int(construction.get("next_instance_id", 1))
	construction["next_instance_id"] = int(construction.get("next_instance_id", 1)) + 1
	var placements: Array = construction.get("placements", [])
	placements.append({
		"id": instance_id,
		"building_id": building_id,
		"cell_x": cell.x,
		"cell_y": cell.y,
		"level": 1
	})
	construction["placements"] = placements
	return {
		"ok": true,
		"instance_id": instance_id,
		"message": "Built %s at (%d, %d)." % [definition["name"], cell.x + 1, cell.y + 1]
	}


func upgrade_building(game_state: Dictionary, instance_id: String) -> Dictionary:
	var placement := find_placement_by_id(game_state.get("construction", {}), instance_id)
	if placement.is_empty():
		return _failure("The selected building no longer exists.")

	var definitions: Dictionary = game_state.get("building_definitions", {})
	var definition: Dictionary = definitions.get(String(placement["building_id"]), {})
	if definition.is_empty():
		return _failure("The selected building definition is missing.")

	var level := int(placement.get("level", 1))
	if level >= int(definition.get("max_level", 1)):
		return _failure("%s is already at max level." % definition["name"])

	var cost: Dictionary = definition.get("upgrade_costs", {}).get(str(level), {})
	var inventory: Dictionary = game_state.get("inventory", {})
	if not _has_items(inventory, cost):
		return _failure("Upgrade %s failed: dungeon materials are not enough." % definition["name"])

	_pay_items(inventory, cost)
	placement["level"] = level + 1
	return {
		"ok": true,
		"instance_id": instance_id,
		"message": "Upgraded %s to Lv.%d." % [definition["name"], placement["level"]]
	}


func set_grid_size(construction: Dictionary, width: int, height: int) -> bool:
	var next_width := clampi(width, MIN_GRID_SIZE, MAX_GRID_SIZE)
	var next_height := clampi(height, MIN_GRID_SIZE, MAX_GRID_SIZE)
	for placement: Dictionary in construction.get("placements", []):
		if int(placement["cell_x"]) >= next_width or int(placement["cell_y"]) >= next_height:
			return false
	construction["width"] = next_width
	construction["height"] = next_height
	return true


func calculate_daily_income(game_state: Dictionary) -> int:
	var definitions: Dictionary = game_state.get("building_definitions", {})
	var total := 0
	for placement: Dictionary in game_state.get("construction", {}).get("placements", []):
		var definition: Dictionary = definitions.get(String(placement["building_id"]), {})
		total += int(definition.get("income_gold", 0)) * int(placement.get("level", 1))
	return total


func find_placement_at(construction: Dictionary, cell: Vector2i) -> Dictionary:
	for placement: Dictionary in construction.get("placements", []):
		if int(placement["cell_x"]) == cell.x and int(placement["cell_y"]) == cell.y:
			return placement
	return {}


func find_placement_by_id(construction: Dictionary, instance_id: String) -> Dictionary:
	for placement: Dictionary in construction.get("placements", []):
		if String(placement.get("id", "")) == instance_id:
			return placement
	return {}


func _is_cell_in_bounds(construction: Dictionary, cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 \
		and cell.x < int(construction.get("width", 0)) \
		and cell.y < int(construction.get("height", 0))


func _has_items(inventory: Dictionary, cost: Dictionary) -> bool:
	for item_id: String in cost:
		if int(inventory.get(item_id, 0)) < int(cost[item_id]):
			return false
	return true


func _pay_items(inventory: Dictionary, cost: Dictionary) -> void:
	for item_id: String in cost:
		inventory[item_id] = int(inventory.get(item_id, 0)) - int(cost[item_id])


func _failure(message: String) -> Dictionary:
	return {"ok": false, "message": message}
