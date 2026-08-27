extends Node3D
## 2.5D 玩家控制器：規則與 2D 版一字不差（一次一格、禁斜向、轉向分離、
## 依地面材質腳步聲），僅把呈現換成 Sprite3D 立牌＋高度層插值。
## 32×48 像素、16px 佔地；腳底貼齊 3D 地面、接觸 blob 陰影。

const STEP_TIME := 0.18
const TURN_DELAY := 0.08
const BUMP_COOLDOWN := 0.35
const SHEET_COLUMNS := 6

## 官方設定圖高解析素材（存在時取代像素 sheet；HD 角色 × 3D 場景）
## 優先序：走路動畫幀 → 全身立牌 → 像素 sheet
const HERO_FRONT := "res://assets/characters/hero/front.png"
const HERO_SIDE := "res://assets/characters/hero/side.png"
const HERO_BACK := "res://assets/characters/hero/back.png"
const HERO_WALK_TEMPLATE := "res://assets/characters/hero/walk_%s_%d.png"
const HERO_HEIGHT := 1.42
const HERO_WALK_HEIGHT := 1.18   # 走路圖為 Q 版比例，貼齊 HD-2D 標準身高

var cell := Vector2i.ZERO
var facing := Vector2i.DOWN
var _hero := false
var _hero_front: Texture2D
var _hero_side: Texture2D
var _hero_back: Texture2D
var _hero_walk := false
var _walk_frames := {}   # "down"/"left"/"up" → Array[Texture2D]（右向鏡射）

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
	_hero_walk = ResourceLoader.exists(HERO_WALK_TEMPLATE % ["down", 0])
	_hero = not _hero_walk and ResourceLoader.exists(HERO_FRONT)
	if _hero_walk:
		for dir_name: String in ["down", "left", "up"]:
			var frames: Array[Texture2D] = []
			for i in range(4):
				frames.append(load(HERO_WALK_TEMPLATE % [dir_name, i]))
			_walk_frames[dir_name] = frames
		var first: Texture2D = _walk_frames["down"][0]
		_sprite.texture = first
		# 幀畫布 272 高、內容 260、底邊留 4px：腳底貼齊地面
		var ps := HERO_WALK_HEIGHT / 260.0
		_sprite.pixel_size = ps
		_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
		_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		_sprite.position = Vector3(0, ps * (float(first.get_height()) * 0.5 - 4.0), 0)
	elif _hero:
		_hero_front = load(HERO_FRONT)
		_hero_side = load(HERO_SIDE)
		_hero_back = load(HERO_BACK)
		_sprite.texture = _hero_front
		_sprite.pixel_size = HERO_HEIGHT / float(_hero_front.get_height())
		_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
		_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		_sprite.position = Vector3(0, HERO_HEIGHT * 0.5 + 0.02, 0)
	else:
		_sprite.texture = load("res://assets/characters/player.png")
		_sprite.hframes = SHEET_COLUMNS
		_sprite.vframes = 4
		_sprite.pixel_size = 1.0 / 32.0
		_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		_sprite.position = Vector3(0, 0.75, 0)
	_sprite.shaded = true
	_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
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
	if _hero_walk:
		# 官方走路圖：四幀步態（step parity 決定前後半週期）
		var dir_key := "down"
		var flip := false
		match facing:
			Vector2i.UP:
				dir_key = "up"
			Vector2i.LEFT:
				dir_key = "left"
			Vector2i.RIGHT:
				dir_key = "left"
				flip = true
		var idx := 0
		if walking:
			idx = (2 * _step_parity + (0 if _move_progress < 0.5 else 1)) % 4
		_sprite.texture = _walk_frames[dir_key][idx]
		_sprite.flip_h = flip
		return
	if _hero:
		# 高解析立牌：視圖切換＋程序化步伐（小彈跳＋輕微擠壓）
		match facing:
			Vector2i.UP:
				_sprite.texture = _hero_back
				_sprite.flip_h = false
			Vector2i.LEFT:
				# 設定圖側視朝左；朝右時鏡射
				_sprite.texture = _hero_side
				_sprite.flip_h = false
			Vector2i.RIGHT:
				_sprite.texture = _hero_side
				_sprite.flip_h = true
			_:
				_sprite.texture = _hero_front
				_sprite.flip_h = false
		var hop := 0.0
		var squash := 1.0
		if walking:
			hop = sin(_move_progress * PI) * 0.07
			squash = 1.0 - 0.035 * sin(_move_progress * TAU)
		_sprite.position.y = HERO_HEIGHT * 0.5 + 0.02 + hop
		_sprite.scale = Vector3(1.0, squash, 1.0)
		return
	var column := 0
	if walking:
		var lift_column := 1 if _step_parity == 0 else 3
		column = lift_column if _move_progress < 0.5 else lift_column + 1
	_sprite.frame = Directions.row_for(facing) * SHEET_COLUMNS + column


func _cell_anchor(of_cell: Vector2i) -> Vector3:
	var h: float = _world.height_of(of_cell) if _world != null else 0.0
	return Vector3(float(of_cell.x) + 0.5, h, float(of_cell.y) + 0.5)
