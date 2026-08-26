extends RefCounted
## 存檔：往返一致、原子寫入、損壞容錯、版本閘門、v1→v2 遷移、.tmp 復原。

const SaveScript := preload("res://scripts/persistence/save_service.gd")
const TEST_PATH := "user://test_save.json"


func run(t: TestContext) -> void:
	_cleanup()
	_test_roundtrip(t)
	_cleanup()
	_test_corruption(t)
	_cleanup()
	_test_versions(t)
	_test_v1_migration(t)
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
		"schema_version": 3,
		"map_id": "trail",
		"player": {"x": 6, "y": 8, "facing": "left"},
		"party": [{"creature_id": "mosshorn", "level": 6, "hp": 20}],
		"inventory": {"herbal_balm": 2, "echo_box": 4},
		"flags": {"opening_done": true, "clue_signal": true, "boss_hint": true},
		"settings": {"master_volume": 0.5, "reduce_flash": true, "reduce_shake": false},
	}


func _test_roundtrip(t: TestContext) -> void:
	t.check(SaveScript.write_payload(TEST_PATH, _payload()), "write_payload 必須成功")
	t.check(not FileAccess.file_exists(TEST_PATH + ".tmp"), "寫入完成後 tmp 檔必須被換走")
	var loaded: Dictionary = SaveScript.read_payload(TEST_PATH)
	t.check(not loaded.is_empty(), "read_payload 必須讀得到")
	t.check_eq(String(loaded.get("map_id", "")), "trail", "地圖 id 往返一致")
	var player := Dictionary(loaded.get("player", {}))
	t.check_eq(int(player.get("x", -1)), 6, "座標 x 往返一致")
	t.check_eq(int(player.get("y", -1)), 8, "座標 y 往返一致")
	t.check_eq(String(player.get("facing", "")), "left", "朝向往返一致")
	var party := Array(loaded.get("party", []))
	t.check_eq(party.size(), 1, "隊伍往返一致")
	t.check_eq(int(Dictionary(party[0]).get("hp", -1)), 20, "隊伍 HP 往返一致")
	t.check_eq(int(Dictionary(loaded.get("inventory", {})).get("echo_box", -1)), 4, "背包往返一致")
	t.check(bool(Dictionary(loaded.get("flags", {})).get("boss_hint", false)), "觀測線索旗標往返一致")
	var settings := Dictionary(loaded.get("settings", {}))
	t.check(absf(float(settings.get("master_volume", 0.0)) - 0.5) < 0.0001, "音量往返一致")
	t.check(bool(settings.get("reduce_flash", false)), "Accessibility 設定往返一致")
	var second := _payload()
	second["map_id"] = "home"
	t.check(SaveScript.write_payload(TEST_PATH, second), "第二次寫入必須成功")
	t.check_eq(String(SaveScript.read_payload(TEST_PATH).get("map_id", "")), "home", "後寫的內容獲勝")


func _test_corruption(t: TestContext) -> void:
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string("{{{ not valid json at all")
	file.close()
	t.check(SaveScript.read_payload(TEST_PATH).is_empty(), "壞檔讀出空字典，不得崩潰")
	var file_b := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file_b.store_string("[1, 2, 3]")
	file_b.close()
	t.check(SaveScript.read_payload(TEST_PATH).is_empty(), "非字典 JSON 必須被拒絕")


func _test_versions(t: TestContext) -> void:
	var no_version := _payload()
	no_version.erase("schema_version")
	t.check(SaveScript.migrate(no_version).is_empty(), "缺 schema_version 必須被拒絕")
	var future := _payload()
	future["schema_version"] = 99
	t.check(SaveScript.migrate(future).is_empty(), "未來版本必須被拒絕")
	t.check(not SaveScript.migrate(_payload()).is_empty(), "目前版本必須被接受")


