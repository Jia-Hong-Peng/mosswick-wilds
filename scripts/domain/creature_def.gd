class_name CreatureDef
extends RefCounted
## Immutable creature definition loaded from res://data/creatures/creatures.json.

var id: String = ""
var display_name: String = ""
var description: String = ""
var element: String = "neutral"
var base_stats: Dictionary = {}
var skill_ids: Array[String] = []
var capture_rate: float = 0.3
var sprite_path: String = ""
var back_path: String = ""
var hit_path: String = ""
var icon_path: String = ""


static func from_dict(data: Dictionary) -> CreatureDef:
	var def := CreatureDef.new()
	def.id = String(data.get("id", ""))
	def.display_name = String(data.get("display_name", def.id))
	def.description = String(data.get("description", ""))
	def.element = String(data.get("element", "neutral"))
	def.base_stats = Dictionary(data.get("base_stats", {}))
	for skill_id: Variant in Array(data.get("skills", [])):
		def.skill_ids.append(String(skill_id))
	def.capture_rate = float(data.get("capture_rate", 0.3))
	def.sprite_path = String(data.get("sprite_path", ""))
	def.back_path = String(data.get("back_path", def.sprite_path))
	def.hit_path = String(data.get("hit_path", def.sprite_path))
	def.icon_path = String(data.get("icon_path", def.sprite_path))
	return def


func base_stat(stat_name: String, fallback: int = 1) -> int:
	return int(base_stats.get(stat_name, fallback))
