extends RefCounted
## DEMO 流程：觀測情境開閉、對話期間凍結移動、路徑選擇旗標、
## 結局旗標＋道具、關卡完成自動存檔與 Continue 恢復。

const SaveScript := preload("res://scripts/persistence/save_service.gd")
const FLOW_PATH := "user://test_flow_save.json"

var _last_choice := PackedStringArray()


func run(t: TestContext) -> void:
	_test_observe_context(t)
	_test_dialogue_blocks_movement(t)
	_test_gate_choice(t)
	_test_ending_flags_and_autosave(t)
	_cleanup()


func _cleanup() -> void:
	for path: String in [FLOW_PATH, FLOW_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


## 觀測模式：情境堆疊正確開閉，且觀測中仍屬「可移動」情境
func _test_observe_context(t: TestContext) -> void:
	InputRouter.set_base_context(InputRouter.Context.WORLD)
	t.check(InputRouter.is_context(InputRouter.Context.WORLD), "基底為 WORLD")
	InputRouter.push_context(InputRouter.Context.OBSERVE)
	t.check(InputRouter.is_context(InputRouter.Context.OBSERVE), "開啟觀測後為 OBSERVE")
	var movable := InputRouter.is_context(InputRouter.Context.WORLD) or InputRouter.is_context(InputRouter.Context.OBSERVE)
	t.check(movable, "觀測中仍可移動")
	InputRouter.pop_context()
	t.check(InputRouter.is_context(InputRouter.Context.WORLD), "關閉觀測回到 WORLD")


## 對話期間：情境切為 DIALOGUE，玩家移動判定必然為否
func _test_dialogue_blocks_movement(t: TestContext) -> void:
	InputRouter.set_base_context(InputRouter.Context.WORLD)
	EventFlagStore.reset()
	DialogueManager.start("sign_plaza")
	t.check(DialogueManager.active, "對話啟動")
	t.check(InputRouter.is_context(InputRouter.Context.DIALOGUE), "對話中情境為 DIALOGUE")
	var movable := InputRouter.is_context(InputRouter.Context.WORLD) or InputRouter.is_context(InputRouter.Context.OBSERVE)
	t.check(not movable, "對話期間不可移動")
	DialogueManager.advance()
	t.check(not DialogueManager.active, "對話結束")
	t.check(InputRouter.is_context(InputRouter.Context.WORLD), "對話後回到 WORLD")


## 路口判讀：線索不足→提示；線索足夠→選擇正確路徑寫入旗標
func _test_gate_choice(t: TestContext) -> void:
	EventFlagStore.reset()
	InputRouter.set_base_context(InputRouter.Context.WORLD)
	# 線索不足：走 fallback 段（無選項）
	DialogueManager.start("gate_choice")
	t.check(DialogueManager.active, "路標對話啟動")
	DialogueManager.advance()
	t.check(not EventFlagStore.has_flag("path_chosen"), "線索不足不得選路")
	# 蒐集兩條線索後：出現選項
	EventFlagStore.set_flag("clue_signal")
	EventFlagStore.set_flag("clue_ripple")
	EventFlagStore.set_flag("clues_ready")
	_last_choice = PackedStringArray()
	DialogueManager.choice_shown.connect(_on_choice)
	var started := DialogueManager.start("gate_choice")
	t.check(started, "第二次路標對話必須能啟動（前一段對話已收束）")
	DialogueManager.advance()
	DialogueManager.choice_shown.disconnect(_on_choice)
	t.check_eq(_last_choice.size(), 2, "路口必須提供兩個方向")
	t.check(_last_choice.size() >= 1 and String(_last_choice[0]).contains("電波"), "選項文字要能預期結果")
	DialogueManager.select_choice(0)
	t.check(EventFlagStore.has_flag("path_chosen"), "選擇後寫入 path_chosen")
	t.check(EventFlagStore.has_flag("path_correct"), "正解寫入 path_correct")
	DialogueManager.advance()
	t.check(not DialogueManager.active, "選後補述結束")
	# 再訪路標：已選路變體
	DialogueManager.start("gate_choice")
	DialogueManager.advance()
	t.check(not DialogueManager.active, "已選路後路標只剩單頁")
	# 錯誤路徑的資料結構存在（實際戰鬥由 E2E 驗證）
	var entry := DataRegistry.get_dialogue("gate_choice")
	var found_tide := false
	for variant: Variant in Array(entry.get("variants", [])):
		for option: Variant in Array(Dictionary(Dictionary(variant).get("choice", {})).get("options", [])):
			if String(Dictionary(option).get("action", "")) == "choose_tide_path":
				found_tide = true
	t.check(found_tide, "沿岸誤選必須存在並觸發教學遭遇動作")


func _on_choice(_prompt: String, options: PackedStringArray) -> void:
	_last_choice = options


## 結局：旗標＋穩定回聲＋自動存檔＋Continue 恢復完成狀態
func _test_ending_flags_and_autosave(t: TestContext) -> void:
	EventFlagStore.reset()
	InventoryService.reset()
	PartyService.reset()
	PartyService.add_member(DataRegistry.make_creature("mosshorn", 5))
	InputRouter.set_base_context(InputRouter.Context.WORLD)
	DialogueManager.start("ending_scene")
	for i in range(4):
		DialogueManager.advance()
	t.check(not DialogueManager.active, "結尾對話四頁後結束")
	t.check(EventFlagStore.has_flag("level1_complete"), "關卡完成旗標寫入")
	t.check_eq(InventoryService.count("stable_echo"), 1, "取得穩定回聲")
	# 自動存檔（用測試路徑驗證同一套 payload 寫讀）
	GameState.set_world_position("harbor", Vector2i(12, 8), Vector2i.DOWN)
	var payload := SaveService.collect_payload()
	t.check(SaveScript.write_payload(FLOW_PATH, payload), "完成後自動存檔成功")
	var loaded: Dictionary = SaveScript.read_payload(FLOW_PATH)
	t.check(bool(Dictionary(loaded.get("flags", {})).get("level1_complete", false)), "存檔含關卡完成旗標")
	# Continue：套回服務後仍是完成狀態、已完成事件不重播（opening 旗標一併保存）
	EventFlagStore.reset()
	SaveService.apply_payload(loaded)
	t.check(EventFlagStore.has_flag("level1_complete"), "Continue 恢復完成狀態")
	t.check_eq(InventoryService.count("stable_echo"), 1, "Continue 恢復關鍵道具")