class_name ManagementScreen
extends Control

signal start_dungeon_requested
signal next_day_requested
signal building_action_requested(building_id: String)

const ITEM_NAMES := {
	"ancient_shard": "古代碎片",
	"iron_ore": "铁矿石",
	"glowing_moss": "发光苔藓",
	"machine_gear": "机关齿轮"
}

const STAT_NAMES := {
	"hp": "HP",
	"mp": "MP",
	"strength": "力量",
	"agility": "敏捷",
	"intelligence": "智力"
}

var state: Dictionary
var _day_label: Label
var _gold_label: Label
var _dungeon_label: Label
var _income_label: Label
var _inventory_list: VBoxContainer
var _building_list: VBoxContainer
var _journal_list: VBoxContainer
var _start_dungeon_button: Button
var _character_panel: PanelContainer
var _character_list: VBoxContainer


func setup(new_state: Dictionary) -> void:
	state = new_state
	if is_inside_tree():
		_refresh()


func _ready() -> void:
	_build_ui()
	_refresh()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.color = Color(0.09, 0.10, 0.13, 1.0)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	var title := Label.new()
	title.text = "边境据点"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	root.add_child(title)

	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 16)
	root.add_child(stats)

	_day_label = _make_stat_label()
	_gold_label = _make_stat_label()
	_dungeon_label = _make_stat_label()
	_income_label = _make_stat_label()
	stats.add_child(_day_label)
	stats.add_child(_gold_label)
	stats.add_child(_dungeon_label)
	stats.add_child(_income_label)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 10)
	root.add_child(actions)

	_start_dungeon_button = Button.new()
	_start_dungeon_button.text = "进入地下城"
	_start_dungeon_button.pressed.connect(func() -> void: start_dungeon_requested.emit())
	actions.add_child(_start_dungeon_button)

	var character_button := Button.new()
	character_button.text = "角色状态"
	character_button.pressed.connect(_open_character_panel)
	actions.add_child(character_button)

	var next_day_button := Button.new()
	next_day_button.text = "结束当天并结算收入"
	next_day_button.pressed.connect(func() -> void: next_day_requested.emit())
	actions.add_child(next_day_button)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	root.add_child(body)

	_building_list = VBoxContainer.new()
	_building_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_building_list.add_theme_constant_override("separation", 10)
	body.add_child(_make_panel("建筑", _building_list))

	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(300, 0)
	side.add_theme_constant_override("separation", 10)
	body.add_child(side)

	_inventory_list = VBoxContainer.new()
	_inventory_list.add_theme_constant_override("separation", 6)
	side.add_child(_make_panel("库存", _inventory_list))

	_journal_list = VBoxContainer.new()
	_journal_list.add_theme_constant_override("separation", 6)
	var journal_panel := _make_panel("日志", _journal_list)
	journal_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(journal_panel)

	_build_character_panel()


func _refresh() -> void:
	if state.is_empty() or _day_label == null:
		return

	_day_label.text = "第 %d 天" % state["day"]
	_gold_label.text = "金币：%d" % state["gold"]
	_dungeon_label.text = "今日地下城：%s" % ("已探索" if state["dungeon_used_today"] else "可进入")
	_income_label.text = "预计日收入：%d 金币" % _calculate_income()
	_start_dungeon_button.disabled = state["dungeon_used_today"]

	_refresh_inventory()
	_refresh_buildings()
	_refresh_journal()


func _refresh_inventory() -> void:
	_clear_children(_inventory_list)
	for item_id: String in ITEM_NAMES:
		var label := Label.new()
		label.text = "%s x%d" % [ITEM_NAMES[item_id], state["inventory"].get(item_id, 0)]
		_inventory_list.add_child(label)


