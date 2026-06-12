class_name ManagementScreen
extends Control

# Base-management UI for the current demo loop. It displays the shared state and
# emits intent signals; MainController performs the actual state mutations.
signal start_dungeon_requested
signal next_day_requested
signal building_action_requested(building_id: String)

const CHARACTER_STATUS_PANEL_SCENE := preload("res://scenes/ui/character_status_panel.tscn")

const STAT_NAMES := {
	"hp": "HP",
	"mp": "MP",
	"strength": "STR",
	"agility": "AGI",
	"intelligence": "INT",
	"speed": "SPD"
}

const ITEM_LABELS := {
	"ancient_shard": "AncientShardLabel",
	"iron_ore": "IronOreLabel",
	"glowing_moss": "GlowingMossLabel",
	"machine_gear": "MachineGearLabel",
	"healing_potion": "HealingPotionLabel"
}

var state: Dictionary
var _building_rows := {}
var _journal_labels: Array[Label] = []
var _character_name_labels: Array[Label] = []
var _character_stat_labels: Array[Label] = []
var _character_status_panel: Variant

@onready var _day_label: Label = %DayLabel
@onready var _gold_label: Label = %GoldLabel
@onready var _dungeon_label: Label = %DungeonLabel
@onready var _income_label: Label = %IncomeLabel
@onready var _start_dungeon_button: Button = %StartDungeonButton
@onready var _character_button: Button = %CharacterButton
@onready var _next_day_button: Button = %NextDayButton
@onready var _character_panel: PanelContainer = %CharacterPanel
@onready var _close_character_button: Button = %CloseCharacterButton


func setup(new_state: Dictionary) -> void:
	state = new_state
	if is_inside_tree():
		_setup_character_status_panel()
		_refresh()


func _ready() -> void:
	_cache_scene_nodes()
	_connect_static_buttons()
	_create_character_status_panel()
	_refresh()


func _cache_scene_nodes() -> void:
	# Building rows are fixed in the scene, while their labels and action buttons
	# are refreshed from the building config stored in state.
	_building_rows = {
		"guild_hall": %GuildHallRow,
		"workshop": %WorkshopRow,
		"herb_garden": %HerbGardenRow
	}
	for index: int in range(8):
		_journal_labels.append(get_node("%%JournalLabel%d" % index))
	_character_name_labels = [%CharacterOneNameLabel, %CharacterTwoNameLabel]
	_character_stat_labels = [%CharacterOneStatsLabel, %CharacterTwoStatsLabel]


func _connect_static_buttons() -> void:
	_start_dungeon_button.pressed.connect(func() -> void: start_dungeon_requested.emit())
	_character_button.pressed.connect(_open_character_panel)
	_next_day_button.pressed.connect(func() -> void: next_day_requested.emit())
	_close_character_button.pressed.connect(_close_character_panel)
	for building_id: String in _building_rows:
		var row: VBoxContainer = _building_rows[building_id]
		var button: Button = row.get_node("ActionRow/ActionButton")
		button.pressed.connect(_on_building_button_pressed.bind(building_id))


func _on_building_button_pressed(building_id: String) -> void:
	building_action_requested.emit(building_id)


func _refresh() -> void:
	if state.is_empty():
		return
	_day_label.text = "Day %d" % state["day"]
	_gold_label.text = "Gold: %d" % state["gold"]
	_dungeon_label.text = "Dungeon: %s" % ("Done" if state["dungeon_used_today"] else "Available")
	_income_label.text = "Expected daily income: %d gold" % _calculate_income()
	_start_dungeon_button.disabled = false
	_refresh_inventory()
	_refresh_buildings()
	_refresh_journal()
	if _character_status_panel != null:
		_character_status_panel.refresh()
	if _character_panel.visible:
		_refresh_character_panel()


func _refresh_inventory() -> void:
	for item_id: String in ITEM_LABELS:
		var label: Label = get_node("%" + ITEM_LABELS[item_id])
		label.text = "%s x%d" % [_item_name(item_id), int(state["inventory"].get(item_id, 0))]


