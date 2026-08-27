class_name CreatureInstance
extends RefCounted
## A concrete creature owned by the player or encountered in the wild.
## Stats are derived from a CreatureDef at a given level; HP is mutable.

var creature_id: String = ""
var display_name: String = ""
var element: String = "neutral"
var level: int = 1
var exp: int = 0
var max_hp: int = 1
var hp: int = 1
var attack: int = 1
var defense: int = 1
var speed: int = 1
var skill_ids: Array[String] = []
var capture_rate: float = 0.3
var sprite_path: String = ""
var back_path: String = ""
var hit_path: String = ""
var icon_path: String = ""


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
	creature.back_path = def.back_path
	creature.hit_path = def.hit_path
	creature.icon_path = def.icon_path
	return creature


## Linear growth: +12% of the base value per level above 1.
static func scaled_stat(base_value: int, at_level: int) -> int:
	return maxi(1, base_value + int(float(base_value) * float(at_level - 1) * 0.12))


## 升到下一級所需經驗（經典曲線：隨等級遞增）
static func exp_to_next(at_level: int) -> int:
	return 20 + at_level * 15


## 擊倒對手獲得的經驗
static func exp_reward(enemy_level: int) -> int:
	return 12 + enemy_level * 9


## 獲得經驗；回傳升了幾級（呈現層依此播訊息）。
## def 用來重算成長後的能力值；升級時 HP 增量直接補上（不回滿）。
func gain_exp(amount: int, def: CreatureDef) -> int:
	exp += maxi(0, amount)
	var levels_gained := 0
	while exp >= exp_to_next(level) and level < 50:
		exp -= exp_to_next(level)
		level += 1
		levels_gained += 1
		var old_max := max_hp
		max_hp = scaled_stat(def.base_stat("max_hp", 30), level)
		attack = scaled_stat(def.base_stat("attack", 8), level)
		defense = scaled_stat(def.base_stat("defense", 8), level)
		speed = scaled_stat(def.base_stat("speed", 8), level)
		hp = clampi(hp + (max_hp - old_max), 1, max_hp)
	return levels_gained


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
		"exp": exp,
		"hp": hp,
	}


## Rebuilds an instance from a save dictionary; def must match creature_id.
static func from_dict(data: Dictionary, def: CreatureDef) -> CreatureInstance:
	var creature := from_def(def, int(data.get("level", 1)))
	creature.exp = maxi(0, int(data.get("exp", 0)))
	creature.hp = clampi(int(data.get("hp", creature.max_hp)), 0, creature.max_hp)
	return creature
