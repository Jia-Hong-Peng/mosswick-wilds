extends Node
## Autoload: versioned JSON save files under user:// with an atomic write
## strategy (write .tmp → verify → swap). Corrupt files never crash the game;
## the .tmp file doubles as a recovery fallback.

const SCHEMA_VERSION := 4
const SAVE_PATH := "user://save.json"
const TMP_SUFFIX := ".tmp"

## v1（Mosswick Wilds 版）→ v2（潮霧群島版）對照表
const V1_CREATURE_MAP := {
	"peatpaw": "mosshorn",
	"drippole": "tidewing",
	"cindermoth": "magshell",
}
const V1_ITEM_MAP := {
	"berry_tonic": "herbal_balm",
	"snare_orb": "echo_box",
}


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
		"starter": {
			"id": GameState.starter_id,
			"nickname": GameState.starter_nickname,
		},
		"nicknames": GameState.nicknames,
		"party": PartyService.to_dicts(),
		"inventory": InventoryService.to_dict(),
		"flags": EventFlagStore.to_dict(),
		"settings": {
			"master_volume": AudioManager.master_volume,
			"reduce_flash": AudioManager.reduce_flash,
			"reduce_shake": AudioManager.reduce_shake,
		},
	}


func apply_payload(payload: Dictionary) -> void:
	var player_data := Dictionary(payload.get("player", {}))
	GameState.set_world_position(
		String(payload.get("map_id", GameState.START_MAP_ID)),
		Vector2i(int(player_data.get("x", 1)), int(player_data.get("y", 1))),
		Directions.from_name(String(player_data.get("facing", "down")))
	)
	var starter := Dictionary(payload.get("starter", {}))
	GameState.starter_id = String(starter.get("id", ""))
	GameState.starter_nickname = String(starter.get("nickname", ""))
	GameState.nicknames = Dictionary(payload.get("nicknames", {}))
	# 舊檔相容：只有 starter 欄位的暱稱也收進字典
	if not GameState.starter_nickname.is_empty() and not GameState.nicknames.has(GameState.starter_id):
		GameState.nicknames[GameState.starter_id] = GameState.starter_nickname
	PartyService.load_from(Array(payload.get("party", [])), DataRegistry)
	InventoryService.load_from(Dictionary(payload.get("inventory", {})))
	EventFlagStore.load_from(Dictionary(payload.get("flags", {})))
	# 暱稱重新套用（隊伍成員由 creature_id 重建，display_name 不入檔）
	for member in PartyService.members:
		if GameState.nicknames.has(member.creature_id):
			member.display_name = String(GameState.nicknames[member.creature_id])
	var settings := Dictionary(payload.get("settings", {}))
	AudioManager.set_master_volume(float(settings.get("master_volume", AudioManager.master_volume)))
	AudioManager.reduce_flash = bool(settings.get("reduce_flash", AudioManager.reduce_flash))
	AudioManager.reduce_shake = bool(settings.get("reduce_shake", AudioManager.reduce_shake))
	# 位置安全網：地圖被改版或座標失效時回到村口，不讓玩家卡牆
	var map := DataRegistry.get_map(GameState.current_map_id)
	if map == null or not map.is_walkable(GameState.player_cell):
		GameState.respawn_at_start()


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


## 存檔 Schema 遷移。未知或未來版本安全拒絕。
static func migrate(data: Dictionary) -> Dictionary:
	var version := int(data.get("schema_version", 0))
	if version <= 0 or version > SCHEMA_VERSION:
		return {}
	if version == 1:
		data = _migrate_v1_to_v2(data)
		version = 2
	if version == 2:
		data = _migrate_v2_to_v3(data)
		version = 3
	if version == 3:
		data = _migrate_v3_to_v4(data)
		version = 4
	data["schema_version"] = version
	return data


## v3 → v4：世界觀重製（回聲觀測 → 潮森群島認養）。舊隊伍的迴靈與
## 回聲旗標已無對應內容，無法合理轉換——安全返回新遊戲開場，
## 只保留玩家的設定值（音量與 Accessibility）。
static func _migrate_v3_to_v4(data: Dictionary) -> Dictionary:
	return {
		"schema_version": 4,
		"map_id": "haven",
		"player": {"x": 10, "y": 3, "facing": "down"},
		"starter": {"id": "", "nickname": ""},
		"party": [],
		"inventory": {},
		"flags": {},
		"settings": Dictionary(data.get("settings", {})),
	}


## v2 → v3：settings 補 Accessibility 欄位（預設關閉）
static func _migrate_v2_to_v3(data: Dictionary) -> Dictionary:
	var settings := Dictionary(data.get("settings", {}))
	if not settings.has("reduce_flash"):
		settings["reduce_flash"] = false
	if not settings.has("reduce_shake"):
		settings["reduce_shake"] = false
	data["settings"] = settings
	return data


## v1 → v2：怪獸與道具 id 對照；舊地圖已不存在，位置交由
## apply_payload 的安全網重置到村口。
static func _migrate_v1_to_v2(data: Dictionary) -> Dictionary:
	var party: Array = Array(data.get("party", []))
	for i in range(party.size()):
		var member := Dictionary(party[i])
		var old_id := String(member.get("creature_id", ""))
		if V1_CREATURE_MAP.has(old_id):
			member["creature_id"] = String(V1_CREATURE_MAP[old_id])
			party[i] = member
	data["party"] = party
	var inventory := Dictionary(data.get("inventory", {}))
	var new_inventory := {}
	for key: Variant in inventory:
		var item_id := String(key)
		new_inventory[String(V1_ITEM_MAP.get(item_id, item_id))] = inventory[key]
	data["inventory"] = new_inventory
	data["map_id"] = "harbor"
	return data
