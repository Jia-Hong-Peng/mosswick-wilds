extends Node
## Autoload: named boolean story/event flags. Prevents repeated one-time events.

signal flag_changed(flag_name: String)

var _flags: Dictionary = {}


func reset() -> void:
	_flags.clear()


func set_flag(flag_name: String) -> void:
	if _flags.has(flag_name):
		return
	_flags[flag_name] = true
	flag_changed.emit(flag_name)


func has_flag(flag_name: String) -> bool:
	return _flags.has(flag_name)


func to_dict() -> Dictionary:
	return _flags.duplicate()


func load_from(data: Dictionary) -> void:
	_flags.clear()
	for key: Variant in data:
		if bool(data[key]):
			_flags[String(key)] = true
