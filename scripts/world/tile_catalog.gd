class_name TileCatalog
extends RefCounted
## 世界圖塊目錄：名稱 → 圖集座標與動畫幀數。
## 產生器（tools/pixgen/gen_tiles.gd）與渲染器（world_scene.gd）共用，
## 地圖 JSON 的 legend 以名稱引用，避免魔術數字。

const ATLAS_PATH := "res://assets/tilesets/overworld.png"
const TILE_SIZE := 16
const ATLAS_COLUMNS := 16
const ATLAS_ROWS := 6

## name -> {"pos": Vector2i(col,row), "frames": int(預設1), "fps": float(預設6)}
const TILES: Dictionary = {
	# --- Row 0：地面 ---
	"grass_a": {"pos": Vector2i(0, 0)},
	"grass_b": {"pos": Vector2i(1, 0)},
	"grass_c": {"pos": Vector2i(2, 0)},
	"dirt": {"pos": Vector2i(3, 0)},
	"path_a": {"pos": Vector2i(4, 0)},
	"path_b": {"pos": Vector2i(5, 0)},
	"sand_a": {"pos": Vector2i(6, 0)},
	"sand_b": {"pos": Vector2i(7, 0)},
	"stone_floor_a": {"pos": Vector2i(8, 0)},
	"stone_floor_b": {"pos": Vector2i(9, 0)},
	"wood_floor_a": {"pos": Vector2i(10, 0)},
	"wood_floor_b": {"pos": Vector2i(11, 0)},
	"boardwalk": {"pos": Vector2i(12, 0)},
	"stairs": {"pos": Vector2i(13, 0)},
	"rug": {"pos": Vector2i(14, 0)},
	"rug_border": {"pos": Vector2i(15, 0)},
	# --- Row 1：動畫地面 ---
	"tallgrass": {"pos": Vector2i(0, 1), "frames": 2, "fps": 2.2},
	"water_deep": {"pos": Vector2i(2, 1), "frames": 4, "fps": 3.0},
	"water_shallow": {"pos": Vector2i(6, 1), "frames": 4, "fps": 3.0},
	"foam": {"pos": Vector2i(10, 1), "frames": 4, "fps": 4.0},
	"sparkle": {"pos": Vector2i(14, 1), "frames": 2, "fps": 2.5},
	# --- Row 2：自然物件 ---
	"tree_trunk": {"pos": Vector2i(0, 2)},
	"rock_a": {"pos": Vector2i(1, 2)},
	"rock_small": {"pos": Vector2i(2, 2)},
	"fern": {"pos": Vector2i(3, 2)},
	"flowers_a": {"pos": Vector2i(4, 2)},
	"flowers_b": {"pos": Vector2i(5, 2)},
	"bush": {"pos": Vector2i(6, 2)},
	"banana_plant": {"pos": Vector2i(7, 2)},
	"log_a": {"pos": Vector2i(8, 2)},
	"log_b": {"pos": Vector2i(9, 2)},
	"stump": {"pos": Vector2i(10, 2)},
	"vine_wall": {"pos": Vector2i(11, 2)},
	"cliff_face": {"pos": Vector2i(12, 2)},
	"cliff_top": {"pos": Vector2i(13, 2)},
	"reed": {"pos": Vector2i(14, 2)},
	"pebbles": {"pos": Vector2i(15, 2)},
	# --- Row 3：聚落物件 ---
	"brick_wall": {"pos": Vector2i(0, 3)},
	"brick_window": {"pos": Vector2i(1, 3)},
	"plaster_wall": {"pos": Vector2i(2, 3)},
	"plaster_window": {"pos": Vector2i(3, 3)},
	"door_wood": {"pos": Vector2i(4, 3)},
	"stone_wall": {"pos": Vector2i(5, 3)},
	"fence": {"pos": Vector2i(6, 3)},
	"power_pole": {"pos": Vector2i(7, 3)},
	"lamp_post": {"pos": Vector2i(8, 3)},
	"sign_wood": {"pos": Vector2i(9, 3)},
	"crate": {"pos": Vector2i(10, 3)},
	"barrel": {"pos": Vector2i(11, 3)},
	"pot_plant": {"pos": Vector2i(12, 3)},
	"buoy": {"pos": Vector2i(13, 3)},
	"flag": {"pos": Vector2i(14, 3), "frames": 2, "fps": 2.5},
	# --- Row 4：屋頂與設備、頂層 ---
	"roof_tin_a": {"pos": Vector2i(0, 4)},
	"roof_tin_b": {"pos": Vector2i(1, 4)},
	"roof_tin_ridge": {"pos": Vector2i(2, 4)},
	"roof_brick_a": {"pos": Vector2i(3, 4)},
	"roof_brick_b": {"pos": Vector2i(4, 4)},
	"roof_brick_ridge": {"pos": Vector2i(5, 4)},
	"roof_eave": {"pos": Vector2i(6, 4)},
	"chimney": {"pos": Vector2i(7, 4)},
	"antenna_dish": {"pos": Vector2i(8, 4)},
	"console_rust": {"pos": Vector2i(9, 4)},
	"telescope": {"pos": Vector2i(10, 4)},
	"bench": {"pos": Vector2i(11, 4)},
	"wire_h": {"pos": Vector2i(12, 4)},
	"canopy_a": {"pos": Vector2i(13, 4)},
	"canopy_b": {"pos": Vector2i(14, 4)},
	"canopy_c": {"pos": Vector2i(15, 4)},
	# --- Row 5：室內 ---
	"wall_plank": {"pos": Vector2i(0, 5)},
	"wall_plank_top": {"pos": Vector2i(1, 5)},
	"wall_stone_in": {"pos": Vector2i(2, 5)},
	"window_in": {"pos": Vector2i(3, 5)},
	"bed_head": {"pos": Vector2i(4, 5)},
	"bed_foot": {"pos": Vector2i(5, 5)},
	"table": {"pos": Vector2i(6, 5)},
	"chair": {"pos": Vector2i(7, 5)},
	"bookshelf": {"pos": Vector2i(8, 5)},
	"counter": {"pos": Vector2i(9, 5)},
	"stove": {"pos": Vector2i(10, 5)},
	"instrument": {"pos": Vector2i(11, 5)},
	"tape_shelf": {"pos": Vector2i(12, 5)},
	"map_wall": {"pos": Vector2i(13, 5)},
	"lamp_floor": {"pos": Vector2i(14, 5)},
	"plant_pot": {"pos": Vector2i(15, 5)},
}


static func has_tile(tile_name: String) -> bool:
	return TILES.has(tile_name)


static func pos(tile_name: String) -> Vector2i:
	return Vector2i(Dictionary(TILES.get(tile_name, {})).get("pos", Vector2i.ZERO))


static func frames(tile_name: String) -> int:
	return int(Dictionary(TILES.get(tile_name, {})).get("frames", 1))


static func fps(tile_name: String) -> float:
	return float(Dictionary(TILES.get(tile_name, {})).get("fps", 6.0))
