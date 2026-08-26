extends Control
## 戰鬥呈現層。規則全在 BattleService（純領域）；本場景負責：
## 依遭遇地點的分層背景、進場動畫、Idle 呼吸、攻擊前搖、受擊閃白＋位移、
## 畫面震動、粒子、HP 平滑增減、捕捉動畫與結算面板。
## 輸入用輪詢，鍵盤與觸控行為一致。

enum View { EVENTS, COMMAND, SKILLS, ITEMS }

const COMMANDS: Array[String] = ["較勁", "背包", "收錄", "離開"]

var _battle: BattleService
var _player: CreatureInstance
var _enemy: CreatureInstance
var _rng := RandomNumberGenerator.new()

var _view: int = View.EVENTS
var _cursor := 0
var _waiting_confirm := false
var _finished := false
var _running_events := false
var _capture_pending := false

var _stage: Control
var _enemy_sprite: Sprite2D
var _player_sprite: Sprite2D
var _enemy_home := Vector2.ZERO
var _player_home := Vector2.ZERO
var _idle_clock := 0.0

var _message_label: Label
var _more_label: Label
var _menu_panel: PanelContainer
var _menu_box: GridContainer
var _menu_rows: Array[Dictionary] = []
var _player_panel: PanelContainer
var _enemy_name: Label
var _enemy_bar: Dictionary
var _player_name: Label
var _player_bar: Dictionary
var _player_hp_text: Label
var _ui_root: Control


func _ready() -> void:
	InputRouter.set_base_context(InputRouter.Context.BATTLE)
	_rng.randomize()
	var encounter := GameState.pending_encounter
	_enemy = DataRegistry.make_creature(String(encounter.get("creature_id", "mosshorn")), int(encounter.get("level", 3)))
	_player = PartyService.first_conscious()
	if _enemy == null or _player == null:
		SceneRouter.goto_world()
		return
	_battle = BattleService.new(_player, _enemy, DataRegistry.skills_for(_enemy), _rng)
	_build_ui(String(encounter.get("bg", "village")))
	_refresh_bars(false)
	_entry_animation()


func _process(delta: float) -> void:
	_animate_idle(delta)
	if _finished or _battle == null:
		return
	if not InputRouter.is_context(InputRouter.Context.BATTLE):
		return
	if _view == View.EVENTS:
		if _waiting_confirm and Input.is_action_just_pressed("confirm"):
			_waiting_confirm = false
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
		_open_command()


# ---------- 選單 ----------

func _row_count() -> int:
	match _view:
		View.SKILLS:
			return DataRegistry.skills_for(_player).size()
		View.ITEMS:
			return _battle_items().size()
		_:
			return COMMANDS.size()


func _battle_items() -> Array[ItemDef]:
	var result: Array[ItemDef] = []
	for item_id in InventoryService.item_ids():
		var item := DataRegistry.get_item(item_id)
		if item != null and item.usable_in_battle and InventoryService.count(item_id) > 0:
			result.append(item)
	return result


func _open_command() -> void:
	_view = View.COMMAND
	_cursor = 0
	_menu_panel.visible = true
	_player_panel.visible = false
	_message_label.text = "%s要怎麼做？" % _player.display_name
	_refresh_menu()


func _refresh_menu() -> void:
	for child in _menu_box.get_children():
		child.queue_free()
	_menu_rows.clear()
	match _view:
		View.SKILLS:
			_layout_menu_list()
			var skills := DataRegistry.skills_for(_player)
			for skill in skills:
				_add_menu_row(skill.display_name, _element_icon(skill.element))
			if _cursor < skills.size():
				var skill := skills[_cursor]
				_message_label.text = "威力%d・命中%d%%　%s" % [skill.power, int(skill.accuracy * 100.0), skill.description]
		View.ITEMS:
			_layout_menu_list()
			for item in _battle_items():
				_add_menu_row("%s ×%d" % [item.display_name, InventoryService.count(item.id)], _icon_or_null(item.icon_path))
		_:
			_layout_menu_grid()
			for command in COMMANDS:
				_add_menu_row(command, null)
	for i in range(_menu_rows.size()):
		UiTheme.set_row_state(_menu_rows[i], "focus" if i == _cursor else "normal")


## 指令：2×2 嵌在訊息列右側
func _layout_menu_grid() -> void:
	_menu_box.columns = 2
	_menu_panel.position = Vector2(208, 132)
	_menu_panel.size = Vector2(108, 44)


