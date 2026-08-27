class_name Follower3D
extends Node3D
## 認養後的夥伴跟隨者。三隻御三家有不同的跟隨個性：
## 芽翼鼯（lag）：保持約兩格距離慢慢跟，停下時原地小跳。
## 燼角羌（lead）：緊跟；玩家停下時走到玩家面前半格，回頭確認。
## 潮冠鷺（wander）：緊跟但很快；玩家停下時到旁邊亂晃，再快速跑回來。

const SHEET_COLUMNS := 6

var cell := Vector2i.ZERO
var facing := Vector2i.DOWN
var starter_id := ""

var _world: Node3D
var _player: Node3D
var _behavior := "lag"
var _step_time := 0.2
var _keep_distance := 1
var _moving := false
var _move_from := Vector3.ZERO
var _move_to := Vector3.ZERO
var _move_progress := 0.0
var _step_parity := 0
var _idle_clock := 0.0
var _quirk_cell := Vector2i(-1, -1)   # wander/lead 的暫時位置
var _hop_clock := 0.0
var _rng := RandomNumberGenerator.new()
var _sprite: Sprite3D
var scripted := false                 # 結局導演接管時停用個性行為


func setup(world: Node3D, player: Node3D, of_starter: String, start_cell: Vector2i) -> void:
	_world = world
	_player = player
	starter_id = of_starter
	cell = start_cell
	var starter := DataRegistry.get_starter(of_starter)
	_behavior = String(starter.get("follow_behavior", "lag"))
	match _behavior:
		"lag":
			_step_time = 0.24
			_keep_distance = 2
		"lead":
			_step_time = 0.15
			_keep_distance = 1
		"wander":
			_step_time = 0.13
			_keep_distance = 1
	_sprite = Sprite3D.new()
	_sprite.texture = load("res://assets/creatures/%s_world.png" % of_starter)
	_sprite.hframes = SHEET_COLUMNS
	_sprite.vframes = 4
	_sprite.pixel_size = 1.0 / 32.0
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.shaded = true
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_sprite.position = Vector3(0, 0.75, 0)
	add_child(_sprite)
	var shadow := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.7, 0.4)
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
	position = _cell_anchor(cell)
	_rng.randomize()
	_update_frame()


func _process(delta: float) -> void:
	if _sprite == null:
		return
	_hop_clock = maxf(0.0, _hop_clock - delta)
	_sprite.position.y = 0.75 + (0.22 * sin(_hop_clock * TAU * 2.5) if _hop_clock > 0.0 else 0.0)
	if _moving:
		_advance_step(delta)
		return
	if scripted:
		return
	var player_cell: Vector2i = _player.get("cell")
	var gap := absi(player_cell.x - cell.x) + absi(player_cell.y - cell.y)
	if gap == 0:
		# 玩家走進自己這一格（可穿越）：立刻讓到旁邊
		_step_aside(player_cell)
		return
	if gap > _keep_distance:
		_quirk_cell = Vector2i(-1, -1)
		_idle_clock = 0.0
		_step_towards(player_cell)
		return
	# 玩家停著：個性小動作
	_idle_clock += delta
	match _behavior:
		"lag":
			if _idle_clock > 2.4:
				_idle_clock = 0.0
				hop()
		"lead":
			if _idle_clock > 1.4 and _quirk_cell == Vector2i(-1, -1):
				var front: Vector2i = player_cell + Vector2i(_player.get("facing"))
				var ahead := front + Vector2i(_player.get("facing"))
				var target := ahead if _cell_free(ahead, player_cell) else front
				if _cell_free(target, player_cell):
					_quirk_cell = target
					_step_towards(target)
		"wander":
			if _idle_clock > 1.6:
				_idle_clock = 0.0
				if _quirk_cell == Vector2i(-1, -1):
					var options: Array[Vector2i] = []
					for dir: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
						var candidate := cell + dir
						if _cell_free(candidate, player_cell):
							options.append(candidate)
					if not options.is_empty():
						_quirk_cell = cell
						_step_towards(options[_rng.randi_range(0, options.size() - 1)])
				else:
					var back := _quirk_cell
					_quirk_cell = Vector2i(-1, -1)
					_step_towards(back)
	if not _moving and _behavior == "lead" and _quirk_cell != Vector2i(-1, -1) and cell == _quirk_cell:
		face_towards(player_cell)


