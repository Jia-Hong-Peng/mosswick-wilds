class_name MapData
extends RefCounted
## 一張地圖 JSON 的不可變視圖（res://data/maps/*.json）。
##
## 地圖分三層字元網格，字元經由各自的 legend 對應到 TileCatalog 名稱：
##   ground   地面（每格必填；可走性由 tile 名稱決定）
##   deco     物件層（'.' 為空；預設阻擋，NONBLOCKING_DECO 例外）
##   overhead 頂層（'.' 為空；樹冠、電線，蓋過角色，不影響碰撞）
##
## 可走規則：有 warp 的格永遠可走；否則需 ground 可走且 deco 為空或不阻擋。

const WALKABLE_GROUND: Array[String] = [
	"grass_a", "grass_b", "grass_c", "dirt", "path_a", "path_b",
	"sand_a", "sand_b", "stone_floor_a", "stone_floor_b",
	"wood_floor_a", "wood_floor_b", "boardwalk", "stairs",
	"rug", "rug_border", "tallgrass", "water_shallow",
]
const GRASS_GROUND: Array[String] = ["tallgrass"]
const SPLASH_GROUND: Array[String] = ["water_shallow"]
const NONBLOCKING_DECO: Array[String] = [
	"fern", "flowers_a", "flowers_b", "rock_small", "pebbles", "reed", "sparkle",
]

var id: String = ""
var display_name: String = ""
var width: int = 0
var height: int = 0
var ground_rows: PackedStringArray = []
var deco_rows: PackedStringArray = []
var overhead_rows: PackedStringArray = []
var legend_ground: Dictionary = {}
var legend_deco: Dictionary = {}
var legend_overhead: Dictionary = {}
var warps: Dictionary = {}
var sign_dialogues: Dictionary = {}
var npcs: Array[Dictionary] = []
var spawn: Dictionary = {}
var encounter_key: String = ""
var battle_bg: String = "village"
var fog: bool = false
var smoke_cells: Array[Vector2i] = []
var hidden_deco: Array[Dictionary] = []


static func from_dict(map_id: String, data: Dictionary) -> MapData:
	var map := MapData.new()
	map.id = map_id
	map.display_name = String(data.get("display_name", map_id))
	for row: Variant in Array(data.get("ground", [])):
		map.ground_rows.append(String(row))
	for row: Variant in Array(data.get("deco", [])):
		map.deco_rows.append(String(row))
	for row: Variant in Array(data.get("overhead", [])):
		map.overhead_rows.append(String(row))
	map.legend_ground = Dictionary(data.get("legend_ground", {}))
	map.legend_deco = Dictionary(data.get("legend_deco", {}))
	map.legend_overhead = Dictionary(data.get("legend_overhead", {}))
	map.height = map.ground_rows.size()
	map.width = map.ground_rows[0].length() if map.height > 0 else 0
	for warp: Variant in Array(data.get("warps", [])):
		var warp_data := Dictionary(warp)
		map.warps[Vector2i(int(warp_data.get("x", 0)), int(warp_data.get("y", 0)))] = warp_data
	for sign: Variant in Array(data.get("signs", [])):
		var sign_data := Dictionary(sign)
		map.sign_dialogues[Vector2i(int(sign_data.get("x", 0)), int(sign_data.get("y", 0)))] = String(sign_data.get("dialogue_id", ""))
	for npc: Variant in Array(data.get("npcs", [])):
		map.npcs.append(Dictionary(npc))
	map.spawn = Dictionary(data.get("spawn", {}))
	map.encounter_key = String(data.get("encounter_key", ""))
	map.battle_bg = String(data.get("battle_bg", "village"))
	map.fog = bool(data.get("fog", false))
	for cell: Variant in Array(data.get("smoke", [])):
		var cell_data := Dictionary(cell)
		map.smoke_cells.append(Vector2i(int(cell_data.get("x", 0)), int(cell_data.get("y", 0))))
	for entry: Variant in Array(data.get("hidden_deco", [])):
		map.hidden_deco.append(Dictionary(entry))
	return map


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func ground_name(cell: Vector2i) -> String:
	if not in_bounds(cell):
		return ""
	return String(legend_ground.get(ground_rows[cell.y][cell.x], ""))


func deco_name(cell: Vector2i) -> String:
	if not in_bounds(cell) or cell.y >= deco_rows.size():
		return ""
	var symbol := deco_rows[cell.y][cell.x]
	if symbol == ".":
		return ""
	return String(legend_deco.get(symbol, ""))


func overhead_name(cell: Vector2i) -> String:
	if not in_bounds(cell) or cell.y >= overhead_rows.size():
		return ""
	var symbol := overhead_rows[cell.y][cell.x]
	if symbol == ".":
		return ""
	return String(legend_overhead.get(symbol, ""))


func is_walkable(cell: Vector2i) -> bool:
	if not in_bounds(cell):
		return false
	if warps.has(cell):
		return true
	if ground_name(cell) not in WALKABLE_GROUND:
		return false
	var deco := deco_name(cell)
	return deco.is_empty() or deco in NONBLOCKING_DECO


func is_grass(cell: Vector2i) -> bool:
	return ground_name(cell) in GRASS_GROUND


func is_splash(cell: Vector2i) -> bool:
	return ground_name(cell) in SPLASH_GROUND


func warp_at(cell: Vector2i) -> Dictionary:
	return Dictionary(warps.get(cell, {}))


func sign_at(cell: Vector2i) -> String:
	return String(sign_dialogues.get(cell, ""))


func spawn_cell() -> Vector2i:
	return Vector2i(int(spawn.get("x", 1)), int(spawn.get("y", 1)))


func spawn_facing() -> Vector2i:
	return Directions.from_name(String(spawn.get("facing", "down")))
