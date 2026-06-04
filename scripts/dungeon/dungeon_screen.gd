class_name DungeonScreen
extends Control

signal run_finished(rewards: Dictionary, flags: Dictionary, summary: Array[String])

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
var run_rewards: Dictionary = {
	"gold": 0,
	"ancient_shard": 0,
	"iron_ore": 0,
	"glowing_moss": 0,
	"machine_gear": 0
}
var run_flags: Dictionary = {}
var run_summary: Array[String] = []
var resolved_events: Dictionary = {}

var _map_layer: Control
var _event_panel: PanelContainer
var _event_title: Label
var _event_body: Label
var _choice_list: VBoxContainer
var _reward_label: Label


func setup(new_state: Dictionary) -> void:
	state = new_state


func _ready() -> void:
	_build_ui()
	_spawn_event_points()
	_update_reward_label()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.color = Color(0.045, 0.055, 0.07, 1.0)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	_map_layer = Control.new()
	_map_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_map_layer)
	_draw_map_background()

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)

	var root := VBoxContainer.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var top_bar := HBoxContainer.new()
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_theme_constant_override("separation", 12)
	root.add_child(top_bar)

	var title := Label.new()
	title.text = "旧王都地下城"
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(title)

	_reward_label = Label.new()
	_reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_reward_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(_reward_label)

	var finish_button := Button.new()
	finish_button.text = "结束探索并返回据点"
	finish_button.pressed.connect(_finish_run)
	top_bar.add_child(finish_button)

	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(spacer)

	_build_event_panel()


func _draw_map_background() -> void:
	var base := ColorRect.new()
	base.color = Color(0.12, 0.13, 0.16, 1.0)
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map_layer.add_child(base)

	var paths := [
		Rect2(120, 240, 820, 44),
		Rect2(260, 140, 44, 320),
		Rect2(520, 220, 44, 250),
		Rect2(720, 120, 44, 350),
		Rect2(200, 430, 620, 38)
	]
	for path_rect: Rect2 in paths:
		var path := ColorRect.new()
		path.color = Color(0.30, 0.27, 0.22, 1.0)
		path.position = path_rect.position
		path.size = path_rect.size
		_map_layer.add_child(path)

	for index: int in range(8):
		var ruin := ColorRect.new()
		ruin.color = Color(0.19, 0.20, 0.23, 1.0)
		ruin.position = Vector2(90 + index * 115, 95 + (index % 3) * 118)
		ruin.size = Vector2(70, 50)
		_map_layer.add_child(ruin)


func _build_event_panel() -> void:
	_event_panel = PanelContainer.new()
	_event_panel.visible = false
	_event_panel.custom_minimum_size = Vector2(420, 0)
	_event_panel.anchor_left = 1.0
	_event_panel.anchor_right = 1.0
	_event_panel.anchor_top = 0.0
	_event_panel.anchor_bottom = 1.0
	_event_panel.offset_left = -460
	_event_panel.offset_right = -24
	_event_panel.offset_top = 84
	_event_panel.offset_bottom = -84
	add_child(_event_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	_event_panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	_event_title = Label.new()
	_event_title.add_theme_font_size_override("font_size", 24)
	root.add_child(_event_title)

	_event_body = Label.new()
	_event_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_event_body)

	_choice_list = VBoxContainer.new()
	_choice_list.add_theme_constant_override("separation", 8)
	root.add_child(_choice_list)


func _spawn_event_points() -> void:
	_add_event_point("sunken_well", "沉没古井", Vector2(250, 180))
	_add_event_point("collapsed_mine", "塌陷矿道", Vector2(560, 260))
	_add_event_point("sealed_gate", "封印石门", Vector2(770, 150))
	_add_event_point("shadow_patrol", "黑影巡逻", Vector2(420, 430))
	_add_event_point("old_shrine", "旧神龛", Vector2(820, 450))


func _add_event_point(event_id: String, label_text: String, position: Vector2) -> void:
	var button := Button.new()
	button.text = label_text
	button.position = position
	button.custom_minimum_size = Vector2(120, 42)
	button.tooltip_text = "调查事件点"
	button.pressed.connect(func() -> void: _open_event(event_id))
	_map_layer.add_child(button)


func _open_event(event_id: String) -> void:
	if resolved_events.has(event_id):
		_event_title.text = "已调查"
		_event_body.text = "这里已经没有新的线索。"
		_set_choices([{"text": "关闭", "method": "_close_event"}])
		_event_panel.visible = true
		return

	var event_data := _event_data(event_id)
	_event_title.text = event_data["title"]
	_event_body.text = event_data["body"]
	_set_choices(event_data["choices"])
	_event_panel.visible = true


