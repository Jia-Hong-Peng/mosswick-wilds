extends Control
## In-world pause menu (M): Party list, Bag with field item use, Save, Close.
## Pushes the MENU input context while open, freezing world movement.

enum View { MAIN, PARTY, BAG, TARGET }

const DialogueBoxScript := preload("res://scripts/ui/dialogue_box.gd")

var _panel: PanelContainer
var _title_label: Label
var _rows_box: VBoxContainer
var _message_label: Label

var _view: int = View.MAIN
var _cursor := 0
var _selected_item_id := ""
var _opened_frame := -1
var _is_open := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	visible = false


func open() -> void:
	if _is_open:
		return
	_is_open = true
	visible = true
	_view = View.MAIN
	_cursor = 0
	_message_label.text = ""
	_opened_frame = Engine.get_process_frames()
	InputRouter.push_context(InputRouter.Context.MENU)
	AudioManager.play_confirm()
	_refresh()


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	visible = false
	InputRouter.pop_context()
	AudioManager.play_cancel()


func _process(_delta: float) -> void:
	if not _is_open or not InputRouter.is_context(InputRouter.Context.MENU):
		return
	if Engine.get_process_frames() == _opened_frame:
		return
	var rows := _current_rows()
	if Input.is_action_just_pressed("move_up") and rows.size() > 0:
		_cursor = (_cursor - 1 + rows.size()) % rows.size()
		_refresh()
	elif Input.is_action_just_pressed("move_down") and rows.size() > 0:
		_cursor = (_cursor + 1) % rows.size()
		_refresh()
	elif Input.is_action_just_pressed("confirm"):
		_activate()
	elif Input.is_action_just_pressed("cancel") or Input.is_action_just_pressed("menu"):
		_back()


func _current_rows() -> PackedStringArray:
	match _view:
		View.PARTY, View.TARGET:
			return _party_rows()
		View.BAG:
			return _bag_rows()
		_:
			return PackedStringArray(["Party", "Bag", "Save", "Close"])


func _party_rows() -> PackedStringArray:
	var rows := PackedStringArray()
	for member in PartyService.members:
		rows.append("%s Lv%d  %d/%d" % [member.display_name, member.level, member.hp, member.max_hp])
	if rows.is_empty():
		rows.append("(no creatures)")
	return rows


func _bag_rows() -> PackedStringArray:
	var rows := PackedStringArray()
	for item_id in InventoryService.item_ids():
		var item := DataRegistry.get_item(item_id)
		var item_name := item.display_name if item != null else item_id
		rows.append("%s x%d" % [item_name, InventoryService.count(item_id)])
	if rows.is_empty():
		rows.append("(empty)")
	return rows


func _activate() -> void:
	match _view:
		View.MAIN:
			match _cursor:
				0:
					_view = View.PARTY
					_cursor = 0
					AudioManager.play_confirm()
				1:
					_view = View.BAG
					_cursor = 0
					AudioManager.play_confirm()
				2:
					_do_save()
				3:
					close()
					return
			_refresh()
		View.BAG:
			_use_bag_item()
		View.TARGET:
			_apply_item_to_target()
		_:
			pass


func _use_bag_item() -> void:
	var ids := InventoryService.item_ids()
	if _cursor >= ids.size():
		return
	var item := DataRegistry.get_item(ids[_cursor])
	if item == null:
		return
	if not item.usable_in_field:
		_message_label.text = "%s can only be used in battle." % item.display_name
		AudioManager.play_bump()
		_refresh()
		return
	if PartyService.members.is_empty():
		_message_label.text = "No creatures in your party."
		AudioManager.play_bump()
		_refresh()
		return
	_selected_item_id = item.id
	_view = View.TARGET
	_cursor = 0
	_message_label.text = "Use %s on which creature?" % item.display_name
	AudioManager.play_confirm()
	_refresh()


func _apply_item_to_target() -> void:
	if _cursor >= PartyService.members.size():
		return
	var member: CreatureInstance = PartyService.members[_cursor]
	var item := DataRegistry.get_item(_selected_item_id)
	if item == null or InventoryService.count(item.id) <= 0:
		_back()
		return
	if member.hp >= member.max_hp:
		_message_label.text = "%s's HP is already full." % member.display_name
		AudioManager.play_bump()
		_refresh()
		return
	var healed := member.heal(item.amount)
	InventoryService.use_item(item.id)
	AudioManager.play_fanfare()
	_message_label.text = "%s restored %d HP." % [member.display_name, healed]
	if InventoryService.count(item.id) <= 0:
		_view = View.BAG
		_cursor = 0
	_refresh()


func _do_save() -> void:
	if SaveService.save_game():
		_message_label.text = "Progress saved."
		AudioManager.play_fanfare()
	else:
		_message_label.text = "Save failed!"
		AudioManager.play_bump()
	_refresh()


func _back() -> void:
	match _view:
		View.MAIN:
			close()
		View.TARGET:
			_view = View.BAG
			_cursor = 0
			_message_label.text = ""
			AudioManager.play_cancel()
			_refresh()
		_:
			_view = View.MAIN
			_cursor = 0
			_message_label.text = ""
			AudioManager.play_cancel()
			_refresh()


func _refresh() -> void:
	match _view:
		View.PARTY:
			_title_label.text = "PARTY"
		View.BAG:
			_title_label.text = "BAG"
		View.TARGET:
			_title_label.text = "CHOOSE TARGET"
		_:
			_title_label.text = "MENU"
	for child in _rows_box.get_children():
		child.queue_free()
	var rows := _current_rows()
	for i in range(rows.size()):
		var label := Label.new()
		label.text = ("> " if i == _cursor else "  ") + rows[i]
		label.add_theme_font_size_override("font_size", 8)
		_rows_box.add_child(label)


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.position = Vector2(164, 8)
	_panel.size = Vector2(152, 132)
	_panel.add_theme_stylebox_override("panel", DialogueBoxScript.make_box_style())
	add_child(_panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	_panel.add_child(vbox)
	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 8)
	_title_label.add_theme_color_override("font_color", Color("f2d27a"))
	vbox.add_child(_title_label)
	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", 1)
	_rows_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_rows_box)
	_message_label = Label.new()
	_message_label.add_theme_font_size_override("font_size", 8)
	_message_label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_message_label)
