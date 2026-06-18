class_name ManagementScreen
extends Control

# Displays shared state and forwards player intent. Construction state changes
# remain owned by MainController and ConstructionManager.
signal start_dungeon_requested
signal next_day_requested
signal building_place_requested(building_id: String, cell: Vector2i)
signal building_upgrade_requested(instance_id: String)

const CHARACTER_STATUS_PANEL_SCENE := preload("res://scenes/ui/character_status_panel.tscn")

const ITEM_LABELS := {
	"ancient_shard": "AncientShardLabel",
	"iron_ore": "IronOreLabel",
	"glowing_moss": "GlowingMossLabel",
	"machine_gear": "MachineGearLabel",
	"healing_potion": "HealingPotionLabel"
}

var state: Dictionary
var _journal_labels: Array[Label] = []
var _character_status_panel: Variant

@onready var _day_label: Label = %DayLabel
@onready var _gold_label: Label = %GoldLabel
@onready var _dungeon_label: Label = %DungeonLabel
@onready var _income_label: Label = %IncomeLabel
@onready var _start_dungeon_button: Button = %StartDungeonButton
@onready var _character_button: Button = %CharacterButton
@onready var _next_day_button: Button = %NextDayButton
@onready var _construction_board: Control = %ConstructionBoard


func setup(new_state: Dictionary) -> void:
	state = new_state
	if is_inside_tree():
		_setup_character_status_panel()
		_construction_board.setup(state)
		refresh()


func _ready() -> void:
	for index: int in range(8):
		_journal_labels.append(get_node("%%JournalLabel%d" % index))
	_start_dungeon_button.pressed.connect(func() -> void: start_dungeon_requested.emit())
	_character_button.pressed.connect(_open_character_panel)
	_next_day_button.pressed.connect(func() -> void: next_day_requested.emit())
	_construction_board.place_building_requested.connect(
		func(building_id: String, cell: Vector2i) -> void:
			building_place_requested.emit(building_id, cell)
	)
	_construction_board.upgrade_building_requested.connect(
		func(instance_id: String) -> void:
			building_upgrade_requested.emit(instance_id)
	)
	_create_character_status_panel()
	_construction_board.setup(state)
	refresh()


func refresh() -> void:
	if state.is_empty():
		return
	_day_label.text = "Day %d" % state["day"]
	_gold_label.text = "Gold: %d" % state["gold"]
	_dungeon_label.text = "Dungeon: %s" % ("Done" if state["dungeon_used_today"] else "Available")
	_income_label.text = "Expected daily income: %d gold" % _calculate_income()
	_refresh_inventory()
	_refresh_journal()
	_construction_board.refresh()
	if _character_status_panel != null:
		_character_status_panel.refresh()


func _refresh_inventory() -> void:
	for item_id: String in ITEM_LABELS:
		var label: Label = get_node("%" + ITEM_LABELS[item_id])
		label.text = "%s x%d" % [_item_name(item_id), int(state["inventory"].get(item_id, 0))]


func _refresh_journal() -> void:
	for index: int in range(_journal_labels.size()):
		_journal_labels[index].text = (
			state["journal"][index] if index < state["journal"].size() else ""
		)


func _calculate_income() -> int:
	var total := 0
	var definitions: Dictionary = state.get("building_definitions", {})
	for placement: Dictionary in state.get("construction", {}).get("placements", []):
		var definition: Dictionary = definitions.get(String(placement["building_id"]), {})
		total += int(definition.get("income_gold", 0)) * int(placement.get("level", 1))
	return total


func _open_character_panel() -> void:
	_setup_character_status_panel()
	_character_status_panel.open()


func _create_character_status_panel() -> void:
	if _character_status_panel != null:
		return
	_character_status_panel = CHARACTER_STATUS_PANEL_SCENE.instantiate()
	add_child(_character_status_panel)
	_setup_character_status_panel()


func _setup_character_status_panel() -> void:
	if _character_status_panel == null or state.is_empty():
		return
	_character_status_panel.setup(state)


func _item_name(item_id: String) -> String:
	return state.get("items", {}).get(item_id, {}).get("name", item_id)
