class_name ScreenGrade
extends CanvasLayer
## 螢幕分級層（假性移軸＋暗角＋觀測去彩度＋通關暖調＋演出閃光）。
## 位於 3D 場景之上、UI CanvasLayer 之下；Web Low 停用柔焦僅留暗角。

var _rect: ColorRect
var _material: ShaderMaterial


func _ready() -> void:
	layer = 0
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = load("res://shaders/screen_grade.gdshader")
	_rect.material = _material
	add_child(_rect)
	apply_quality()


func apply_quality() -> void:
	_material.set_shader_parameter("blur_strength", 2.0 if AudioManager.quality_high else 0.0)


func set_observe(active: bool) -> void:
	var tween := create_tween()
	tween.tween_method(_set_param.bind("observe_mix"), _get_param("observe_mix"), 1.0 if active else 0.0, 0.35)


func set_warm(amount: float, duration: float = 1.2) -> void:
	var tween := create_tween()
	tween.tween_method(_set_param.bind("warm_mix"), _get_param("warm_mix"), amount, duration)


func flash(strength: float = 0.8, duration: float = 0.25) -> void:
	if AudioManager.reduce_flash:
		return
	_material.set_shader_parameter("flash", strength)
	var tween := create_tween()
	tween.tween_method(_set_param.bind("flash"), strength, 0.0, duration)


func observe_pulse() -> void:
	var tween := create_tween()
	tween.tween_method(_set_param.bind("observe_mix"), 0.0, 1.0, 0.35)
	tween.tween_interval(0.8)
	tween.tween_method(_set_param.bind("observe_mix"), 1.0, 0.0, 0.5)


func _set_param(value: float, param: String) -> void:
	_material.set_shader_parameter(param, value)


func _get_param(param: String) -> float:
	var value: Variant = _material.get_shader_parameter(param)
	return float(value) if value != null else 0.0