func _set_choices(choices: Array) -> void:
	_clear_children(_choice_list)
	for choice: Dictionary in choices:
		var button := Button.new()
		var requirements: Dictionary = choice.get("requirements", {})
		button.text = choice["text"] + _requirements_text(requirements)
		button.disabled = not _meets_requirements(requirements)
		button.pressed.connect(func() -> void: _resolve_choice(choice))
		_choice_list.add_child(button)


func _resolve_choice(choice: Dictionary) -> void:
	if choice.has("method"):
		call(choice["method"])
		return

	var requirements: Dictionary = choice.get("requirements", {})
	if not _meets_requirements(requirements):
		_event_body.text = "当前队伍属性不足，无法执行这个选择。"
		return

	var event_id: String = choice["event_id"]
	resolved_events[event_id] = true
	if choice.has("rewards"):
		_add_run_rewards(choice["rewards"])
	if choice.has("flags"):
		for flag_name: String in choice["flags"]:
			run_flags[flag_name] = choice["flags"][flag_name]
	if choice.has("summary"):
		run_summary.append(choice["summary"])
	_event_title.text = "调查完成"
	_event_body.text = choice.get("result", "探索队记录下这里的变化。")
	_set_choices([{"text": "继续探索", "method": "_close_event"}])
	_update_reward_label()


func _event_data(event_id: String) -> Dictionary:
	match event_id:
		"sunken_well":
			return {
				"title": "沉没古井",
				"body": "井底有微弱的蓝绿色光。绳梯还能承重，但井壁上刻着警告。",
				"choices": [
					{
						"text": "放下绳梯采集苔藓",
						"event_id": event_id,
						"rewards": {"glowing_moss": 2},
						"summary": "地下城：从沉没古井采集到发光苔藓。",
						"result": "队员采下几束发光苔藓，井底的光随之暗淡。"
					},
					{
						"text": "沿湿滑井壁攀下",
						"event_id": event_id,
						"requirements": {"agility": 8},
						"rewards": {"glowing_moss": 1, "ancient_shard": 1},
						"summary": "地下城：敏捷通过，探索队深入古井底部。",
						"result": "队伍借助灵巧动作抵达井底暗格，找到一块古代碎片。"
					},
					{
						"text": "捞取井底金属箱",
						"event_id": event_id,
						"rewards": {"machine_gear": 1},
						"summary": "地下城：在古井里找到机关齿轮。",
						"result": "金属箱里装着保存完好的机关齿轮。"
					}
				]
			}
		"collapsed_mine":
			return {
				"title": "塌陷矿道",
				"body": "矿道被碎石堵住，缝隙里能看到铁矿脉。支撑柱旁还有一只老旧拉杆。",
				"choices": [
					{
						"text": "采集裸露矿脉",
						"event_id": event_id,
						"rewards": {"iron_ore": 3},
						"summary": "地下城：从塌陷矿道采到铁矿石。",
						"result": "采矿声在废墟里回荡，背包里多了沉重的铁矿石。"
					},
					{
						"text": "搬开堵路巨石",
						"event_id": event_id,
						"requirements": {"strength": 8},
						"rewards": {"iron_ore": 4, "machine_gear": 1},
						"summary": "地下城：力量通过，清开矿道深处的落石。",
						"result": "巨石被移开，矿道深处露出更多铁矿和一枚机关齿轮。"
					},
					{
						"text": "拉下支撑柱旁的机关",
						"event_id": event_id,
						"flags": {"east_gate_open": true},
						"rewards": {"iron_ore": 1},
						"summary": "地下城：启动矿道机关，远处石门传来响动。",
						"result": "远处传来石门移动的低响，队伍顺手带走了一块铁矿。"
					}
				]
			}
		"sealed_gate":
			var gate_open := bool(run_flags.get("east_gate_open", false)) or bool(state["flags"].get("east_gate_open", false))
			return {
				"title": "封印石门",
				"body": "石门上刻着旧王都的徽记。%s" % ("矿道机关已经解除了一部分封印。" if gate_open else "门缝里有光，但封印还没有松动。"),
				"choices": [
					{
						"text": "推开石门调查密室" if gate_open else "记录符文后撤离",
						"event_id": event_id,
						"rewards": {"ancient_shard": 2} if gate_open else {"ancient_shard": 1},
						"summary": "地下城：调查封印石门并获得古代碎片。",
						"result": "石门后的石台上散落着可用于建设的古代碎片。" if gate_open else "队伍拓下符文，带回一小块脱落的古代碎片。"
					},
					{
						"text": "解析封印术式",
						"event_id": event_id,
						"requirements": {"intelligence": 9},
						"flags": {"east_gate_open": true},
						"rewards": {"ancient_shard": 2},
						"summary": "地下城：智力通过，解析封印并记录开门方式。",
						"result": "术式被成功解析，石门封印松动，队伍取下一组高纯度古代碎片。"
					}
				]
			}
		"shadow_patrol":
			return {
				"title": "黑影巡逻",
				"body": "几道黑影在废墟街道间徘徊。战斗系统尚未开放，本次 demo 会以事件方式处理遭遇。",
				"choices": [
					{
						"text": "绕开巡逻并搜刮补给",
						"event_id": event_id,
						"rewards": {"gold": 15, "glowing_moss": 1},
						"summary": "地下城：避开黑影巡逻，带回一些金币和苔藓。",
						"result": "队伍没有开战，沿侧巷找到了一只遗落钱袋。"
					},
					{
						"text": "穿过巡逻空隙",
						"event_id": event_id,
						"requirements": {"agility": 9},
						"rewards": {"gold": 25, "machine_gear": 1},
						"summary": "地下城：敏捷通过，队伍穿过巡逻线找到隐藏补给。",
						"result": "队伍抓住短暂空隙穿过街巷，带回更高价值的补给。"
					},
					{
						"text": "标记敌人位置，暂不战斗",
						"event_id": event_id,
						"flags": {"battle_marker_found": true},
						"rewards": {"gold": 8},
						"summary": "地下城：记录了一个未来可扩展为战斗的遭遇点。",
						"result": "地图上新增了战斗标记，当前版本不会进入战斗。"
					}
				]
			}
		"old_shrine":
			return {
				"title": "旧神龛",
				"body": "神龛旁的石灯仍有余温。献上从废墟中找到的碎片，也许能换来指引。",
				"choices": [
					{
						"text": "调查石灯底座",
						"event_id": event_id,
						"rewards": {"ancient_shard": 1, "machine_gear": 1},
						"summary": "地下城：在旧神龛找到古代碎片和机关齿轮。",
						"result": "石灯底座弹开，里面藏着一枚齿轮和碎片。"
					},
					{
						"text": "注入魔力点亮神龛",
						"event_id": event_id,
						"requirements": {"mp": 25, "intelligence": 8},
						"rewards": {"ancient_shard": 3},
						"summary": "地下城：魔力与智力通过，旧神龛显露隐藏供品。",
						"result": "蓝白色火光照亮神龛，隐藏供品中有三块古代碎片。"
					}
				]
			}
	return {}


