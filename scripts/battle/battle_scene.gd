extends Node3D
## 戰鬥呈現層（2.5D 立體舞台版）。規則仍在 BattleService；
## 3D 舞台由 BattleStage3D 依遭遇地生成；UI 完整沿用（CanvasLayer ×2）。

enum View { EVENTS, COMMAND, SKILLS, ITEMS }

const COMMANDS: Array[String] = ["較勁", "登記", "背包", "離開"]
const CREATURE_PIXEL := 1.0 / 26.0

var _battle: BattleService
var _player: CreatureInstance
var _enemy: CreatureInstance
var _trainer := false          # 較勁對手戰：不能登記、不能離開
var _scripted := ""
var _rng := RandomNumberGenerator.new()

var _view: int = View.EVENTS
var _cursor := 0
var _waiting_confirm := false
var _finished := false
var _running_events := false

var _camera: Camera3D
var _enemy_sprite: Sprite3D
var _player_sprite: Sprite3D
var _enemy_home := Vector3.ZERO
var _player_home := Vector3.ZERO
var _idle_clock := 0.0
var _shake_rng := RandomNumberGenerator.new()

var _canvas: CanvasLayer
var _ui_root: Control
var _message_label: Label
var _more_label: Label
var _menu_panel: PanelContainer
var _menu_box: GridContainer
var _menu_rows: Array[Dictionary] = []
var _player_panel: PanelContainer
var _player_name: Label
var _player_bar: Dictionary
var _player_hp_text: Label
var _enemy_name: Label
var _enemy_bar: Dictionary


func _ready() -> void:
	InputRouter.set_base_context(InputRouter.Context.BATTLE)
	_rng.randomize()
	_shake_rng.randomize()
	var encounter := GameState.pending_encounter
	_trainer = bool(encounter.get("trainer", false))
	_scripted = String(encounter.get("scripted", ""))
	_enemy = DataRegistry.make_creature(String(encounter.get("creature_id", "sproutwing")), int(encounter.get("level", 3)))
	_player = PartyService.first_conscious()
	if _enemy == null or _player == null:
		SceneRouter.goto_world()
		return
	_battle = BattleService.new(_player, _enemy, DataRegistry.skills_for(_enemy), _rng)
	var stage := BattleStage3D.build(self, String(encounter.get("bg", "village")))
	_camera = stage["camera"]
	_player_home = Vector3(stage["player_pos"])
	_enemy_home = Vector3(stage["enemy_pos"])
	_player_sprite = BattleStage3D.make_creature(self, load(_player.back_path), _player_home, CREATURE_PIXEL)
	_enemy_sprite = BattleStage3D.make_creature(self, load(_enemy.sprite_path), _enemy_home, CREATURE_PIXEL, 2)
	_build_ui()
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


# ---------- 選單（沿用） ----------

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


func _layout_menu_grid() -> void:
	_menu_box.columns = 2
	_menu_panel.position = Vector2(208, 132)
	_menu_panel.size = Vector2(108, 44)


func _layout_menu_list() -> void:
	_menu_box.columns = 1
	_menu_panel.position = Vector2(196, 54)
	_menu_panel.size = Vector2(120, 0)


func _add_menu_row(text: String, icon: Texture2D) -> void:
	var row := UiTheme.make_row(text, icon)
	_menu_box.add_child(row["panel"])
	_menu_rows.append(row)


func _element_icon(element: String) -> Texture2D:
	if element in ["grass", "fire", "water", "neutral"]:
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
					_try_register()
				2:
					if _battle_items().is_empty():
						_flash_message("背包裡沒有能用的東西。")
					else:
						AudioManager.play_confirm()
						_view = View.ITEMS
						_cursor = 0
						_refresh_menu()
				3:
					if _trainer:
						_flash_message("較勁中不能中途走人！")
					else:
						_do_action(BattleService.ActionType.FLEE, {})
		View.SKILLS:
			var skills := DataRegistry.skills_for(_player)
			if _cursor < skills.size():
				_do_action(BattleService.ActionType.SKILL, {"skill": skills[_cursor]})
		View.ITEMS:
			var items := _battle_items()
			if _cursor < items.size():
				_do_action(BattleService.ActionType.ITEM, {"item": items[_cursor]})
		_:
			pass


## 登記：出示空白啟用標籤，邀請野生個體同行
func _try_register() -> void:
	if _trainer:
		_flash_message("對手的夥伴已經有啟用標籤了！")
		return
	var tag := DataRegistry.get_item("blank_tag")
	if tag == null or InventoryService.count(tag.id) <= 0:
		_flash_message("沒有空白啟用標籤了。")
		return
	_do_action(BattleService.ActionType.CAPTURE, {"item": tag, "party_full": PartyService.is_full()})


func _do_action(action: int, payload: Dictionary) -> void:
	if _running_events:
		return
	AudioManager.play_confirm()
	_run_events(_battle.take_turn(action, payload))


func _flash_message(text: String) -> void:
	AudioManager.play_bump()
	_message_label.text = text


# ---------- 事件演出（3D） ----------

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
				_message_label.text = event.text
				await _wait_confirm()
			BattleService.EVENT_ENEMY_HP:
				await _apply_hp_event(event, false)
			BattleService.EVENT_PLAYER_HP:
				await _apply_hp_event(event, true)
			BattleService.EVENT_CONSUME_ITEM:
				InventoryService.use_item(String(event.data.get("item_id", "")))
			BattleService.EVENT_CAPTURED:
				await _register_success()
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