## 技能／道具：直式清單（蓋在敵方側，選完即收）
func _layout_menu_list() -> void:
	_menu_box.columns = 1
	_menu_panel.position = Vector2(196, 54)
	_menu_panel.size = Vector2(120, 0)


func _add_menu_row(text: String, icon: Texture2D) -> void:
	var row := UiTheme.make_row(text, icon)
	_menu_box.add_child(row["panel"])
	_menu_rows.append(row)


func _element_icon(element: String) -> Texture2D:
	if element in ["forest", "tide", "signal", "neutral"]:
		return load("res://assets/ui/elem_%s.png" % element)
	return null


func _icon_or_null(path: String) -> Texture2D:
	return load(path) if not path.is_empty() else null


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
						_flash_message("背包裡沒有能用的東西。")
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
					_do_action(BattleService.ActionType.CAPTURE, {"item": item, "party_full": PartyService.is_full()})
				else:
					_do_action(BattleService.ActionType.ITEM, {"item": item})
		_:
			pass


func _try_capture() -> void:
	var orb := DataRegistry.get_item("echo_box")
	if orb == null or InventoryService.count(orb.id) <= 0:
		_flash_message("共鳴匣用完了。")
		return
	_do_action(BattleService.ActionType.CAPTURE, {"item": orb, "party_full": PartyService.is_full()})


func _do_action(action: int, payload: Dictionary) -> void:
	if _running_events:
		return
	AudioManager.play_confirm()
	_run_events(_battle.take_turn(action, payload))


func _flash_message(text: String) -> void:
	AudioManager.play_bump()
	_message_label.text = text


# ---------- 事件序列（非同步演出） ----------

func _run_events(events: Array[BattleService.BattleEvent]) -> void:
	_running_events = true
	_view = View.EVENTS
	_menu_panel.visible = false
	_player_panel.visible = true
	for event in events:
		if not is_inside_tree():
			return
		match event.kind:
			BattleService.EVENT_MESSAGE:
				if event.data.has("attacker"):
					await _lunge(String(event.data["attacker"]))
				if _capture_pending and event.text.contains("掙脫"):
					await _capture_break()
				_message_label.text = event.text
				await _wait_confirm()
			BattleService.EVENT_ENEMY_HP:
				await _apply_hp_event(event, false)
			BattleService.EVENT_PLAYER_HP:
				await _apply_hp_event(event, true)
			BattleService.EVENT_CONSUME_ITEM:
				var item_id := String(event.data.get("item_id", ""))
				InventoryService.use_item(item_id)
				var item := DataRegistry.get_item(item_id)
				if item != null and item.kind == ItemDef.KIND_CAPTURE:
					await _capture_throw()
			BattleService.EVENT_CAPTURED:
				await _capture_success()
				PartyService.add_member(_enemy)
				_message_label.text = event.text
				await _wait_confirm()
			BattleService.EVENT_END:
				pass
	_running_events = false
	if _battle.outcome == BattleService.Outcome.ONGOING:
		_open_command()
	else:
		await _end_sequence()


func _wait_confirm() -> void:
	_more_label.visible = true
	_waiting_confirm = true
	while _waiting_confirm and is_inside_tree():
		await get_tree().process_frame
	_more_label.visible = false


func _apply_hp_event(event: BattleService.BattleEvent, is_player: bool) -> void:
	var damage := int(event.data.get("damage", 0))
	var healed := int(event.data.get("healed", 0))
	if damage > 0:
		await _hit_fx(is_player)
	elif healed > 0:
		AudioManager.play_heal()
		var sprite := _player_sprite if is_player else _enemy_sprite
		var tween := create_tween()
		tween.tween_property(sprite, "modulate", Color(0.75, 1.0, 0.75), 0.12)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.18)
		await tween.finished
	_refresh_bars(true)
	await get_tree().create_timer(0.28).timeout


# ---------- 演出 ----------

