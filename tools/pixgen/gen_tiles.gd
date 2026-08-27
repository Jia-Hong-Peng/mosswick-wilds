class_name GenTiles
extends RefCounted
## 世界圖集產生器。每個 tile 在獨立 16×16 畫布繪製後合入圖集，
## 佈局由 TileCatalog 定義。規則見 docs/art-bible.md：
## 光源左上、每材質三階、dither 漸層、INK 描邊、禁止色盤外顏色。

const T := 16


static func generate() -> void:
	var atlas := Pix.img(TileCatalog.ATLAS_COLUMNS * T, TileCatalog.ATLAS_ROWS * T)
	for tile_name: String in TileCatalog.TILES:
		var pos := TileCatalog.pos(tile_name)
		for frame in range(TileCatalog.frames(tile_name)):
			var cell := Pix.img(T, T)
			_draw(tile_name, cell, frame)
			Pix.blit(atlas, cell, (pos.x + frame) * T, pos.y * T)
	Pix.save(atlas, TileCatalog.ATLAS_PATH)


static func _draw(tile_name: String, c: Image, f: int) -> void:
	match tile_name:
		"grass_a": _grass(c, 11)
		"grass_b": _grass(c, 22, true)
		"grass_c": _grass_shaded(c, 33)
		"dirt": _dirt(c)
		"path_a": _path(c, 44)
		"path_b": _path(c, 55)
		"sand_a": _sand(c, 66, false)
		"sand_b": _sand(c, 77, true)
		"stone_floor_a": _stone_floor(c, false)
		"stone_floor_b": _stone_floor(c, true)
		"wood_floor_a": _wood_floor(c, 0)
		"wood_floor_b": _wood_floor(c, 2)
		"boardwalk": _boardwalk(c)
		"stairs": _stairs(c)
		"rug": _rug(c, false)
		"rug_border": _rug(c, true)
		"tallgrass": _tallgrass(c, f)
		"water_deep": _water_deep(c, f)
		"water_shallow": _water_shallow(c, f)
		"foam": _foam(c, f)
		"sparkle": _sparkle(c, f)
		"tree_trunk": _tree_trunk(c)
		"rock_a": _rock(c)
		"rock_small": _rock_small(c)
		"fern": _fern(c)
		"flowers_a": _flowers(c, Pal.CORAL_LT, Pal.AMBER)
		"flowers_b": _flowers(c, Pal.FOAM, Pal.AMBER)
		"bush": _bush(c)
		"banana_plant": _banana(c)
		"log_a": _log(c, true)
		"log_b": _log(c, false)
		"stump": _stump(c)
		"vine_wall": _vine(c)
		"cliff_face": _cliff_face(c)
		"cliff_top": _cliff_top(c)
		"reed": _reed(c)
		"pebbles": _pebbles(c)
		"brick_wall": _brick_wall(c)
		"brick_window": _brick_window(c)
		"plaster_wall": _plaster_wall(c)
		"plaster_window": _plaster_window(c)
		"door_wood": _door(c)
		"stone_wall": _stone_wall(c)
		"fence": _fence(c)
		"power_pole": _power_pole(c)
		"lamp_post": _lamp_post(c)
		"sign_wood": _sign(c)
		"crate": _crate(c)
		"barrel": _barrel(c)
		"pot_plant": _pot_plant(c)
		"buoy": _buoy(c)
		"flag": _flag(c, f)
		"roof_tin_a": _roof_tin(c, 12, false)
		"roof_tin_b": _roof_tin(c, 34, true)
		"roof_tin_ridge": _roof_tin_ridge(c)
		"roof_brick_a": _roof_brick(c, false)
		"roof_brick_b": _roof_brick(c, true)
		"roof_brick_ridge": _roof_brick_ridge(c)
		"roof_eave": _roof_eave(c)
		"chimney": _chimney(c)
		"antenna_dish": _antenna(c)
		"console_rust": _console(c)
		"telescope": _telescope(c)
		"bench": _bench(c)
		"wire_h": _wire(c)
		"canopy_a": _canopy(c, 5)
		"canopy_b": _canopy(c, 9)
		"canopy_c": _canopy(c, 13)
		"wall_plank": _wall_plank(c)
		"wall_plank_top": _wall_plank_top(c)
		"wall_stone_in": _wall_stone_in(c)
		"window_in": _window_in(c)
		"bed_head": _bed_head(c)
		"bed_foot": _bed_foot(c)
		"table": _table(c)
		"chair": _chair(c)
		"bookshelf": _bookshelf(c)
		"counter": _counter(c)
		"stove": _stove(c)
		"instrument": _instrument(c)
		"tape_shelf": _tape_shelf(c)
		"map_wall": _map_wall(c)
		"lamp_floor": _lamp_floor(c)
		"plant_pot": _plant_pot(c)
		_:
			Pix.rect(c, 0, 0, T, T, Pal.CORAL)  # 醒目的「缺 tile」警告色


# ---------- 地面 ----------

static func _grass(c: Image, seed_value: int, sprout: bool = false) -> void:
	Pix.rect(c, 0, 0, T, T, Pal.LEAF)
	var r := Pix.rng(seed_value)
	for i in range(7):
		var x := r.randi_range(0, 14)
		var y := r.randi_range(0, 13)
		Pix.px(c, x, y, Pal.LEAF_LT)
		Pix.px(c, x, y + 1, Pal.LEAF_LT)
	Pix.speckle(c, 0, 0, T, T, Pal.MOSS, 6, seed_value + 1)
	if sprout:
		Pix.px(c, r.randi_range(2, 13), r.randi_range(2, 13), Pal.SPROUT)


static func _grass_shaded(c: Image, seed_value: int) -> void:
	Pix.rect(c, 0, 0, T, T, Pal.LEAF)
	Pix.dither(c, 0, 8, T, 8, Pal.LEAF, Pal.MOSS)
	Pix.speckle(c, 0, 0, T, 8, Pal.LEAF_LT, 5, seed_value)
	Pix.speckle(c, 0, 8, T, 8, Pal.MOSS_DK, 4, seed_value + 1)


static func _dirt(c: Image) -> void:
	Pix.rect(c, 0, 0, T, T, Pal.SAND_DK)
	Pix.speckle(c, 0, 0, T, T, Pal.WOOD_LT, 9, 5)
	Pix.speckle(c, 0, 0, T, T, Pal.SAND, 10, 6)
	Pix.speckle(c, 0, 0, T, T, Pal.WOOD, 4, 7)


