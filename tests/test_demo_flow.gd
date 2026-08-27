extends RefCounted
## DEMO 流程（認養日）：對話凍結移動、閘門變體閘控、認養互動→
## 確認→動作訊號、葵姨旅行包發放、夥伴互動變體、伏筆公告板、
## 認養結果入檔與 Continue 恢復。

const SaveScript := preload("res://scripts/persistence/save_service.gd")
const FLOW_PATH := "user://test_flow_save.json"

var _last_choice := PackedStringArray()
var _adopt_requested := ""


func run(t: TestContext) -> void:
	_test_dialogue_blocks_movement(t)
	_test_yard_gate_variants(t)
	_test_adoption_interaction(t)
	_test_kui_travel_pack(t)
	_test_partner_talk_variants(t)
	_test_board_teaser(t)
	_test_adopt_and_autosave(t)
	_cleanup()


func _cleanup() -> void:
	for path: String in [FLOW_PATH, FLOW_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _pump() -> void:
	var guard := 0
	while DialogueManager.active and not DialogueManager._awaiting_choice and guard < 30:
		guard += 1
		DialogueManager.advance()


## 對話期間：情境切為 DIALOGUE，玩家移動判定必然為否
func _test_dialogue_blocks_movement(t: TestContext) -> void:
	InputRouter.set_base_context(InputRouter.Context.WORLD)
	EventFlagStore.reset()
	DialogueManager.start("board_notice")
	t.check(DialogueManager.active, "對話啟動")
	t.check(InputRouter.is_context(InputRouter.Context.DIALOGUE), "對話中情境為 DIALOGUE")
	t.check(not InputRouter.is_context(InputRouter.Context.WORLD), "對話期間不可移動")
	_pump()
	t.check(not DialogueManager.active, "對話結束")
	t.check(InputRouter.is_context(InputRouter.Context.WORLD), "對話後回到 WORLD")


## 閘門對話：依進度切換五種變體，危機只觸發一次
func _test_yard_gate_variants(t: TestContext) -> void:
	EventFlagStore.reset()
	InputRouter.set_base_context(InputRouter.Context.WORLD)
	# 尚未認養：勸回
	DialogueManager.start("yard_gate")
	_pump()
	t.check(not EventFlagStore.has_flag("crisis_started"), "未認養不得觸發危機")
	# 已認養未拿包：提醒
	EventFlagStore.set_flag("starter_chosen")
	DialogueManager.start("yard_gate")
	_pump()
	t.check(not EventFlagStore.has_flag("crisis_started"), "沒拿旅行包不得觸發危機")
	# 拿了旅行包：危機（有單一選項＋start_crisis 動作）
	EventFlagStore.set_flag("travel_pack_taken")
	_last_choice = PackedStringArray()
	DialogueManager.choice_shown.connect(_on_choice)
	DialogueManager.start("yard_gate")
	_pump()
	DialogueManager.choice_shown.disconnect(_on_choice)
	t.check_eq(_last_choice.size(), 1, "危機只有一個選項：一起面對")
	t.check(DialogueManager._awaiting_choice, "危機停在選項等玩家點頭")
	# 不真的開戰（start_crisis 會換場景）；直接收掉對話狀態
	DialogueManager._awaiting_choice = false
	DialogueManager._pending_choice = {}
	DialogueManager._post_action = ""
	DialogueManager._finish()
	t.check(EventFlagStore.has_flag("crisis_started"), "危機收束後立旗（不重播）")
	# 危機已觸發過：改為圍欄敘述
	DialogueManager.start("yard_gate")
	_pump()
	t.check(not DialogueManager.active, "危機後閘門對話收束為單頁")
	# 資料結構：start_crisis 動作存在
	var entry := DataRegistry.get_dialogue("yard_gate")
	var found := false
	for variant: Variant in Array(entry.get("variants", [])):
		for option: Variant in Array(Dictionary(Dictionary(variant).get("choice", {})).get("options", [])):
			if String(Dictionary(option).get("action", "")) == "start_crisis":
				found = true
	t.check(found, "危機選項必須掛 start_crisis 動作")


func _on_choice(_prompt: String, options: PackedStringArray) -> void:
	_last_choice = options


## 認養互動：錯誤方式不留旗標可重試；正確方式立 met_ 旗標；
## 再次互動出現認養確認；「認養」發出世界動作訊號；「再想一下」可反悔
func _test_adoption_interaction(t: TestContext) -> void:
	for id: String in ["sproutwing", "emberhorn", "tidecrest"]:
		EventFlagStore.reset()
		InputRouter.set_base_context(InputRouter.Context.WORLD)
		# 錯誤接近：無旗標
		DialogueManager.start("pen_" + id)
		_pump()
		t.check(DialogueManager._awaiting_choice, "%s 首次互動要出現接近方式選項" % id)
		DialogueManager.select_choice(1)  # 錯誤選項
		_pump()
		t.check(not DialogueManager.active, "%s 錯誤接近後對話收束" % id)
		t.check(not EventFlagStore.has_flag("met_" + id), "%s 錯誤接近不得立旗（可重試）" % id)
		# 正確接近
		DialogueManager.start("pen_" + id)
		_pump()
		DialogueManager.select_choice(0)
		_pump()
		t.check(EventFlagStore.has_flag("met_" + id), "%s 正確接近立 met_ 旗標" % id)
		# 認養確認：再想一下
		DialogueManager.start("pen_" + id)
		_pump()
		t.check(DialogueManager._awaiting_choice, "%s 再訪要出現認養確認" % id)
		DialogueManager.select_choice(1)
		_pump()
		t.check(not EventFlagStore.has_flag("starter_chosen"), "%s 再想一下不得成立認養" % id)
		# 認養：發出世界動作
		_adopt_requested = ""
		DialogueManager.world_action_requested.connect(_on_adopt)
		DialogueManager.start("pen_" + id)
		_pump()
		DialogueManager.select_choice(0)
		_pump()
		DialogueManager.world_action_requested.disconnect(_on_adopt)
		t.check_eq(_adopt_requested, id, "%s 選「認養」必須發出世界動作訊號" % id)
		# 已認養：欄位變體（幼獸留在之家、不消失也不被拋棄）
		EventFlagStore.set_flag("starter_chosen")
		var other := "sproutwing" if id != "sproutwing" else "emberhorn"
		DialogueManager.start("pen_" + other)
		t.check(DialogueManager.active, "其他幼獸保留在認養之家（有留守對話）")
		_pump()


func _on_adopt(starter_id: String) -> void:
	_adopt_requested = starter_id


## 葵姨：認養後首次對話發旅行包＋依御三家給不同評語
func _test_kui_travel_pack(t: TestContext) -> void:
	EventFlagStore.reset()
	InventoryService.reset()
	InputRouter.set_base_context(InputRouter.Context.WORLD)
	EventFlagStore.set_flag("starter_chosen")
	EventFlagStore.set_flag("adopted_emberhorn")
	DialogueManager.start("npc_kui")
	_pump()
	t.check(EventFlagStore.has_flag("travel_pack_taken"), "葵姨首次對話立旅行包旗標")
	t.check_eq(InventoryService.count("travel_pack"), 1, "取得旅行包")
	t.check_eq(InventoryService.count("herbal_balm"), 2, "旅行包附青草膏 ×2")
	# 再談：不重複發包
	DialogueManager.start("npc_kui")
	_pump()
	t.check_eq(InventoryService.count("travel_pack"), 1, "旅行包不得重複發放")


func _test_partner_talk_variants(t: TestContext) -> void:
	for id: String in ["sproutwing", "emberhorn", "tidecrest"]:
		EventFlagStore.reset()
		InputRouter.set_base_context(InputRouter.Context.WORLD)
		EventFlagStore.set_flag("adopted_" + id)
		DialogueManager.start("partner_talk")
		t.check(DialogueManager.active, "%s 的夥伴互動要有專屬反應" % id)
		_pump()


func _test_board_teaser(t: TestContext) -> void:
	EventFlagStore.reset()
	InputRouter.set_base_context(InputRouter.Context.WORLD)
	DialogueManager.start("board_notice")
	var entry := DataRegistry.get_dialogue("board_notice")
	t.check(Array(entry.get("variants", [])).size() >= 2, "公告板要有通關前後兩種內容")
	_pump()
	EventFlagStore.set_flag("chapter_done")
	DialogueManager.start("board_notice")
	# 通關後：失蹤伴獸啟事（伏筆）
	var teaser_found := false
	for variant: Variant in Array(entry.get("variants", [])):
		for page: Variant in Array(Dictionary(variant).get("pages", [])):
			if String(Dictionary(page).get("text", "")).contains("不同顏色的眼睛"):
				teaser_found = true
	t.check(teaser_found, "伏筆：雨水暈開的照片與不同色的眼睛")
	_pump()


## 認養結果：入隊、旗標、旅伴牌、暱稱、自動存檔與 Continue 恢復
func _test_adopt_and_autosave(t: TestContext) -> void:
	EventFlagStore.reset()
	InventoryService.reset()
	PartyService.reset()
	GameState.starter_id = ""
	GameState.starter_nickname = ""
	GameState.adopt_starter("tidecrest", "小浪")
	t.check_eq(PartyService.size(), 1, "認養後隊伍一名成員")
	t.check_eq(PartyService.members[0].creature_id, "tidecrest", "入隊的是選中的御三家")
	t.check_eq(PartyService.members[0].display_name, "小浪", "暱稱套用")
	t.check(EventFlagStore.has_flag("starter_chosen"), "starter_chosen 旗標")
	t.check(EventFlagStore.has_flag("adopted_tidecrest"), "adopted_<id> 旗標")
	t.check_eq(InventoryService.count("travel_tag"), 1, "配戴旅伴牌")
	# 自動存檔 → Continue
	GameState.set_world_position("haven", Vector2i(20, 7), Vector2i.UP)
	var payload := SaveService.collect_payload()
	t.check(SaveScript.write_payload(FLOW_PATH, payload), "認養後自動存檔成功")
	var loaded: Dictionary = SaveScript.read_payload(FLOW_PATH)
	EventFlagStore.reset()
	PartyService.reset()
	GameState.starter_id = ""
	SaveService.apply_payload(loaded)
	t.check_eq(GameState.starter_id, "tidecrest", "Continue 恢復御三家")
	t.check_eq(GameState.starter_nickname, "小浪", "Continue 恢復暱稱")
	t.check_eq(PartyService.members[0].display_name, "小浪", "Continue 後隊伍成員仍用暱稱")
	t.check(EventFlagStore.has_flag("adopted_tidecrest"), "Continue 恢復認養旗標")
	# 保留原名：暱稱與原名相同時不入檔
	GameState.adopt_starter("sproutwing", "芽翼鼯")
	t.check_eq(GameState.starter_nickname, "", "與原名相同視為保留原名")