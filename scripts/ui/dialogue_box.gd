extends Control
## Renders DialogueManager pages and choices. Input is polled (not event
## driven) so on-screen touch buttons work identically to the keyboard.

var _panel: PanelContainer
var _name_label: Label
var _text_label: Label
var _more_label: Label
var _choice_panel: PanelContainer
var _choice_box: VBoxContainer
var _choice_index := 0
var _choice_count := 0


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
	# Skip the frame that opened the dialogue so the same confirm press
	# doesn't immediately advance the first page.
	if Engine.get_process_frames() == DialogueManager.opened_frame:
		return
	if _choice_panel.visible:
		if Input.is_action_just_pressed("move_up"):
			_choice_index = maxi(0, _choice_index - 1)
			_refresh_choice_cursor()
		elif Input.is_action_just_pressed("move_down"):
			_choice_index = mini(_choice_count - 1, _choice_index + 1)
			_refresh_choice_cursor()
		elif Input.is_action_just_pressed("confirm"):
			AudioManager.play_confirm()
			DialogueManager.select_choice(_choice_index)
	elif Input.is_action_just_pressed("confirm"):
		AudioManager.play_confirm()
		DialogueManager.advance()


func _on_page_shown(speaker: String, text: String) -> void:
	_panel.visible = true
	_choice_panel.visible = false
	_more_label.visible = true
	_name_label.visible = not speaker.is_empty()
	_name_label.text = speaker
	_text_label.text = text


func _on_choice_shown(prompt: String, options: PackedStringArray) -> void:
	_panel.visible = true
	_more_label.visible = false
	if not prompt.is_empty():
		_text_label.text = prompt
	for child in _choice_box.get_children():
		child.queue_free()
	_choice_count = options.size()
	for option in options:
		var label := Label.new()
		label.text = option
		label.add_theme_font_size_override("font_size", 10)
		_choice_box.add_child(label)
	_choice_index = 0
	_choice_panel.visible = true
	_refresh_choice_cursor()


func _on_finished() -> void:
	_panel.visible = false
	_choice_panel.visible = false
	_more_label.visible = false


func _refresh_choice_cursor() -> void:
	var i := 0
	for child: Node in _choice_box.get_children():
		if child is Label:
			var label := child as Label
			var raw := label.text.trim_prefix("> ").trim_prefix("  ")
			label.text = ("> " if i == _choice_index else "  ") + raw
			i += 1


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.position = Vector2(4, 122)
	_panel.size = Vector2(312, 54)
	_panel.add_theme_stylebox_override("panel", make_box_style())
	_panel.visible = false
	add_child(_panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 1)
	_panel.add_child(vbox)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 10)
	_name_label.add_theme_color_override("font_color", Color("f2d27a"))
	vbox.add_child(_name_label)
	_text_label = Label.new()
	_text_label.add_theme_font_size_override("font_size", 10)
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_text_label)
	_more_label = Label.new()
	_more_label.text = "Z/Enter"
	_more_label.position = Vector2(276, 166)
	_more_label.add_theme_font_size_override("font_size", 8)
	_more_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	add_child(_more_label)
	_more_label.visible = false

	_choice_panel = PanelContainer.new()
	_choice_panel.position = Vector2(222, 78)
	_choice_panel.size = Vector2(94, 42)
	_choice_panel.add_theme_stylebox_override("panel", make_box_style())
	_choice_panel.visible = false
	add_child(_choice_panel)
	_choice_box = VBoxContainer.new()
	_choice_box.add_theme_constant_override("separation", 1)
	_choice_panel.add_child(_choice_box)


static func make_box_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.09, 0.15, 0.94)
	style.border_color = Color(0.88, 0.9, 0.95)
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.set_content_margin_all(5)
	return style