static func _path(c: Image, seed_value: int) -> void:
	Pix.rect(c, 0, 0, T, T, Pal.SAND)
	# 中央亮帶（踩實的路面）
	Pix.dither(c, 3, 3, 10, 10, Pal.SAND, Pal.SAND_LT)
	# 不規則草緣：邊緣咬進草色，避免直線硬切
	var r := Pix.rng(seed_value)
	for i in range(10):
		var edge := r.randi_range(0, 3)
		var t := r.randi_range(0, 15)
		match edge:
			0: Pix.px(c, t, 0, Pal.LEAF)
			1: Pix.px(c, t, 15, Pal.LEAF)
			2: Pix.px(c, 0, t, Pal.LEAF)
			3: Pix.px(c, 15, t, Pal.LEAF)
	Pix.speckle(c, 0, 0, T, T, Pal.SAND_DK, 6, seed_value + 2)
	Pix.px(c, r.randi_range(2, 13), r.randi_range(2, 13), Pal.GRAY)


static func _sand(c: Image, seed_value: int, shells: bool) -> void:
	Pix.rect(c, 0, 0, T, T, Pal.SAND_LT)
	Pix.speckle(c, 0, 0, T, T, Pal.SAND, 12, seed_value)
	Pix.speckle(c, 0, 0, T, T, Pal.SAND_DK, 4, seed_value + 1)
	if shells:
		Pix.px(c, 4, 11, Pal.FOAM)
		Pix.px(c, 11, 5, Pal.CORAL_LT)


static func _stone_floor(c: Image, cracked: bool) -> void:
	Pix.rect(c, 0, 0, T, T, Pal.MIST)
	Pix.speckle(c, 0, 0, T, T, Pal.MIST_LT, 14, 8)
	Pix.speckle(c, 0, 0, T, T, Pal.MIST_DK, 6, 9)
	Pix.hline(c, 0, 7, T, Pal.MIST_DK)
	Pix.vline(c, 7 if not cracked else 11, 8, 8, Pal.MIST_DK)
	Pix.vline(c, 3, 0, 7, Pal.MIST_DK)
	if cracked:
		Pix.px(c, 5, 3, Pal.SLATE)
		Pix.px(c, 6, 4, Pal.SLATE)
		Pix.px(c, 6, 5, Pal.SLATE)


static func _wood_floor(c: Image, offset: int) -> void:
	Pix.rect(c, 0, 0, T, T, Pal.WOOD_LT)
	for y: int in [3, 7, 11, 15]:
		Pix.hline(c, 0, y, T, Pal.WOOD)
	Pix.vline(c, (5 + offset) % T, 0, 3, Pal.WOOD)
	Pix.vline(c, (12 + offset) % T, 4, 3, Pal.WOOD)
	Pix.vline(c, (8 + offset) % T, 8, 3, Pal.WOOD)
	Pix.vline(c, (2 + offset) % T, 12, 3, Pal.WOOD)
	# 木紋亮點克制：只留一點點，避免整片地板像下雪
	Pix.px(c, (9 + offset) % T, 5, Pal.SAND)
	Pix.px(c, 5 + offset, 5, Pal.WOOD_DK)
	Pix.px(c, (3 + offset) % T, 13, Pal.WOOD_DK)


static func _boardwalk(c: Image) -> void:
	Pix.rect(c, 0, 0, T, T, Pal.WOOD_LT)
	for x: int in [0, 5, 10, 15]:
		Pix.vline(c, x, 0, T, Pal.WOOD_DK)
	for x: int in [1, 6, 11]:
		Pix.vline(c, x, 0, T, Pal.SAND_LT)
	Pix.hline(c, 0, 4, T, Pal.WOOD)
	Pix.hline(c, 0, 12, T, Pal.WOOD)
	Pix.px(c, 3, 2, Pal.WOOD_DK)
	Pix.px(c, 13, 9, Pal.WOOD_DK)


static func _stairs(c: Image) -> void:
	for step in range(4):
		var y := step * 4
		Pix.rect(c, 0, y, T, 2, Pal.MIST_LT)
		Pix.rect(c, 0, y + 2, T, 2, Pal.MIST_DK)
		Pix.hline(c, 0, y + 2, T, Pal.SLATE)
	Pix.vline(c, 0, 0, T, Pal.MIST_DK)
	Pix.vline(c, 15, 0, T, Pal.MIST_DK)


static func _rug(c: Image, border: bool) -> void:
	Pix.rect(c, 0, 0, T, T, Pal.BRICK_LT)
	Pix.dither(c, 2, 2, 12, 12, Pal.BRICK_LT, Pal.CORAL)
	if border:
		Pix.outline_rect(c, 0, 0, T, T, Pal.BRICK_DK)
		Pix.outline_rect(c, 1, 1, 14, 14, Pal.AMBER)
	else:
		Pix.px(c, 5, 5, Pal.AMBER)
		Pix.px(c, 10, 10, Pal.AMBER)


# ---------- 動畫地面 ----------

static func _tallgrass(c: Image, f: int) -> void:
	Pix.rect(c, 0, 0, T, T, Pal.MOSS)
	Pix.dither(c, 0, 12, T, 4, Pal.MOSS, Pal.MOSS_DK)
	var lean := -1 if f == 0 else 1
	for i in range(5):
		var x := 2 + i * 3
		Pix.vline(c, x, 6, 9, Pal.LEAF)
		Pix.vline(c, x + lean, 3, 4, Pal.LEAF)
		Pix.px(c, x + lean, 2, Pal.LEAF_LT)
		Pix.px(c, x + lean * 2, 3, Pal.SPROUT if i % 2 == 0 else Pal.LEAF_LT)
	Pix.speckle(c, 0, 10, T, 6, Pal.MOSS_DK, 5, 12 + f)


static func _water_deep(c: Image, f: int) -> void:
	Pix.rect(c, 0, 0, T, T, Pal.SEA)
	Pix.dither(c, 0, 10, T, 6, Pal.SEA, Pal.SEA_DK)
	var shift: int = [0, 2, 4, 2][f]
	Pix.hline(c, (2 + shift) % T, 3, 5, Pal.SEA_LT)
	Pix.hline(c, (9 + shift) % T, 8, 4, Pal.SEA_LT)
	Pix.hline(c, (5 - shift + T) % T, 13, 4, Pal.SEA_DK)
	if f % 2 == 0:
		Pix.px(c, (12 + shift) % T, 5, Pal.SEA_PALE)


static func _water_shallow(c: Image, f: int) -> void:
	Pix.rect(c, 0, 0, T, T, Pal.SEA_LT)
	Pix.dither(c, 0, 11, T, 5, Pal.SEA_LT, Pal.SAND)
	var shift: int = [0, 1, 2, 1][f]
	Pix.hline(c, (3 + shift * 2) % T, 4, 4, Pal.SEA_PALE)
	Pix.hline(c, (10 - shift + T) % T, 9, 4, Pal.SEA_PALE)
	if f == 1 or f == 3:
		Pix.px(c, (7 + shift) % T, 6, Pal.FOAM)


