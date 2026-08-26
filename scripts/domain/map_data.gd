class_name MapData
extends RefCounted
## Parsed, immutable view of one map JSON (res://data/maps/*.json).
## The grid is an array of equal-length strings; each character is one tile.
##
## Tile legend:
##   G grass · T tall grass (encounters) · P path · F floor · D door (warp)
##   M mat (warp) · W water · R tree · B building wall · I interior wall · S sign

const WALKABLE_TILES: Array[String] = ["G", "T", "P", "F", "D", "M"]
const GRASS_TILES: Array[String] = ["T"]

var id: String = ""
var display_name: String = ""
var width: int = 0
var height: int = 0
var rows: PackedStringArray = []
var warps: Dictionary = {}
var sign_dialogues: Dictionary = {}
var npcs: Array[Dictionary] = []
var spawn: Dictionary = {}
var encounter_key: String = ""


static func from_dict(map_id: String, data: Dictionary) -> MapData:
	var map := MapData.new()
	map.id = map_id
	map.display_name = String(data.get("display_name", map_id))
	for row: Variant in Array(data.get("grid", [])):
		map.rows.append(String(row))
	map.height = map.rows.size()
	map.width = map.rows[0].length() if map.height > 0 else 0
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
	return map


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func tile_at(cell: Vector2i) -> String:
	if not in_bounds(cell):
		return ""
	return rows[cell.y][cell.x]


func is_walkable(cell: Vector2i) -> bool:
	return tile_at(cell) in WALKABLE_TILES


func is_grass(cell: Vector2i) -> bool:
	return tile_at(cell) in GRASS_TILES


func warp_at(cell: Vector2i) -> Dictionary:
	return Dictionary(warps.get(cell, {}))


func sign_at(cell: Vector2i) -> String:
	return String(sign_dialogues.get(cell, ""))


func spawn_cell() -> Vector2i:
	return Vector2i(int(spawn.get("x", 1)), int(spawn.get("y", 1)))


func spawn_facing() -> Vector2i:
	return Directions.from_name(String(spawn.get("facing", "down")))
