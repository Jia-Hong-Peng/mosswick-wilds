extends Node3D
## 2.5D 定點 NPC：Sprite3D 立牌＋blob 陰影＋偶發重心微移；
## 互動時面向玩家開啟對話（邏輯與 2D 版相同）。

const SHEET_COLUMNS := 6

var cell := Vector2i.ZERO
var facing := Vector2i.DOWN
var dialogue_id: String = ""

var _idle_timer := 0.0
var _shift_left := 0.0
var _rng := RandomNumberGenerator.new()
var _sprite: Sprite3D


func setup(world: Node3D, data: Dictionary) -> void:
	cell = Vector2i(int(data.get("x", 0)), int(data.get("y", 0)))
	facing = Directions.from_name(String(data.get("facing", "down")))
	dialogue_id = String(data.get("dialogue_id", ""))
	_sprite = Sprite3D.new()
	var texture_path := String(data.get("sprite", ""))
	if not texture_path.is_empty():
		_sprite.texture = load(texture_path)
	_sprite.hframes = SHEET_COLUMNS
	_sprite.vframes = 4
	# 32×48 格為設計基準；高解析圖集依格高自動換算，畫面尺寸不變
	var cell_h := 48.0
	if _sprite.texture != null:
		cell_h = float(_sprite.texture.get_height()) / 4.0
	var hd := cell_h > 96.0
	_sprite.pixel_size = (1.0 / 32.0) * 48.0 / cell_h
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR if hd else BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.shaded = true
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED if hd else SpriteBase3D.ALPHA_CUT_DISCARD
	_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_sprite.position = Vector3(0, 0.75, 0)
	add_child(_sprite)
	var shadow := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.8, 0.45)
	quad.orientation = PlaneMesh.FACE_Y
	shadow.mesh = quad
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = load("res://assets/ui/contact_shadow.png")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow.material_override = material
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shadow.position = Vector3(0, 0.02, 0)
	add_child(shadow)
	var h: float = world.height_of(cell)
	position = Vector3(float(cell.x) + 0.5, h, float(cell.y) + 0.5)
	_rng.randomize()
	_idle_timer = _rng.randf_range(2.0, 5.0)
	_update_frame()


func _process(delta: float) -> void:
	if _sprite == null:
		return
	if _shift_left > 0.0:
		_shift_left -= delta
		if _shift_left <= 0.0:
			_update_frame()
		return
	_idle_timer -= delta
	if _idle_timer <= 0.0:
		_idle_timer = _rng.randf_range(2.5, 6.0)
		_shift_left = 0.35
		_sprite.frame = Directions.row_for(facing) * SHEET_COLUMNS + 2


func face_towards(other_cell: Vector2i) -> void:
	facing = Directions.towards(cell, other_cell)
	_shift_left = 0.0
	_update_frame()


func _update_frame() -> void:
	_sprite.frame = Directions.row_for(facing) * SHEET_COLUMNS