static func _foam(c: Image, f: int) -> void:
	# 海岸線：上半水、下半沙，交界泡沫隨幀推移
	Pix.rect(c, 0, 0, T, 9, Pal.SEA_LT)
	Pix.rect(c, 0, 9, T, 7, Pal.SAND_LT)
	Pix.speckle(c, 0, 10, T, 6, Pal.SAND, 6, 14)
	var offset: int = [0, 1, 2, 1][f]
	for x in range(T):
		var y: int = 8 + ((x / 3 + offset) % 2)
		Pix.px(c, x, y, Pal.FOAM)
		if (x + offset) % 4 == 0:
			Pix.px(c, x, y - 1, Pal.FOAM)
			Pix.px(c, x, y + 1, Pal.SEA_PALE)
	Pix.hline(c, 0, 3 + offset, 3, Pal.SEA_PALE)
	Pix.hline(c, 10, 5 - offset, 3, Pal.SEA_PALE)


static func _sparkle(c: Image, f: int) -> void:
	if f == 0:
		Pix.px(c, 8, 6, Pal.AMBER_LT)
		Pix.px(c, 8, 8, Pal.AMBER_LT)
		Pix.px(c, 7, 7, Pal.AMBER_LT)
		Pix.px(c, 9, 7, Pal.AMBER_LT)
		Pix.px(c, 8, 7, Pal.FOAM)
	else:
		Pix.px(c, 8, 7, Pal.AMBER)
		Pix.px(c, 11, 4, Pal.SPROUT)


# ---------- 自然物件 ----------

static func _tree_trunk(c: Image) -> void:
	Pix.contact_shadow(c, 8.0, 13.5, 6.0, 2.0)
	Pix.rect(c, 5, 2, 5, 12, Pal.WOOD)
	Pix.vline(c, 5, 2, 12, Pal.WOOD_LT)
	Pix.vline(c, 9, 2, 12, Pal.WOOD_DK)
	# 根部外張
	Pix.rect(c, 3, 12, 2, 2, Pal.WOOD)
	Pix.rect(c, 10, 12, 3, 2, Pal.WOOD_DK)
	Pix.px(c, 7, 6, Pal.WOOD_DK)
	Pix.px(c, 7, 7, Pal.WOOD_DK)
	Pix.px(c, 6, 9, Pal.MOSS)
	Pix.px(c, 6, 10, Pal.MOSS)
	Pix.vline(c, 4, 3, 11, Pal.INK)
	Pix.vline(c, 10, 3, 9, Pal.INK)


static func _rock(c: Image) -> void:
	Pix.contact_shadow(c, 8.0, 13.0, 6.5, 2.0)
	Pix.ellipse(c, 8, 9, 6, 5, Pal.INK)
	Pix.ellipse(c, 8, 9, 5, 4, Pal.MIST)
	Pix.ellipse(c, 6.5, 7.5, 2.5, 1.8, Pal.MIST_LT)
	Pix.dither(c, 5, 10, 7, 3, Pal.MIST, Pal.MIST_DK)
	Pix.px(c, 10, 7, Pal.MIST_DK)
	Pix.px(c, 4, 11, Pal.MOSS)


static func _rock_small(c: Image) -> void:
	Pix.ellipse(c, 5, 11, 2.5, 1.8, Pal.MIST_DK)
	Pix.px(c, 4, 10, Pal.MIST_LT)
	Pix.ellipse(c, 11, 12, 1.8, 1.4, Pal.MIST)
	Pix.px(c, 11, 11, Pal.MIST_LT)


static func _fern(c: Image) -> void:
	for i in range(3):
		var bx := 4 + i * 4
		Pix.vline(c, bx, 8, 6, Pal.MOSS)
		Pix.px(c, bx - 1, 7 + i % 2, Pal.LEAF)
		Pix.px(c, bx + 1, 6 + i % 2, Pal.LEAF)
		Pix.px(c, bx, 5 + i % 2, Pal.SPROUT)
	Pix.hline(c, 3, 14, 10, Pal.MOSS_DK)


static func _flowers(c: Image, petal: Color, core: Color) -> void:
	for p: Vector2i in [Vector2i(4, 5), Vector2i(11, 8), Vector2i(6, 12)]:
		Pix.vline(c, p.x, p.y + 1, 3, Pal.MOSS)
		Pix.px(c, p.x - 1, p.y, petal)
		Pix.px(c, p.x + 1, p.y, petal)
		Pix.px(c, p.x, p.y - 1, petal)
		Pix.px(c, p.x, p.y + 1, petal)
		Pix.px(c, p.x, p.y, core)


static func _bush(c: Image) -> void:
	Pix.contact_shadow(c, 8.0, 13.5, 6.0, 1.8)
	Pix.ellipse(c, 8, 9, 6.5, 5, Pal.INK)
	Pix.ellipse(c, 8, 9, 5.5, 4, Pal.MOSS)
	Pix.ellipse(c, 6, 7.5, 3, 2, Pal.LEAF)
	Pix.px(c, 5, 6, Pal.LEAF_LT)
	Pix.px(c, 8, 7, Pal.LEAF_LT)
	Pix.px(c, 11, 10, Pal.CORAL)
	Pix.px(c, 5, 11, Pal.CORAL)


static func _banana(c: Image) -> void:
	Pix.contact_shadow(c, 8.0, 14.0, 5.0, 1.6)
	Pix.vline(c, 8, 6, 8, Pal.WOOD)
	# 大型芭蕉葉：往兩側彎垂
	for i in range(5):
		Pix.px(c, 7 - i, 5 + i / 2, Pal.LEAF_LT)
		Pix.px(c, 6 - i, 6 + i / 2, Pal.LEAF)
		Pix.px(c, 9 + i, 5 + i / 2, Pal.LEAF_LT)
		Pix.px(c, 10 + i, 6 + i / 2, Pal.LEAF)
	Pix.px(c, 8, 3, Pal.SPROUT)
	Pix.px(c, 8, 4, Pal.LEAF_LT)
	Pix.px(c, 3, 8, Pal.MOSS)
	Pix.px(c, 13, 8, Pal.MOSS)