func _refresh_buildings() -> void:
	_clear_children(_building_list)
	for building_id: String in state["buildings"]:
		var building: Dictionary = state["buildings"][building_id]
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 5)
		row.add_theme_constant_override("margin_bottom", 4)

		var name_label := Label.new()
		name_label.add_theme_font_size_override("font_size", 20)
		name_label.text = "%s  %s" % [building["name"], _building_level_text(building)]
		row.add_child(name_label)

		var desc_label := Label.new()
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.text = "%s 每日收益：%d 金币。" % [building["description"], int(building["income_gold"]) * max(1, int(building["level"]))]
		row.add_child(desc_label)

		var action_row := HBoxContainer.new()
		action_row.add_theme_constant_override("separation", 8)
		row.add_child(action_row)

		var cost_label := Label.new()
		cost_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cost_label.text = _building_cost_text(building)
		action_row.add_child(cost_label)

		var action_button := Button.new()
		action_button.text = _building_button_text(building)
		action_button.disabled = _is_building_done(building)
		action_button.pressed.connect(func() -> void: building_action_requested.emit(building_id))
		action_row.add_child(action_button)

		var separator := HSeparator.new()
		_building_list.add_child(row)
		_building_list.add_child(separator)


func _refresh_journal() -> void:
	_clear_children(_journal_list)
	for line: String in state["journal"]:
		var label := Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.text = line
		_journal_list.add_child(label)


func _build_character_panel() -> void:
	_character_panel = PanelContainer.new()
	_character_panel.visible = false
	_character_panel.custom_minimum_size = Vector2(430, 0)
	_character_panel.anchor_left = 0.5
	_character_panel.anchor_right = 0.5
	_character_panel.anchor_top = 0.5
	_character_panel.anchor_bottom = 0.5
	_character_panel.offset_left = -215
	_character_panel.offset_right = 215
	_character_panel.offset_top = -230
	_character_panel.offset_bottom = 230
	add_child(_character_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	_character_panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)

	var title := Label.new()
	title.text = "角色状态"
	title.add_theme_font_size_override("font_size", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_button := Button.new()
	close_button.text = "关闭"
	close_button.pressed.connect(_close_character_panel)
	header.add_child(close_button)

	_character_list = VBoxContainer.new()
	_character_list.add_theme_constant_override("separation", 10)
	root.add_child(_character_list)


func _open_character_panel() -> void:
	_refresh_character_panel()
	_character_panel.visible = true


func _close_character_panel() -> void:
	_character_panel.visible = false


func _refresh_character_panel() -> void:
	_clear_children(_character_list)
	for character: Dictionary in state["characters"]:
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 4)

		var name_label := Label.new()
		name_label.text = "%s  /  %s" % [character["name"], character["role"]]
		name_label.add_theme_font_size_override("font_size", 18)
		row.add_child(name_label)

		var stats_label := Label.new()
		stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stats_label.text = _character_stats_text(character)
		row.add_child(stats_label)

		_character_list.add_child(row)
		_character_list.add_child(HSeparator.new())


func _character_stats_text(character: Dictionary) -> String:
	var parts: Array[String] = []
	for stat_id: String in STAT_NAMES:
		parts.append("%s %d" % [STAT_NAMES[stat_id], int(character[stat_id])])
	return " / ".join(parts)


func _calculate_income() -> int:
	var total := 0
	for building_id: String in state["buildings"]:
		var building: Dictionary = state["buildings"][building_id]
		if building["built"]:
			total += int(building["income_gold"]) * int(building["level"])
	return total


func _building_level_text(building: Dictionary) -> String:
	if not building["built"]:
		return "未建造"
	return "Lv.%d/%d" % [building["level"], building["max_level"]]


func _building_cost_text(building: Dictionary) -> String:
	if _is_building_done(building):
		return "已满级"
	var cost: Dictionary = building["build_cost"] if not building["built"] else building["upgrade_costs"][building["level"]]
	if cost.is_empty():
		return "无需材料"
	var parts: Array[String] = []
	for item_id: String in cost:
		parts.append("%s x%d" % [ITEM_NAMES[item_id], cost[item_id]])
	return "消耗：" + "，".join(parts)


func _building_button_text(building: Dictionary) -> String:
	if not building["built"]:
		return "建造"
	if _is_building_done(building):
		return "满级"
	return "升级"


func _is_building_done(building: Dictionary) -> bool:
	return building["built"] and int(building["level"]) >= int(building["max_level"])


func _make_stat_label() -> Label:
	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	return label


func _make_panel(title: String, content: Control) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 22)
	root.add_child(label)
	root.add_child(content)
	return panel


func _clear_children(node: Node) -> void:
	for child: Node in node.get_children():
		child.queue_free()
