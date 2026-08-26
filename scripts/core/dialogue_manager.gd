extends Node
## Autoload: dialogue flow (pages, choices, event flags, one-time grants).
## The DialogueBox UI listens to the signals; this node never builds UI.
##
## Dialogue entry format (res://data/dialogue/dialogues.json):
##   {"pages": [{"speaker": "...", "text": "..."}],
##    "choice": {"prompt": "...", "options": [
##        {"text": "...", "action": "heal_party", "pages_after": [...]}]},
##    "set_flag": "...", "grant_items": {"item_id": count},
##    "variants": [{"if_flag_not": "...", ...entry...}, {...fallback...}]}

signal page_shown(speaker: String, text: String)
signal choice_shown(prompt: String, options: PackedStringArray)
signal dialogue_finished

var active := false
var opened_frame := -1

var _pages: Array[Dictionary] = []
var _page_index := 0
var _variant: Dictionary = {}
var _pending_choice: Dictionary = {}
var _awaiting_choice := false


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
	page_shown.emit(String(page.get("speaker", "")), String(page.get("text", "")))


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
			AudioManager.play_fanfare()
		"":
			pass
		_:
			push_warning("Unknown dialogue action: " + action)


func _finish() -> void:
	# One-time effects fire exactly once: the flag flips the variant next time.
	if _variant.has("set_flag"):
		EventFlagStore.set_flag(String(_variant["set_flag"]))
	var grants := Dictionary(_variant.get("grant_items", {}))
	for item_id: Variant in grants:
		InventoryService.add_item(String(item_id), int(grants[item_id]))
	_variant = {}
	active = false
	InputRouter.pop_context()
	dialogue_finished.emit()
