extends Control
## Battle presentation layer. All rules live in BattleService (pure domain);
## this scene renders its events, updates HP bars, and forwards menu input.
## Input is polled so on-screen touch buttons work like the keyboard.

enum View { EVENTS, COMMAND, SKILLS, ITEMS }

const DialogueBoxScript := preload("res://scripts/ui/dialogue_box.gd")

var _battle: BattleService
var _player: CreatureInstance
var _enemy: CreatureInstance
var _rng := RandomNumberGenerator.new()

var _queue: Array[BattleService.BattleEvent] = []
var _view: int = View.EVENTS
var _cursor := 0
var _waiting_confirm := false
var _finished := false

var _message_label: Label
var _more_label: Label
var _menu_panel: PanelContainer
var _menu_box: VBoxContainer
var _player_info: Label
var _player_hp_text: Label
var _player_hp_bar: ColorRect
var _enemy_info: Label
var _enemy_hp_bar: ColorRect


func _ready() -> void:
	InputRouter.set_base_context(InputRouter.Context.BATTLE)
	_rng.randomize()
	var encounter := GameState.pending_encounter
	_enemy = DataRegistry.make_creature(String(encounter.get("creature_id", "cindermoth")), int(encounter.get("level", 3)))
	_player = PartyService.first_conscious()
	if _enemy == null or _player == null:
		SceneRouter.goto_world()
		return
	_battle = BattleService.new(_player, _enemy, DataRegistry.skills_for(_enemy), _rng)
	_build_ui()
	_refresh_bars()
	_queue = _battle.intro_events()
	_view = View.EVENTS
	_pump()


func _process(_delta: float) -> void:
	if _finished or _battle == null:
		return
	if not InputRouter.is_context(InputRouter.Context.BATTLE):
		return
	if _view == View.EVENTS:
		if _waiting_confirm and Input.is_action_just_pressed("confirm"):
			_waiting_confirm = false
			_pump()
		return
	var count := _row_count()
	if Input.is_action_just_pressed("move_up") and count > 0:
		_cursor = (_cursor - 1 + count) % count
		_refresh_menu()
	elif Input.is_action_just_pressed("move_down") and count > 0:
		_cursor = (_cursor + 1) % count
		_refresh_menu()
	elif Input.is_action_just_pressed("confirm"):
		_activate()
	elif Input.is_action_just_pressed("cancel") and _view != View.COMMAND:
		AudioManager.play_cancel()
		_view = View.COMMAND
		_cursor = 0
		_refresh_menu()


func _row_count() -> int:
	match _view:
		View.SKILLS:
			return DataRegistry.skills_for(_player).size()
		View.ITEMS:
			return _battle_items().size()
		_:
			return 4


func _menu_rows() -> PackedStringArray:
	match _view:
		View.SKILLS:
			var rows := PackedStringArray()
			for skill in DataRegistry.skills_for(_player):
				rows.append("%s (%d)" % [skill.display_name, skill.power])
			return rows
		View.ITEMS:
			var rows := PackedStringArray()
			for item in _battle_items():
				rows.append("%s x%d" % [item.display_name, InventoryService.count(item.id)])
			return rows
		_:
			return PackedStringArray(["戰鬥", "背包", "捕捉", "逃跑"])


func _battle_items() -> Array[ItemDef]:
	var result: Array[ItemDef] = []
	for item_id in InventoryService.item_ids():
		var item := DataRegistry.get_item(item_id)
		if item != null and item.usable_in_battle and InventoryService.count(item_id) > 0:
			result.append(item)
	return result


func _activate() -> void:
	match _view:
		View.COMMAND:
			match _cursor:
				0:
					AudioManager.play_confirm()
					_view = View.SKILLS
					_cursor = 0
					_refresh_menu()
				1:
					if _battle_items().is_empty():
						_flash_message("沒有可用的道具！")
					else:
						AudioManager.play_confirm()
						_view = View.ITEMS
						_cursor = 0
						_refresh_menu()
				2:
					_try_capture()
				3:
					_do_action(BattleService.ActionType.FLEE, {})
		View.SKILLS:
			var skills := DataRegistry.skills_for(_player)
			if _cursor < skills.size():
				_do_action(BattleService.ActionType.SKILL, {"skill": skills[_cursor]})
		View.ITEMS:
			var items := _battle_items()
			if _cursor < items.size():
				var item := items[_cursor]
				if item.kind == ItemDef.KIND_CAPTURE:
					_do_capture_with(item)
				else:
					_do_action(BattleService.ActionType.ITEM, {"item": item})
		_:
			pass


func _try_capture() -> void:
	var orb := DataRegistry.get_item("snare_orb")
	if orb == null or InventoryService.count(orb.id) <= 0:
		_flash_message("藤縛球用完了！")
		return
	_do_capture_with(orb)


func _do_capture_with(item: ItemDef) -> void:
	_do_action(BattleService.ActionType.CAPTURE, {"item": item, "party_full": PartyService.is_full()})


func _do_action(action: int, payload: Dictionary) -> void:
	AudioManager.play_confirm()
	_queue = _battle.take_turn(action, payload)
	_view = View.EVENTS
	_menu_panel.visible = false
	_pump()


func _flash_message(text: String) -> void:
	AudioManager.play_bump()
	_message_label.text = text