func _entry_animation() -> void:
	_enemy_sprite.position.x += 4.0
	_player_sprite.position.x -= 4.0
	_ui_root.modulate.a = 0.0
	var enemy_target := _enemy_home + Vector3(0, _enemy_sprite.position.y - _enemy_home.y, 0)
	var player_target := _player_home + Vector3(0, _player_sprite.position.y - _player_home.y, 0)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_enemy_sprite, "position:x", enemy_target.x, 0.4).set_ease(Tween.EASE_OUT)
	tween.tween_property(_player_sprite, "position:x", player_target.x, 0.4).set_ease(Tween.EASE_OUT)
	tween.tween_property(_ui_root, "modulate:a", 1.0, 0.45)
	await tween.finished
	_enemy_home = _enemy_sprite.position
	_player_home = _player_sprite.position
	_run_events(_battle.intro_events())


func _animate_idle(delta: float) -> void:
	if _enemy_sprite == null:
		return
	_idle_clock += delta
	_enemy_sprite.frame = int(_idle_clock / 0.55) % 2
	_player_sprite.offset.y = 1.0 if fmod(_idle_clock, 1.0) < 0.5 else 0.0


func _lunge(side: String) -> void:
	var sprite := _player_sprite if side == "player" else _enemy_sprite
	var home := _player_home if side == "player" else _enemy_home
	var push := Vector3(0.6, 0, -0.4) if side == "player" else Vector3(-0.6, 0, 0.4)
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
	tween.tween_property(sprite, "position", home - push * 0.35, 0.1)
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
	if not creature.hit_path.is_empty():
		sprite.texture = load(creature.hit_path)
		sprite.hframes = 1
		sprite.frame = 0
	_burst(home + Vector3(0, 1.0, 0), Pal.FOAM)
	var tween := create_tween()
	for i in range(3):
		tween.tween_property(sprite, "position:x", home.x + (0.14 if i % 2 == 0 else -0.14), 0.04)
	tween.tween_property(sprite, "position:x", home.x, 0.04)
	_shake_camera(0.06, 0.14)
	await get_tree().create_timer(0.12).timeout
	sprite.texture = normal_texture
	sprite.hframes = normal_hframes
	await tween.finished


func _shake_camera(strength: float, duration: float) -> void:
	if AudioManager.reduce_shake:
		return
	var steps := int(duration / 0.04)
	var tween := create_tween()
	for i in range(steps):
		tween.tween_property(_camera, "h_offset", _shake_rng.randf_range(-strength, strength), 0.04)
	tween.tween_property(_camera, "h_offset", 0.0, 0.04)


func _burst(at: Vector3, color: Color) -> void:
	var burst := CPUParticles3D.new()
	burst.position = at
	burst.one_shot = true
	burst.emitting = true
	burst.amount = 12 if AudioManager.quality_high else 6
	burst.lifetime = 0.4
	burst.explosiveness = 1.0
	burst.spread = 180.0
	burst.initial_velocity_min = 1.6
	burst.initial_velocity_max = 3.0
	burst.gravity = Vector3(0, -4.0, 0)
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.07, 0.07)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mesh.material = material
	burst.mesh = mesh
	add_child(burst)
	get_tree().create_timer(0.7).timeout.connect(burst.queue_free)


## 勝利經驗值：給出戰的夥伴；回傳結算文字附加段
func _award_exp() -> String:
	var def := DataRegistry.get_creature(_player.creature_id)
	if def == null:
		return ""
	var amount := CreatureInstance.exp_reward(_enemy.level)
	var before := _player.level
	var gained := _player.gain_exp(amount, def)
	var text := "\n%s獲得了 %d 點經驗。" % [_player.display_name, amount]
	if gained > 0:
		AudioManager.play_heal()
		text += "升到了 Lv%d！" % _player.level
		if before < _player.level:
			_refresh_bars(true)
	return text


## 登記成功：啟用標籤光紋＋野生個體走向我方
func _register_success() -> void:
	AudioManager.play_adopt_jingle()
	_burst(_enemy_home + Vector3(0, 1.0, 0), Pal.AMBER_LT)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_enemy_sprite, "position", _enemy_home + Vector3(-1.2, 0, 0.8), 0.8).set_ease(Tween.EASE_OUT)
	tween.tween_property(_enemy_sprite, "modulate", Color(1.0, 0.95, 0.8), 0.8)
	await tween.finished


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
	if _battle.outcome == BattleService.Outcome.FLED:
		SceneRouter.goto_world()
		return
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_style())
	panel.position = Vector2(84, 56)
	panel.custom_minimum_size = Vector2(152, 0)
	_ui_root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var header := Label.new()
	header.text = "── 戰鬥紀錄 ──"
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
			if _scripted == "rival":
				EventFlagStore.set_flag("rival_beaten")
				result.text = "阿汐收回了夥伴：「可惡……默契輸你們一截！」"
			else:
				result.text = "野生的%s退開了，鑽回草叢深處。" % _enemy.display_name
			result.text += _award_exp()
		BattleService.Outcome.CAPTURED:
			result.text = "%s 登記完成！防護已在它身上生效，成為你的旅伴了。" % _enemy.display_name
		BattleService.Outcome.DEFEAT:
			result.text = "你眼前一黑……醒來時已回到A00A 導入前哨站。"
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


# ---------- UI（沿用 v0.3 版面，掛在 ×2 CanvasLayer） ----------

func _build_ui() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 1
	_canvas.scale = Vector2(4, 4)
	add_child(_canvas)
	_ui_root = Control.new()
	_ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_ui_root)

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