func _refresh_buildings() -> void:
	for building_id: String in _building_rows:
		var building: Dictionary = state["buildings"][building_id]
		var row: VBoxContainer = _building_rows[building_id]
		var name_label: Label = row.get_node("NameLabel")
		var desc_label: Label = row.get_node("DescLabel")
		var cost_label: Label = row.get_node("ActionRow/CostLabel")
		var action_button: Button = row.get_node("ActionRow/ActionButton")

		name_label.text = "%s  %s" % [building["name"], _building_level_text(building)]
		desc_label.text = "%s Daily income: %d gold." % [
			building["description"],
			int(building["income_gold"]) * max(1, int(building["level"]))
		]
		cost_label.text = _building_cost_text(building)
		action_button.text = _building_button_text(building)
		action_button.disabled = _is_building_done(building)


func _refresh_journal() -> void:
	for index: int in range(_journal_labels.size()):
		var label := _journal_labels[index]
		label.text = state["journal"][index] if index < state["journal"].size() else ""


func _open_character_panel() -> void:
	_setup_character_status_panel()
	_character_status_panel.open()


func _close_character_panel() -> void:
	_character_panel.visible = false


func _create_character_status_panel() -> void:
	if _character_status_panel != null:
		return
	# The reusable panel is instantiated once and kept as a child so base, world,
	# dungeon, and battle screens can share the same character-detail behavior.
	_character_status_panel = CHARACTER_STATUS_PANEL_SCENE.instantiate()
	add_child(_character_status_panel)
	_setup_character_status_panel()


func _setup_character_status_panel() -> void:
	if _character_status_panel == null or state.is_empty():
		return
	_character_status_panel.setup(state)


func _refresh_character_panel() -> void:
	for index: int in range(_character_name_labels.size()):
		if index >= state["characters"].size():
			_character_name_labels[index].text = ""
			_character_stat_labels[index].text = ""
			continue
		var character: Dictionary = state["characters"][index]
		_character_name_labels[index].text = "%s  /  %s  /  Lv.%d  EXP %d/%d" % [
			character["name"],
			character["role"],
			int(character.get("level", 1)),
			int(character.get("exp", 0)),
			int(character.get("next_exp", 20))
		]
		_character_stat_labels[index].text = _character_stats_text(character)


func _character_stats_text(character: Dictionary) -> String:
	var parts: Array[String] = []
	for stat_id: String in STAT_NAMES:
		parts.append("%s %d" % [STAT_NAMES[stat_id], int(character[stat_id])])
	return " / ".join(parts) + "\nSkills: " + _character_skills_text(character)


func _character_skills_text(character: Dictionary) -> String:
	var names: Array[String] = []
	for skill_id: String in character.get("skills", []):
		names.append(state.get("skills", {}).get(skill_id, {}).get("name", skill_id))
	return "None" if names.is_empty() else ", ".join(names)


func _calculate_income() -> int:
	var total := 0
	for building_id: String in state["buildings"]:
		var building: Dictionary = state["buildings"][building_id]
		if bool(building["built"]):
			total += int(building["income_gold"]) * int(building["level"])
	return total


func _building_level_text(building: Dictionary) -> String:
	if not bool(building["built"]):
		return "Not built"
	return "Lv.%d/%d" % [building["level"], building["max_level"]]


func _building_cost_text(building: Dictionary) -> String:
	if _is_building_done(building):
		return "Max level"
	var cost := _building_action_cost(building)
	if cost.is_empty():
		return "No materials required"
	var parts: Array[String] = []
	for item_id: String in cost:
		parts.append("%s x%d" % [_item_name(item_id), int(cost[item_id])])
	return "Cost: " + ", ".join(parts)


func _building_button_text(building: Dictionary) -> String:
	if not bool(building["built"]):
		return "Build"
	if _is_building_done(building):
		return "Max"
	return "Upgrade"


func _building_action_cost(building: Dictionary) -> Dictionary:
	if not bool(building["built"]):
		return building.get("build_cost", {})
	return building.get("upgrade_costs", {}).get(str(building["level"]), {})


func _is_building_done(building: Dictionary) -> bool:
	return bool(building["built"]) and int(building["level"]) >= int(building["max_level"])


func _item_name(item_id: String) -> String:
	return state.get("items", {}).get(item_id, {}).get("name", item_id)
