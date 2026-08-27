class_name SkillDef
extends RefCounted
## Immutable skill definition loaded from res://data/skills/skills.json.

var id: String = ""
var display_name: String = ""
var description: String = ""
var element: String = "neutral"
var power: int = 0
var accuracy: float = 1.0
var effect: String = ""         # 輔助效果：slow/shield/break/warm/dodge/cleanse


static func from_dict(skill_id: String, data: Dictionary) -> SkillDef:
	var def := SkillDef.new()
	def.id = skill_id
	def.display_name = String(data.get("display_name", skill_id))
	def.description = String(data.get("description", ""))
	def.element = String(data.get("element", "neutral"))
	def.power = int(data.get("power", 0))
	def.accuracy = clampf(float(data.get("accuracy", 1.0)), 0.0, 1.0)
	def.effect = String(data.get("effect", ""))
	return def
