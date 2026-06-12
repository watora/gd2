class_name CharacterStatusPanel
extends PanelContainer

# Reusable character detail overlay shared by management, world, and dungeon
# screens. It reads and mutates the shared state directly for talent learning.
const STAT_NAMES := {
	"hp": "HP",
	"max_hp": "Max HP",
	"mp": "MP",
	"max_mp": "Max MP",
	"strength": "STR",
	"agility": "AGI",
	"intelligence": "INT",
	"speed": "SPD"
}
const TALENT_BUTTON_SIZE := Vector2(150, 58)

var state: Dictionary = {}
var _character_buttons: Array[Button] = []
var _talent_nodes: Array[Node] = []
var _selected_character_index := -1
var _showing_talent_tree := false

@onready var _character_list: VBoxContainer = %CharacterList
@onready var _detail_panel: PanelContainer = %CharacterDetailPanel
@onready var _detail_label: Label = %CharacterDetailLabel
@onready var _talent_tree_button: Button = %TalentTreeButton
@onready var _talent_tree_panel: PanelContainer = %TalentTreePanel
@onready var _back_to_detail_button: Button = %BackToDetailButton
@onready var _talent_tree_title: Label = %TalentTreeTitle
@onready var _talent_points_label: Label = %TalentPointsLabel
@onready var _talent_tree_area: Control = %TalentTreeArea
@onready var _talent_info_label: Label = %TalentInfoLabel
@onready var _close_button: Button = %CloseButton


func setup(new_state: Dictionary) -> void:
	state = new_state
	if is_inside_tree():
		_refresh()


func open() -> void:
	if state.is_empty():
		return
	visible = true
	_refresh()
	if _selected_character_index < 0 and not state.get("characters", []).is_empty():
		_select_character(0)


func close() -> void:
	visible = false


func refresh() -> void:
	if visible:
		_refresh()


func _ready() -> void:
	_close_button.pressed.connect(close)
	_talent_tree_button.pressed.connect(_open_talent_tree)
	_back_to_detail_button.pressed.connect(_open_character_detail)
	_refresh()


func _refresh() -> void:
	if state.is_empty():
		return
	_rebuild_character_buttons()
	if _selected_character_index >= state.get("characters", []).size():
		_selected_character_index = -1
	if _selected_character_index >= 0:
		if _showing_talent_tree:
			_show_talent_tree(_selected_character_index)
		else:
			_show_character_detail(_selected_character_index)
	elif not state.get("characters", []).is_empty():
		_talent_tree_button.disabled = true
		_detail_label.text = "Select a character."
	else:
		_talent_tree_button.disabled = true
		_detail_label.text = "No characters recruited."


func _rebuild_character_buttons() -> void:
	for button: Button in _character_buttons:
		button.queue_free()
	_character_buttons.clear()

	var characters: Array = state.get("characters", [])
	for index: int in range(characters.size()):
		var character: Dictionary = characters[index]
		var button := Button.new()
		button.text = "%s  Lv.%d" % [
			character.get("name", "Character"),
			int(character.get("level", 1))
		]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_select_character.bind(index))
		_character_list.add_child(button)
		_character_buttons.append(button)


func _select_character(index: int) -> void:
	if index < 0 or index >= state.get("characters", []).size():
		return
	_selected_character_index = index
	_showing_talent_tree = false
	_show_character_detail(index)


func _show_character_detail(index: int) -> void:
	_detail_panel.visible = true
	_talent_tree_panel.visible = false
	var character: Dictionary = state.get("characters", [])[index]
	_talent_tree_button.disabled = character.get("talents", []).is_empty()
	_detail_label.text = "%s\n%s\n\n%s\n\nSkills\n%s\n\nItems\n%s" % [
		_character_header_text(character),
		_exp_text(character),
		_stats_text(character),
		_skills_text(character),
		_items_text()
	]


