class_name EncounterSystem
extends RefCounted
## Rolls random encounters from a data-driven table.
## RNG is injected so tests can pin the seed.

var rate: float = 0.0
var entries: Array[Dictionary] = []

var _rng: RandomNumberGenerator


func _init(table: Dictionary, rng: RandomNumberGenerator) -> void:
	rate = clampf(float(table.get("rate", 0.0)), 0.0, 1.0)
	for entry: Variant in Array(table.get("entries", [])):
		entries.append(Dictionary(entry))
	_rng = rng


## Called once per step on encounter terrain.
## Returns {} for no encounter, else {"creature_id": String, "level": int}.
func roll_step() -> Dictionary:
	if entries.is_empty() or _rng.randf() >= rate:
		return {}
	var total_weight := 0
	for entry in entries:
		total_weight += maxi(0, int(entry.get("weight", 1)))
	if total_weight <= 0:
		return {}
	var pick := _rng.randi_range(1, total_weight)
	var accumulated := 0
	for entry in entries:
		accumulated += maxi(0, int(entry.get("weight", 1)))
		if pick <= accumulated:
			var min_level := int(entry.get("min_level", 2))
			var max_level := maxi(min_level, int(entry.get("max_level", min_level)))
			return {
				"creature_id": String(entry.get("creature_id", "")),
				"level": _rng.randi_range(min_level, max_level),
			}
	return {}
