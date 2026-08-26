extends Node
## Autoload QA：`-- --tour` 從 New Game 完整自動通關（含計時與截圖）；
## `-- --tour-wrong` 走錯誤路線觸發教學遭遇後結束。未帶參數時完全不作用。
## 僅供 QA：會直接讀取場景內部狀態（_view/_service）驅動頭目戰。

var enabled := false
var wrong_mode := false
var continue_mode := false
var _t0 := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	wrong_mode = "--tour-wrong" in args
	continue_mode = "--tour-continue" in args
	enabled = ("--tour" in args) or wrong_mode or continue_mode
	if enabled and continue_mode:
		_run_continue()
	elif enabled:
		_run()


## Continue 驗證：讀取通關存檔，確認世界回到「恢復後」狀態
func _run_continue() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/qa"))
	_t0 = Time.get_ticks_msec()
	await _wait(14)
	await _press("move_down")  # 游標到「繼續觀測」
	await _press("confirm")
	await _wait(40)
	_mark("Continue → 完成狀態：level1_complete=%s stable_echo=%d" % [
		str(EventFlagStore.has_flag("level1_complete")), InventoryService.count("stable_echo")])
	_shot("continue_restored")
	# 與村民對話應為通關後變體
	get_tree().quit()


func _mark(label: String) -> void:
	var seconds := float(Time.get_ticks_msec() - _t0) / 1000.0
	print("[tour %6.1fs] %s ｜map=%s cell=%s dlg=%s" % [seconds, label, GameState.current_map_id, str(GameState.player_cell), str(DialogueManager.active)])


func _shot(shot_name: String) -> void:
	var image := get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("res://build/qa/%s.png" % shot_name))
	_mark("shot " + shot_name)


func _wait(frames: int) -> void:
	for i in range(frames):
		await get_tree().process_frame


func _press(action_name: String, hold: int = 2) -> void:
	Input.action_press(action_name)
	await _wait(hold)
	Input.action_release(action_name)
	await _wait(3)


## 精準走一格：按到「起步」就放開（避免連走），再等抵達
func _step(direction: StringName, expected: Vector2i) -> void:
	var player: Variant = get_tree().current_scene.get("_player") if get_tree().current_scene != null else null
	Input.action_press(direction)
	var tries := 0
	while tries < 60:
		tries += 1
		await get_tree().process_frame
		if player != null and Vector2i(player.get("cell")) == expected:
			break  # 已起步（內部座標先更新）
		if GameState.player_cell == expected:
			break
	Input.action_release(direction)
	tries = 0
	while GameState.player_cell != expected and tries < 40:
		tries += 1
		await get_tree().process_frame
	await _wait(2)


func _walk(direction: StringName, steps: int) -> void:
	var delta := {"move_up": Vector2i.UP, "move_down": Vector2i.DOWN, "move_left": Vector2i.LEFT, "move_right": Vector2i.RIGHT}[direction] as Vector2i
	for i in range(steps):
		await _step(direction, GameState.player_cell + delta)


func _face(direction: StringName) -> void:
	await _press(direction, 2)
	await _wait(4)