static func _log(c: Image, left_end: bool) -> void:
	Pix.contact_shadow(c, 8.0, 13.0, 7.5, 1.8)
	Pix.rect(c, 0, 6, T, 6, Pal.WOOD)
	Pix.hline(c, 0, 6, T, Pal.WOOD_LT)
	Pix.hline(c, 0, 11, T, Pal.WOOD_DK)
	Pix.hline(c, 0, 5, T, Pal.INK)
	Pix.hline(c, 0, 12, T, Pal.INK)
	if left_end:
		Pix.ellipse(c, 3, 8.5, 2.5, 3.2, Pal.WOOD_LT)
		Pix.ellipse(c, 3, 8.5, 1.4, 1.8, Pal.WOOD_DK)
		Pix.px(c, 3, 8, Pal.WOOD)
	Pix.px(c, 8, 7, Pal.MOSS)
	Pix.px(c, 9, 7, Pal.MOSS)
	Pix.px(c, 12, 8, Pal.WOOD_DK)


static func _stump(c: Image) -> void:
	Pix.contact_shadow(c, 8.0, 13.0, 4.5, 1.6)
	Pix.rect(c, 5, 8, 6, 5, Pal.WOOD)
	Pix.vline(c, 5, 8, 5, Pal.WOOD_LT)
	Pix.vline(c, 10, 8, 5, Pal.WOOD_DK)
	Pix.ellipse(c, 8, 7.5, 3.5, 2, Pal.WOOD_LT)
	Pix.ellipse(c, 8, 7.5, 2, 1.2, Pal.WOOD_DK)
	Pix.px(c, 8, 7, Pal.WOOD)


static func _vine(c: Image) -> void:
	for x: int in [2, 6, 10, 14]:
		var len := 8 + (x * 3) % 6
		Pix.vline(c, x, 0, len, Pal.MOSS)
		Pix.px(c, x - 1, len / 2, Pal.LEAF)
		Pix.px(c, x + 1, len / 3, Pal.LEAF)
		Pix.px(c, x, len, Pal.LEAF_LT)


static func _cliff_face(c: Image) -> void:
	Pix.rect(c, 0, 0, T, T, Pal.MIST_DK)
	Pix.hline(c, 0, 0, T, Pal.MIST_LT)
	Pix.hline(c, 0, 1, T, Pal.MIST)
	for y: int in [5, 9, 13]:
		Pix.hline(c, 0, y, T, Pal.SLATE)
	Pix.vline(c, 4, 5, 4, Pal.SLATE)
	Pix.vline(c, 11, 9, 4, Pal.SLATE)
	Pix.speckle(c, 0, 2, T, 13, Pal.MIST, 7, 15)
	Pix.px(c, 7, 3, Pal.MOSS)
	Pix.hline(c, 0, 15, T, Pal.INK)


static func _cliff_top(c: Image) -> void:
	_grass(c, 16)
	Pix.hline(c, 0, 13, T, Pal.MOSS_DK)
	Pix.hline(c, 0, 14, T, Pal.MIST_LT)
	Pix.hline(c, 0, 15, T, Pal.MIST_DK)


static func _reed(c: Image) -> void:
	for x: int in [3, 7, 12]:
		Pix.vline(c, x, 4 + x % 3, 10 - x % 3, Pal.LEAF)
		Pix.px(c, x, 3 + x % 3, Pal.SAND_LT)
		Pix.px(c, x, 2 + x % 3, Pal.SAND)


static func _pebbles(c: Image) -> void:
	Pix.px(c, 4, 6, Pal.MIST)
	Pix.px(c, 5, 6, Pal.MIST_LT)
	Pix.px(c, 10, 11, Pal.MIST)
	Pix.px(c, 12, 4, Pal.GRAY)
	Pix.px(c, 7, 13, Pal.MIST_LT)


# ---------- 聚落 ----------

static func _brick_wall(c: Image) -> void:
	Pix.rect(c, 0, 0, T, T, Pal.BRICK)
	for row in range(4):
		var y := row * 4
		Pix.hline(c, 0, y + 3, T, Pal.PAPER_DIM)
		var offset := 0 if row % 2 == 0 else 4
		for x in range(offset, T, 8):
			Pix.vline(c, x, y, 3, Pal.PAPER_DIM)
	Pix.speckle(c, 0, 0, T, T, Pal.BRICK_LT, 6, 17)
	Pix.speckle(c, 0, 0, T, T, Pal.BRICK_DK, 5, 18)
	Pix.rect(c, 0, 13, T, 3, Pal.BRICK_DK)
	Pix.hline(c, 0, 0, T, Pal.INK)


static func _brick_window(c: Image) -> void:
	_brick_wall(c)
	Pix.rect(c, 3, 4, 10, 8, Pal.WOOD_DK)
	Pix.rect(c, 4, 5, 8, 6, Pal.AMBER)
	Pix.dither(c, 4, 8, 8, 3, Pal.AMBER, Pal.AMBER_DK)
	Pix.px(c, 5, 6, Pal.AMBER_LT)
	Pix.px(c, 6, 6, Pal.AMBER_LT)
	Pix.vline(c, 8, 5, 6, Pal.WOOD_DK)
	Pix.hline(c, 3, 12, 10, Pal.INK)


static func _plaster_wall(c: Image) -> void:
	Pix.rect(c, 0, 0, T, T, Pal.MIST)
	Pix.speckle(c, 0, 0, T, T, Pal.MIST_LT, 16, 19)
	Pix.speckle(c, 0, 0, T, T, Pal.MIST_DK, 8, 20)
	Pix.rect(c, 0, 13, T, 3, Pal.MIST_DK)
	Pix.vline(c, 12, 2, 5, Pal.MIST_DK)
	Pix.px(c, 11, 7, Pal.MIST_DK)
	Pix.hline(c, 0, 0, T, Pal.INK)


static func _plaster_window(c: Image) -> void:
	_plaster_wall(c)
	Pix.rect(c, 3, 4, 10, 8, Pal.WOOD)
	Pix.rect(c, 4, 5, 8, 6, Pal.NIGHT)
	Pix.px(c, 5, 6, Pal.FOG)
	Pix.px(c, 6, 7, Pal.FOG)
	Pix.px(c, 10, 9, Pal.SLATE)
	Pix.vline(c, 8, 5, 6, Pal.WOOD)
	Pix.hline(c, 3, 12, 10, Pal.INK)


static func _door(c: Image) -> void:
	_plaster_wall(c)
	Pix.rect(c, 3, 2, 10, 14, Pal.WOOD_DK)
	Pix.rect(c, 4, 3, 8, 13, Pal.WOOD)
	for x: int in [6, 9]:
		Pix.vline(c, x, 3, 13, Pal.WOOD_DK)
	Pix.vline(c, 4, 3, 13, Pal.WOOD_LT)
	Pix.px(c, 10, 9, Pal.AMBER)
	Pix.hline(c, 3, 2, 10, Pal.INK)
	Pix.rect(c, 3, 15, 10, 1, Pal.SAND_DK)


