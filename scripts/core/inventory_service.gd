extends Node
## Autoload: the player's bag. Counts per item id; changes go through
## named methods only; instantiable without the scene tree for tests.

signal inventory_changed

var _counts: Dictionary = {}


func reset() -> void:
	_counts.clear()
	inventory_changed.emit()


func add_item(item_id: String, amount: int = 1) -> void:
	if amount <= 0:
		return
	_counts[item_id] = count(item_id) + amount
	inventory_changed.emit()


func count(item_id: String) -> int:
	return int(_counts.get(item_id, 0))


## Deducts one unit. Returns false (and changes nothing) when none are left.
func use_item(item_id: String) -> bool:
	var current := count(item_id)
	if current <= 0:
		return false
	if current == 1:
		_counts.erase(item_id)
	else:
		_counts[item_id] = current - 1
	inventory_changed.emit()
	return true


func item_ids() -> Array[String]:
	var ids: Array[String] = []
	for key: Variant in _counts:
		ids.append(String(key))
	ids.sort()
	return ids


func to_dict() -> Dictionary:
	return _counts.duplicate()


func load_from(data: Dictionary) -> void:
	_counts.clear()
	for key: Variant in data:
		var amount := int(data[key])
		if amount > 0:
			_counts[String(key)] = amount
	inventory_changed.emit()
