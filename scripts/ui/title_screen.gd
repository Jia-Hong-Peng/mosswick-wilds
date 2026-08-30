extends Control
## 標題畫面：分層港村晨光背景＋手冊風選單。
## 開始旅程／繼續旅程（無存檔時停用）／音量／輔助設定／畫質。

const MENU_NEW_GAME := 0
const MENU_CONTINUE := 1
const MENU_VOLUME := 2
const MENU_FLASH := 3
const MENU_SHAKE := 4
const MENU_QUALITY := 5
const MENU_COUNT := 6

var _cursor := 0
var _has_save := false
var _rows: Array[Dictionary] = []
var _root: Control


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
		MENU_QUALITY:
			AudioManager.set_quality_high(not AudioManager.quality_high)
			AudioManager.play_confirm()
			_refresh()


func _refresh() -> void:
	var volume_percent := int(roundf(AudioManager.master_volume * 100.0))
	var texts: Array[String] = [
		"開始旅程",
		"繼續旅程",
		"◂音量%d%%▸" % volume_percent,
		"閃爍:%s" % ("減" if AudioManager.reduce_flash else "常"),
		"震動:%s" % ("減" if AudioManager.reduce_shake else "常"),
		"畫質:%s" % ("高" if AudioManager.quality_high else "低"),
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
	# 640×360 視窗下沿用 320×180 設計座標：整體 ×2
	_root = Control.new()
	_root.size = Vector2(320, 180)
	_root.scale = Vector2(4, 4)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var bg := TextureRect.new()
	# 使用者提供的高解析島嶼背景優先；缺檔時退回程式生成版
	var island_path := "res://assets/ui/title_bg_island.png"
	if ResourceLoader.exists(island_path):
		bg.texture = load(island_path)
		bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_SCALE
	else:
		bg.texture = load("res://assets/ui/title_bg.png")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)

	# 標題：左上，半透明深色底板保住高解析背景上的可讀性
	var title_scrim := Panel.new()
	var scrim_style := StyleBoxFlat.new()
	scrim_style.bg_color = Pal.alpha(Pal.NIGHT, 0.55)
	scrim_style.set_corner_radius_all(2)
	scrim_style.set_content_margin_all(0)
	title_scrim.add_theme_stylebox_override("panel", scrim_style)
	title_scrim.position = Vector2(10, 14)
	title_scrim.size = Vector2(204, 50)
	title_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(title_scrim)

	var title := Label.new()
	title.text = "潮 森 群 島"
	title.position = Vector2(0, 18)
	title.size = Vector2(220, 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Pal.PAPER)
	title.add_theme_color_override("font_shadow_color", Pal.alpha(Pal.INK, 0.9))
	title.add_theme_constant_override("shadow_offset_x", 1)
	title.add_theme_constant_override("shadow_offset_y", 1)
	_root.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "A00A IT × GHAS 導入篇"
	subtitle.position = Vector2(0, 46)
	subtitle.size = Vector2(220, 14)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Pal.SEA_PALE)
	subtitle.add_theme_color_override("font_shadow_color", Pal.alpha(Pal.INK, 0.85))
	subtitle.add_theme_constant_override("shadow_offset_x", 1)
	subtitle.add_theme_constant_override("shadow_offset_y", 1)
	_root.add_child(subtitle)

	# 主選單：開始／繼續（左側直列）
	var panel := PanelContainer.new()
	panel.position = Vector2(20, 72)
	panel.custom_minimum_size = Vector2(128, 0)
	panel.add_theme_stylebox_override("panel", UiTheme.panel_style())
	_root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	for i in range(2):
		var row := UiTheme.make_row("", null)
		box.add_child(row["panel"])
		_rows.append(row)

	# 設定列：音量／閃爍／震動／畫質（底部橫列紙面板，位於操作提示上方）
	var settings_panel := PanelContainer.new()
	settings_panel.position = Vector2(8, 128)
	var settings_style := UiTheme.panel_style()
	settings_style.set_content_margin_all(3)
	settings_panel.add_theme_stylebox_override("panel", settings_style)
	_root.add_child(settings_panel)
	var settings := HBoxContainer.new()
	settings.add_theme_constant_override("separation", 4)
	settings_panel.add_child(settings)
	for i in range(2, MENU_COUNT):
		var row := UiTheme.make_row("", null)
		settings.add_child(row["panel"])
		_rows.append(row)

	# 操作提示（底部儀器色帶）
	var hint_panel := PanelContainer.new()
	hint_panel.position = Vector2(0, 162)
	hint_panel.size = Vector2(320, 18)
	var hint_style := UiTheme.dark_panel_style()
	hint_style.set_content_margin_all(2)
	hint_panel.add_theme_stylebox_override("panel", hint_style)
	_root.add_child(hint_panel)
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
	_root.add_child(version)