static func _stone_wall(c: Image) -> void:
	# 石造矮牆：上緣頂面 + 疊石正面
	Pix.rect(c, 0, 0, T, 5, Pal.MIST_LT)
	Pix.hline(c, 0, 0, T, Pal.FOG)
	Pix.rect(c, 0, 5, T, 11, Pal.MIST)
	for p: Vector2i in [Vector2i(1, 6), Vector2i(9, 6), Vector2i(5, 10), Vector2i(12, 10), Vector2i(2, 12)]:
		Pix.ellipse(c, p.x + 2, p.y + 1.5, 2.6, 1.7, Pal.MIST_DK)
		Pix.ellipse(c, p.x + 1.6, p.y + 1.1, 1.6, 1.0, Pal.MIST)
		Pix.px(c, p.x + 1, p.y, Pal.MIST_LT)
	Pix.px(c, 7, 8, Pal.MOSS)
	Pix.px(c, 14, 13, Pal.MOSS)
	Pix.px(c, 3, 7, Pal.MOSS)
	Pix.hline(c, 0, 15, T, Pal.INK)
	Pix.hline(c, 0, 5, T, Pal.SLATE)


static func _fence(c: Image) -> void:
	for x: int in [2, 8, 14]:
		Pix.vline(c, x, 4, 10, Pal.WOOD)
		Pix.px(c, x, 4, Pal.WOOD_LT)
		Pix.px(c, x, 13, Pal.WOOD_DK)
	Pix.hline(c, 0, 6, T, Pal.WOOD_LT)
	Pix.hline(c, 0, 7, T, Pal.WOOD_DK)
	Pix.hline(c, 0, 10, T, Pal.WOOD_LT)
	Pix.hline(c, 0, 11, T, Pal.WOOD_DK)


static func _power_pole(c: Image) -> void:
	Pix.contact_shadow(c, 8.0, 14.0, 3.5, 1.4)
	Pix.rect(c, 7, 1, 3, 14, Pal.WOOD)
	Pix.vline(c, 7, 1, 14, Pal.WOOD_LT)
	Pix.vline(c, 9, 1, 14, Pal.WOOD_DK)
	Pix.rect(c, 3, 2, 11, 2, Pal.WOOD_DK)
	Pix.hline(c, 3, 2, 11, Pal.WOOD)
	Pix.px(c, 4, 1, Pal.AMBER)
	Pix.px(c, 12, 1, Pal.AMBER)
	Pix.px(c, 8, 6, Pal.WOOD_DK)
	Pix.px(c, 8, 10, Pal.WOOD_DK)


static func _lamp_post(c: Image) -> void:
	Pix.contact_shadow(c, 8.0, 14.0, 3.0, 1.3)
	Pix.vline(c, 8, 4, 11, Pal.STEEL)
	Pix.vline(c, 7, 4, 11, Pal.SLATE)
	Pix.rect(c, 6, 1, 5, 4, Pal.SLATE)
	Pix.rect(c, 7, 2, 3, 2, Pal.AMBER)
	Pix.px(c, 7, 2, Pal.AMBER_LT)
	Pix.blend(c, 6, 3, Pal.AMBER, 0.35)
	Pix.blend(c, 10, 3, Pal.AMBER, 0.35)
	Pix.px(c, 8, 0, Pal.SLATE)


static func _sign(c: Image) -> void:
	Pix.contact_shadow(c, 8.0, 14.0, 4.0, 1.4)
	Pix.rect(c, 7, 8, 2, 6, Pal.WOOD)
	Pix.vline(c, 7, 8, 6, Pal.WOOD_LT)
	Pix.rect(c, 2, 2, 12, 7, Pal.WOOD_DK)
	Pix.rect(c, 3, 3, 10, 5, Pal.WOOD_LT)
	Pix.hline(c, 4, 4, 8, Pal.INK)
	Pix.hline(c, 4, 6, 6, Pal.INK)
	Pix.px(c, 3, 3, Pal.SAND_LT)


static func _crate(c: Image) -> void:
	Pix.contact_shadow(c, 8.0, 14.0, 5.0, 1.4)
	Pix.rect(c, 3, 4, 10, 10, Pal.WOOD)
	Pix.outline_rect(c, 3, 4, 10, 10, Pal.WOOD_DK)
	Pix.hline(c, 4, 5, 8, Pal.WOOD_LT)
	Pix.px(c, 4, 5, Pal.WOOD_LT)
	for i in range(8):
		Pix.px(c, 4 + i, 6 + i, Pal.WOOD_DK)
	Pix.hline(c, 3, 14, 10, Pal.INK)


static func _barrel(c: Image) -> void:
	Pix.contact_shadow(c, 8.0, 14.0, 4.5, 1.4)
	Pix.rect(c, 4, 4, 8, 10, Pal.WOOD)
	Pix.vline(c, 4, 4, 10, Pal.WOOD_LT)
	Pix.vline(c, 11, 4, 10, Pal.WOOD_DK)
	Pix.ellipse(c, 7.5, 4, 4, 1.5, Pal.WOOD_LT)
	Pix.ellipse(c, 7.5, 4, 2.5, 0.8, Pal.WOOD_DK)
	Pix.hline(c, 4, 7, 8, Pal.STEEL)
	Pix.hline(c, 4, 11, 8, Pal.STEEL)
	Pix.hline(c, 4, 14, 8, Pal.INK)


static func _pot_plant(c: Image) -> void:
	Pix.contact_shadow(c, 8.0, 14.5, 3.5, 1.2)
	Pix.rect(c, 5, 9, 6, 5, Pal.BRICK)
	Pix.vline(c, 5, 9, 5, Pal.BRICK_LT)
	Pix.vline(c, 10, 9, 5, Pal.BRICK_DK)
	Pix.hline(c, 4, 9, 8, Pal.BRICK_LT)
	Pix.ellipse(c, 8, 6, 4, 3, Pal.MOSS)
	Pix.ellipse(c, 7, 5, 2, 1.5, Pal.LEAF)
	Pix.px(c, 6, 4, Pal.LEAF_LT)
	Pix.px(c, 10, 6, Pal.LEAF)


static func _buoy(c: Image) -> void:
	# 透明背景（3D 立牌直接浮在水面 Shader 上；只留船身與兩撇浪花）
	Pix.ellipse(c, 8, 9, 4.5, 3.5, Pal.INK)
	Pix.ellipse(c, 8, 9, 3.5, 2.7, Pal.CORAL)
	Pix.ellipse(c, 7, 8, 1.5, 1.0, Pal.CORAL_LT)
	Pix.hline(c, 5, 9, 7, Pal.FOAM)
	Pix.rect(c, 7, 3, 3, 3, Pal.STEEL)
	Pix.px(c, 8, 2, Pal.AMBER_LT)
	Pix.hline(c, 4, 13, 3, Pal.SEA_PALE)
	Pix.hline(c, 10, 12, 4, Pal.SEA_PALE)