func _entry_animation() -> void:
	_enemy_home = _enemy_sprite.position
	_player_home = _player_sprite.position
	_enemy_sprite.position.x += 110
	_player_sprite.position.x -= 110
	_ui_root.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_enemy_sprite, "position:x", _enemy_home.x, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(_player_sprite, "position:x", _player_home.x, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(_ui_root, "modulate:a", 1.0, 0.45)
	await tween.finished
	_run_events(_battle.intro_events())


func _animate_idle(delta: float) -> void:
	if _enemy_sprite == null:
		return
	_idle_clock += delta
	# 敵方：兩幀 Idle 呼吸；我方：1px 上下浮動
	_enemy_sprite.frame = int(_idle_clock / 0.55) % 2
	_player_sprite.offset.y = -1.0 if fmod(_idle_clock, 1.0) < 0.5 else 0.0


func _lunge(side: String) -> void:
	var sprite := _player_sprite if side == "player" else _enemy_sprite
	var home := _player_home if side == "player" else _enemy_home
	var push := Vector2(10, -4) if side == "player" else Vector2(-10, 4)
	# 敵方：前搖幀（Anticipation）→ 攻擊幀 → 還原
	var restore_texture: Texture2D = null
	var restore_hframes := 1
	if side == "enemy":
		var antic_path := "res://assets/creatures/%s_antic.png" % _enemy.creature_id
		var attack_path := "res://assets/creatures/%s_attack.png" % _enemy.creature_id
		if ResourceLoader.exists(antic_path):
			restore_texture = sprite.texture
			restore_hframes = sprite.hframes
			sprite.texture = load(antic_path)
			sprite.hframes = 1
			sprite.frame = 0
			await get_tree().create_timer(0.22).timeout
			if ResourceLoader.exists(attack_path):
				sprite.texture = load(attack_path)
	AudioManager.play_attack()
	var tween := create_tween()
	tween.tween_property(sprite, "position", home - push * 0.4, 0.1)
	tween.tween_property(sprite, "position", home + push, 0.08)
	tween.tween_property(sprite, "position", home, 0.12)
	await tween.finished
	if restore_texture != null:
		sprite.texture = restore_texture
		sprite.hframes = restore_hframes


func _hit_fx(is_player: bool) -> void:
	AudioManager.play_hit()
	var sprite := _player_sprite if is_player else _enemy_sprite
	var creature := _player if is_player else _enemy
	var home := _player_home if is_player else _enemy_home
	var normal_texture := sprite.texture
	var normal_hframes := sprite.hframes
	# 閃白剪影 + 受擊位移
	if not creature.hit_path.is_empty():
		sprite.texture = load(creature.hit_path)
		sprite.hframes = 1
		sprite.frame = 0
	_burst_particles(sprite.position)
	var tween := create_tween()
	for i in range(3):
		tween.tween_property(sprite, "position:x", home.x + (3 if i % 2 == 0 else -3), 0.04)
	tween.tween_property(sprite, "position:x", home.x, 0.04)
	_shake_stage()
	await get_tree().create_timer(0.12).timeout
	sprite.texture = normal_texture
	sprite.hframes = normal_hframes
	await tween.finished


func _shake_stage() -> void:
	if AudioManager.reduce_shake:
		return
	var tween := create_tween()
	for i in range(3):
		tween.tween_property(_stage, "position", Vector2((2 if i % 2 == 0 else -2), 0), 0.04)
	tween.tween_property(_stage, "position", Vector2.ZERO, 0.04)


func _burst_particles(at: Vector2) -> void:
	var burst := CPUParticles2D.new()
	burst.position = at
	burst.one_shot = true
	burst.emitting = true
	burst.amount = 10
	burst.lifetime = 0.35
	burst.explosiveness = 1.0
	burst.spread = 180.0
	burst.initial_velocity_min = 40.0
	burst.initial_velocity_max = 70.0
	burst.gravity = Vector2(0, 120)
	burst.scale_amount_min = 1.0
	burst.scale_amount_max = 2.0
	burst.color = Pal.FOAM
	_stage.add_child(burst)
	get_tree().create_timer(0.6).timeout.connect(burst.queue_free)


func _capture_throw() -> void:
	_capture_pending = true
	AudioManager.play_capture_throw()
	var box := Sprite2D.new()
	box.name = "EchoBox"
	box.texture = load("res://assets/ui/item_echo_box.png")
	box.position = _player_home + Vector2(10, -20)
	_stage.add_child(box)
	# 拋物線：兩段補間
	var mid := (_player_home + _enemy_home) * 0.5 + Vector2(0, -46)
	var tween := create_tween()
	tween.tween_property(box, "position", mid, 0.2).set_ease(Tween.EASE_OUT)
	tween.tween_property(box, "position", _enemy_home + Vector2(0, 6), 0.2).set_ease(Tween.EASE_IN)
	await tween.finished
	# 迴靈被收入匣中
	var close_tween := create_tween().set_parallel(true)
	close_tween.tween_property(_enemy_sprite, "scale", Vector2(0.1, 0.1), 0.2)
	close_tween.tween_property(_enemy_sprite, "modulate", Pal.AMBER_LT, 0.2)
	await close_tween.finished
	_enemy_sprite.visible = false
	# 匣子晃三下（判定中）
	var shake := create_tween()
	for i in range(3):
		shake.tween_property(box, "rotation_degrees", 12.0 if i % 2 == 0 else -12.0, 0.16)
		shake.tween_interval(0.08)
	shake.tween_property(box, "rotation_degrees", 0.0, 0.1)
	await shake.finished


func _capture_success() -> void:
	AudioManager.play_capture_success()
	_burst_particles(_enemy_home + Vector2(0, 6))
	var box := _stage.get_node_or_null("EchoBox")
	if box != null:
		var tween := create_tween()
		tween.tween_property(box, "modulate:a", 0.0, 0.35)
		await tween.finished
		box.queue_free()
	_capture_pending = false


func _capture_break() -> void:
	AudioManager.play_capture_fail()
	var box := _stage.get_node_or_null("EchoBox")
	if box != null:
		box.queue_free()
	_enemy_sprite.visible = true
	_enemy_sprite.modulate = Color.WHITE
	var tween := create_tween()
	tween.tween_property(_enemy_sprite, "scale", Vector2.ONE, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	await tween.finished
	_capture_pending = false


func _refresh_bars(animated: bool) -> void:
	_enemy_name.text = "%s Lv%d" % [_enemy.display_name, _enemy.level]
	_player_name.text = "%s Lv%d" % [_player.display_name, _player.level]
	_player_hp_text.text = "%d / %d" % [_player.hp, _player.max_hp]
	_set_bar(_enemy_bar, _enemy.hp_ratio(), animated)
	_set_bar(_player_bar, _player.hp_ratio(), animated)


func _set_bar(bar: Dictionary, ratio: float, animated: bool) -> void:
	var fill := bar["fill"] as ColorRect
	var target := maxf(0.0, float(bar["width"]) * ratio)
	fill.color = UiTheme.hp_color(ratio)
	if animated:
		var tween := create_tween()
		tween.tween_property(fill, "size:x", target, 0.3).set_ease(Tween.EASE_OUT)
	else:
		fill.size.x = target


func _end_sequence() -> void:
	_finished = true
	if String(GameState.pending_encounter.get("scripted", "")) == "tutorial":
		EventFlagStore.set_flag("tutorial_done")
	if _battle.outcome == BattleService.Outcome.FLED:
		SceneRouter.goto_world()
		return
	# 結算面板：調查紀錄
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_style())
	panel.position = Vector2(84, 56)
	panel.custom_minimum_size = Vector2(152, 0)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var header := Label.new()
	header.text = "── 調查紀錄 ──"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTheme.style_header(header)
	box.add_child(header)
	var result := Label.new()
	result.add_theme_font_size_override("font_size", 12)
	result.add_theme_color_override("font_color", UiTheme.text_color("normal"))
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.custom_minimum_size = Vector2(140, 0)
	match _battle.outcome:
		BattleService.Outcome.VICTORY:
			result.text = "野生的%s退開了。這一帶的回聲安定了一些。" % _enemy.display_name
		BattleService.Outcome.CAPTURED:
			result.text = "%s的回聲已收錄，成為同行的夥伴。" % _enemy.display_name
		BattleService.Outcome.DEFEAT:
			result.text = "你眼前一黑……醒來時已躺在霧港村。"
		_:
			result.text = ""
	box.add_child(result)
	var hint := Label.new()
	hint.text = "Z 繼續"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", UiTheme.text_color("accent"))
	box.add_child(hint)
	panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.25)
	_finished = false
	await _wait_confirm()
	_finished = true
	if _battle.outcome == BattleService.Outcome.DEFEAT:
		PartyService.heal_all()
		GameState.respawn_at_start()
	SceneRouter.goto_world()


