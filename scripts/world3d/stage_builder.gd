class_name StageBuilder
extends RefCounted
## 2.5D 立體劇場建構器：讀取既有 MapData（三層網格＋elevation）建出
## 低面數 3D 舞台。地形＋建築＋盒體道具合併為單一 ArrayMesh（1 Draw Call，
## 頂點色烘焙 AO）；立牌道具用 Sprite3D（Alpha Scissor）；水面用輕量 Shader。
## 不改任何 Domain Logic；格座標 Grid(X,Y) → World(X,Z)，高度 → World Y。

const LEVEL_H := 0.85           # 每個高度層的世界高度
const EDGE_SKIRT := 1.6         # 戶外地圖邊緣往下的裙牆
const UV_INSET := 0.0015

## 室內牆柱（ground 名稱 → 柱高）
const GROUND_COLUMN := {
	"wall_plank_top": 1.75, "wall_plank": 1.75, "window_in": 1.75, "map_wall": 1.75,
}
const GROUND_HEIGHT_BONUS := {"cliff_face": 1.0}

## 建築立面（deco 名稱 → 盒高）
const FACADE := {
	"brick_wall": 1.35, "brick_window": 1.35, "plaster_wall": 1.35,
	"plaster_window": 1.35, "door_wood": 1.35,
}
## 屋頂板（deco 名稱 → 頂高；基座 1.30 → 形成階狀山形屋頂）
const ROOF := {
	"roof_tin_a": 1.75, "roof_tin_b": 1.75, "roof_tin_ridge": 2.15,
	"roof_brick_a": 1.75, "roof_brick_b": 1.75, "roof_brick_ridge": 2.15,
	"roof_eave": 1.6,
}
## 盒體道具（deco 名稱 → 高）
const BOX := {
	"crate": 0.55, "barrel": 0.62, "log_a": 0.45, "log_b": 0.45, "stump": 0.4,
	"rock_a": 0.5, "bed_head": 0.55, "bed_foot": 0.55, "table": 0.55, "chair": 0.45,
	"bookshelf": 1.3, "counter": 0.85, "stove": 1.0, "instrument": 1.35,
	"tape_shelf": 1.3, "stone_wall": 0.55, "fence": 0.45, "bench": 0.45,
}
## 立牌道具（Sprite3D；tree_trunk 使用合成樹貼圖）
const STANDEE := [
	"tree_trunk", "power_pole", "lamp_post", "sign_wood", "telescope",
	"antenna_dish", "console_rust", "banana_plant", "bush", "fern",
	"flowers_a", "flowers_b", "reed", "rock_small", "buoy", "flag",
	"plant_pot", "pot_plant", "lamp_floor", "pebbles", "vine_wall",
]
## 光源收集（世界場景據此放置 ≤3 盞動態燈＋光暈）
const LIGHT_EMITTERS := ["lamp_post", "lamp_floor", "stove", "brick_window"]

const OUTDOOR_MAPS := ["harbor", "trail", "haven", "shoreline"]


