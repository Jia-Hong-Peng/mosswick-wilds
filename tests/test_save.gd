extends RefCounted
## Save/load: roundtrip consistency, atomic write, corruption tolerance,
## schema version gating, .tmp recovery fallback.

const SaveScript := preload("res://scripts/persistence/save_service.gd")
const TEST_PATH := "user://test_save.json"


func run(t: TestContext) -> void:
	_cleanup()
	_test_roundtrip(t)
	_cleanup()
	_test_corruption(t)
	_cleanup()
	_test_versions(t)
	_cleanup()
	_test_tmp_fallback(t)
	_cleanup()
	_test_service_roundtrip(t)


func _cleanup() -> void:
	for path: String in [TEST_PATH, TEST_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _payload() -> Dictionary:
	return {
		"schema_version": 1,
		"map_id": "route",
		"player": {"x": 5, "y": 7, "facing": "left"},
		"party": [{"creature_id": "peatpaw", "level": 6, "hp": 20}],
		"inventory": {"berry_tonic": 2, "snare_orb": 4},
		"flags": {"met_alder": true},
		"settings": {"master_volume": 0.5},
	}


func _test_roundtrip(t: TestContext) -> void:
	t.check(SaveScript.write_payload(TEST_PATH, _payload()), "write_payload must succeed")
	t.check(not FileAccess.file_exists(TEST_PATH + ".tmp"), "tmp file is swapped away after a clean write")
	var loaded: Dictionary = SaveScript.read_payload(TEST_PATH)
	t.check(not loaded.is_empty(), "read_payload must find the save")
	t.check_eq(String(loaded.get("map_id", "")), "route", "map id survives roundtrip")
	var player := Dictionary(loaded.get("player", {}))
	t.check_eq(int(player.get("x", -1)), 5, "player x survives roundtrip")
	t.check_eq(int(player.get("y", -1)), 7, "player y survives roundtrip")
	t.check_eq(String(player.get("facing", "")), "left", "facing survives roundtrip")
	var party := Array(loaded.get("party", []))
	t.check_eq(party.size(), 1, "party entries survive roundtrip")
	t.check_eq(int(Dictionary(party[0]).get("hp", -1)), 20, "party hp survives roundtrip")
	t.check_eq(int(Dictionary(loaded.get("inventory", {})).get("snare_orb", -1)), 4, "inventory survives roundtrip")
	t.check(bool(Dictionary(loaded.get("flags", {})).get("met_alder", false)), "flags survive roundtrip")
	t.check(absf(float(Dictionary(loaded.get("settings", {})).get("master_volume", 0.0)) - 0.5) < 0.0001, "settings survive roundtrip")
	# Overwriting keeps the latest content.
	var second := _payload()
	second["map_id"] = "house"
	t.check(SaveScript.write_payload(TEST_PATH, second), "second write must succeed")
	t.check_eq(String(SaveScript.read_payload(TEST_PATH).get("map_id", "")), "house", "second write wins")


func _test_corruption(t: TestContext) -> void:
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string("{{{ not valid json at all")
	file.close()
	t.check(SaveScript.read_payload(TEST_PATH).is_empty(), "corrupt saves load as empty, never crash")
	var file_b := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file_b.store_string("[1, 2, 3]")
	file_b.close()
	t.check(SaveScript.read_payload(TEST_PATH).is_empty(), "non-dictionary JSON is rejected")


func _test_versions(t: TestContext) -> void:
	var no_version := _payload()
	no_version.erase("schema_version")
	t.check(SaveScript.migrate(no_version).is_empty(), "missing schema_version is rejected")
	var future := _payload()
	future["schema_version"] = 99
	t.check(SaveScript.migrate(future).is_empty(), "future schema versions are rejected")
	t.check(not SaveScript.migrate(_payload()).is_empty(), "current schema version is accepted")


func _test_tmp_fallback(t: TestContext) -> void:
	# Simulate a crash after writing .tmp but before the swap.
	var tmp := FileAccess.open(TEST_PATH + ".tmp", FileAccess.WRITE)
	tmp.store_string(JSON.stringify(_payload()))
	tmp.close()
	var broken := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	broken.store_string("garbage")
	broken.close()
	var recovered: Dictionary = SaveScript.read_payload(TEST_PATH)
	t.check_eq(String(recovered.get("map_id", "")), "route", "reader must fall back to the .tmp file")


## End-to-end through the live services (autoloads are present in test runs).
func _test_service_roundtrip(t: TestContext) -> void:
	SaveService.apply_payload(_payload())
	t.check_eq(GameState.current_map_id, "route", "apply_payload restores the map")
	t.check_eq(GameState.player_cell, Vector2i(5, 7), "apply_payload restores the position")
	t.check_eq(GameState.player_facing, Vector2i.LEFT, "apply_payload restores facing")
	t.check_eq(PartyService.size(), 1, "apply_payload restores the party")
	t.check_eq(InventoryService.count("berry_tonic"), 2, "apply_payload restores the bag")
	t.check(EventFlagStore.has_flag("met_alder"), "apply_payload restores flags")
	var collected: Dictionary = SaveService.collect_payload()
	t.check_eq(int(collected.get("schema_version", 0)), SaveScript.SCHEMA_VERSION, "collect stamps the schema version")
	t.check_eq(String(collected.get("map_id", "")), "route", "collect mirrors the applied state")
	t.check_eq(int(Dictionary(collected.get("inventory", {})).get("snare_orb", -1)), 4, "collect mirrors the bag")
	t.check_eq(Array(collected.get("party", [])).size(), 1, "collect mirrors the party")
