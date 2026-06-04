class_name MainController
extends Control

const ManagementScreenScene := preload("res://scenes/management/management_screen.tscn")
const DungeonScreenScene := preload("res://scenes/dungeon/dungeon_screen.tscn")

var game_state: Dictionary = {
	"day": 1,
	"gold": 40,
	"dungeon_used_today": false,
	"characters": [
		{
			"name": "星野明",
			"role": "见习探索者",
			"hp": 38,
			"mp": 16,
			"strength": 7,
			"agility": 8,
			"intelligence": 6
		},
		{
			"name": "雾岛澪",
			"role": "遗迹术士",
			"hp": 28,
			"mp": 30,
			"strength": 4,
			"agility": 6,
			"intelligence": 9
		}
	],
	"inventory": {
		"ancient_shard": 0,
		"iron_ore": 0,
		"glowing_moss": 0,
		"machine_gear": 0
	},
	"flags": {},
	"journal": ["第 1 天：据点刚刚建立，今天可以探索一次地下城。"],
	"buildings": {
		"guild_hall": {
			"name": "冒险者公会",
			"description": "组织探索队伍，提供稳定金币收入。",
			"built": true,
			"level": 1,
			"max_level": 3,
			"income_gold": 12,
			"build_cost": {},
			"upgrade_costs": {
				1: {"iron_ore": 2},
				2: {"iron_ore": 3, "ancient_shard": 1}
			}
		},
		"workshop": {
			"name": "修复工坊",
			"description": "修复地下城带回的器物，增加每日金币收入。",
			"built": false,
			"level": 0,
			"max_level": 2,
			"income_gold": 18,
			"build_cost": {"machine_gear": 1, "iron_ore": 1},
			"upgrade_costs": {
				1: {"machine_gear": 1, "ancient_shard": 1}
			}
		},
		"herb_garden": {
			"name": "药草温室",
			"description": "培育发光苔藓，每日将药草加工为金币。",
			"built": false,
			"level": 0,
			"max_level": 2,
			"income_gold": 15,
			"build_cost": {"glowing_moss": 2},
			"upgrade_costs": {
				1: {"glowing_moss": 3, "iron_ore": 1}
			}
		}
	}
}

var _current_screen: Control


func _ready() -> void:
	_show_management()


func _show_management() -> void:
	_clear_screen()
	var screen: Control = ManagementScreenScene.instantiate()
	_current_screen = screen
	add_child(screen)
	screen.setup(game_state)
	screen.start_dungeon_requested.connect(_show_dungeon)
	screen.next_day_requested.connect(_advance_day)
	screen.building_action_requested.connect(_handle_building_action)


func _show_dungeon() -> void:
	if game_state["dungeon_used_today"]:
		_add_journal("今天已经探索过地下城了。")
		_show_management()
		return

	_clear_screen()
	var screen: Control = DungeonScreenScene.instantiate()
	_current_screen = screen
	add_child(screen)
	screen.setup(game_state)
	screen.run_finished.connect(_finish_dungeon_run)


func _finish_dungeon_run(rewards: Dictionary, flags: Dictionary, summary: Array[String]) -> void:
	game_state["dungeon_used_today"] = true
	_add_rewards(rewards)
	for flag_name: String in flags:
		game_state["flags"][flag_name] = flags[flag_name]
	for line: String in summary:
		_add_journal(line)
	_show_management()


func _advance_day() -> void:
	var income: int = _calculate_daily_income()
	game_state["gold"] += income
	game_state["day"] += 1
	game_state["dungeon_used_today"] = false
	_add_journal("第 %d 天结算：据点建筑产出 %d 金币。" % [game_state["day"] - 1, income])
	_add_journal("第 %d 天开始：地下城探索次数已刷新。" % game_state["day"])
	_show_management()


func _handle_building_action(building_id: String) -> void:
	var building: Dictionary = game_state["buildings"][building_id]
	var cost: Dictionary = {}
	var action_name := ""

	if not building["built"]:
		cost = building["build_cost"]
		action_name = "建造"
	else:
		if int(building["level"]) >= int(building["max_level"]):
			_add_journal("%s 已达到最高等级。" % building["name"])
			_show_management()
			return
		cost = building["upgrade_costs"][building["level"]]
		action_name = "升级"

	if not _has_items(cost):
		_add_journal("%s%s失败：地下城材料不足。" % [action_name, building["name"]])
		_show_management()
		return

	_pay_items(cost)
	if not building["built"]:
		building["built"] = true
		building["level"] = 1
	else:
		building["level"] += 1

	_add_journal("%s%s完成，当前等级 Lv.%d。" % [action_name, building["name"], building["level"]])
	_show_management()


func _calculate_daily_income() -> int:
	var total := 0
	for building_id: String in game_state["buildings"]:
		var building: Dictionary = game_state["buildings"][building_id]
		if building["built"]:
			total += int(building["income_gold"]) * int(building["level"])
	return total


func _add_rewards(rewards: Dictionary) -> void:
	if rewards.has("gold"):
		game_state["gold"] += int(rewards["gold"])
	for item_id: String in game_state["inventory"]:
		if rewards.has(item_id):
			game_state["inventory"][item_id] += int(rewards[item_id])


func _has_items(cost: Dictionary) -> bool:
	for item_id: String in cost:
		if int(game_state["inventory"].get(item_id, 0)) < int(cost[item_id]):
			return false
	return true


func _pay_items(cost: Dictionary) -> void:
	for item_id: String in cost:
		game_state["inventory"][item_id] -= int(cost[item_id])


func _add_journal(text: String) -> void:
	game_state["journal"].push_front(text)
	if game_state["journal"].size() > 8:
		game_state["journal"].resize(8)


func _clear_screen() -> void:
	if is_instance_valid(_current_screen):
		var old_screen := _current_screen
		_current_screen = null
		remove_child(old_screen)
		old_screen.queue_free()
