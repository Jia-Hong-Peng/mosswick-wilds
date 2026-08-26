extends Node
## Autoload: versioned JSON save files under user:// with an atomic write
## strategy (write .tmp → verify → swap). Corrupt files never crash the game;
## the .tmp file doubles as a recovery fallback.

const SCHEMA_VERSION := 1
const SAVE_PATH := "user://save.json"
const TMP_SUFFIX := ".tmp"


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(SAVE_PATH + TMP_SUFFIX)


func collect_payload() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"map_id": GameState.current_map_id,
		"player": {
			"x": GameState.player_cell.x,
			"y": GameState.player_cell.y,
			"facing": Directions.to_name(GameState.player_facing),
		},
		"party": PartyService.to_dicts(),
		"inventory": InventoryService.to_dict(),
		"flags": EventFlagStore.to_dict(),
		"settings": {
			"master_volume": AudioManager.master_volume,
		},
	}


func apply_payload(payload: Dictionary) -> void:
	var player_data := Dictionary(payload.get("player", {}))
	GameState.set_world_position(
		String(payload.get("map_id", GameState.START_MAP_ID)),
		Vector2i(int(player_data.get("x", 1)), int(player_data.get("y", 1))),
		Directions.from_name(String(player_data.get("facing", "down")))
	)
	PartyService.load_from(Array(payload.get("party", [])), DataRegistry)
	InventoryService.load_from(Dictionary(payload.get("inventory", {})))
	EventFlagStore.load_from(Dictionary(payload.get("flags", {})))
	var settings := Dictionary(payload.get("settings", {}))
	AudioManager.set_master_volume(float(settings.get("master_volume", AudioManager.master_volume)))


func save_game() -> bool:
	return write_payload(SAVE_PATH, collect_payload())


func load_game() -> bool:
	var payload := read_payload(SAVE_PATH)
	if payload.is_empty():
		return false
	apply_payload(payload)
	return true


static func write_payload(path: String, payload: Dictionary) -> bool:
	var tmp_path := path + TMP_SUFFIX
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot open save file for writing: " + tmp_path)
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	# Verify the temp file parses before touching the existing save.
	var check: Variant = JSON.parse_string(FileAccess.get_file_as_string(tmp_path))
	if not (check is Dictionary):
		push_error("Save verification failed for: " + tmp_path)
		return false
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	return DirAccess.rename_absolute(tmp_path, path) == OK


## Returns {} when no readable save exists. Falls back to the .tmp file if the
## main file is missing or corrupt (e.g. interrupted write).
static func read_payload(path: String) -> Dictionary:
	for candidate: String in [path, path + TMP_SUFFIX]:
		if not FileAccess.file_exists(candidate):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(candidate))
		if parsed is Dictionary:
			var migrated := migrate(Dictionary(parsed))
			if not migrated.is_empty():
				return migrated
	return {}


## Save schema migration hook. Unknown or future versions are rejected safely.
static func migrate(data: Dictionary) -> Dictionary:
	var version := int(data.get("schema_version", 0))
	if version <= 0 or version > SCHEMA_VERSION:
		return {}
	# Future migrations: while version < SCHEMA_VERSION, upgrade step by step.
	return data
