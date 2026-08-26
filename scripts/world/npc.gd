extends Node2D
## 定點 NPC：佔一格（世界阻擋移動）、互動時面向玩家開啟對話、
## 帶有偶發的重心微移（Idle 細微動作）。

const TILE_SIZE := 16
const SHEET_COLUMNS := 6

var cell := Vector2i.ZERO
var facing := Vector2i.DOWN
var dialogue_id: String = ""

var _idle_timer := 0.0
var _shift_left := 0.0
var _rng := RandomNumberGenerator.new()

@onready var _sprite: Sprite2D = $Sprite


## 必須在節點進入場景樹後呼叫
func setup(data: Dictionary) -> void:
	cell = Vector2i(int(data.get("x", 0)), int(data.get("y", 0)))
	facing = Directions.from_name(String(data.get("facing", "down")))
	dialogue_id = String(data.get("dialogue_id", ""))
	var texture_path := String(data.get("sprite", ""))
	if not texture_path.is_empty():
		_sprite.texture = load(texture_path)
	_sprite.hframes = SHEET_COLUMNS
	_sprite.vframes = 4
	position = Vector2(cell * TILE_SIZE) + Vector2(8, 4)
	_rng.randomize()
	_idle_timer = _rng.randf_range(2.0, 5.0)
	_update_frame()


func _process(delta: float) -> void:
	if _shift_left > 0.0:
		_shift_left -= delta
		if _shift_left <= 0.0:
			_update_frame()
		return
	_idle_timer -= delta
	if _idle_timer <= 0.0:
		_idle_timer = _rng.randf_range(2.5, 6.0)
		_shift_left = 0.35
		_sprite.frame = Directions.row_for(facing) * SHEET_COLUMNS + 2  # 重心微移


func face_towards(other_cell: Vector2i) -> void:
	facing = Directions.towards(cell, other_cell)
	_shift_left = 0.0
	_update_frame()


func _update_frame() -> void:
	_sprite.frame = Directions.row_for(facing) * SHEET_COLUMNS