# ---------- 版面 ----------

func _build_ui(bg_key: String) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_stage = Control.new()
	_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)

	var bg := TextureRect.new()
	var bg_path := "res://assets/battle/bg_%s.png" % bg_key
	bg.texture = load(bg_path if ResourceLoader.exists(bg_path) else "res://assets/battle/bg_village.png")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stage.add_child(bg)

	var shadow_texture: Texture2D = load("res://assets/ui/contact_shadow.png")
	var enemy_shadow := Sprite2D.new()
	enemy_shadow.texture = shadow_texture
	enemy_shadow.position = Vector2(240, 84)
	_stage.add_child(enemy_shadow)
	var player_shadow := Sprite2D.new()
	player_shadow.texture = shadow_texture
	player_shadow.position = Vector2(76, 150)
	_stage.add_child(player_shadow)

	_enemy_sprite = Sprite2D.new()
	_enemy_sprite.texture = load(_enemy.sprite_path)
	_enemy_sprite.hframes = 2
	_enemy_sprite.position = Vector2(240, 58)
	_stage.add_child(_enemy_sprite)

	_player_sprite = Sprite2D.new()
	_player_sprite.texture = load(_player.back_path)
	_player_sprite.position = Vector2(76, 124)
	_stage.add_child(_player_sprite)

	_ui_root = Control.new()
	_ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ui_root)

	# 敵方資訊（左上，儀器面板）
	var enemy_panel := PanelContainer.new()
	enemy_panel.position = Vector2(6, 6)
	enemy_panel.add_theme_stylebox_override("panel", UiTheme.dark_panel_style())
	_ui_root.add_child(enemy_panel)
	var enemy_box := VBoxContainer.new()
	enemy_box.add_theme_constant_override("separation", 2)
	enemy_panel.add_child(enemy_box)
	var enemy_head := HBoxContainer.new()
	enemy_head.add_theme_constant_override("separation", 4)
	enemy_box.add_child(enemy_head)
	var enemy_elem := TextureRect.new()
	enemy_elem.texture = _element_icon(_enemy.element)
	enemy_elem.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	enemy_head.add_child(enemy_elem)
	_enemy_name = Label.new()
	_enemy_name.add_theme_font_size_override("font_size", 12)
	_enemy_name.add_theme_color_override("font_color", Pal.PAPER)
	enemy_head.add_child(_enemy_name)
	_enemy_bar = UiTheme.make_hp_bar(88.0)
	enemy_box.add_child(_enemy_bar["back"])

	# 我方資訊：與指令選單共用右下欄位（訊息列右側），開選單時互換
	_player_panel = PanelContainer.new()
	_player_panel.position = Vector2(208, 132)
	_player_panel.size = Vector2(108, 44)
	_player_panel.add_theme_stylebox_override("panel", UiTheme.dark_panel_style())
	_ui_root.add_child(_player_panel)
	var player_box := VBoxContainer.new()
	player_box.add_theme_constant_override("separation", 2)
	_player_panel.add_child(player_box)
	var player_head := HBoxContainer.new()
	player_head.add_theme_constant_override("separation", 4)
	player_box.add_child(player_head)
	var player_elem := TextureRect.new()
	player_elem.texture = _element_icon(_player.element)
	player_elem.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	player_head.add_child(player_elem)
	_player_name = Label.new()
	_player_name.add_theme_font_size_override("font_size", 12)
	_player_name.add_theme_color_override("font_color", Pal.PAPER)
	player_head.add_child(_player_name)
	_player_bar = UiTheme.make_hp_bar(98.0)
	player_box.add_child(_player_bar["back"])
	_player_hp_text = Label.new()
	_player_hp_text.add_theme_font_size_override("font_size", 12)
	_player_hp_text.add_theme_color_override("font_color", Pal.MIST_LT)
	_player_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	player_box.add_child(_player_hp_text)

	# 訊息面板（手冊紙面）
	var message_panel := PanelContainer.new()
	message_panel.position = Vector2(4, 132)
	message_panel.size = Vector2(200, 44)
	message_panel.add_theme_stylebox_override("panel", UiTheme.panel_style())
	_ui_root.add_child(message_panel)
	_message_label = Label.new()
	_message_label.add_theme_font_size_override("font_size", 12)
	_message_label.add_theme_color_override("font_color", UiTheme.text_color("normal"))
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_panel.add_child(_message_label)
	_more_label = Label.new()
	_more_label.text = "▼"
	_more_label.position = Vector2(190, 162)
	_more_label.add_theme_font_size_override("font_size", 12)
	_more_label.add_theme_color_override("font_color", UiTheme.text_color("accent"))
	_more_label.visible = false
	_ui_root.add_child(_more_label)

	# 指令選單（預設 2×2，技能清單時改直式）
	_menu_panel = PanelContainer.new()
	_menu_panel.position = Vector2(208, 132)
	_menu_panel.size = Vector2(108, 44)
	_menu_panel.add_theme_stylebox_override("panel", UiTheme.panel_style())
	_menu_panel.visible = false
	_ui_root.add_child(_menu_panel)
	_menu_box = GridContainer.new()
	_menu_box.columns = 2
	_menu_box.add_theme_constant_override("v_separation", 1)
	_menu_box.add_theme_constant_override("h_separation", 2)
	_menu_panel.add_child(_menu_box)
