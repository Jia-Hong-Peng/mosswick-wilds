extends CanvasLayer
## Autoload scene: on-screen D-pad (bottom-left) and confirm/cancel buttons
## (bottom-right) for touch devices. Buttons press the same input actions as
## the keyboard, so every menu works unchanged. Hidden on non-touch devices.


func _ready() -> void:
	layer = 100
	visible = DisplayServer.is_touchscreen_available()
	_add_button("res://assets/ui/arrow_up.png", "move_up", Vector2(28, 122), true)
	_add_button("res://assets/ui/arrow_down.png", "move_down", Vector2(28, 158), true)
	_add_button("res://assets/ui/arrow_left.png", "move_left", Vector2(6, 140), true)
	_add_button("res://assets/ui/arrow_right.png", "move_right", Vector2(50, 140), true)
	_add_button("res://assets/ui/btn_confirm.png", "confirm", Vector2(288, 136), false)
	_add_button("res://assets/ui/btn_cancel.png", "cancel", Vector2(258, 152), false)
	_add_button("res://assets/ui/btn_menu.png", "menu", Vector2(296, 6), false)


func _add_button(texture_path: String, action_name: String, at: Vector2, passby: bool) -> void:
	var button := TouchScreenButton.new()
	button.texture_normal = load(texture_path)
	button.action = action_name
	button.passby_press = passby
	button.position = at
	add_child(button)
