extends Node
## Autoload QA：`-- --tour` 從 New Game 完整自動通關（認養芽翼鼯、草系解法）；
## `-- --tour-fire` 認養燼角羌（爆發解法）；`-- --tour-water` 認養潮冠鷺（速度解法）；
## `-- --tour-continue` 驗證通關存檔的 Continue。未帶參數時完全不作用。
## 僅供 QA：會直接讀取場景內部狀態（_view/_service）驅動危機戰。

var enabled := false
var starter := "sproutwing"
var continue_mode := false
var _t0 := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	continue_mode = "--tour-continue" in args
	if "--tour-fire" in args:
		starter = "emberhorn"
	elif "--tour-water" in args:
		starter = "tidecrest"
	enabled = ("--tour" in args) or ("--tour-fire" in args) or ("--tour-water" in args) or continue_mode
	if enabled and continue_mode:
		_run_continue()
	elif enabled:
		_run()


## Continue 驗證：讀取通關存檔，確認御三家與章節狀態正確恢復
func _run_continue() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/qa"))
	_t0 = Time.get_ticks_msec()
	await _wait(14)
	await _press("move_down")  # 游標到「繼續旅程」
	await _press("confirm")
	await _wait(45)
	_mark("Continue → starter=%s nickname=%s chapter_done=%s party=%d" % [
		GameState.starter_id, GameState.starter_nickname,
		str(EventFlagStore.has_flag("chapter_done")), PartyService.size()])
	_shot("continue_restored")
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


func _wait_dialogue_start() -> void:
	var guard := 0
	while not DialogueManager.active and guard < 500:
		guard += 1
		await get_tree().process_frame


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/qa"))
	_t0 = Time.get_ticks_msec()
	var default_run := starter == "sproutwing"
	await _wait(14)
	if default_run:
		_shot("title")
	# 開始旅程
	await _press("confirm")
	await _wait(35)
	_mark("new game → 潮芽伴獸之家")
	# 開場運鏡：拍一張後跳過
	await _wait(45)
	if default_run:
		_shot("opening_pan")
	await _press("confirm")
	await _wait(25)
	# 開場對話（葵姨）
	await _wait_dialogue_start()
	if default_run:
		await _pump_dialogue(2, "opening_kui")
	else:
		await _pump_dialogue()
	_mark("開場結束：認養日開始")
	# ---- 認養互動 ----
	match starter:
		"sproutwing":
			await _goto_sproutwing_pen()
		"emberhorn":
			await _goto_emberhorn_pen()
		"tidecrest":
			await _goto_tidecrest_pen()
	# 第一次互動：介紹＋接近方式（選正確的第一項）
	await _press("confirm")
	await _wait(8)
	await _pump_choice_first()
	if default_run:
		_shot("adopt_interact")
	await _pump_dialogue()
	_mark("互動完成：%s 接受了你" % starter)
	# 第二次互動：認養確認（選「認養」）
	await _press("confirm")
	await _wait(8)
	await _pump_choice_first()
	await _pump_dialogue()
	# 認養儀式（兩段對話＋暱稱視窗）
	await _wait(20)
	await _pump_dialogue()  # ceremony_<id>
	await _wait(50)          # 幼獸跳向玩家
	await _pump_dialogue(1, "adopt_ceremony" if default_run else "adopt_ceremony_%s" % starter)
	await _wait(20)
	# 暱稱視窗：Esc 保留原名
	await _press("cancel")
	await _wait(40)
	_mark("認養完成：%s 入隊（保留原名）" % starter)
	if default_run:
		_shot("adopt_done")
	# ---- 第一次同行 ----
	await _return_to_main_path()
	# 與夥伴互動一次（夥伴會跟在附近；面向下方嘗試）
	await _wait(30)
	await _try_partner_talk()
	# 找葵姨拿旅行包（11,9）：站 (11,8) 面下
	await _walk_to_row8_x(11)
	await _face("move_down")
	await _press("confirm")
	await _pump_dialogue()
	_mark("取得旅行包")
	if default_run:
		_shot("first_walk")
	# ---- 危機 ----
	await _walk_to_row8_x(21)
	await _walk("move_down", 3)  # (21,11) 閘門 → 危機觸發
	await _wait(10)
	await _wait_dialogue_start()
	await _pump_until_choice(3, "crisis_intro" if default_run else "")
	await _pump_choice_first()  # （點頭）我們一起。
	await _pump_dialogue()
	await _wait(50)
	_mark("危機戰開始（岩背獾）")
	await _run_crisis()
	# ---- 結局 ----
	await _wait_dialogue_start()
	await _pump_dialogue(2, "ending_calm" if default_run else "")
	await _wait(30)
	await _wait_dialogue_start()
	await _pump_dialogue()  # ending_check
	await _wait_dialogue_start()
	await _pump_dialogue()  # ending_farewell
	_mark("告別完成：閘門開啟")
	# 導演步行＋鏡頭拉遠＋最後兩句
	await _wait_dialogue_start()
	if default_run:
		await _pump_dialogue(1, "ending_walk")
	else:
		await _pump_dialogue()
	# 章節卡
	await _wait(60)
	_shot("chapter_card" if default_run else "chapter_card_%s" % starter)
	await _press("confirm")
	# 伏筆（公告板特寫）
	await _wait(160)
	if default_run:
		_shot("teaser")
	await _wait(120)
	# 結尾選單：繼續探索
	if default_run:
		_shot("end_menu")
	await _press("confirm")
	await _wait(60)
	if default_run:
		_shot("free_roam")
	_mark("完整通關（含繼續探索）")
	get_tree().quit()


# ---- 認養路線（spawn 10,3） ----

