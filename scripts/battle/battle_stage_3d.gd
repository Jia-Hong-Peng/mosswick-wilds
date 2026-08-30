class_name BattleStage3D
extends RefCounted
## 戰鬥用 3D 立體小舞台：依遭遇地（trail／village／station）生成
## 地面、背景層物件、霧片與燈光；回傳站位與攝影機。
## 與世界共用圖集材質與立牌手法；燈光可由戰鬥腳本切換（頭目階段轉換）。

const GROUND_KINDS := {
	"trail": ["grass_a", "grass_b", "grass_c"],
	"village": ["stone_floor_a", "stone_floor_b"],
	"station": ["wood_floor_a", "wood_floor_b"],
	"haven": ["grass_a", "grass_b", "path_a"],
}


static func build(root: Node3D, kind: String) -> Dictionary:
	var result := {}
	# ---------- 環境 ----------
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.fog_enabled = true
	env.fog_sky_affect = 0.2
	match kind:
		"station":
			env.background_color = Color("0d131c")
			env.ambient_light_color = Color(0.4, 0.44, 0.56)
			env.ambient_light_energy = 0.72
			env.fog_light_color = Color(0.14, 0.17, 0.25)
			env.fog_density = 0.025
		"trail":
			env.background_color = Color("b9cdc2")
			env.ambient_light_color = Color(0.58, 0.67, 0.7)
			env.ambient_light_energy = 0.88
			env.fog_light_color = Color(0.72, 0.8, 0.78)
			env.fog_density = 0.012
		"haven":
			env.background_color = Color("a8bfb6")
			env.ambient_light_color = Color(0.5, 0.58, 0.56)
			env.ambient_light_energy = 0.8
			env.fog_light_color = Color(0.74, 0.8, 0.76)
			env.fog_density = 0.01
		_:
			env.background_color = Color("c2d2c8")
			env.ambient_light_color = Color(0.6, 0.67, 0.7)
			env.ambient_light_energy = 0.88
			env.fog_light_color = Color(0.74, 0.8, 0.79)
			env.fog_density = 0.01
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	root.add_child(world_env)
	result["environment"] = env

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_color = Color(1.0, 0.95, 0.85) if kind != "station" else Color(0.7, 0.72, 0.85)
	sun.light_energy = 1.0 if kind != "station" else 0.5
	sun.shadow_enabled = AudioManager.quality_high
	root.add_child(sun)
	result["sun"] = sun

	# ---------- 地面（10×8 舞台盤） ----------
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var kinds: Array = GROUND_KINDS.get(kind, GROUND_KINDS["village"])
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for y in range(8):
		for x in range(-2, 12):
			var tile: String = kinds[rng.randi_range(0, kinds.size() - 1)]
			var shade := 1.0 - float(y) * 0.03
			_ground_quad(st, float(x), float(y), tile, shade)
	# 舞台邊緣裙牆（南緣＋東西側緣——斜角鏡頭會看到側面）
	var skirt_tile := "cliff_face" if kind != "station" else "wall_stone_in"
	for x in range(-2, 12):
		_skirt(st, float(x), 8.0, skirt_tile)
	for y in range(8):
		_side_skirt(st, 12.0, float(y), skirt_tile)
	# 箱型背景物（與地面共用網格，逐面貼 UV——AtlasTexture 不能直接當 3D 材質）
	match kind:
		"village":
			for i in range(3):
				_tex_box(st, "plaster_wall", Vector3(1.6 + float(i) * 3.1, 0.0, 0.7), Vector3(2.4, 1.3, 1.0))
				_tex_box(st, "roof_tin_a", Vector3(1.6 + float(i) * 3.1, 1.3, 0.7), Vector3(2.6, 0.45, 1.2))
		"station":
			for i in range(4):
				_tex_box(st, "instrument", Vector3(1.2 + float(i) * 2.4, 0.0, 0.6), Vector3(1.6, 1.35, 0.8))
		"haven":
			# 庭院背景：圍欄一排（缺口＝被馱庫龜撞破的位置）＋培育木框
			for i in range(8):
				if i == 2 or i == 3:
					continue
				_tex_box(st, "stone_wall", Vector3(0.65 + float(i) * 1.25, 0.0, 0.5), Vector3(1.2, 0.55, 0.5))
			_tex_box(st, "log_a", Vector3(8.9, 0.0, 1.8), Vector3(1.6, 0.4, 1.0))
	st.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.mesh = st.commit()
	var material := StandardMaterial3D.new()
	material.albedo_texture = load(TileCatalog.ATLAS_PATH)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	mesh.material_override = material
	root.add_child(mesh)

	# ---------- 背景層物件 ----------
	match kind:
		"trail":
			for i in range(5):
				_standee(root, load("res://assets/world3d/tree_a.png" if i % 2 == 0 else "res://assets/world3d/tree_b.png"),
					Vector3(0.8 + float(i) * 2.1, 1.0, 0.6 + float(i % 2) * 0.5), 1.0 / 32.0)
			for i in range(4):
				_atlas_standee(root, "tallgrass", Vector3(1.5 + float(i) * 2.3, 0.5, 2.2))
			_atlas_standee(root, "rock_a", Vector3(9.4, 0.5, 3.6))
		"village":
			_atlas_standee(root, "lamp_post", Vector3(9.2, 0.5, 2.8))
			_atlas_standee(root, "barrel", Vector3(1.2, 0.5, 2.4))
		"station":
			_atlas_standee(root, "console_rust", Vector3(0.9, 0.5, 2.2))
			_atlas_standee(root, "vine_wall", Vector3(3.4, 1.2, 0.5))
		"haven":
			_standee(root, load("res://assets/world3d/tree_a.png"), Vector3(0.7, 1.0, 1.4), 1.0 / 32.0)
			_standee(root, load("res://assets/world3d/tree_b.png"), Vector3(9.6, 1.0, 1.2), 1.0 / 32.0)
			_atlas_standee(root, "lamp_post", Vector3(6.3, 0.5, 1.3))
			_atlas_standee(root, "fern", Vector3(8.6, 0.5, 2.4))
			_atlas_standee(root, "flowers_a", Vector3(1.9, 0.5, 2.8))
			_atlas_standee(root, "barrel", Vector3(4.3, 0.5, 1.0))
	# 霧片
	var fog_texture: Texture2D = load("res://assets/ui/fog_blob.png")
	var fog_count := 3 if AudioManager.quality_high else 1
	for i in range(fog_count):
		var fog := Sprite3D.new()
		fog.texture = fog_texture
		fog.pixel_size = 1.0 / 10.0
		fog.shaded = false
		fog.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		fog.modulate = Color(1, 1, 1, 0.4)
		fog.position = Vector3(1.5 + float(i) * 3.2, 0.7, 1.4)
		root.add_child(fog)

	# ---------- 站位與攝影機 ----------
	# 構圖對齊 2D 版：我方左下（約 25%,70%）、敵方右上（約 59%,37%）；
	# -30° 俯角下要拉開足夠的 z 縱深才能在畫面上分出高低。
	result["player_pos"] = Vector3(2.0, 0.0, 6.4)
	result["enemy_pos"] = Vector3(8.1, 0.0, 1.7)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	# 輕微斜角（yaw 14°）：戰鬥舞台同樣維持立體劇場感
	camera.rotation_degrees = Vector3(-30, 14, 0)
	# 對準構圖中心沿視線後退定位
	var target := Vector3(5.2, 1.62, 4.0)
	var back := Basis.from_euler(Vector3(deg_to_rad(-30.0), deg_to_rad(14.0), 0)) * Vector3(0, 0, 1)
	camera.position = target + back * 14.0
	root.add_child(camera)
	camera.make_current()
	result["camera"] = camera
	# 遭遇推鏡：由略遠推近
	camera.size = 7.4
	var tween := root.create_tween()
	tween.tween_property(camera, "size", 6.6, 0.5).set_ease(Tween.EASE_OUT)
	return result