static func _flag(c: Image, f: int) -> void:
	Pix.vline(c, 3, 1, 14, Pal.WOOD_DK)
	Pix.px(c, 3, 1, Pal.WOOD_LT)
	Pix.px(c, 3, 2, Pal.AMBER)
	if f == 0:
		Pix.rect(c, 4, 2, 9, 5, Pal.CORAL)
		Pix.rect(c, 4, 2, 9, 1, Pal.CORAL_LT)
		Pix.px(c, 12, 6, Pal.CORAL)
		Pix.rect(c, 11, 5, 3, 2, Pal.BRICK_DK)
	else:
		Pix.rect(c, 4, 2, 7, 5, Pal.CORAL)
		Pix.rect(c, 4, 2, 7, 1, Pal.CORAL_LT)
		Pix.rect(c, 10, 3, 3, 3, Pal.CORAL)
		Pix.px(c, 13, 4, Pal.BRICK_DK)


# ---------- 屋頂與設備 ----------

static func _roof_tin(c: Image, seed_value: int, rusty: bool) -> void:
	Pix.rect(c, 0, 0, T, T, Pal.RUST)
	for x in range(0, T, 4):
		Pix.vline(c, x, 0, T, Pal.RUST_DK)
		Pix.vline(c, x + 1, 0, T, Pal.RUST_LT)
	Pix.speckle(c, 0, 0, T, T, Pal.BRICK_DK, 8 if rusty else 4, seed_value)
	if rusty:
		Pix.rect(c, 9, 9, 3, 2, Pal.BRICK_DK)
	Pix.hline(c, 0, 15, T, Pal.RUST_DK)


static func _roof_tin_ridge(c: Image) -> void:
	_roof_tin(c, 56, false)
	Pix.rect(c, 0, 0, T, 3, Pal.RUST_LT)
	Pix.hline(c, 0, 0, T, Pal.INK)
	Pix.hline(c, 0, 3, T, Pal.RUST_DK)


static func _roof_brick(c: Image, alt: bool) -> void:
	Pix.rect(c, 0, 0, T, T, Pal.BRICK)
	for row in range(4):
		var y := row * 4
		var offset := 0 if (row + (1 if alt else 0)) % 2 == 0 else 4
		for x in range(offset - 8, T, 8):
			# 圓弧瓦片
			Pix.hline(c, x + 1, y + 3, 6, Pal.BRICK_DK)
			Pix.px(c, x + 1, y + 2, Pal.BRICK_DK)
			Pix.px(c, x + 6, y + 2, Pal.BRICK_DK)
			Pix.hline(c, x + 2, y, 4, Pal.BRICK_LT)
	Pix.hline(c, 0, 15, T, Pal.BRICK_DK)


static func _roof_brick_ridge(c: Image) -> void:
	_roof_brick(c, false)
	Pix.rect(c, 0, 0, T, 3, Pal.BRICK_LT)
	Pix.hline(c, 0, 0, T, Pal.INK)
	Pix.hline(c, 0, 3, T, Pal.BRICK_DK)


static func _roof_eave(c: Image) -> void:
	Pix.rect(c, 0, 0, T, 12, Pal.RUST)
	for x in range(0, T, 4):
		Pix.vline(c, x, 0, 12, Pal.RUST_DK)
		Pix.vline(c, x + 1, 0, 12, Pal.RUST_LT)
	Pix.rect(c, 0, 12, T, 2, Pal.RUST_DK)
	Pix.hline(c, 0, 14, T, Pal.INK)
	# 簷下陰影落在下一格，這裡收在 INK 線


static func _chimney(c: Image) -> void:
	Pix.rect(c, 5, 4, 6, 11, Pal.BRICK)
	Pix.vline(c, 5, 4, 11, Pal.BRICK_LT)
	Pix.vline(c, 10, 4, 11, Pal.BRICK_DK)
	Pix.rect(c, 4, 2, 8, 3, Pal.BRICK_DK)
	Pix.hline(c, 4, 2, 8, Pal.BRICK_LT)
	Pix.rect(c, 6, 3, 4, 1, Pal.INK)
	Pix.hline(c, 5, 8, 6, Pal.PAPER_DIM)
	Pix.hline(c, 5, 12, 6, Pal.PAPER_DIM)


static func _antenna(c: Image) -> void:
	Pix.contact_shadow(c, 8.0, 14.0, 5.0, 1.5)
	Pix.rect(c, 7, 9, 2, 6, Pal.STEEL)
	Pix.ellipse(c, 8, 6, 6, 4, Pal.SLATE)
	Pix.ellipse(c, 8, 6, 5, 3, Pal.STEEL)
	Pix.ellipse(c, 6.5, 5, 2, 1.2, Pal.MIST_LT)
	Pix.px(c, 8, 6, Pal.AMBER)
	Pix.speckle(c, 4, 4, 9, 5, Pal.RUST, 5, 21)
	Pix.px(c, 12, 9, Pal.MOSS)
	Pix.px(c, 4, 10, Pal.MOSS)


static func _console(c: Image) -> void:
	Pix.contact_shadow(c, 8.0, 14.5, 5.5, 1.4)
	Pix.rect(c, 2, 4, 12, 10, Pal.STEEL)
	Pix.rect(c, 2, 4, 12, 1, Pal.MIST_LT)
	Pix.vline(c, 13, 4, 10, Pal.SLATE)
	Pix.rect(c, 4, 6, 8, 4, Pal.NIGHT)
	Pix.px(c, 5, 7, Pal.AMBER)
	Pix.px(c, 7, 8, Pal.SEA_PALE)
	Pix.px(c, 10, 7, Pal.CORAL)
	Pix.px(c, 4, 12, Pal.AMBER)
	Pix.px(c, 6, 12, Pal.CORAL)
	Pix.speckle(c, 2, 10, 12, 4, Pal.RUST, 4, 22)
	Pix.vline(c, 12, 2, 2, Pal.MOSS)
	Pix.px(c, 12, 4, Pal.LEAF)


static func _telescope(c: Image) -> void:
	Pix.contact_shadow(c, 8.0, 14.5, 4.0, 1.3)
	Pix.vline(c, 6, 9, 6, Pal.STEEL)
	Pix.vline(c, 10, 9, 6, Pal.STEEL)
	Pix.vline(c, 8, 8, 7, Pal.SLATE)
	# 斜向鏡筒
	for i in range(6):
		Pix.px(c, 5 + i, 8 - i, Pal.STEEL)
		Pix.px(c, 6 + i, 8 - i, Pal.MIST_LT)
	Pix.px(c, 11, 2, Pal.AMBER_LT)
	Pix.px(c, 4, 9, Pal.SLATE)