static func build(map: MapData, parent: Node3D) -> Dictionary:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var heights := {}
	var deep_cells: Array[Vector2i] = []
	var shallow_cells: Array[Vector2i] = []
	var lights: Array[Vector3] = []
	var outdoor := map.id in OUTDOOR_MAPS
	# ---------- 地面 ----------
	for y in range(map.height):
		for x in range(map.width):
			var cell := Vector2i(x, y)
			var ground := map.ground_name(cell)
			var h := float(map.elevation(cell)) * LEVEL_H
			if GROUND_COLUMN.has(ground):
				var col_h: float = GROUND_COLUMN[ground]
				_box(st, cell, h, h + col_h, ground, ground, 0.78)
				heights[cell] = h + col_h
				continue
			if GROUND_HEIGHT_BONUS.has(ground):
				h += float(GROUND_HEIGHT_BONUS[ground]) * LEVEL_H
			match ground:
				"water_deep":
					deep_cells.append(cell)
					heights[cell] = h - 0.34
					_top(st, cell, h - 0.55, "water_deep", 0.35)  # 深色池底
				"water_shallow":
					shallow_cells.append(cell)
					heights[cell] = h - 0.14
					_top(st, cell, h - 0.14, "sand_a", 0.9)
				"foam":
					heights[cell] = h - 0.06
					_top(st, cell, h - 0.06, "foam", 1.0)
				"stairs":
					heights[cell] = _stairs(st, map, cell)
				"":
					heights[cell] = h
				_:
					heights[cell] = h
					# 手作感：每格頂面帶細微明度差（棋盤僵硬感 → 手鋪石板／草皮）
					var jitter := 1.0 - 0.05 * float((cell.x * 31 + cell.y * 17) % 4) / 3.0
					_top(st, cell, h, ground, jitter)
	# ---------- 側裙（高低差與地圖邊緣） ----------
	for y in range(map.height):
		for x in range(map.width):
			var cell := Vector2i(x, y)
			if GROUND_COLUMN.has(map.ground_name(cell)):
				continue
			var h: float = heights.get(cell, 0.0)
			for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n := cell + offset
				var nh: float
				if map.in_bounds(n):
					nh = float(heights.get(n, 0.0))
					if GROUND_COLUMN.has(map.ground_name(n)):
						continue
				else:
					nh = h - (EDGE_SKIRT if outdoor else 0.0)
				if nh < h - 0.02:
					_side(st, cell, offset, h, nh, "cliff_face" if outdoor else "wall_stone_in", 0.62)
	# ---------- 建築與盒體道具 ----------
	for y in range(map.height):
		for x in range(map.width):
			var cell := Vector2i(x, y)
			var deco := map.deco_name(cell)
			if deco.is_empty():
				continue
			var base: float = float(map.elevation(cell)) * LEVEL_H
			if FACADE.has(deco):
				_box(st, cell, base, base + float(FACADE[deco]), deco, "roof_eave", 0.9)
				if deco == "brick_window":
					lights.append(_center(cell) + Vector3(0, 0.9, 0.65))
			elif ROOF.has(deco):
				_roof_prism(st, map, cell, base, deco)
			elif deco == "chimney":
				# 煙囪格自己也要有屋面，煙囪柱從屋脊冒出
				_roof_prism(st, map, cell, base, "roof_tin_a")
				_box(st, cell, base + 1.9, base + 2.6, "chimney", "chimney", 0.8, 0.4)
			elif BOX.has(deco):
				_box(st, cell, base, base + float(BOX[deco]), deco, deco, 0.85, 0.86)
	st.generate_normals()
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = st.commit()
	mesh_instance.material_override = _atlas_material()
	parent.add_child(mesh_instance)
	# ---------- 立牌道具 ----------
	var tree_flip := false
	for y in range(map.height):
		for x in range(map.width):
			var cell := Vector2i(x, y)
			var deco := map.deco_name(cell)
			if deco.is_empty() or not deco in STANDEE:
				continue
			var h: float = heights.get(cell, 0.0)
			if deco == "tree_trunk":
				tree_flip = not tree_flip
				_tree_standee(parent, cell, h, tree_flip)
			else:
				_atlas_standee(parent, cell, h, deco)
			if deco in LIGHT_EMITTERS:
				lights.append(_center(cell) + Vector3(0, 0.85, 0.1))
	# ---------- 水面 ----------
	if not deep_cells.is_empty():
		_water_plane(parent, deep_cells, -0.32, map, true, outdoor and map.id in ["harbor", "haven", "shoreline"])
	if not shallow_cells.is_empty():
		_water_plane(parent, shallow_cells, -0.05, map, false, false)
	# ---------- 戶外遠景 ----------
	if outdoor:
		_backdrop(parent, map)
	return {"heights": heights, "lights": lights}


static func _center(cell: Vector2i) -> Vector3:
	return Vector3(float(cell.x) + 0.5, 0.0, float(cell.y) + 0.5)