static func _ground_quad(st: SurfaceTool, x: float, z: float, tile: String, shade: float) -> void:
	var pos := TileCatalog.pos(tile)
	var uv := Rect2(float(pos.x) / 16.0 + 0.0015, float(pos.y) / 6.0 + 0.0015, 1.0 / 16.0 - 0.003, 1.0 / 6.0 - 0.003)
	var color := Color(shade, shade, shade)
	var uvs: Array[Vector2] = [uv.position, Vector2(uv.end.x, uv.position.y), uv.end, Vector2(uv.position.x, uv.end.y)]
	var verts: Array[Vector3] = [Vector3(x, 0, z), Vector3(x + 1, 0, z), Vector3(x + 1, 0, z + 1), Vector3(x, 0, z + 1)]
	for i: int in [0, 1, 2, 0, 2, 3]:
		st.set_color(color)
		st.set_uv(uvs[i])
		st.add_vertex(verts[i])


## 東側緣裙牆（x 固定、沿 z 方向一格）
static func _side_skirt(st: SurfaceTool, x: float, z: float, tile: String) -> void:
	var pos := TileCatalog.pos(tile)
	var uv := Rect2(float(pos.x) / 16.0, float(pos.y) / 6.0, 1.0 / 16.0, 1.0 / 6.0)
	var uvs: Array[Vector2] = [uv.position, Vector2(uv.end.x, uv.position.y), uv.end, Vector2(uv.position.x, uv.end.y)]
	var verts: Array[Vector3] = [Vector3(x, 0, z + 1), Vector3(x, 0, z), Vector3(x, -1.4, z), Vector3(x, -1.4, z + 1)]
	for i: int in [0, 1, 2, 0, 2, 3]:
		st.set_color(Color(0.5, 0.5, 0.5))
		st.set_uv(uvs[i])
		st.add_vertex(verts[i])


