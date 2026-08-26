extends Control
## Title screen: New Game / Continue (only with an existing save) / volume
## setting, plus keyboard and touch control hints.

const DialogueBoxScript := preload("res://scripts/ui/dialogue_box.gd")

const MENU_NEW_GAME := 0
const MENU_CONTINUE := 1
const MENU_VOLUME := 2
const MENU_COUNT := 3

var _cursor := 0
var _has_save := false
var _menu_labels: Array[Label] = []


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
		_refresh()
	elif Input.is_action_just_pressed("move_down"):
		_cursor = (_cursor + 1) % MENU_COUNT
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


func _refresh() -> void:
	var volume_percent := int(roundf(AudioManager.master_volume * 100.0))
	var texts: Array[String] = [
		"新遊戲",
		"繼續冒險",
		"音量  < %d%% >" % volume_percent,
	]
	for i in range(_menu_labels.size()):
		var prefix := "> " if i == _cursor else "  "
		_menu_labels[i].text = prefix + texts[i]
		var color := Color.WHITE
		if i == MENU_CONTINUE and not _has_save:
			color = Color(1, 1, 1, 0.35)
		elif i != _cursor:
			color = Color(1, 1, 1, 0.75)
		_menu_labels[i].add_theme_color_override("font_color", color)


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.14, 0.11)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title := Label.new()
	title.text = "苔木野林"
	title.position = Vector2(0, 18)
	title.size = Vector2(320, 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color("bfe3a8"))
	add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Mosswick Wilds · 迷你怪獸收服冒險"
	subtitle.position = Vector2(0, 42)
	subtitle.size = Vector2(320, 12)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 10)
	subtitle.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	add_child(subtitle)

	var creature_paths: Array[String] = [
		"res://assets/creatures/peatpaw.png",
		"res://assets/creatures/cindermoth.png",
		"res://assets/creatures/drippole.png",
	]
	for i in range(creature_paths.size()):
		var portrait := TextureRect.new()
		portrait.texture = load(creature_paths[i])
		portrait.position = Vector2(112 + i * 34, 58)
		portrait.size = Vector2(32, 32)
		add_child(portrait)

	for i in range(MENU_COUNT):
		var label := Label.new()
		label.position = Vector2(118, 100 + i * 14)
		label.size = Vector2(200, 12)
		label.add_theme_font_size_override("font_size", 10)
		add_child(label)
		_menu_labels.append(label)

	var hints := Label.new()
	hints.text = "方向鍵/WASD 移動 · Z/Enter 確認 · X/Esc 取消 · M 選單"
	hints.position = Vector2(0, 154)
	hints.size = Vector2(320, 12)
	hints.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hints.add_theme_font_size_override("font_size", 9)
	hints.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	add_child(hints)

	var hints2 := Label.new()
	hints2.text = "觸控裝置：螢幕方向鍵＋按鈕"
	hints2.position = Vector2(0, 166)
	hints2.size = Vector2(320, 12)
	hints2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hints2.add_theme_font_size_override("font_size", 9)
	hints2.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	add_child(hints2)

	var version := Label.new()
	version.text = "v%s" % String(ProjectSettings.get_setting("application/config/version", "0.1.0"))
	version.position = Vector2(288, 4)
	version.add_theme_font_size_override("font_size", 8)
	version.add_theme_color_override("font_color", Color(1, 1, 1, 0.3))
	add_child(version)