static func height_at(heights: Dictionary, cell: Vector2i) -> float:
	return float(heights.get(cell, 0.0))


# ---------- Mesh 工具 ----------

static func _uv_rect(tile_name: String) -> Rect2:
	var pos := TileCatalog.pos(tile_name if TileCatalog.has_tile(tile_name) else "grass_a")
	var u0 := float(pos.x) / 16.0 + UV_INSET
	var v0 := float(pos.y) / 6.0 + UV_INSET
	return Rect2(u0, v0, 1.0 / 16.0 - UV_INSET * 2.0, 1.0 / 6.0 - UV_INSET * 2.0)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, uv: Rect2, shade: float) -> void:
	var color := Color(shade, shade, shade)
	var uvs: Array[Vector2] = [
		Vector2(uv.position.x, uv.position.y),
		Vector2(uv.end.x, uv.position.y),
		Vector2(uv.end.x, uv.end.y),
		Vector2(uv.position.x, uv.end.y),
	]
	var order: Array[int] = [0, 1, 2, 0, 2, 3]
	var verts: Array[Vector3] = [a, b, c, d]
	for i in order:
		st.set_color(color)
		st.set_uv(uvs[i])
		st.add_vertex(verts[i])


static func _top(st: SurfaceTool, cell: Vector2i, h: float, tile_name: String, shade: float) -> void:
	var x := float(cell.x)
	var z := float(cell.y)
	_quad(st,
		Vector3(x, h, z), Vector3(x + 1, h, z),
		Vector3(x + 1, h, z + 1), Vector3(x, h, z + 1),
		_uv_rect(tile_name), shade)


static func _side(st: SurfaceTool, cell: Vector2i, dir: Vector2i, top: float, bottom: float, tile_name: String, shade: float) -> void:
	var x := float(cell.x)
	var z := float(cell.y)
	var uv := _uv_rect(tile_name)
	# 高牆重複貼圖：以整層切段
	var y1 := top
	while y1 > bottom + 0.01:
		var y0 := maxf(bottom, y1 - 1.0)
		var a: Vector3
		var b: Vector3
		if dir == Vector2i(0, 1):
			a = Vector3(x, y1, z + 1)
			b = Vector3(x + 1, y1, z + 1)
		elif dir == Vector2i(0, -1):
			a = Vector3(x + 1, y1, z)
			b = Vector3(x, y1, z)
		elif dir == Vector2i(1, 0):
			a = Vector3(x + 1, y1, z + 1)
			b = Vector3(x + 1, y1, z)
		else:
			a = Vector3(x, y1, z)
			b = Vector3(x, y1, z + 1)
		_quad(st, a, b, Vector3(b.x, y0, b.z), Vector3(a.x, y0, a.z), uv, shade)
		y1 = y0


static func _box(st: SurfaceTool, cell: Vector2i, y0: float, y1: float, side_tile: String, top_tile: String, top_shade: float, inset_scale: float = 1.0) -> void:
	var cx := float(cell.x) + 0.5
	var cz := float(cell.y) + 0.5
	var half := 0.5 * inset_scale
	var uv := _uv_rect(side_tile)
	var top_uv := _uv_rect(top_tile)
	var x0 := cx - half
	var x1 := cx + half
	var z0 := cz - half
	var z1 := cz + half
	# 頂
	_quad(st, Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x0, y1, z1), top_uv, top_shade)
	# ¾ 斜角（鏡頭在東南）：南面最亮、東面次亮、西面暗、北面最暗——
	# 面向明暗差拉大，立體感靠明暗讀出來
	_quad(st, Vector3(x0, y1, z1), Vector3(x1, y1, z1), Vector3(x1, y0, z1), Vector3(x0, y0, z1), uv, 1.0)
	_quad(st, Vector3(x1, y1, z0), Vector3(x0, y1, z0), Vector3(x0, y0, z0), Vector3(x1, y0, z0), uv, 0.45)
	_quad(st, Vector3(x1, y1, z1), Vector3(x1, y1, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1), uv, 0.86)
	_quad(st, Vector3(x0, y1, z0), Vector3(x0, y1, z1), Vector3(x0, y0, z1), Vector3(x0, y0, z0), uv, 0.6)


