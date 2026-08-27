extends RefCounted
## 存檔：往返一致、原子寫入、損壞容錯、版本閘門、
## v1→v4 遷移鏈、v3（回聲版）→ v4 安全重置、.tmp 復原。

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
	_test_v3_reset(t)
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
		"schema_version": 4,
		"map_id": "haven",
		"player": {"x": 11, "y": 8, "facing": "left"},
		"starter": {"id": "sproutwing", "nickname": "小芽"},
		"party": [{"creature_id": "sproutwing", "level": 5, "hp": 20}],
		"inventory": {"herbal_balm": 2, "travel_tag": 1},
		"flags": {"opening_done": true, "starter_chosen": true, "adopted_sproutwing": true},
		"settings": {"master_volume": 0.5, "reduce_flash": true, "reduce_shake": false},
	}


func _test_roundtrip(t: TestContext) -> void:
	t.check(SaveScript.write_payload(TEST_PATH, _payload()), "write_payload 必須成功")
	t.check(not FileAccess.file_exists(TEST_PATH + ".tmp"), "寫入完成後 tmp 檔必須被換走")
	var loaded: Dictionary = SaveScript.read_payload(TEST_PATH)
	t.check(not loaded.is_empty(), "read_payload 必須讀得到")
	t.check_eq(String(loaded.get("map_id", "")), "haven", "地圖 id 往返一致")
	var player := Dictionary(loaded.get("player", {}))
	t.check_eq(int(player.get("x", -1)), 11, "座標 x 往返一致")
	t.check_eq(int(player.get("y", -1)), 8, "座標 y 往返一致")
	t.check_eq(String(player.get("facing", "")), "left", "朝向往返一致")
	var starter := Dictionary(loaded.get("starter", {}))
	t.check_eq(String(starter.get("id", "")), "sproutwing", "御三家 id 往返一致")
	t.check_eq(String(starter.get("nickname", "")), "小芽", "暱稱往返一致")
	var party := Array(loaded.get("party", []))
	t.check_eq(party.size(), 1, "隊伍往返一致")
	t.check_eq(int(Dictionary(party[0]).get("hp", -1)), 20, "隊伍 HP 往返一致")
	t.check_eq(int(Dictionary(loaded.get("inventory", {})).get("travel_tag", -1)), 1, "背包往返一致")
	t.check(bool(Dictionary(loaded.get("flags", {})).get("adopted_sproutwing", false)), "認養旗標往返一致")
	var settings := Dictionary(loaded.get("settings", {}))
	t.check(absf(float(settings.get("master_volume", 0.0)) - 0.5) < 0.0001, "音量往返一致")
	t.check(bool(settings.get("reduce_flash", false)), "Accessibility 設定往返一致")
	var second := _payload()
	second["map_id"] = "haven2"
	t.check(SaveScript.write_payload(TEST_PATH, second), "第二次寫入必須成功")
	t.check_eq(String(SaveScript.read_payload(TEST_PATH).get("map_id", "")), "haven2", "後寫的內容獲勝")


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
		"party": [{"creature_id": "peatpaw", "level": 6, "hp": 20}],
		"inventory": {"berry_tonic": 2},
		"flags": {"met_alder": true},
		"settings": {"master_volume": 0.8},
	}
	var migrated := SaveScript.migrate(v1)
	t.check(not migrated.is_empty(), "v1 存檔必須可遷移（不崩潰、不拒絕）")
	t.check_eq(int(migrated.get("schema_version", 0)), 4, "遷移後版本為最新（4）")
	# v1/v2/v3 都是回聲版世界——最終安全重置為新遊戲開場
	t.check_eq(String(migrated.get("map_id", "")), "haven", "舊世界地圖重設為潮芽伴獸之家")
	t.check_eq(Array(migrated.get("party", [])).size(), 0, "舊迴靈隊伍無對應內容，安全清空")
	t.check(absf(float(Dictionary(migrated.get("settings", {})).get("master_volume", 0.0)) - 0.8) < 0.0001, "玩家設定值保留")


