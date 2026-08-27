extends Node3D
## 2.5D 玩家控制器：規則與 2D 版一字不差（一次一格、禁斜向、轉向分離、
## 依地面材質腳步聲），僅把呈現換成 Sprite3D 立牌＋高度層插值。
## 32×48 像素、16px 佔地；腳底貼齊 3D 地面、接觸 blob 陰影。

const STEP_TIME := 0.18
const TURN_DELAY := 0.08
const BUMP_COOLDOWN := 0.35
const SHEET_COLUMNS := 6

var cell := Vector2i.ZERO
var facing := Vector2i.DOWN

var _world: Node3D
var _moving := false
var _move_from := Vector3.ZERO
var _move_to := Vector3.ZERO
var _move_progress := 0.0
var _turn_timer := 0.0
var _bump_timer := 0.0
var _step_parity := 0

var _sprite: Sprite3D


func _ready() -> void:
	_sprite = Sprite3D.new()
	_sprite.texture = load("res://assets/characters/player.png")
	_sprite.hframes = SHEET_COLUMNS
	_sprite.vframes = 4
	_sprite.pixel_size = 1.0 / 32.0
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.shaded = true
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
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


func setup(world: Node3D, start_cell: Vector2i, start_facing: Vector2i) -> void:
	_world = world
	cell = start_cell
	facing = start_facing
	position = _cell_anchor(cell)
	_update_frame()


func _process(delta: float) -> void:
	_bump_timer = maxf(0.0, _bump_timer - delta)
	if _moving:
		_advance_step(delta)
		return
	var movable := InputRouter.is_context(InputRouter.Context.WORLD) or InputRouter.is_context(InputRouter.Context.OBSERVE)
	if not movable:
		_update_frame()
		return
	if Input.is_action_just_pressed("confirm"):
		_world.on_player_interact(cell + facing)
		return
	var dir := InputRouter.movement_dir()
	if dir == Vector2i.ZERO:
		_turn_timer = 0.0
		_update_frame()
		return
	if dir != facing:
		facing = dir
		GameState.player_facing = facing
		_turn_timer = TURN_DELAY
		_update_frame()
		return
	if _turn_timer > 0.0:
		_turn_timer -= delta
		return
	_try_start_step()


## 導演步行：無視輸入情境往指定方向走一步（結局／演出用）。
func force_step(direction: Vector2i) -> bool:
	if _moving:
		return false
	facing = direction
	GameState.player_facing = facing
	_update_frame()
	var result: Dictionary = _world.try_step(cell, facing)
	if not bool(result["moved"]):
		return false
	cell = Vector2i(result["cell"])
	_moving = true
	_move_from = position
	_move_to = _cell_anchor(cell)
	_move_progress = 0.0
	_step_parity = 1 - _step_parity
	AudioManager.play_step(String(_world.ground_kind_at(cell)))
	return true


func is_moving() -> bool:
	return _moving


func _try_start_step() -> void:
	var result: Dictionary = _world.try_step(cell, facing)
	if not bool(result["moved"]):
		if _bump_timer <= 0.0:
			AudioManager.play_bump()
			_bump_timer = BUMP_COOLDOWN
		return
	cell = Vector2i(result["cell"])
	_moving = true
	_move_from = position
	_move_to = _cell_anchor(cell)
	_move_progress = 0.0
	_step_parity = 1 - _step_parity
	AudioManager.play_step(String(_world.ground_kind_at(cell)))


func _advance_step(delta: float) -> void:
	_move_progress += delta / STEP_TIME
	if _move_progress >= 1.0:
		position = _move_to
		_moving = false
		_update_frame()
		_world.on_player_arrived(cell)
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
