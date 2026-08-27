extends Node
## Autoload: the player's party (max 3 creatures). State changes go through
## named methods only; instantiable without the scene tree for tests.

signal party_changed

const MAX_PARTY := 6

var members: Array[CreatureInstance] = []


func reset() -> void:
	members.clear()
	party_changed.emit()


func is_full() -> bool:
	return members.size() >= MAX_PARTY


func size() -> int:
	return members.size()


func add_member(creature: CreatureInstance) -> bool:
	if creature == null or is_full():
		return false
	members.append(creature)
	party_changed.emit()
	return true


func heal_all() -> void:
	for member in members:
		member.heal_full()
	party_changed.emit()


func first_conscious() -> CreatureInstance:
	for member in members:
		if not member.is_fainted():
			return member
	return null


func has_conscious() -> bool:
	return first_conscious() != null


func to_dicts() -> Array:
	var result: Array = []
	for member in members:
		result.append(member.to_dict())
	return result


## registry must expose get_creature(id) -> CreatureDef (DataRegistry or a test double).
func load_from(saved_members: Array, registry: Object) -> void:
	members.clear()
	for entry: Variant in saved_members:
		var data := Dictionary(entry)
		var def: CreatureDef = registry.get_creature(String(data.get("creature_id", "")))
		if def == null:
			continue
		if members.size() < MAX_PARTY:
			members.append(CreatureInstance.from_dict(data, def))
	party_changed.emit()
