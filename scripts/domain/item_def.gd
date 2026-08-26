class_name ItemDef
extends RefCounted
## Immutable item definition loaded from res://data/items/items.json.

const KIND_HEAL := "heal"
const KIND_CAPTURE := "capture"

var id: String = ""
var display_name: String = ""
var description: String = ""
var kind: String = KIND_HEAL
var amount: int = 0
var usable_in_battle: bool = false
var usable_in_field: bool = false


static func from_dict(item_id: String, data: Dictionary) -> ItemDef:
	var def := ItemDef.new()
	def.id = item_id
	def.display_name = String(data.get("display_name", item_id))
	def.description = String(data.get("description", ""))
	def.kind = String(data.get("kind", KIND_HEAL))
	def.amount = int(data.get("amount", 0))
	def.usable_in_battle = bool(data.get("usable_in_battle", false))
	def.usable_in_field = bool(data.get("usable_in_field", false))
	return def
