class_name CreatureInstance
extends RefCounted
## A concrete creature owned by the player or encountered in the wild.
## Stats are derived from a CreatureDef at a given level; HP is mutable.

var creature_id: String = ""
var display_name: String = ""
var element: String = "neutral"
var level: int = 1
var max_hp: int = 1
var hp: int = 1
var attack: int = 1
var defense: int = 1
var speed: int = 1
var skill_ids: Array[String] = []
var capture_rate: float = 0.3
var sprite_path: String = ""


static func from_def(def: CreatureDef, at_level: int) -> CreatureInstance:
	var creature := CreatureInstance.new()
	creature.creature_id = def.id
	creature.display_name = def.display_name
	creature.element = def.element
	creature.level = maxi(1, at_level)
	creature.max_hp = scaled_stat(def.base_stat("max_hp", 30), creature.level)
	creature.hp = creature.max_hp
	creature.attack = scaled_stat(def.base_stat("attack", 8), creature.level)
	creature.defense = scaled_stat(def.base_stat("defense", 8), creature.level)
	creature.speed = scaled_stat(def.base_stat("speed", 8), creature.level)
	creature.skill_ids = def.skill_ids.duplicate()
	creature.capture_rate = def.capture_rate
	creature.sprite_path = def.sprite_path
	return creature


## Linear growth: +12% of the base value per level above 1.
static func scaled_stat(base_value: int, at_level: int) -> int:
	return maxi(1, base_value + int(float(base_value) * float(at_level - 1) * 0.12))


func is_fainted() -> bool:
	return hp <= 0


func hp_ratio() -> float:
	return float(hp) / float(maxi(1, max_hp))


func apply_damage(amount: int) -> void:
	hp = clampi(hp - maxi(0, amount), 0, max_hp)


func heal(amount: int) -> int:
	var before := hp
	hp = clampi(hp + maxi(0, amount), 0, max_hp)
	return hp - before


func heal_full() -> void:
	hp = max_hp


func to_dict() -> Dictionary:
	return {
		"creature_id": creature_id,
		"level": level,
		"hp": hp,
	}


## Rebuilds an instance from a save dictionary; def must match creature_id.
static func from_dict(data: Dictionary, def: CreatureDef) -> CreatureInstance:
	var creature := from_def(def, int(data.get("level", 1)))
	creature.hp = clampi(int(data.get("hp", creature.max_hp)), 0, creature.max_hp)
	return creature