func _test_v1_migration(t: TestContext) -> void:
	var v1 := {
		"schema_version": 1,
		"map_id": "route",
		"player": {"x": 5, "y": 7, "facing": "left"},
		"party": [
			{"creature_id": "peatpaw", "level": 6, "hp": 20},
			{"creature_id": "drippole", "level": 4, "hp": 30},
		],
		"inventory": {"berry_tonic": 2, "snare_orb": 4},
		"flags": {"met_alder": true},
		"settings": {"master_volume": 0.8},
	}
	var migrated := SaveScript.migrate(v1)
	t.check(not migrated.is_empty(), "v1 存檔必須可遷移")
	t.check_eq(int(migrated.get("schema_version", 0)), 3, "遷移後版本為最新（3）")
	t.check(Dictionary(migrated.get("settings", {})).has("reduce_flash"), "遷移鏈補上 Accessibility 欄位")
	t.check_eq(String(migrated.get("map_id", "")), "harbor", "舊地圖重設為霧港村")
	var party := Array(migrated.get("party", []))
	t.check_eq(String(Dictionary(party[0]).get("creature_id", "")), "mosshorn", "peatpaw → mosshorn")
	t.check_eq(String(Dictionary(party[1]).get("creature_id", "")), "tidewing", "drippole → tidewing")
	t.check_eq(int(Dictionary(party[0]).get("level", 0)), 6, "等級保留")
	var inventory := Dictionary(migrated.get("inventory", {}))
	t.check_eq(int(inventory.get("herbal_balm", -1)), 2, "berry_tonic → herbal_balm")
	t.check_eq(int(inventory.get("echo_box", -1)), 4, "snare_orb → echo_box")
	# v2 → v3 單獨遷移
	var v2 := _payload()
	v2["schema_version"] = 2
	var settings_v2 := Dictionary(v2["settings"])
	settings_v2.erase("reduce_flash")
	settings_v2.erase("reduce_shake")
	v2["settings"] = settings_v2
	var migrated_v2 := SaveScript.migrate(v2)
	t.check_eq(int(migrated_v2.get("schema_version", 0)), 3, "v2 遷移到 3")
	t.check(not bool(Dictionary(migrated_v2.get("settings", {})).get("reduce_flash", true)), "v2 遷移補預設值（關）")


func _test_tmp_fallback(t: TestContext) -> void:
	var tmp := FileAccess.open(TEST_PATH + ".tmp", FileAccess.WRITE)
	tmp.store_string(JSON.stringify(_payload()))
	tmp.close()
	var broken := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	broken.store_string("garbage")
	broken.close()
	var recovered: Dictionary = SaveScript.read_payload(TEST_PATH)
	t.check_eq(String(recovered.get("map_id", "")), "trail", "主檔壞掉時必須回退到 .tmp")


## 透過真實服務跑一輪（--script 模式下 autoload 存在）
func _test_service_roundtrip(t: TestContext) -> void:
	SaveService.apply_payload(_payload())
	t.check_eq(GameState.current_map_id, "trail", "apply_payload 還原地圖")
	t.check_eq(GameState.player_cell, Vector2i(6, 8), "apply_payload 還原座標")
	t.check_eq(GameState.player_facing, Vector2i.LEFT, "apply_payload 還原朝向")
	t.check_eq(PartyService.size(), 1, "apply_payload 還原隊伍")
	t.check_eq(InventoryService.count("herbal_balm"), 2, "apply_payload 還原背包")
	t.check(EventFlagStore.has_flag("clue_signal"), "apply_payload 還原觀測線索")
	var collected: Dictionary = SaveService.collect_payload()
	t.check_eq(int(collected.get("schema_version", 0)), SaveScript.SCHEMA_VERSION, "collect 蓋上目前版本")
	t.check_eq(String(collected.get("map_id", "")), "trail", "collect 反映還原後狀態")
	t.check_eq(int(Dictionary(collected.get("inventory", {})).get("echo_box", -1)), 4, "collect 反映背包")
	t.check_eq(Array(collected.get("party", [])).size(), 1, "collect 反映隊伍")
	# 位置安全網：無效座標必須回村口
	var bad := _payload()
	bad["player"] = {"x": 0, "y": 0, "facing": "down"}
	SaveService.apply_payload(bad)
	t.check_eq(GameState.current_map_id, "harbor", "無效座標時回到村口")