## 斜屋頂：東西向屋脊的山形雙坡＋屋簷懸挑＋山牆端面。
## 斜角鏡頭下讀得出屋面坡度與屋簷厚度——「建築不是平面圖片」的關鍵。
static func _roof_prism(st: SurfaceTool, map: MapData, cell: Vector2i, base: float, tile: String) -> void:
	var eave_h := base + 1.3
	var ridge_h := base + 2.15 if tile.ends_with("_ridge") else base + 2.0
	var over := 0.2
	var left_deco := map.deco_name(cell + Vector2i(-1, 0))
	var right_deco := map.deco_name(cell + Vector2i(1, 0))
	var left_roof := ROOF.has(left_deco) or left_deco == "chimney"
	var right_roof := ROOF.has(right_deco) or right_deco == "chimney"
	var x0 := float(cell.x) - (0.0 if left_roof else over)
	var x1 := float(cell.x) + 1.0 + (0.0 if right_roof else over)
	var z0 := float(cell.y) - over
	var z1 := float(cell.y) + 1.0 + over
	var cz := float(cell.y) + 0.5
	var uv := _uv_rect(tile)
	# 南坡（受光）／北坡（背光；補反面讓越過屋脊的視線也看得到坡面）
	_quad(st, Vector3(x0, eave_h, z1), Vector3(x1, eave_h, z1), Vector3(x1, ridge_h, cz), Vector3(x0, ridge_h, cz), uv, 1.0)
	_quad(st, Vector3(x1, eave_h, z0), Vector3(x0, eave_h, z0), Vector3(x0, ridge_h, cz), Vector3(x1, ridge_h, cz), uv, 0.5)
	_quad(st, Vector3(x0, eave_h, z0), Vector3(x1, eave_h, z0), Vector3(x1, ridge_h, cz), Vector3(x0, ridge_h, cz), uv, 0.55)
	# 屋簷底板：朝下的簷底（只在由下往上看時可見）
	_quad(st, Vector3(x0, eave_h, z1), Vector3(x1, eave_h, z1), Vector3(x1, eave_h, z0), Vector3(x0, eave_h, z0), _uv_rect("roof_eave"), 0.42)
	# 山牆端面
	var wall_uv := _uv_rect("plaster_wall")
	if not left_roof:
		_tri(st, Vector3(x0, eave_h, z0), Vector3(x0, eave_h, z1), Vector3(x0, ridge_h, cz), wall_uv, 0.62)
	if not right_roof:
		_tri(st, Vector3(x1, eave_h, z1), Vector3(x1, eave_h, z0), Vector3(x1, ridge_h, cz), wall_uv, 0.82)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, uv: Rect2, shade: float) -> void:
	var color := Color(shade, shade, shade)
	var uvs: Array[Vector2] = [
		Vector2(uv.position.x, uv.end.y),
		Vector2(uv.end.x, uv.end.y),
		Vector2((uv.position.x + uv.end.x) * 0.5, uv.position.y),
	]
	var verts: Array[Vector3] = [a, b, c]
	for i in range(3):
		st.set_color(color)
		st.set_uv(uvs[i])
		st.add_vertex(verts[i])