static func _bench(c: Image) -> void:
	Pix.contact_shadow(c, 8.0, 14.0, 6.0, 1.3)
	Pix.rect(c, 2, 8, 12, 2, Pal.WOOD_LT)
	Pix.hline(c, 2, 10, 12, Pal.WOOD_DK)
	Pix.vline(c, 3, 10, 4, Pal.WOOD)
	Pix.vline(c, 12, 10, 4, Pal.WOOD)
	Pix.rect(c, 2, 4, 12, 1, Pal.WOOD_LT)
	Pix.vline(c, 3, 5, 3, Pal.WOOD)
	Pix.vline(c, 12, 5, 3, Pal.WOOD)


static func _wire(c: Image) -> void:
	for x in range(T):
		var sag := 0
		if x >= 3 and x <= 12:
			sag = 1
		if x >= 6 and x <= 9:
			sag = 2
		Pix.px(c, x, 4 + sag, Pal.INK)
	Pix.px(c, 0, 4, Pal.SLATE)
	Pix.px(c, 15, 4, Pal.SLATE)


static func _canopy(c: Image, seed_value: int) -> void:
	Pix.ellipse(c, 8, 8, 7.5, 7, Pal.INK)
	Pix.ellipse(c, 8, 8, 6.5, 6, Pal.MOSS)
	Pix.ellipse(c, 6, 6, 3.5, 3, Pal.LEAF)
	var r := Pix.rng(seed_value)
	for i in range(5):
		Pix.px(c, r.randi_range(3, 12), r.randi_range(3, 12), Pal.LEAF_LT)
	Pix.px(c, 5, 4, Pal.SPROUT)
	Pix.dither(c, 5, 11, 7, 3, Pal.MOSS, Pal.MOSS_DK)


# ---------- 室內 ----------

static func _wall_plank(c: Image) -> void:
	Pix.rect(c, 0, 0, T, T, Pal.WOOD)
	for x in range(0, T, 4):
		Pix.vline(c, x, 0, T, Pal.WOOD_DK)
		Pix.vline(c, x + 1, 0, T, Pal.WOOD_LT)
	Pix.rect(c, 0, 0, T, 3, Pal.WOOD_DK)
	Pix.hline(c, 0, 3, T, Pal.INK)
	Pix.rect(c, 0, 13, T, 3, Pal.WOOD_DK)
	Pix.hline(c, 0, 13, T, Pal.WOOD_LT)


static func _wall_plank_top(c: Image) -> void:
	Pix.rect(c, 0, 0, T, T, Pal.NIGHT)
	Pix.speckle(c, 0, 0, T, T, Pal.SLATE, 8, 23)
	Pix.hline(c, 0, 15, T, Pal.INK)


static func _wall_stone_in(c: Image) -> void:
	Pix.rect(c, 0, 0, T, T, Pal.MIST_DK)
	for p: Vector2i in [Vector2i(1, 2), Vector2i(8, 1), Vector2i(4, 7), Vector2i(11, 8), Vector2i(1, 11), Vector2i(9, 12)]:
		Pix.ellipse(c, p.x + 2, p.y + 1.5, 2.6, 1.8, Pal.MIST)
		Pix.px(c, p.x + 1, p.y + 1, Pal.MIST_LT)
	Pix.hline(c, 0, 15, T, Pal.INK)


static func _window_in(c: Image) -> void:
	_wall_plank(c)
	Pix.rect(c, 3, 4, 10, 8, Pal.WOOD_DK)
	Pix.rect(c, 4, 5, 8, 6, Pal.SEA_PALE)
	Pix.dither(c, 4, 5, 8, 3, Pal.SEA_PALE, Pal.FOG)
	Pix.vline(c, 8, 5, 6, Pal.WOOD_DK)
	Pix.hline(c, 4, 8, 8, Pal.WOOD_DK)


static func _bed_head(c: Image) -> void:
	Pix.rect(c, 2, 2, 12, 14, Pal.WOOD_DK)
	Pix.rect(c, 2, 2, 12, 3, Pal.WOOD)
	Pix.hline(c, 2, 2, 12, Pal.WOOD_LT)
	Pix.rect(c, 3, 5, 10, 11, Pal.FOAM)
	Pix.rect(c, 4, 6, 8, 3, Pal.PAPER)
	Pix.hline(c, 4, 8, 8, Pal.PAPER_DIM)
	Pix.rect(c, 3, 10, 10, 6, Pal.SEA)
	Pix.hline(c, 3, 10, 10, Pal.SEA_LT)
	Pix.px(c, 5, 12, Pal.SEA_LT)
	Pix.px(c, 9, 13, Pal.SEA_LT)


static func _bed_foot(c: Image) -> void:
	Pix.rect(c, 2, 0, 12, 13, Pal.SEA)
	Pix.vline(c, 2, 0, 13, Pal.SEA_DK)
	Pix.vline(c, 13, 0, 13, Pal.SEA_DK)
	Pix.px(c, 6, 2, Pal.SEA_LT)
	Pix.px(c, 10, 5, Pal.SEA_LT)
	Pix.px(c, 4, 8, Pal.SEA_LT)
	Pix.rect(c, 2, 11, 12, 3, Pal.WOOD)
	Pix.hline(c, 2, 11, 12, Pal.WOOD_LT)
	Pix.hline(c, 2, 13, 12, Pal.WOOD_DK)
	Pix.hline(c, 2, 14, 12, Pal.INK)


static func _table(c: Image) -> void:
	Pix.contact_shadow(c, 8.0, 14.0, 6.0, 1.5)
	Pix.rect(c, 2, 4, 12, 8, Pal.WOOD_LT)
	Pix.outline_rect(c, 2, 4, 12, 8, Pal.WOOD_DK)
	Pix.rect(c, 4, 6, 4, 3, Pal.PAPER)
	Pix.hline(c, 5, 7, 2, Pal.GRAY)
	Pix.ellipse(c, 11, 7, 1.5, 1.2, Pal.SEA)
	Pix.px(c, 11, 6, Pal.SEA_LT)
	Pix.vline(c, 3, 12, 3, Pal.WOOD)
	Pix.vline(c, 12, 12, 3, Pal.WOOD)


static func _chair(c: Image) -> void:
	Pix.contact_shadow(c, 8.0, 14.0, 3.5, 1.2)
	Pix.rect(c, 5, 3, 6, 4, Pal.WOOD)
	Pix.hline(c, 5, 3, 6, Pal.WOOD_LT)
	Pix.rect(c, 5, 8, 6, 3, Pal.WOOD_LT)
	Pix.vline(c, 5, 11, 3, Pal.WOOD_DK)
	Pix.vline(c, 10, 11, 3, Pal.WOOD_DK)