func _open_character_detail() -> void:
	_showing_talent_tree = false
	if _selected_character_index >= 0:
		_show_character_detail(_selected_character_index)


func _open_talent_tree() -> void:
	if _selected_character_index < 0:
		return
	_showing_talent_tree = true
	_show_talent_tree(_selected_character_index)


func _show_talent_tree(index: int) -> void:
	_detail_panel.visible = false
	_talent_tree_panel.visible = true
	var character: Dictionary = state.get("characters", [])[index]
	_talent_tree_title.text = "%s Talent Tree" % character.get("name", "Character")
	_talent_points_label.text = "Points: %d" % int(character.get("talent_points", 0))
	_rebuild_talent_tree(character)


func _rebuild_talent_tree(character: Dictionary) -> void:
	for node: Node in _talent_nodes:
		node.queue_free()
	_talent_nodes.clear()

	# Lines are created before buttons so prerequisite links render behind the
	# talent buttons in the same Control area.
	var talents: Array = character.get("talents", [])
	var talent_by_id := _talent_map(talents)
	for talent: Dictionary in talents:
		_add_talent_lines(talent, talent_by_id)
	for talent: Dictionary in talents:
		_add_talent_button(character, talent)
	if talents.is_empty():
		_talent_info_label.text = "No talents configured for this character."
	else:
		_talent_info_label.text = "Learn a root talent first, then unlock connected branches."


func _add_talent_lines(talent: Dictionary, talent_by_id: Dictionary) -> void:
	var target_position := _talent_position(talent) + TALENT_BUTTON_SIZE * 0.5
	for prerequisite_id: String in talent.get("requires", []):
		if not talent_by_id.has(prerequisite_id):
			continue
		var source: Dictionary = talent_by_id[prerequisite_id]
		var source_position := _talent_position(source) + TALENT_BUTTON_SIZE * 0.5
		var line := Line2D.new()
		line.points = PackedVector2Array([source_position, target_position])
		line.width = 2.0
		line.default_color = Color(0.44, 0.48, 0.62, 1.0)
		line.z_index = -1
		_talent_tree_area.add_child(line)
		_talent_nodes.append(line)


func _add_talent_button(character: Dictionary, talent: Dictionary) -> void:
	var button := Button.new()
	var learned := _is_talent_learned(character, String(talent.get("id", "")))
	var can_learn := _can_learn_talent(character, talent)
	button.position = _talent_position(talent)
	button.size = TALENT_BUTTON_SIZE
	button.text = "%s\n%s" % [
		"[Learned]" if learned else ("Learn" if can_learn else "Locked"),
		talent.get("name", "Talent")
	]
	button.disabled = learned or not can_learn
	button.pressed.connect(_learn_talent.bind(String(talent.get("id", ""))))
	button.mouse_entered.connect(_show_talent_info.bind(talent, character))
	_talent_tree_area.add_child(button)
	_talent_nodes.append(button)


func _learn_talent(talent_id: String) -> void:
	if _selected_character_index < 0:
		return
	var character: Dictionary = state.get("characters", [])[_selected_character_index]
	var talent := _talent_by_id(character, talent_id)
	if talent.is_empty() or not _can_learn_talent(character, talent):
		return
	character["talent_points"] = max(0, int(character.get("talent_points", 0)) - 1)
	if not character.has("learned_talents"):
		character["learned_talents"] = []
	var learned_talents: Array = character["learned_talents"]
	learned_talents.append(talent_id)
	# Talent bonuses are applied to runtime character state immediately; this is
	# enough for the demo because the shared state is the active save model.
	_apply_talent_bonus(character, talent)
	_talent_info_label.text = "Learned %s." % talent.get("name", talent_id)
	_show_talent_tree(_selected_character_index)


