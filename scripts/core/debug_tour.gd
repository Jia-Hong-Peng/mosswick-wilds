extends Node
## Autoload QA harness: with `-- --tour` on the command line it plays through
## the key scenes and saves screenshots to res://build/qa/. Inert otherwise.

var enabled := false


func _ready() -> void:
	enabled = "--tour" in OS.get_cmdline_user_args()
	if enabled:
		_run_tour()


func _run_tour() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/qa"))
	await _wait_frames(10)
	_shot("title")
	GameState.start_new_game()
	SceneRouter.goto_world()
	await _wait_frames(15)
	_shot("world_town")
	Input.action_press("menu")
	await _wait_frames(2)
	Input.action_release("menu")
	await _wait_frames(5)
	_shot("pause_menu")
	Input.action_press("cancel")
	await _wait_frames(2)
	Input.action_release("cancel")
	await _wait_frames(5)
	SceneRouter.goto_battle({"creature_id": "cindermoth", "level": 4})
	await _wait_frames(15)
	_shot("battle")
	GameState.set_world_position("route", Vector2i(5, 4), Vector2i.DOWN)
	SceneRouter.goto_world()
	await _wait_frames(15)
	_shot("world_route")
	GameState.set_world_position("house", Vector2i(4, 4), Vector2i.UP)
	SceneRouter.goto_world()
	await _wait_frames(15)
	_shot("world_house")
	get_tree().quit()


func _wait_frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	var image := get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("res://build/qa/%s.png" % shot_name))
	print("[tour] captured %s" % shot_name)