## 階梯：朝較高鄰格方向的三階實體（頂面＋立面）。
## 回傳角色行走的錨定高度（中點，走起來像踏上台階）。
static func _stairs(st: SurfaceTool, map: MapData, cell: Vector2i) -> float:
	var low := float(map.elevation(cell)) * LEVEL_H
	var high := low + LEVEL_H
	var dir := Vector2i(0, -1)
	for offset: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		var neighbor := cell + offset
		if map.in_bounds(neighbor) and map.elevation(neighbor) > map.elevation(cell):
			dir = offset
			high = float(map.elevation(neighbor)) * LEVEL_H
			break
	var uv := _uv_rect("stairs")
	var riser_uv := _uv_rect("stone_floor_b")
	var x0 := float(cell.x)
	var z0 := float(cell.y)
	var steps := 3
	for i in range(steps):
		var f0 := float(i) / float(steps)
		var f1 := float(i + 1) / float(steps)
		var y_top := low + (high - low) * f1
		var y_bot := low + (high - low) * f0
		var shade := 0.98 - f0 * 0.12
		if dir == Vector2i(0, -1):
			var za := z0 + 1.0 - f1
			var zb := z0 + 1.0 - f0
			_quad(st, Vector3(x0, y_top, za), Vector3(x0 + 1, y_top, za), Vector3(x0 + 1, y_top, zb), Vector3(x0, y_top, zb), uv, shade)
			_quad(st, Vector3(x0, y_top, zb), Vector3(x0 + 1, y_top, zb), Vector3(x0 + 1, y_bot, zb), Vector3(x0, y_bot, zb), riser_uv, 0.72)
		elif dir == Vector2i(0, 1):
			var za := z0 + f0
			var zb := z0 + f1
			_quad(st, Vector3(x0, y_top, za), Vector3(x0 + 1, y_top, za), Vector3(x0 + 1, y_top, zb), Vector3(x0, y_top, zb), uv, shade)
			_quad(st, Vector3(x0 + 1, y_top, za), Vector3(x0, y_top, za), Vector3(x0, y_bot, za), Vector3(x0 + 1, y_bot, za), riser_uv, 0.5)
		elif dir == Vector2i(-1, 0):
			var xa := x0 + 1.0 - f1
			var xb := x0 + 1.0 - f0
			_quad(st, Vector3(xa, y_top, z0), Vector3(xb, y_top, z0), Vector3(xb, y_top, z0 + 1), Vector3(xa, y_top, z0 + 1), uv, shade)
			_quad(st, Vector3(xb, y_top, z0 + 1), Vector3(xb, y_top, z0), Vector3(xb, y_bot, z0), Vector3(xb, y_bot, z0 + 1), riser_uv, 0.82)
		else:
			var xa := x0 + f0
			var xb := x0 + f1
			_quad(st, Vector3(xa, y_top, z0), Vector3(xb, y_top, z0), Vector3(xb, y_top, z0 + 1), Vector3(xa, y_top, z0 + 1), uv, shade)
			_quad(st, Vector3(xa, y_top, z0), Vector3(xa, y_top, z0 + 1), Vector3(xa, y_bot, z0 + 1), Vector3(xa, y_bot, z0), riser_uv, 0.6)
	return (low + high) * 0.5


static func _atlas_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = load(TileCatalog.ATLAS_PATH)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	material.metallic = 0.0
	return material


# ---------- 立牌 ----------

static func _atlas_standee(parent: Node3D, cell: Vector2i, h: float, tile_name: String) -> void:
	var sprite := Sprite3D.new()
	sprite.texture = load(TileCatalog.ATLAS_PATH)
	sprite.region_enabled = true
	var pos := TileCatalog.pos(tile_name)
	sprite.region_rect = Rect2(pos.x * 16, pos.y * 16, 16, 16)
	sprite.pixel_size = 1.0 / 16.0
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.shaded = true
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.position = _center(cell) + Vector3(0, h + 0.5, 0)
	parent.add_child(sprite)
	_blob_shadow(parent, _center(cell) + Vector3(0, h, 0), 0.35)


static func _tree_standee(parent: Node3D, cell: Vector2i, h: float, flip: bool) -> void:
	var sprite := Sprite3D.new()
	sprite.texture = load("res://assets/world3d/tree_a.png" if not flip else "res://assets/world3d/tree_b.png")
	sprite.pixel_size = 1.0 / 16.0
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.shaded = true
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.position = _center(cell) + Vector3(0, h + 1.0, 0)
	parent.add_child(sprite)
	_blob_shadow(parent, _center(cell) + Vector3(0, h, 0), 0.5)


