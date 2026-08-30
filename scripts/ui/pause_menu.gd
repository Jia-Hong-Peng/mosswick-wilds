extends Control
## 旅行手冊（M）：隊伍（含 HP 條與圖示）、背包（道具圖示）、記錄、闔上。
## 開啟時推入 MENU 輸入情境，凍結世界移動。

enum View { MAIN, PARTY, BAG, TARGET }

const MAIN_OPTIONS: Array[String] = ["同行隊伍", "工具包", "記錄進度", "闔上手冊"]

var _panel: PanelContainer
var _title_label: Label
var _rows_box: VBoxContainer
var _message_label: Label
var _rows: Array[Dictionary] = []

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
	var count := _row_count()
	if Input.is_action_just_pressed("move_up") and count > 0:
		_cursor = (_cursor - 1 + count) % count
		AudioManager.play_talk()
		_refresh()
	elif Input.is_action_just_pressed("move_down") and count > 0:
		_cursor = (_cursor + 1) % count
		AudioManager.play_talk()
		_refresh()
	elif Input.is_action_just_pressed("confirm"):
		_activate()
	elif Input.is_action_just_pressed("cancel") or Input.is_action_just_pressed("menu"):
		_back()


func _row_count() -> int:
	match _view:
		View.PARTY, View.TARGET:
			return maxi(1, PartyService.size())
		View.BAG:
			return maxi(1, InventoryService.item_ids().size())
		_:
			return MAIN_OPTIONS.size()


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
		_message_label.text = "%s要在較勁時才用得上。" % item.display_name
		AudioManager.play_bump()
		_refresh()
		return
	if PartyService.members.is_empty():
		_message_label.text = "還沒有導入任何工具。"
		AudioManager.play_bump()
		_refresh()
		return
	_selected_item_id = item.id
	_view = View.TARGET
	_cursor = 0
	_message_label.text = "把%s用在誰身上？" % item.display_name
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
		_message_label.text = "%s的狀態很好，不需要。" % member.display_name
		AudioManager.play_bump()
		_refresh()
		return
	var healed := member.heal(item.amount)
	InventoryService.use_item(item.id)
	AudioManager.play_heal()
	_message_label.text = "%s恢復了 %d HP。" % [member.display_name, healed]
	if InventoryService.count(item.id) <= 0:
		_view = View.BAG
		_cursor = 0
	_refresh()


func _do_save() -> void:
	if SaveService.save_game():
		_message_label.text = "已寫進旅行手冊。"
		AudioManager.play_item()
	else:
		_message_label.text = "記錄失敗……再試一次。"
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
			_title_label.text = "◈ 同行隊伍"
		View.BAG:
			_title_label.text = "◈ 工具包"
		View.TARGET:
			_title_label.text = "◈ 選擇對象"
		_:
			_title_label.text = "◈ 旅行手冊"
	for child in _rows_box.get_children():
		child.queue_free()
	_rows.clear()
	match _view:
		View.PARTY, View.TARGET:
			if PartyService.members.is_empty():
				_add_text_row("（還沒有導入任何工具）", null)
			for member in PartyService.members:
				_add_party_row(member)
		View.BAG:
			var ids := InventoryService.item_ids()
			if ids.is_empty():
				_add_text_row("（空空如也）", null)
			for item_id in ids:
				var item := DataRegistry.get_item(item_id)
				var item_name := item.display_name if item != null else item_id
				var icon: Texture2D = null
				if item != null and not item.icon_path.is_empty():
					icon = load(item.icon_path)
				_add_text_row("%s ×%d" % [item_name, InventoryService.count(item_id)], icon)
		_:
			for option in MAIN_OPTIONS:
				_add_text_row(option, null)
	for i in range(_rows.size()):
		UiTheme.set_row_state(_rows[i], "focus" if i == _cursor else "normal")


func _add_text_row(text: String, icon: Texture2D) -> void:
	var row := UiTheme.make_row(text, icon)
	_rows_box.add_child(row["panel"])
	_rows.append(row)


## 隊伍列：圖示＋名字/等級＋HP 條＋數值
func _add_party_row(member: CreatureInstance) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.row_style("normal"))
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var icon := TextureRect.new()
	if not member.icon_path.is_empty():
		icon.texture = load(member.icon_path)
	icon.custom_minimum_size = Vector2(20, 20)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	box.add_child(icon)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 1)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(info)
	var label := Label.new()
	label.text = "%s Lv%d　%d/%d" % [member.display_name, member.level, member.hp, member.max_hp]
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", UiTheme.text_color("normal"))
	info.add_child(label)
	var bar := UiTheme.make_hp_bar(92.0)
	var fill := bar["fill"] as ColorRect
	fill.size.x = float(bar["width"]) * member.hp_ratio()
	fill.color = UiTheme.hp_color(member.hp_ratio())
	info.add_child(bar["back"])
	_rows_box.add_child(panel)
	_rows.append({"panel": panel, "label": label})


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.position = Vector2(164, 4)
	_panel.size = Vector2(152, 172)
	_panel.add_theme_stylebox_override("panel", UiTheme.panel_style())
	add_child(_panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	_panel.add_child(vbox)
	_title_label = Label.new()
	UiTheme.style_header(_title_label)
	vbox.add_child(_title_label)
	var divider := ColorRect.new()
	divider.color = Pal.PAPER_DIM
	divider.custom_minimum_size = Vector2(0, 1)
	vbox.add_child(divider)
	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", 2)
	_rows_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_rows_box)
	_message_label = Label.new()
	_message_label.add_theme_font_size_override("font_size", 12)
	_message_label.add_theme_color_override("font_color", UiTheme.text_color("dim"))
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_message_label)