static func _skirt(st: SurfaceTool, x: float, z: float, tile: String) -> void:
	var pos := TileCatalog.pos(tile)
	var uv := Rect2(float(pos.x) / 16.0, float(pos.y) / 6.0, 1.0 / 16.0, 1.0 / 6.0)
	var uvs: Array[Vector2] = [uv.position, Vector2(uv.end.x, uv.position.y), uv.end, Vector2(uv.position.x, uv.end.y)]
	var verts: Array[Vector3] = [Vector3(x, 0, z), Vector3(x + 1, 0, z), Vector3(x + 1, -1.4, z), Vector3(x, -1.4, z)]
	for i: int in [0, 1, 2, 0, 2, 3]:
		st.set_color(Color(0.6, 0.6, 0.6))
		st.set_uv(uvs[i])
		st.add_vertex(verts[i])


static func _standee(root: Node3D, texture: Texture2D, at: Vector3, pixel: float) -> void:
	var sprite := Sprite3D.new()
	sprite.texture = texture
	sprite.pixel_size = pixel
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.shaded = true
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.position = at
	root.add_child(sprite)


static func _atlas_standee(root: Node3D, tile: String, at: Vector3) -> void:
	var sprite := Sprite3D.new()
	sprite.texture = load(TileCatalog.ATLAS_PATH)
	sprite.region_enabled = true
	var pos := TileCatalog.pos(tile)
	sprite.region_rect = Rect2(pos.x * 32, pos.y * 32, 32, 32)
	sprite.pixel_size = 1.0 / 32.0
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.shaded = true
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.position = at
	root.add_child(sprite)


static func _tex_box(st: SurfaceTool, tile: String, at: Vector3, size: Vector3) -> void:
	var pos := TileCatalog.pos(tile)
	var uv := Rect2(float(pos.x) / 16.0 + 0.0015, float(pos.y) / 6.0 + 0.0015, 1.0 / 16.0 - 0.003, 1.0 / 6.0 - 0.003)
	var uvs: Array[Vector2] = [uv.position, Vector2(uv.end.x, uv.position.y), uv.end, Vector2(uv.position.x, uv.end.y)]
	var x0 := at.x - size.x / 2.0
	var x1 := at.x + size.x / 2.0
	var y0 := at.y
	var y1 := at.y + size.y
	var z0 := at.z - size.z / 2.0
	var z1 := at.z + size.z / 2.0
	# 頂面（亮）、前面（中）、左右側（暗）——手繪式明暗面
	_box_face(st, [Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x0, y1, z1)], uvs, 1.0)
	_box_face(st, [Vector3(x0, y1, z1), Vector3(x1, y1, z1), Vector3(x1, y0, z1), Vector3(x0, y0, z1)], uvs, 0.84)
	_box_face(st, [Vector3(x0, y1, z0), Vector3(x0, y1, z1), Vector3(x0, y0, z1), Vector3(x0, y0, z0)], uvs, 0.68)
	_box_face(st, [Vector3(x1, y1, z1), Vector3(x1, y1, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1)], uvs, 0.68)


static func _box_face(st: SurfaceTool, verts: Array[Vector3], uvs: Array[Vector2], shade: float) -> void:
	var color := Color(shade, shade, shade)
	for i: int in [0, 1, 2, 0, 2, 3]:
		st.set_color(color)
		st.set_uv(uvs[i])
		st.add_vertex(verts[i])


static func make_creature(root: Node3D, texture: Texture2D, at: Vector3, pixel: float, hframes: int = 1) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture = texture
	sprite.hframes = hframes
	sprite.pixel_size = pixel
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.shaded = true
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.position = at + Vector3(0, 32.0 * pixel, 0)
	root.add_child(sprite)
	var shadow := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.6, 0.8)
	quad.orientation = PlaneMesh.FACE_Y
	shadow.mesh = quad
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = load("res://assets/ui/contact_shadow.png")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow.material_override = material
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shadow.position = at + Vector3(0, 0.02, 0)
	root.add_child(shadow)
	return sprite
