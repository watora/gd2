class_name CharacterManager
extends Node

# Loads character and skill configuration, then normalizes character records so
# the rest of the demo can rely on required combat and growth fields.
const CHARACTERS_CONFIG := "res://data/config/characters.json"
const SKILLS_CONFIG := "res://data/config/skills.json"
const DEFAULT_SPEED := 100

var character_config: Dictionary = {}
var skill_config: Dictionary = {}


func load_data() -> void:
	character_config = _load_json(CHARACTERS_CONFIG)
	skill_config = _load_json(SKILLS_CONFIG)


func initial_characters() -> Array:
	var characters: Array = character_config.get("characters", []).duplicate(true)
	for character: Dictionary in characters:
		_normalize_character(character)
	return characters


func skills() -> Dictionary:
	return skill_config.duplicate(true)


func character_skill_ids(character: Dictionary) -> Array:
	return character.get("skills", [])


func skill_data(skill_id: String) -> Dictionary:
	return skill_config.get(skill_id, {})


func has_skill(skill_id: String) -> bool:
	return skill_config.has(skill_id)


func _normalize_character(character: Dictionary) -> void:
	# Config files may omit demo-era fields. Fill them here instead of scattering
	# defaults across battle, management, and character UI code.
	if not character.has("speed"):
		character["speed"] = DEFAULT_SPEED
	character["speed"] = max(1, int(character["speed"]))
	if not character.has("talent_points"):
		character["talent_points"] = 0
	if not character.has("learned_talents"):
		character["learned_talents"] = []
	if not character.has("talents"):
		character["talents"] = []
	if not character.has("skills"):
		character["skills"] = []
	var valid_skills: Array[String] = []
	for skill_id: String in character.get("skills", []):
		if has_skill(skill_id):
			valid_skills.append(skill_id)
	character["skills"] = valid_skills


func _load_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	push_error("Failed to load JSON config: %s" % path)
	return {}