func _goto_sproutwing_pen() -> void:
	await _walk("move_down", 5)   # (10,8)
	await _walk("move_left", 6)   # (4,8)
	await _walk("move_up", 3)     # (4,5)
	await _face("move_left")      # 面向 (3,5)


func _goto_emberhorn_pen() -> void:
	await _walk("move_down", 5)   # (10,8)
	await _walk("move_right", 5)  # (15,8)
	await _walk("move_up", 3)     # (15,6)... (15,7)(15,6)
	await _face("move_up")        # 面向 (15,5)


func _goto_tidecrest_pen() -> void:
	await _walk("move_down", 5)   # (10,8)
	await _walk("move_right", 10)  # (20,8)
	await _walk("move_up", 1)     # (20,7)
	await _face("move_up")        # 面向 (20,6)


func _return_to_main_path() -> void:
	# 回到大路（列 8）
	while GameState.player_cell.y < 8:
		await _walk("move_down", 1)
	while GameState.player_cell.y > 8:
		await _walk("move_up", 1)


func _walk_to_row8_x(target_x: int) -> void:
	await _return_to_main_path()
	while GameState.player_cell.x < target_x:
		await _walk("move_right", 1)
	while GameState.player_cell.x > target_x:
		await _walk("move_left", 1)


func _try_partner_talk() -> void:
	# 讀取跟隨者位置，轉向面對後互動
	var scene := get_tree().current_scene
	var follower: Variant = scene.get("_follower") if scene != null else null
	if follower == null:
		_mark("與夥伴互動：找不到夥伴（略過）")
		return
	# 等夥伴停在相鄰格
	for i in range(90):
		var gap: Vector2i = Vector2i(follower.get("cell")) - GameState.player_cell
		if absi(gap.x) + absi(gap.y) == 1:
			break
		await get_tree().process_frame
	var delta: Vector2i = Vector2i(follower.get("cell")) - GameState.player_cell
	var dir_name: StringName = "move_down"
	if delta == Vector2i.UP:
		dir_name = "move_up"
	elif delta == Vector2i.LEFT:
		dir_name = "move_left"
	elif delta == Vector2i.RIGHT:
		dir_name = "move_right"
	if GameState.player_facing != delta:
		await _face(dir_name)
	await _press("confirm")
	await _wait(8)
	if DialogueManager.active:
		await _pump_dialogue()
		_mark("與夥伴互動成功")
	else:
		_mark("與夥伴互動：未觸發（略過）")


## 走到選項出現為止（對話頁數不定時使用）
func _pump_until_choice(shot_at_page: int = -1, shot_name: String = "") -> void:
	var guard := 0
	var page := 0
	while DialogueManager.active and not DialogueManager._awaiting_choice and guard < 40:
		guard += 1
		page += 1
		if page == shot_at_page and shot_name != "":
			await _wait(6)
			_shot(shot_name)
		await _press("confirm", 2)
		await _wait(6)


func _pump_choice_first() -> void:
	# 對話選項：確保游標在第一項後確認
	var guard := 0
	while DialogueManager.active and not DialogueManager._awaiting_choice and guard < 40:
		guard += 1
		await _press("confirm", 2)
		await _wait(6)
	if DialogueManager.active:
		await _press("confirm", 2)
		await _wait(8)


## 危機戰：依御三家策略行動（讀場景內部狀態）
func _run_crisis() -> void:
	var guard := 0
	var shot_battle := false
	var shot_soothe := false
	var default_run := starter == "sproutwing"
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
		var service: CrisisBattleService = service_ref
		if service.outcome != CrisisBattleService.Outcome.ONGOING:
			_mark("危機戰收尾（回合數 %d、outcome=%d）" % [service.turn_count, service.outcome])
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
		if not shot_battle:
			shot_battle = true
			_shot("crisis_battle" if default_run else "crisis_battle_%s" % starter)
		# 指令決策
		if service.at_floor():
			if not shot_soothe and default_run:
				shot_soothe = true
				_shot("soothe_window")
			await _select_command(scene, 1)  # 安撫
			continue
		var skill_index := _pick_skill(service)
		await _select_command(scene, 0)  # 技能
		await _wait(6)
		await _select_menu_row(scene, skill_index)
	_mark("crisis loop guard exceeded")


## 御三家策略：
## 芽翼鼯＝縮甲時上纏芽、衝撞前葉幕、其餘葉拍；
## 燼角羌＝縮甲後燼角衝撬開、其餘熱蹄；
## 潮冠鷺＝衝撞前霧步閃避（附帶連擊）、其餘潮羽。
func _pick_skill(service: CrisisBattleService) -> int:
	match starter:
		"sproutwing":
			if service.next_move() == CrisisBattleService.Move.RAM:
				return 2  # 葉幕
			if service.next_move() == CrisisBattleService.Move.SHELL:
				return 1  # 纏芽（衝撞前上減速）
			return 0      # 葉拍
		"emberhorn":
			if service.shelled and not service.shell_broken:
				return 1  # 燼角衝
			return 0      # 熱蹄
		_:
			if service.next_move() == CrisisBattleService.Move.RAM:
				return 1  # 霧步
			return 0      # 潮羽


func _select_command(scene: Node, target: int) -> void:
	var cursor := int(scene.get("_cursor"))
	var tries := 0
	while cursor != target and tries < 8:
		tries += 1
		await _press("move_down" if cursor < target else "move_up")
		cursor = int(scene.get("_cursor"))
	await _press("confirm")
	await _wait(6)


func _select_menu_row(scene: Node, target: int) -> void:
	var cursor := int(scene.get("_cursor"))
	var tries := 0
	while cursor != target and tries < 8:
		tries += 1
		await _press("move_down" if cursor < target else "move_up")
		cursor = int(scene.get("_cursor"))
	await _press("confirm")
	await _wait(6)