func hop() -> void:
	_hop_clock = 0.4


## 與玩家重疊時讓開：優先退到玩家背後，再試左右
func _step_aside(player_cell: Vector2i) -> void:
	var player_facing := Vector2i(_player.get("facing"))
	for dir: Vector2i in [-player_facing, Vector2i(player_facing.y, player_facing.x), Vector2i(-player_facing.y, -player_facing.x), player_facing]:
		if dir != Vector2i.ZERO and _cell_free(cell + dir, player_cell):
			facing = dir
			_begin_move(cell + dir)
			return


## 導演／保險用：把夥伴直接放到某格（含從隱藏狀態復原）
func place_at(new_cell: Vector2i) -> void:
	cell = new_cell
	_moving = false
	_quirk_cell = Vector2i(-1, -1)
	visible = true
	scale = Vector3.ONE
	position = _cell_anchor(cell)
	_update_frame()


func face_towards(other_cell: Vector2i) -> void:
	if other_cell != cell:
		facing = Directions.towards(cell, other_cell)
	_update_frame()


## 結局導演用：往指定方向走一步（無視個性），回傳是否成功。
func scripted_step(direction: Vector2i) -> bool:
	if _moving:
		return false
	facing = direction
	var target := cell + direction
	if not _cell_free(target, Vector2i(-99, -99)):
		_update_frame()
		return false
	_begin_move(target)
	return true


func is_moving() -> bool:
	return _moving


func _step_towards(target: Vector2i) -> void:
	var delta_cell := target - cell
	var dirs: Array[Vector2i] = []
	if absi(delta_cell.x) >= absi(delta_cell.y):
		if delta_cell.x != 0:
			dirs.append(Vector2i(signi(delta_cell.x), 0))
		if delta_cell.y != 0:
			dirs.append(Vector2i(0, signi(delta_cell.y)))
	else:
		if delta_cell.y != 0:
			dirs.append(Vector2i(0, signi(delta_cell.y)))
		if delta_cell.x != 0:
			dirs.append(Vector2i(signi(delta_cell.x), 0))
	for dir in dirs:
		var next := cell + dir
		if _cell_free(next, Vector2i(_player.get("cell"))):
			facing = dir
			_begin_move(next)
			return
	_update_frame()


func _cell_free(target: Vector2i, player_cell: Vector2i) -> bool:
	if target == player_cell:
		return false
	return bool(_world.is_cell_free(target))


func _begin_move(target: Vector2i) -> void:
	cell = target
	_moving = true
	_move_from = position
	_move_to = _cell_anchor(cell)
	_move_progress = 0.0
	_step_parity = 1 - _step_parity


func _advance_step(delta: float) -> void:
	_move_progress += delta / _step_time
	if _move_progress >= 1.0:
		position = _move_to
		_moving = false
		_update_frame()
		return
	position = _move_from.lerp(_move_to, _move_progress)
	_update_frame(true)


func _update_frame(walking: bool = false) -> void:
	var column := 0
	if walking:
		var lift_column := 1 if _step_parity == 0 else 3
		column = lift_column if _move_progress < 0.5 else lift_column + 1
	_sprite.frame = Directions.row_for(facing) * SHEET_COLUMNS + column


func _cell_anchor(of_cell: Vector2i) -> Vector3:
	var h: float = _world.height_of(of_cell) if _world != null else 0.0
	return Vector3(float(of_cell.x) + 0.5, h, float(of_cell.y) + 0.5)
