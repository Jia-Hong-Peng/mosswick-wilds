extends Control
## 對話框：手冊紙面＋說話者名牌＋左右立繪（說話者高亮、非說話者壓暗、
## 換頁小幅進場位移）＋選項清單。取消鍵跳過演出頁。

const PORTRAIT_DIR := "res://assets/portraits"

var _panel: PanelContainer
var _name_tag: PanelContainer
var _name_label: Label
var _text_label: Label
var _more_label: Label
var _choice_panel: PanelContainer
var _choice_box: VBoxContainer
var _choice_rows: Array[Dictionary] = []
var _choice_index := 0
var _portrait_left: TextureRect
var _portrait_right: TextureRect


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	DialogueManager.page_shown.connect(_on_page_shown)
	DialogueManager.choice_shown.connect(_on_choice_shown)
	DialogueManager.dialogue_finished.connect(_on_finished)


func _process(_delta: float) -> void:
	if not DialogueManager.active:
		return
	if not InputRouter.is_context(InputRouter.Context.DIALOGUE):
		return
	if Engine.get_process_frames() == DialogueManager.opened_frame:
		return
	if _choice_panel.visible:
		if Input.is_action_just_pressed("move_up"):
			_choice_index = maxi(0, _choice_index - 1)
			AudioManager.play_talk()
			_refresh_choice()
		elif Input.is_action_just_pressed("move_down"):
			_choice_index = mini(_choice_rows.size() - 1, _choice_index + 1)
			AudioManager.play_talk()
			_refresh_choice()
		elif Input.is_action_just_pressed("confirm"):
			AudioManager.play_confirm()
			DialogueManager.select_choice(_choice_index)
	elif Input.is_action_just_pressed("confirm"):
		AudioManager.play_talk()
		DialogueManager.advance()
	elif Input.is_action_just_pressed("cancel"):
		DialogueManager.skip()


func _on_page_shown(page: Dictionary) -> void:
	_panel.visible = true
	_more_label.visible = true
	_choice_panel.visible = false
	var speaker := String(page.get("speaker", ""))
	_name_tag.visible = not speaker.is_empty()
	_name_label.text = speaker
	_text_label.text = String(page.get("text", ""))
	_update_portraits(page)


func _update_portraits(page: Dictionary) -> void:
	var speaker_side := String(page.get("speaker_side", ""))
	if page.has("left"):
		_set_portrait(_portrait_left, String(page["left"]))
	if page.has("right"):
		_set_portrait(_portrait_right, String(page["right"]))
	if speaker_side.is_empty():
		speaker_side = "right" if page.has("right") else ("left" if page.has("left") else "")
	# 說話者高亮＋輕微進場位移；另一側壓暗
	for entry: Array in [[_portrait_left, "left", Vector2(6, 74)], [_portrait_right, "right", Vector2(274, 74)]]:
		var rect := entry[0] as TextureRect
		var side := String(entry[1])
		var home := Vector2(entry[2])
		if rect.texture == null:
			rect.visible = false
			continue
		rect.visible = true
		if side == speaker_side:
			rect.modulate = Color.WHITE
			rect.position = home + Vector2(0, 3)
			var tween := create_tween()
			tween.tween_property(rect, "position", home, 0.12).set_ease(Tween.EASE_OUT)
		else:
			rect.modulate = Color(0.55, 0.58, 0.62)
			rect.position = home
	# 名牌跟著說話者側
	_name_tag.position.x = 10.0 if speaker_side != "right" else 226.0


func _set_portrait(rect: TextureRect, spec: String) -> void:
	var parts := spec.split(":")
	var char_name := parts[0]
	var expression := parts[1] if parts.size() > 1 else "neutral"
	var path := "%s/%s_%s.png" % [PORTRAIT_DIR, char_name, expression]
	if ResourceLoader.exists(path):
		rect.texture = load(path)
	else:
		rect.texture = null


func _on_choice_shown(prompt: String, options: PackedStringArray) -> void:
	_panel.visible = true
	_more_label.visible = false
	if not prompt.is_empty():
		_text_label.text = prompt
	for child in _choice_box.get_children():
		child.queue_free()
	_choice_rows.clear()
	for option in options:
		var row := UiTheme.make_row(option, null)
		_choice_box.add_child(row["panel"])
		_choice_rows.append(row)
	_choice_index = 0
	_choice_panel.visible = true
	_refresh_choice()


func _on_finished() -> void:
	_panel.visible = false
	_choice_panel.visible = false
	_more_label.visible = false
	_name_tag.visible = false
	_portrait_left.visible = false
	_portrait_right.visible = false
	_portrait_left.texture = null
	_portrait_right.texture = null


func _refresh_choice() -> void:
	for i in range(_choice_rows.size()):
		UiTheme.set_row_state(_choice_rows[i], "focus" if i == _choice_index else "normal")


func _build_ui() -> void:
	_portrait_left = TextureRect.new()
	_portrait_left.position = Vector2(6, 74)
	_portrait_left.visible = false
	add_child(_portrait_left)
	_portrait_right = TextureRect.new()
	_portrait_right.position = Vector2(274, 74)
	_portrait_right.visible = false
	add_child(_portrait_right)

	_panel = PanelContainer.new()
	_panel.position = Vector2(4, 126)
	_panel.size = Vector2(312, 50)
	_panel.add_theme_stylebox_override("panel", UiTheme.panel_style())
	_panel.visible = false
	add_child(_panel)
	_text_label = Label.new()
	_text_label.add_theme_font_size_override("font_size", 12)
	_text_label.add_theme_color_override("font_color", UiTheme.text_color("normal"))
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel.add_child(_text_label)

	_name_tag = PanelContainer.new()
	_name_tag.position = Vector2(10, 108)
	_name_tag.add_theme_stylebox_override("panel", UiTheme.name_tag_style())
	_name_tag.visible = false
	add_child(_name_tag)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 12)
	_name_label.add_theme_color_override("font_color", Pal.AMBER_LT)
	_name_tag.add_child(_name_label)

	_more_label = Label.new()
	_more_label.text = "▼"
	_more_label.position = Vector2(302, 162)
	_more_label.add_theme_font_size_override("font_size", 12)
	_more_label.add_theme_color_override("font_color", UiTheme.text_color("accent"))
	_more_label.visible = false
	add_child(_more_label)

	_choice_panel = PanelContainer.new()
	_choice_panel.position = Vector2(196, 64)
	_choice_panel.custom_minimum_size = Vector2(120, 0)
	_choice_panel.add_theme_stylebox_override("panel", UiTheme.panel_style())
	_choice_panel.visible = false
	add_child(_choice_panel)
	_choice_box = VBoxContainer.new()
	_choice_box.add_theme_constant_override("separation", 2)
	_choice_panel.add_child(_choice_box)