func _pump() -> void:
	while not _queue.is_empty():
		var event: BattleService.BattleEvent = _queue.pop_front()
		match event.kind:
			BattleService.EVENT_MESSAGE:
				_message_label.text = event.text
				_waiting_confirm = true
				_more_label.visible = true
				return
			BattleService.EVENT_PLAYER_HP, BattleService.EVENT_ENEMY_HP:
				AudioManager.play_hit()
				_refresh_bars()
			BattleService.EVENT_CONSUME_ITEM:
				InventoryService.use_item(String(event.data.get("item_id", "")))
			BattleService.EVENT_CAPTURED:
				PartyService.add_member(_enemy)
				AudioManager.play_fanfare()
				_message_label.text = event.text
				_waiting_confirm = true
				_more_label.visible = true
				return
			BattleService.EVENT_END:
				pass
	_more_label.visible = false
	if _battle.outcome == BattleService.Outcome.ONGOING:
		_view = View.COMMAND
		_cursor = 0
		_menu_panel.visible = true
		_message_label.text = "%s要做什麼？" % _player.display_name
		_refresh_menu()
	else:
		_finish_battle()


func _finish_battle() -> void:
	_finished = true
	if _battle.outcome == BattleService.Outcome.DEFEAT:
		# Blacked out: the party is patched up back at the town square.
		PartyService.heal_all()
		GameState.respawn_at_start()
	SceneRouter.goto_world()


func _refresh_menu() -> void:
	for child in _menu_box.get_children():
		child.queue_free()
	var rows := _menu_rows()
	for i in range(rows.size()):
		var label := Label.new()
		label.text = ("> " if i == _cursor else "  ") + rows[i]
		label.add_theme_font_size_override("font_size", 10)
		_menu_box.add_child(label)


func _refresh_bars() -> void:
	_enemy_info.text = "%s Lv%d" % [_enemy.display_name, _enemy.level]
	_enemy_hp_bar.size.x = 60.0 * _enemy.hp_ratio()
	_enemy_hp_bar.color = _hp_color(_enemy.hp_ratio())
	_player_info.text = "%s Lv%d" % [_player.display_name, _player.level]
	_player_hp_text.text = "%d/%d" % [_player.hp, _player.max_hp]
	_player_hp_bar.size.x = 60.0 * _player.hp_ratio()
	_player_hp_bar.color = _hp_color(_player.hp_ratio())


func _hp_color(ratio: float) -> Color:
	if ratio > 0.5:
		return Color(0.35, 0.78, 0.36)
	if ratio > 0.2:
		return Color(0.9, 0.78, 0.25)
	return Color(0.85, 0.3, 0.25)


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var sky := ColorRect.new()
	sky.color = Color(0.55, 0.68, 0.58)
	sky.position = Vector2.ZERO
	sky.size = Vector2(320, 112)
	add_child(sky)
	var ground := ColorRect.new()
	ground.color = Color(0.36, 0.5, 0.4)
	ground.position = Vector2(0, 112)
	ground.size = Vector2(320, 68)
	add_child(ground)

	var enemy_sprite := TextureRect.new()
	enemy_sprite.texture = load(_enemy.sprite_path)
	enemy_sprite.position = Vector2(206, 22)
	enemy_sprite.size = Vector2(64, 64)
	enemy_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	enemy_sprite.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(enemy_sprite)

	var player_sprite := TextureRect.new()
	player_sprite.texture = load(_player.sprite_path)
	player_sprite.position = Vector2(46, 62)
	player_sprite.size = Vector2(64, 64)
	player_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	player_sprite.stretch_mode = TextureRect.STRETCH_SCALE
	player_sprite.flip_h = true
	add_child(player_sprite)

	_enemy_info = _info_panel(Vector2(8, 8))
	_enemy_hp_bar = _hp_bar_at(Vector2(14, 24))
	_player_info = _info_panel(Vector2(118, 84))
	_player_hp_bar = _hp_bar_at(Vector2(124, 100))
	_player_hp_text = Label.new()
	_player_hp_text.position = Vector2(124, 110)
	_player_hp_text.add_theme_font_size_override("font_size", 8)
	add_child(_player_hp_text)

	var message_panel := PanelContainer.new()
	message_panel.position = Vector2(4, 126)
	message_panel.size = Vector2(312, 50)
	message_panel.add_theme_stylebox_override("panel", DialogueBoxScript.make_box_style())
	add_child(message_panel)
	var message_box := VBoxContainer.new()
	message_panel.add_child(message_box)
	_message_label = Label.new()
	_message_label.add_theme_font_size_override("font_size", 10)
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	message_box.add_child(_message_label)
	_more_label = Label.new()
	_more_label.text = "Z/Enter"
	_more_label.position = Vector2(276, 166)
	_more_label.add_theme_font_size_override("font_size", 8)
	_more_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	add_child(_more_label)

	_menu_panel = PanelContainer.new()
	_menu_panel.position = Vector2(204, 56)
	_menu_panel.size = Vector2(112, 66)
	_menu_panel.add_theme_stylebox_override("panel", DialogueBoxScript.make_box_style())
	_menu_panel.visible = false
	add_child(_menu_panel)
	_menu_box = VBoxContainer.new()
	_menu_box.add_theme_constant_override("separation", 1)
	_menu_panel.add_child(_menu_box)


func _info_panel(at: Vector2) -> Label:
	var panel := PanelContainer.new()
	panel.position = at
	panel.size = Vector2(80, 24)
	panel.add_theme_stylebox_override("panel", DialogueBoxScript.make_box_style())
	add_child(panel)
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 10)
	panel.add_child(label)
	return label


func _hp_bar_at(at: Vector2) -> ColorRect:
	var back := ColorRect.new()
	back.color = Color(0.1, 0.1, 0.14)
	back.position = at
	back.size = Vector2(62, 5)
	add_child(back)
	var front := ColorRect.new()
	front.color = Color(0.35, 0.78, 0.36)
	front.position = at + Vector2(1, 1)
	front.size = Vector2(60, 3)
	add_child(front)
	return front
