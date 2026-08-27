class_name CameraRig
extends Node3D
## 立體舞台攝影機：正交、¾ 斜角（水平 45°、俯角 35°）、遊玩期間不旋轉。
## 斜角讓建築同時露出正面、側面與屋頂——微縮模型構圖的關鍵。
## 短平滑跟隨＋地圖邊界寬鬆夾制；演出僅允許短距離推鏡（set_zoom）。

const YAW := 45.0
const PITCH := -35.0
const DIST := 26.0
const BASE_SIZE := 8.8

var camera: Camera3D
var follow_speed := 7.0
var _target: Node3D
var _bounds := Vector2(24, 16)
var _shake_left := 0.0
var _shake_strength := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	rotation_degrees.y = YAW
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = BASE_SIZE
	camera.rotation_degrees.x = PITCH
	camera.position = Vector3(0, DIST * sin(deg_to_rad(-PITCH)), DIST * cos(deg_to_rad(-PITCH)))
	add_child(camera)
	camera.make_current()
	_rng.randomize()


func setup(target: Node3D, map_size: Vector2) -> void:
	_target = target
	_bounds = map_size
	position = _clamped(_target.position)


func _process(delta: float) -> void:
	if _target != null:
		position = position.lerp(_clamped(_target.position), minf(1.0, delta * follow_speed))
	if _shake_left > 0.0:
		_shake_left -= delta
		camera.h_offset = _rng.randf_range(-_shake_strength, _shake_strength) * 0.04
		camera.v_offset = _rng.randf_range(-_shake_strength, _shake_strength) * 0.04
		if _shake_left <= 0.0:
			camera.h_offset = 0.0
			camera.v_offset = 0.0


func shake(strength: float, duration: float) -> void:
	if AudioManager.reduce_shake:
		return
	_shake_strength = strength
	_shake_left = duration


func set_zoom(size: float, duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(camera, "size", size, duration).set_ease(Tween.EASE_OUT)


## 演出用：切換跟隨目標（僅限開場／結局導演短暫使用）。
func retarget(target: Node3D) -> void:
	_target = target


## 演出用：把鏡頭立即放到某個世界點（之後照常向目標平滑靠攏）。
func jump_to(world_point: Vector3) -> void:
	position = _clamped(world_point)


## 斜角視野的邊界夾制：以寬鬆邊距讓構圖自然收束，不硬貼地圖框。
func _clamped(target: Vector3) -> Vector3:
	var view := camera.size if camera != null else BASE_SIZE
	var mx := view * 0.62
	var mz := view * 0.52
	var x := clampf(target.x, mx, maxf(mx, _bounds.x - mx))
	var z := clampf(target.z, mz, maxf(mz, _bounds.y - mz * 0.4))
	return Vector3(x, 0, z)