static func _blob_shadow(parent: Node3D, at: Vector3, size: float) -> void:
	var quad := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(size * 2.0, size * 1.2)
	mesh.orientation = PlaneMesh.FACE_Y
	quad.mesh = mesh
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = load("res://assets/ui/contact_shadow.png")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = false
	quad.material_override = material
	quad.position = at + Vector3(0, 0.015, 0)
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(quad)


# ---------- 水面 ----------

static func _water_plane(parent: Node3D, cells: Array[Vector2i], y: float, map: MapData, deep: bool, extend_sea: bool) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for cell in cells:
		var x := float(cell.x)
		var z := float(cell.y)
		_water_quad(st, x, x + 1.0, z, z + 1.0, y)
	if extend_sea:
		# 島外大海：四面延伸的巨大海面——島是海上的台地，不是浮在天上的板子
		_water_quad(st, -14.0, float(map.width) + 14.0, float(map.height), float(map.height) + 18.0, y)
		_water_quad(st, -14.0, 0.0, -14.0, float(map.height), y)
		_water_quad(st, float(map.width), float(map.width) + 14.0, -14.0, float(map.height), y)
		_water_quad(st, 0.0, float(map.width), -14.0, 0.0, y)
	st.generate_normals()
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = st.commit()
	if deep:
		var material := ShaderMaterial.new()
		material.shader = load("res://shaders/water3d.gdshader")
		material.set_shader_parameter("noise_tex", load("res://assets/world3d/water_noise.png"))
		mesh_instance.material_override = material
		mesh_instance.set_meta("water_material", true)
	else:
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(0.31, 0.61, 0.71, 0.45)
		material.roughness = 0.3
		mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh_instance)


static func _water_quad(st: SurfaceTool, x0: float, x1: float, z0: float, z1: float, y: float) -> void:
	var uv := Rect2(x0 * 0.25, z0 * 0.25, (x1 - x0) * 0.25, (z1 - z0) * 0.25)
	st.set_color(Color.WHITE)
	for i: int in [0, 1, 2, 0, 2, 3]:
		var vx := x0 if (i == 0 or i == 3) else x1
		var vz := z0 if (i == 0 or i == 1) else z1
		st.set_uv(Vector2(vx * 0.25, vz * 0.25))
		st.add_vertex(Vector3(vx, y, vz))


# ---------- 遠景 ----------

static func _backdrop(parent: Node3D, map: MapData) -> void:
	# 北側遠山（兩層、不同距離與明度）
	# 遠山壓在地平線上、低透明度——只當空氣透視的淡影，不搶畫面
	for layer in range(2):
		var hills := Sprite3D.new()
		hills.texture = load("res://assets/world3d/far_hills.png")
		hills.pixel_size = 0.07 + float(layer) * 0.03
		hills.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		hills.shaded = false
		hills.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		hills.modulate = Color(1, 1, 1, 0.5 - float(layer) * 0.15)
		hills.position = Vector3(float(map.width) / 2.0 - float(layer) * 5.0, 1.2 + float(layer) * 0.5, -7.0 - float(layer) * 6.0)
		parent.add_child(hills)
	# 西側一層淡遠山（¾ 斜角會看到西北角）
	var west_hills := Sprite3D.new()
	west_hills.texture = load("res://assets/world3d/far_hills.png")
	west_hills.pixel_size = 0.07
	west_hills.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	west_hills.shaded = false
	west_hills.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	west_hills.modulate = Color(1, 1, 1, 0.38)
	west_hills.position = Vector3(-11.0, 1.1, float(map.height) * 0.35)
	parent.add_child(west_hills)
	# 南側遠海帶（霧色漸層）
	var sea := Sprite3D.new()
	sea.texture = load("res://assets/world3d/far_sea.png")
	sea.pixel_size = 0.14
	sea.shaded = false
	sea.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sea.modulate = Color(1, 1, 1, 0.85)
	sea.position = Vector3(float(map.width) / 2.0 + 6.0, 1.2, float(map.height) + 13.0)
	parent.add_child(sea)