func _test_v3_reset(t: TestContext) -> void:
	var v3 := {
		"schema_version": 3,
		"map_id": "tide_station",
		"player": {"x": 6, "y": 5, "facing": "right"},
		"party": [{"creature_id": "mosshorn", "level": 6, "hp": 20}],
		"inventory": {"herbal_balm": 2, "echo_box": 4, "stable_echo": 1},
		"flags": {"level1_complete": true, "clue_signal": true},
		"settings": {"master_volume": 0.4, "reduce_flash": true, "reduce_shake": true},
	}
	var migrated := SaveScript.migrate(v3)
	t.check(not migrated.is_empty(), "v3（回聲版）存檔必須可讀，不得讓遊戲崩潰")
	t.check_eq(int(migrated.get("schema_version", 0)), 4, "v3 遷移到 4")
	t.check_eq(String(migrated.get("map_id", "")), "haven", "安全返回新遊戲開場")
	t.check_eq(Array(migrated.get("party", [])).size(), 0, "回聲隊伍清空")
	t.check_eq(Dictionary(migrated.get("flags", {})).size(), 0, "回聲旗標不得殘留（無殭屍旗標）")
	t.check_eq(String(Dictionary(migrated.get("starter", {})).get("id", "?")), "", "尚未認養")
	var settings := Dictionary(migrated.get("settings", {}))
	t.check(bool(settings.get("reduce_flash", false)), "Accessibility 設定保留")
	t.check(absf(float(settings.get("master_volume", 0.0)) - 0.4) < 0.0001, "音量保留")


func _test_tmp_fallback(t: TestContext) -> void:
	var tmp := FileAccess.open(TEST_PATH + ".tmp", FileAccess.WRITE)
	tmp.store_string(JSON.stringify(_payload()))
	tmp.close()
	var broken := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	broken.store_string("garbage")
	broken.close()
	var recovered: Dictionary = SaveScript.read_payload(TEST_PATH)
	t.check_eq(String(recovered.get("map_id", "")), "haven", "主檔壞掉時必須回退到 .tmp")


## 透過真實服務跑一輪（--script 模式下 autoload 存在）
func _test_service_roundtrip(t: TestContext) -> void:
	SaveService.apply_payload(_payload())
	t.check_eq(GameState.current_map_id, "haven", "apply_payload 還原地圖")
	t.check_eq(GameState.player_cell, Vector2i(11, 8), "apply_payload 還原座標")
	t.check_eq(GameState.player_facing, Vector2i.LEFT, "apply_payload 還原朝向")
	t.check_eq(GameState.starter_id, "sproutwing", "apply_payload 還原御三家")
	t.check_eq(PartyService.size(), 1, "apply_payload 還原隊伍")
	t.check_eq(PartyService.members[0].display_name, "小芽", "暱稱重新套用到隊伍成員")
	t.check_eq(InventoryService.count("herbal_balm"), 2, "apply_payload 還原背包")
	t.check(EventFlagStore.has_flag("adopted_sproutwing"), "apply_payload 還原認養旗標")
	var collected: Dictionary = SaveService.collect_payload()
	t.check_eq(int(collected.get("schema_version", 0)), SaveScript.SCHEMA_VERSION, "collect 蓋上目前版本")
	t.check_eq(String(Dictionary(collected.get("starter", {})).get("nickname", "")), "小芽", "collect 反映暱稱")
	t.check_eq(Array(collected.get("party", [])).size(), 1, "collect 反映隊伍")
	# 位置安全網：無效座標必須回到認養之家門口
	var bad := _payload()
	bad["player"] = {"x": 0, "y": 0, "facing": "down"}
	SaveService.apply_payload(bad)
	t.check_eq(GameState.player_cell, DataRegistry.get_map("haven").spawn_cell(), "無效座標時回到門口")