extends Node2D
## Grid-locked player controller: tap to turn, hold to walk, exactly one tile
## per step, no diagonals. Movement legality is delegated to the world scene
## (GridMovement domain rules); this node only animates and forwards input.

const TILE_SIZE := 16
const STEP_TIME := 0.18
const TURN_DELAY := 0.08
const BUMP_COOLDOWN := 0.35
const VIEW_SIZE := Vector2i(320, 180)

var cell := Vector2i.ZERO
var facing := Vector2i.DOWN

var _world: Node2D
var _moving := false
var _move_from := Vector2.ZERO
var _move_to := Vector2.ZERO
var _move_progress := 0.0
var _turn_timer := 0.0
var _bump_timer := 0.0

@onready var _sprite: Sprite2D = $Sprite
@onready var _camera: Camera2D = $Camera


func _ready() -> void:
	_sprite.texture = load("res://assets/characters/player.png")
	_sprite.hframes = 2
	_sprite.vframes = 4
	_camera.make_current()


func setup(world: Node2D, start_cell: Vector2i, start_facing: Vector2i, map_pixel_size: Vector2i) -> void:
	_world = world
	cell = start_cell
	facing = start_facing
	position = _cell_center(cell)
	_configure_camera(map_pixel_size)
	_update_frame()


func _process(delta: float) -> void:
	_bump_timer = maxf(0.0, _bump_timer - delta)
	if _moving:
		_advance_step(delta)
		return
	if not InputRouter.is_context(InputRouter.Context.WORLD):
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
		# Turning is separate from stepping: a quick tap only changes facing.
		facing = dir
		GameState.player_facing = facing
		_turn_timer = TURN_DELAY
		_update_frame()
		return
	if _turn_timer > 0.0:
		_turn_timer -= delta
		return
	_try_start_step()


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
	_move_to = _cell_center(cell)
	_move_progress = 0.0


func _advance_step(delta: float) -> void:
	_move_progress += delta / STEP_TIME
	if _move_progress >= 1.0:
		position = _move_to
		_moving = false
		_update_frame()
		_world.on_player_arrived(cell)
		return
	# Integer positions only: no subpixel blur at any zoom.
	var offset := (_move_to - _move_from) * _move_progress
	position = _move_from + Vector2(roundf(offset.x), roundf(offset.y))
	_update_frame(true)


func _update_frame(walking: bool = false) -> void:
	var step := 1 if walking and _move_progress < 0.5 else 0
	_sprite.frame = Directions.row_for(facing) * 2 + step


func _cell_center(of_cell: Vector2i) -> Vector2:
	return Vector2(of_cell * TILE_SIZE) + Vector2(TILE_SIZE, TILE_SIZE) / 2.0


## Clamps the camera to the map; centers maps smaller than the viewport.
func _configure_camera(map_pixel_size: Vector2i) -> void:
	if map_pixel_size.x >= VIEW_SIZE.x:
		_camera.limit_left = 0
		_camera.limit_right = map_pixel_size.x
	else:
		_camera.limit_left = (map_pixel_size.x - VIEW_SIZE.x) / 2
		_camera.limit_right = _camera.limit_left + VIEW_SIZE.x
	if map_pixel_size.y >= VIEW_SIZE.y:
		_camera.limit_top = 0
		_camera.limit_bottom = map_pixel_size.y
	else:
		_camera.limit_top = (map_pixel_size.y - VIEW_SIZE.y) / 2
		_camera.limit_bottom = _camera.limit_top + VIEW_SIZE.y