func _meets_requirements(requirements: Dictionary) -> bool:
	if requirements.is_empty():
		return true
	for stat_id: String in requirements:
		if _best_party_stat(stat_id) < int(requirements[stat_id]):
			return false
	return true


func _best_party_stat(stat_id: String) -> int:
	var best_value := 0
	for character: Dictionary in state["characters"]:
		best_value = max(best_value, int(character.get(stat_id, 0)))
	return best_value


func _requirements_text(requirements: Dictionary) -> String:
	if requirements.is_empty():
		return ""
	var parts: Array[String] = []
	for stat_id: String in requirements:
		parts.append("%s %d" % [STAT_NAMES.get(stat_id, stat_id), int(requirements[stat_id])])
	return "  [需要 %s]" % " / ".join(parts)


func _add_run_rewards(rewards: Dictionary) -> void:
	for reward_id: String in rewards:
		run_rewards[reward_id] = int(run_rewards.get(reward_id, 0)) + int(rewards[reward_id])


func _update_reward_label() -> void:
	var parts: Array[String] = []
	if int(run_rewards["gold"]) > 0:
		parts.append("金币 x%d" % run_rewards["gold"])
	for item_id: String in ITEM_NAMES:
		if int(run_rewards[item_id]) > 0:
			parts.append("%s x%d" % [ITEM_NAMES[item_id], run_rewards[item_id]])
	_reward_label.text = "本次收获：" + ("无" if parts.is_empty() else "，".join(parts))


func _finish_run() -> void:
	if run_summary.is_empty():
		run_summary.append("地下城：队伍谨慎撤回，没有带回新发现。")
	run_finished.emit(run_rewards, run_flags, run_summary)


func _close_event() -> void:
	_event_panel.visible = false


func _clear_children(node: Node) -> void:
	for child: Node in node.get_children():
		child.queue_free()