func _show_talent_info(talent: Dictionary, character: Dictionary) -> void:
	var status := "Learned" if _is_talent_learned(character, String(talent.get("id", ""))) else ("Available" if _can_learn_talent(character, talent) else "Locked")
	_talent_info_label.text = "%s\n%s\nStatus: %s\nRequires: %s" % [
		talent.get("name", "Talent"),
		talent.get("description", "No description."),
		status,
		_requirements_text(talent)
	]


func _talent_map(talents: Array) -> Dictionary:
	var result := {}
	for talent: Dictionary in talents:
		result[String(talent.get("id", ""))] = talent
	return result


func _talent_by_id(character: Dictionary, talent_id: String) -> Dictionary:
	for talent: Dictionary in character.get("talents", []):
		if String(talent.get("id", "")) == talent_id:
			return talent
	return {}


func _can_learn_talent(character: Dictionary, talent: Dictionary) -> bool:
	var talent_id := String(talent.get("id", ""))
	if talent_id == "" or _is_talent_learned(character, talent_id):
		return false
	if int(character.get("talent_points", 0)) <= 0:
		return false
	for prerequisite_id: String in talent.get("requires", []):
		if not _is_talent_learned(character, prerequisite_id):
			return false
	return true


func _is_talent_learned(character: Dictionary, talent_id: String) -> bool:
	return character.get("learned_talents", []).has(talent_id)


func _requirements_text(talent: Dictionary) -> String:
	var requirements: Array = talent.get("requires", [])
	if requirements.is_empty():
		return "None"
	var names: Array[String] = []
	for prerequisite_id: String in requirements:
		names.append(prerequisite_id)
	return ", ".join(names)


func _apply_talent_bonus(character: Dictionary, talent: Dictionary) -> void:
	var stat_bonus: Dictionary = talent.get("stat_bonus", {})
	for stat_id: String in stat_bonus:
		character[stat_id] = int(character.get(stat_id, 0)) + int(stat_bonus[stat_id])


func _talent_position(talent: Dictionary) -> Vector2:
	var position_data: Array = talent.get("position", [0, 0])
	if position_data.size() < 2:
		return Vector2.ZERO
	return Vector2(float(position_data[0]), float(position_data[1]))


func _character_header_text(character: Dictionary) -> String:
	return "%s / %s / Lv.%d" % [
		character.get("name", "Character"),
		character.get("role", "Adventurer"),
		int(character.get("level", 1))
	]


func _exp_text(character: Dictionary) -> String:
	return "EXP %d/%d\nTalent Points: %d" % [
		int(character.get("exp", 0)),
		int(character.get("next_exp", 20)),
		int(character.get("talent_points", 0))
	]


func _stats_text(character: Dictionary) -> String:
	var parts: Array[String] = []
	for stat_id: String in STAT_NAMES:
		parts.append("%s: %d" % [STAT_NAMES[stat_id], int(character.get(stat_id, 0))])
	return "Stats\n" + "\n".join(parts)


func _skills_text(character: Dictionary) -> String:
	var rows: Array[String] = []
	for skill_id: String in character.get("skills", []):
		var skill: Dictionary = state.get("skills", {}).get(skill_id, {})
		var name := String(skill.get("name", skill_id))
		var mp_cost := int(skill.get("mp_cost", 0))
		var description := String(skill.get("description", "No description."))
		rows.append("%s  MP %d\n%s" % [name, mp_cost, description])
	return "None" if rows.is_empty() else "\n\n".join(rows)


func _items_text() -> String:
	var rows: Array[String] = []
	for item_id: String in state.get("inventory", {}):
		var count := int(state.get("inventory", {}).get(item_id, 0))
		if count <= 0:
			continue
		var item: Dictionary = state.get("items", {}).get(item_id, {})
		var name := String(item.get("name", item_id))
		var description := String(item.get("description", ""))
		if description == "":
			rows.append("%s x%d" % [name, count])
		else:
			rows.append("%s x%d - %s" % [name, count, description])
	return "None" if rows.is_empty() else "\n".join(rows)
