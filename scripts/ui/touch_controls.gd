extends CanvasLayer
## Autoload 場景：觀測儀器風螢幕按鍵（左下十字鍵、右下確認／取消、右上選單）。
## 按鍵觸發與鍵盤相同的輸入動作，所有選單行為一致；非觸控裝置自動隱藏。
## 按下態使用 *_pressed 材質（GenUi 產生）。


func _ready() -> void:
	layer = 100
	visible = DisplayServer.is_touchscreen_available()
	_add_button("arrow_up", "move_up", Vector2(28, 120), true)
	_add_button("arrow_down", "move_down", Vector2(28, 156), true)
	_add_button("arrow_left", "move_left", Vector2(6, 138), true)
	_add_button("arrow_right", "move_right", Vector2(50, 138), true)
	_add_button("btn_confirm", "confirm", Vector2(288, 134), false)
	_add_button("btn_cancel", "cancel", Vector2(258, 152), false)
	_add_button("btn_observe", "observe", Vector2(288, 104), false)
	_add_button("btn_menu", "menu", Vector2(296, 24), false)


func _add_button(texture_name: String, action_name: String, at: Vector2, passby: bool) -> void:
	var button := TouchScreenButton.new()
	button.texture_normal = load("res://assets/ui/%s.png" % texture_name)
	button.texture_pressed = load("res://assets/ui/%s_pressed.png" % texture_name)
	button.action = action_name
	button.passby_press = passby
	button.position = at
	add_child(button)
