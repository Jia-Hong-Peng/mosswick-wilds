extends Node
## Autoload: loads every JSON definition once and exposes typed lookups.
## Instantiable without the scene tree for headless tests (call ensure_loaded()).

const CREATURES_PATH := "res://data/creatures/creatures.json"
const SKILLS_PATH := "res://data/skills/skills.json"
const ITEMS_PATH := "res://data/items/items.json"
const ENCOUNTERS_PATH := "res://data/encounters/encounters.json"
const MAP_INDEX_PATH := "res://data/maps/_index.json"
const MAPS_DIR := "res://data/maps"
const DIALOGUES_PATH := "res://data/dialogue/dialogues.json"
const STARTERS_PATH := "res://data/starters/starters.json"

var creatures: Dictionary = {}
var skills: Dictionary = {}
var items: Dictionary = {}
var encounter_tables: Dictionary = {}
var maps: Dictionary = {}
var dialogues: Dictionary = {}
var starters: Dictionary = {}

var _loaded := false


func _ready() -> void:
	ensure_loaded()


func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var creature_data := read_json_dict(CREATURES_PATH)
	for creature_id: Variant in creature_data:
		creatures[String(creature_id)] = CreatureDef.from_dict(Dictionary(creature_data[creature_id]))
	var skill_data := read_json_dict(SKILLS_PATH)
	for skill_id: Variant in skill_data:
		skills[String(skill_id)] = SkillDef.from_dict(String(skill_id), Dictionary(skill_data[skill_id]))
	var item_data := read_json_dict(ITEMS_PATH)
	for item_id: Variant in item_data:
		items[String(item_id)] = ItemDef.from_dict(String(item_id), Dictionary(item_data[item_id]))
	encounter_tables = read_json_dict(ENCOUNTERS_PATH)
	dialogues = read_json_dict(DIALOGUES_PATH)
	starters = read_json_dict(STARTERS_PATH)
	var index: Variant = read_json_any(MAP_INDEX_PATH)
	if index is Array:
		for map_id: Variant in Array(index):
			var map_path := "%s/%s.json" % [MAPS_DIR, String(map_id)]
			maps[String(map_id)] = MapData.from_dict(String(map_id), read_json_dict(map_path))


static func read_json_any(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("Missing data file: " + path)
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed == null:
		push_error("Invalid JSON in: " + path)
	return parsed


static func read_json_dict(path: String) -> Dictionary:
	var parsed: Variant = read_json_any(path)
	return Dictionary(parsed) if parsed is Dictionary else {}


func get_creature(creature_id: String) -> CreatureDef:
	ensure_loaded()
	return creatures.get(creature_id) as CreatureDef


func get_skill(skill_id: String) -> SkillDef:
	ensure_loaded()
	return skills.get(skill_id) as SkillDef


func get_item(item_id: String) -> ItemDef:
	ensure_loaded()
	return items.get(item_id) as ItemDef


func get_map(map_id: String) -> MapData:
	ensure_loaded()
	return maps.get(map_id) as MapData


func get_encounter_table(table_key: String) -> Dictionary:
	ensure_loaded()
	return Dictionary(encounter_tables.get(table_key, {}))


func get_dialogue(dialogue_id: String) -> Dictionary:
	ensure_loaded()
	return Dictionary(dialogues.get(dialogue_id, {}))


func get_starter(starter_id: String) -> Dictionary:
	ensure_loaded()
	return Dictionary(starters.get(starter_id, {}))


func starter_ids() -> Array[String]:
	ensure_loaded()
	var result: Array[String] = []
	for key: Variant in starters:
		result.append(String(key))
	return result


func make_creature(creature_id: String, at_level: int) -> CreatureInstance:
	var def := get_creature(creature_id)
	if def == null:
		push_error("Unknown creature id: " + creature_id)
		return null
	return CreatureInstance.from_def(def, at_level)


func skills_for(creature: CreatureInstance) -> Array[SkillDef]:
	var result: Array[SkillDef] = []
	for skill_id in creature.skill_ids:
		var skill := get_skill(skill_id)
		if skill != null:
			result.append(skill)
	return result