static func _bookshelf(c: Image) -> void:
	Pix.rect(c, 1, 1, 14, 15, Pal.WOOD_DK)
	Pix.rect(c, 2, 2, 12, 13, Pal.WOOD)
	for shelf in range(3):
		var y := 3 + shelf * 4
		var colors: Array = [[Pal.CORAL, Pal.SEA, Pal.AMBER, Pal.MOSS], [Pal.SEA, Pal.AMBER, Pal.BRICK, Pal.STEEL], [Pal.AMBER, Pal.MOSS, Pal.CORAL, Pal.SEA]][shelf]
		var x := 3
		for book_color: Color in colors:
			Pix.rect(c, x, y, 2, 3, book_color)
			Pix.px(c, x, y, Color(book_color).lightened(0.2))
			x += 3
		Pix.hline(c, 2, y + 3, 12, Pal.WOOD_DK)
	Pix.hline(c, 1, 15, 14, Pal.INK)


static func _counter(c: Image) -> void:
	Pix.rect(c, 0, 4, T, 3, Pal.WOOD_LT)
	Pix.hline(c, 0, 4, T, Pal.SAND_LT)
	Pix.rect(c, 0, 7, T, 8, Pal.WOOD)
	for x in range(0, T, 4):
		Pix.vline(c, x, 7, 8, Pal.WOOD_DK)
	Pix.hline(c, 0, 15, T, Pal.INK)
	Pix.ellipse(c, 4, 5, 1.4, 1.0, Pal.SEA_PALE)
	Pix.rect(c, 10, 4, 3, 2, Pal.BRICK)


static func _stove(c: Image) -> void:
	Pix.contact_shadow(c, 8.0, 14.5, 5.0, 1.3)
	Pix.rect(c, 3, 4, 10, 11, Pal.SLATE)
	Pix.rect(c, 3, 4, 10, 1, Pal.STEEL)
	Pix.rect(c, 5, 7, 6, 4, Pal.NIGHT)
	Pix.px(c, 6, 9, Pal.AMBER)
	Pix.px(c, 7, 8, Pal.AMBER_LT)
	Pix.px(c, 8, 9, Pal.CORAL)
	Pix.rect(c, 5, 2, 2, 2, Pal.STEEL)
	Pix.ellipse(c, 10, 3, 1.6, 1.2, Pal.MIST)
	Pix.hline(c, 3, 14, 10, Pal.INK)


static func _instrument(c: Image) -> void:
	Pix.rect(c, 1, 1, 14, 14, Pal.STEEL)
	Pix.rect(c, 1, 1, 14, 1, Pal.MIST_LT)
	Pix.vline(c, 14, 1, 14, Pal.SLATE)
	Pix.rect(c, 3, 3, 5, 4, Pal.NIGHT)
	Pix.px(c, 4, 4, Pal.SPROUT)
	Pix.px(c, 5, 5, Pal.SPROUT)
	Pix.px(c, 6, 4, Pal.SEA_PALE)
	Pix.ellipse(c, 11, 5, 1.8, 1.8, Pal.PAPER)
	Pix.px(c, 11, 4, Pal.CORAL)
	for x: int in [3, 5, 7, 9, 11]:
		Pix.px(c, x, 9, Pal.AMBER if x % 4 == 3 else Pal.CORAL)
	Pix.rect(c, 3, 11, 10, 2, Pal.NIGHT)
	Pix.hline(c, 4, 12, 6, Pal.SEA_PALE)
	Pix.hline(c, 1, 15, 14, Pal.INK)


static func _tape_shelf(c: Image) -> void:
	Pix.rect(c, 1, 1, 14, 15, Pal.WOOD_DK)
	Pix.rect(c, 2, 2, 12, 13, Pal.WOOD)
	for row in range(2):
		var y := 4 + row * 6
		for i in range(3):
			var x := 3 + i * 4
			Pix.ellipse(c, x + 1, y, 1.8, 1.8, Pal.SLATE)
			Pix.px(c, x + 1, y, Pal.PAPER)
			Pix.px(c, x, y - 1, Pal.MIST_LT)
		Pix.hline(c, 2, y + 3, 12, Pal.WOOD_DK)
	Pix.hline(c, 1, 15, 14, Pal.INK)


static func _map_wall(c: Image) -> void:
	_wall_plank(c)
	Pix.rect(c, 2, 4, 12, 9, Pal.PAPER)
	Pix.outline_rect(c, 2, 4, 12, 9, Pal.WOOD_DK)
	# 群島海圖：小島形狀與航線
	Pix.px(c, 5, 6, Pal.MOSS)
	Pix.rect(c, 4, 7, 3, 2, Pal.LEAF)
	Pix.px(c, 10, 8, Pal.LEAF)
	Pix.rect(c, 9, 9, 3, 2, Pal.MOSS)
	Pix.px(c, 7, 10, Pal.SEA)
	Pix.px(c, 8, 9, Pal.SEA)
	Pix.px(c, 6, 11, Pal.SEA)
	Pix.px(c, 5, 6, Pal.CORAL)
	Pix.px(c, 11, 10, Pal.CORAL)


static func _lamp_floor(c: Image) -> void:
	Pix.contact_shadow(c, 8.0, 14.5, 3.0, 1.2)
	Pix.vline(c, 8, 6, 9, Pal.WOOD_DK)
	Pix.rect(c, 5, 2, 7, 4, Pal.AMBER)
	Pix.rect(c, 5, 2, 7, 1, Pal.AMBER_LT)
	Pix.rect(c, 5, 5, 7, 1, Pal.AMBER_DK)
	Pix.blend(c, 4, 3, Pal.AMBER, 0.35)
	Pix.blend(c, 12, 3, Pal.AMBER, 0.35)
	Pix.rect(c, 6, 14, 5, 1, Pal.WOOD_DK)


static func _plant_pot(c: Image) -> void:
	Pix.contact_shadow(c, 8.0, 14.5, 3.0, 1.2)
	Pix.rect(c, 6, 10, 5, 4, Pal.BRICK)
	Pix.hline(c, 5, 10, 7, Pal.BRICK_LT)
	Pix.vline(c, 8, 5, 5, Pal.MOSS)
	Pix.px(c, 6, 5, Pal.LEAF)
	Pix.px(c, 7, 4, Pal.LEAF_LT)
	Pix.px(c, 10, 6, Pal.LEAF)
	Pix.px(c, 9, 3, Pal.SPROUT)
