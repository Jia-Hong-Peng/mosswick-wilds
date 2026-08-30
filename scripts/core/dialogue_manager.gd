extends Node
## Autoload：對話流程（頁、選項、旗標、一次性給予、立繪、演出 FX、跳過）。
## UI（DialogueBox）與場景聽訊號；本節點不建 UI。
##
## 頁面格式：{"speaker","text","left":"char:expr","right":"char:expr",
##   "speaker_side":"left|right","fx":"效果名"}
## 選項格式：{"text","action","set_flag","pages_after":[...]}
## 條目可含 "variants"（if_flag / if_flag_not）、"set_flag"、"grant_items"。

signal page_shown(page: Dictionary)
signal choice_shown(prompt: String, options: PackedStringArray)
signal fx_requested(fx_name: String)
signal dialogue_finished
signal world_action_requested(starter_id: String)

var active := false
var opened_frame := -1

var _pages: Array[Dictionary] = []
var _page_index := 0
var _variant: Dictionary = {}
var _pending_choice: Dictionary = {}
var _awaiting_choice := false
var _post_action := ""


func start(dialogue_id: String) -> bool:
	if active:
		return false
	var entry := DataRegistry.get_dialogue(dialogue_id)
	if entry.is_empty():
		push_warning("Unknown dialogue id: " + dialogue_id)
		return false
	var variant := _pick_variant(entry)
	if variant.is_empty():
		return false
	_begin(variant)
	return true


func advance() -> void:
	if not active or _awaiting_choice:
		return
	_page_index += 1
	if _page_index < _pages.size():
		_show_current_page()
	elif not _pending_choice.is_empty():
		_present_choice()
	else:
		_finish()


## 跳過演出：直接跳到最後一頁（保留必要資訊），選項不可跳過
func skip() -> void:
	if not active or _awaiting_choice:
		return
	if _page_index < _pages.size() - 1:
		_page_index = _pages.size() - 1
		_show_current_page()


func select_choice(index: int) -> void:
	if not active or not _awaiting_choice:
		return
	var options := Array(_pending_choice.get("options", []))
	if options.is_empty():
		_finish()
		return
	var option := Dictionary(options[clampi(index, 0, options.size() - 1)])
	_awaiting_choice = false
	_pending_choice = {}
	if option.has("set_flag"):
		EventFlagStore.set_flag(String(option["set_flag"]))
	_apply_action(String(option.get("action", "")))
	var after_pages := Array(option.get("pages_after", []))
	if after_pages.is_empty():
		_finish()
		return
	_pages.clear()
	for page: Variant in after_pages:
		_pages.append(Dictionary(page))
	_page_index = 0
	_show_current_page()


func _pick_variant(entry: Dictionary) -> Dictionary:
	if not entry.has("variants"):
		return entry
	for variant: Variant in Array(entry["variants"]):
		var data := Dictionary(variant)
		if data.has("if_flag") and not EventFlagStore.has_flag(String(data["if_flag"])):
			continue
		if data.has("if_flag_not") and EventFlagStore.has_flag(String(data["if_flag_not"])):
			continue
		return data
	return {}


func _begin(variant: Dictionary) -> void:
	active = true
	opened_frame = Engine.get_process_frames()
	_variant = variant
	_post_action = ""
	_pages.clear()
	for page: Variant in Array(variant.get("pages", [])):
		_pages.append(Dictionary(page))
	_pending_choice = Dictionary(variant.get("choice", {}))
	_page_index = 0
	_awaiting_choice = false
	InputRouter.push_context(InputRouter.Context.DIALOGUE)
	if _pages.is_empty() and not _pending_choice.is_empty():
		_present_choice()
	elif _pages.is_empty():
		_finish()
	else:
		_show_current_page()


func _show_current_page() -> void:
	var page := _pages[_page_index]
	if page.has("fx"):
		fx_requested.emit(String(page["fx"]))
	page_shown.emit(page)


func _present_choice() -> void:
	_awaiting_choice = true
	var option_texts := PackedStringArray()
	for option: Variant in Array(_pending_choice.get("options", [])):
		option_texts.append(String(Dictionary(option).get("text", "...")))
	choice_shown.emit(String(_pending_choice.get("prompt", "")), option_texts)


func _apply_action(action: String) -> void:
	match action:
		"heal_party":
			PartyService.heal_all()
			AudioManager.play_heal()
		"adopt_sproutwing", "adopt_emberhorn", "adopt_tidecrest", \
		"start_crisis", "rival_battle", "return_title", "continue_explore":
			_post_action = action
		"":
			pass
		_:
			push_warning("Unknown dialogue action: " + action)


func _finish() -> void:
	if _variant.has("set_flag"):
		EventFlagStore.set_flag(String(_variant["set_flag"]))
	var grants := Dictionary(_variant.get("grant_items", {}))
	for item_id: Variant in grants:
		InventoryService.add_item(String(item_id), int(grants[item_id]))
	if not grants.is_empty():
		AudioManager.play_item()
	_variant = {}
	active = false
	InputRouter.pop_context()
	var pending := _post_action
	_post_action = ""
	dialogue_finished.emit()
	match pending:
		"start_crisis":
			SceneRouter.goto_crisis()
		"rival_battle":
			# 老桑的夥伴剋玩家御三家（草→火、火→水、水→草）
			var counter := {
				"sproutwing": "emberhorn",
				"emberhorn": "tidecrest",
				"tidecrest": "sproutwing",
			}
			SceneRouter.goto_battle({
				"creature_id": String(counter.get(GameState.starter_id, "rockbadger")),
				"level": 7,
				"bg": "trail",
				"trainer": true,
				"scripted": "rival",
			})
		"return_title":
			SceneRouter.goto_title()
		"adopt_sproutwing", "adopt_emberhorn", "adopt_tidecrest":
			# 認養儀式由世界場景導演接手
			world_action_requested.emit(pending.trim_prefix("adopt_"))
		_:
			pass
