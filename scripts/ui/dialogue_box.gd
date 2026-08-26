extends Control
## 對話框：手冊紙面＋說話者名牌＋選項清單。由 DialogueManager 驅動；
## 輸入用輪詢，鍵盤與觸控行為一致。

var _panel: PanelContainer
var _name_tag: PanelContainer
var _name_label: Label
var _text_label: Label
var _more_label: Label
var _choice_panel: PanelContainer
var _choice_box: VBoxContainer
var _choice_rows: Array[Dictionary] = []
var _choice_index := 0


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
	# 開啟當幀不吃輸入，避免同一次確認鍵連跳
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


func _on_page_shown(speaker: String, text: String) -> void:
	_panel.visible = true
	_more_label.visible = true
	_choice_panel.visible = false
	_name_tag.visible = not speaker.is_empty()
	_name_label.text = speaker
	_text_label.text = text


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


func _refresh_choice() -> void:
	for i in range(_choice_rows.size()):
		UiTheme.set_row_state(_choice_rows[i], "focus" if i == _choice_index else "normal")


func _build_ui() -> void:
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

	# 說話者名牌：浮在對話框左上
	_name_tag = PanelContainer.new()
	_name_tag.position = Vector2(10, 114)
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
	_choice_panel.position = Vector2(216, 64)
	_choice_panel.custom_minimum_size = Vector2(100, 0)
	_choice_panel.add_theme_stylebox_override("panel", UiTheme.panel_style())
	_choice_panel.visible = false
	add_child(_choice_panel)
	_choice_box = VBoxContainer.new()
	_choice_box.add_theme_constant_override("separation", 2)
	_choice_panel.add_child(_choice_box)