## 清空目前對話（選項一律選第一項）
func _pump_dialogue(shot_at_page: int = -1, shot_name: String = "") -> void:
	var page := 0
	var guard := 0
	while DialogueManager.active and guard < 80:
		guard += 1
		page += 1
		if page == shot_at_page and shot_name != "":
			await _wait(6)
			_shot(shot_name)
		await _press("confirm", 2)
		await _wait(6)
	await _wait(6)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/qa"))
	_t0 = Time.get_ticks_msec()
	await _wait(14)
	if not wrong_mode:
		_shot("title")
	# New Game
	await _press("confirm")
	await _wait(30)
	_mark("new game → 霧港村")
	# 開場（3 框）
	await _wait(20)
	if not wrong_mode:
		await _pump_dialogue(2, "dialogue_opening")
	else:
		await _pump_dialogue()
	_mark("開場結束，目標已交付")
	# 走到村口並觀測（spawn 3,6 → 東行）
	await _walk("move_right", 5)
	await _press("observe")
	_mark("第一次使用核心玩法：回聲觀測")
	if not wrong_mode:
		await _wait(10)
		_shot("observe_mode")
	# 線索一：無聲波紋（8,10）——沿水道西岸 x7 南下，面右調查
	await _walk("move_left", 1)
	await _walk("move_down", 4)
	await _face("move_right")
	await _press("confirm")
	await _pump_dialogue()
	_mark("線索一：無聲波紋")
	# 線索二：電波刮痕（21,5)——回主路東行到村口
	await _walk("move_up", 4)
	await _walk("move_right", 14)
	await _face("move_up")
	await _press("confirm")
	if not wrong_mode:
		await _pump_dialogue(1, "observe_clue")
	else:
		await _pump_dialogue()
	_mark("兩條線索到手")
	# 關閉觀測，走到路口做出判斷（路標 20,5，站 20,6）
	await _press("observe")
	await _walk("move_left", 1)
	await _face("move_up")
	await _press("confirm")
	await _wait(8)
	if wrong_mode:
		# 錯誤路線：翻頁 → 選第二項（沿岸）→ 教學遭遇
		await _press("confirm")
		await _wait(6)
		await _press("move_down")
		await _press("confirm")
		await _pump_dialogue()
		await _wait(40)
		_shot("tutorial_encounter")
		_mark("教學遭遇進場")
		# 打完教學戰（普攻到底）
		await _finish_normal_battle()
		await _wait(30)
		await _pump_dialogue()
		_shot("tutorial_after")
		_mark("錯誤路線已導正——tour-wrong 結束")
		get_tree().quit()
		return
	# 正解：上坡・電波刮痕（第一個選項）
	await _press("confirm")
	await _pump_dialogue()
	_mark("路徑判讀完成（正解）")
	# 出村 → 潮霧古道（出口 23,6）
	await _walk("move_right", 3)
	await _wait(30)
	_mark("進入潮霧古道")
	# 補給箱（5,5）：東行至 x6、上一步、面左
	await _walk("move_right", 5)
	await _walk("move_up", 1)
	await _face("move_left")
	await _press("confirm")
	await _pump_dialogue()
	# 上到主稜線 y3
	await _walk("move_up", 2)
	await _walk("move_right", 3)
	await _face("move_up")
	await _press("confirm")
	await _pump_dialogue()
	_shot("trail_landmark")
	# 續東：異常加劇（11,3 自動）→ 觀測位（12,4）
	await _walk("move_right", 2)
	await _pump_dialogue()
	await _walk("move_right", 1)
	await _face("move_down")
	await _press("confirm")
	await _pump_dialogue()
	_mark("可選觀測完成：取得頭目前兆")
	# 進站（15,3）
	await _walk("move_right", 3)
	await _wait(30)
	_mark("抵達廢棄潮汐觀測站")
	# 進場演出（4 框）
	await _wait(20)
	await _pump_dialogue(4, "station_reveal")
	# 走向中央（6,5 觸發對峙）→ 翻頁 → 上前
	await _walk("move_right", 4)
	await _wait(10)
	await _press("confirm")
	await _wait(6)
	await _press("confirm")
	await _wait(45)
	_mark("頭目戰開始")
	await _run_boss()
	# 結局：等港口結尾對話開始（色彩回歸演出後）
	await _wait_dialogue_start()
	await _pump_dialogue(1, "ending_bell")
	_mark("結尾演出完成、自動存檔")
	await _wait(45)
	_shot("chapter_card")
	await _press("confirm")
	# 伏筆（黑幕）
	await _wait_dialogue_start()
	await _wait(25)
	_shot("epilogue")
	await _pump_dialogue()
	await _wait(55)
	_shot("ending_free_roam")
	_mark("完整通關（含繼續探索）")
	get_tree().quit()


func _wait_dialogue_start() -> void:
	var guard := 0
	while not DialogueManager.active and guard < 400:
		guard += 1
		await get_tree().process_frame


## 頭目戰：讀取場景狀態按最優策略行動
func _run_boss() -> void:
	var guard := 0
	var shot_phase1 := false
	var shot_phase2 := false
	while guard < 400:
		guard += 1
		var scene := get_tree().current_scene
		var service_ref: Variant = scene.get("_service") if scene != null else null
		if service_ref == null:
			await _wait(10)
			var again := get_tree().current_scene
			if again == null or again.get("_service") == null:
				break
			continue
		var service: BossBattleService = service_ref
		if service.outcome != BossBattleService.Outcome.ONGOING:
			_mark("頭目戰收尾（回合數 %d）" % service.turn_count)
			# 等共鳴演出播完、按到場景切換為止
			for i in range(60):
				if get_tree().current_scene != scene:
					break
				await _press("confirm", 2)
				await _wait(10)
			return
		var view := int(scene.get("_view"))
		if view != 1:  # View.COMMAND
			await _press("confirm", 2)
			await _wait(4)
			continue
		# 指令階段
		if not shot_phase1:
			shot_phase1 = true
			_shot("boss_phase1")
		if service.phase == 2 and not shot_phase2:
			shot_phase2 = true
			_shot("boss_phase2")
		var target := 0
		if service.disrupted:
			target = 3  # 啟動共鳴
		elif service.next_move() == BossBattleService.Move.STRONGWAVE:
			target = 1  # 穩流防禦
		elif service.next_move() == BossBattleService.Move.CHARGE:
			target = 2  # 逆頻干擾
		else:
			target = 0  # 技能
		var cursor := int(scene.get("_cursor"))
		while cursor != target:
			await _press("move_down" if cursor < target else "move_up")
			cursor = int(scene.get("_cursor"))
		if service.disrupted and target == 3:
			_shot("boss_resonance_window")
		await _press("confirm")
		await _wait(6)
		if target == 0:
			await _press("confirm")  # 技能清單第一招
			await _wait(6)
	_mark("boss loop guard exceeded")


## 教學遭遇：普攻連打直到離開戰鬥場景
func _finish_normal_battle() -> void:
	var guard := 0
	while guard < 200:
		guard += 1
		var scene := get_tree().current_scene
		if scene == null:
			return
		var battle_ref: Variant = scene.get("_battle")
		if battle_ref == null:
			return
		await _press("confirm", 2)
		await _wait(6)