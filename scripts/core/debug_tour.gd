extends Node
## Autoload QA 巡覽：命令列帶 `-- --tour` 時自動走過主要畫面並輸出截圖到
## res://build/qa/。未帶參數時完全不作用。

var enabled := false


func _ready() -> void:
	enabled = "--tour" in OS.get_cmdline_user_args()
	if enabled:
		_run_tour()


func _run_tour() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/qa"))
	await _wait(12)
	_shot("title")
	GameState.start_new_game()
	SceneRouter.goto_world()
	await _wait(20)
	_shot("world_harbor")
	# 觀測手冊：主選單 → 隊伍 → 工具包
	await _press("menu")
	await _wait(5)
	_shot("menu_main")
	await _press("confirm")
	await _wait(5)
	_shot("menu_party")
	await _press("cancel")
	await _press("move_down")
	await _press("confirm")
	await _wait(5)
	_shot("menu_bag")
	await _press("cancel")
	await _press("cancel")
	await _wait(5)
	# NPC 對話（含選項）
	DialogueManager.start("npc_haibo")
	await _wait(5)
	_shot("dialogue")
	await _press("confirm")
	await _press("confirm")
	await _wait(5)
	_shot("dialogue_choice")
	await _press("move_down")
	await _press("confirm")
	await _press("confirm")
	await _wait(5)
	# 戰鬥：進場 → 訊息 → 指令 → 技能清單
	SceneRouter.goto_battle({"creature_id": "tidewing", "level": 4, "bg": "trail"})
	await _wait(45)
	_shot("battle_intro")
	await _press("confirm")
	await _wait(10)
	await _press("confirm")
	await _wait(15)
	_shot("battle_menu")
	await _press("confirm")
	await _wait(8)
	_shot("battle_skills")
	# 其他地圖
	GameState.set_world_position("trail", Vector2i(7, 11), Vector2i.DOWN)
	SceneRouter.goto_world()
	await _wait(20)
	_shot("world_trail")
	GameState.set_world_position("station", Vector2i(6, 5), Vector2i.UP)
	SceneRouter.goto_world()
	await _wait(20)
	_shot("world_station")
	GameState.set_world_position("home", Vector2i(5, 4), Vector2i.UP)
	SceneRouter.goto_world()
	await _wait(20)
	_shot("world_home")
	get_tree().quit()


func _wait(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame


func _press(action_name: String) -> void:
	Input.action_press(action_name)
	await _wait(2)
	Input.action_release(action_name)
	await _wait(3)


func _shot(shot_name: String) -> void:
	var image := get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("res://build/qa/%s.png" % shot_name))
	print("[tour] captured %s" % shot_name)
