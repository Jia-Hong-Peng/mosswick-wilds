extends Control
## 標題畫面：分層港村黃昏背景＋手冊風選單。
## 新的觀測／繼續觀測（無存檔時停用）／音量。

const MENU_NEW_GAME := 0
const MENU_CONTINUE := 1
const MENU_VOLUME := 2
const MENU_FLASH := 3
const MENU_SHAKE := 4
const MENU_COUNT := 5

var _cursor := 0
var _has_save := false
var _rows: Array[Dictionary] = []


func _ready() -> void:
	InputRouter.set_base_context(InputRouter.Context.TITLE)
	_has_save = SaveService.has_save()
	_build_ui()
	_refresh()


func _process(_delta: float) -> void:
	if not InputRouter.is_context(InputRouter.Context.TITLE):
		return
	if Input.is_action_just_pressed("move_up"):
		_cursor = (_cursor - 1 + MENU_COUNT) % MENU_COUNT
		AudioManager.play_talk()
		_refresh()
	elif Input.is_action_just_pressed("move_down"):
		_cursor = (_cursor + 1) % MENU_COUNT
		AudioManager.play_talk()
		_refresh()
	elif Input.is_action_just_pressed("move_left") and _cursor == MENU_VOLUME:
		AudioManager.set_master_volume(AudioManager.master_volume - 0.1)
		AudioManager.play_confirm()
		_refresh()
	elif Input.is_action_just_pressed("move_right") and _cursor == MENU_VOLUME:
		AudioManager.set_master_volume(AudioManager.master_volume + 0.1)
		AudioManager.play_confirm()
		_refresh()
	elif Input.is_action_just_pressed("confirm"):
		_activate()


func _activate() -> void:
	match _cursor:
		MENU_NEW_GAME:
			AudioManager.play_confirm()
			GameState.start_new_game()
			SceneRouter.goto_world()
		MENU_CONTINUE:
			if _has_save and SaveService.load_game():
				AudioManager.play_confirm()
				SceneRouter.goto_world()
			else:
				AudioManager.play_bump()
		MENU_VOLUME:
			AudioManager.play_confirm()
		MENU_FLASH:
			AudioManager.set_reduce_flash(not AudioManager.reduce_flash)
			AudioManager.play_confirm()
			_refresh()
		MENU_SHAKE:
			AudioManager.set_reduce_shake(not AudioManager.reduce_shake)
			AudioManager.play_confirm()
			_refresh()


func _refresh() -> void:
	var volume_percent := int(roundf(AudioManager.master_volume * 100.0))
	var texts: Array[String] = [
		"新的觀測",
		"繼續觀測",
		"音量　◂ %d%% ▸" % volume_percent,
		"減少閃爍：%s" % ("開" if AudioManager.reduce_flash else "關"),
		"減少震動：%s" % ("開" if AudioManager.reduce_shake else "關"),
	]
	for i in range(_rows.size()):
		var row := _rows[i]
		(row["label"] as Label).text = texts[i]
		if i == MENU_CONTINUE and not _has_save:
			UiTheme.set_row_state(row, "disabled")
		else:
			UiTheme.set_row_state(row, "focus" if i == _cursor else "normal")


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := TextureRect.new()
	bg.texture = load("res://assets/ui/title_bg.png")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 標題：靠左置於海霧上方，避開右側村落剪影
	var title := Label.new()
	title.text = "潮 霧 群 島"
	title.position = Vector2(0, 20)
	title.size = Vector2(220, 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Pal.NIGHT)
	title.add_theme_color_override("font_shadow_color", Pal.alpha(Pal.FOG, 0.9))
	title.add_theme_constant_override("shadow_offset_x", 1)
	title.add_theme_constant_override("shadow_offset_y", 1)
	add_child(title)

	var subtitle := Label.new()
	subtitle.text = "TIDEMIST ISLES ── 霧港村的回聲觀測"
	subtitle.position = Vector2(0, 46)
	subtitle.size = Vector2(220, 14)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Pal.SLATE)
	subtitle.add_theme_color_override("font_shadow_color", Pal.alpha(Pal.FOG, 0.85))
	subtitle.add_theme_constant_override("shadow_offset_x", 1)
	subtitle.add_theme_constant_override("shadow_offset_y", 1)
	add_child(subtitle)

	# 選單：手冊面板（左下，避開右側村落剪影）
	var panel := PanelContainer.new()
	panel.position = Vector2(20, 88)
	panel.custom_minimum_size = Vector2(128, 0)
	panel.add_theme_stylebox_override("panel", UiTheme.panel_style())
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	for i in range(MENU_COUNT):
		var row := UiTheme.make_row("", null)
		box.add_child(row["panel"])
		_rows.append(row)

	# 操作提示（底部儀器色帶）
	var hint_panel := PanelContainer.new()
	hint_panel.position = Vector2(0, 162)
	hint_panel.size = Vector2(320, 18)
	var hint_style := UiTheme.dark_panel_style()
	hint_style.set_content_margin_all(2)
	hint_panel.add_theme_stylebox_override("panel", hint_style)
	add_child(hint_panel)
	var hints := Label.new()
	hints.text = "方向鍵/WASD 移動　Z/Enter 確認　X/Esc 取消　M 選單"
	hints.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hints.add_theme_font_size_override("font_size", 12)
	hints.add_theme_color_override("font_color", Pal.MIST_LT)
	hint_panel.add_child(hints)

	var version := Label.new()
	version.text = "v%s" % String(ProjectSettings.get_setting("application/config/version", "0.2.0"))
	version.position = Vector2(284, 4)
	version.add_theme_font_size_override("font_size", 12)
	version.add_theme_color_override("font_color", Pal.alpha(Pal.NIGHT, 0.6))
	add_child(version)
