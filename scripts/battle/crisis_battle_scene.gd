extends Node3D
## 首戰呈現層（受驚的岩背獾，2.5D 立體舞台版）。規則在 CrisisBattleService；
## 本場景負責：前兆橫幅（不需確認、保持節奏）、姿勢幀切換（縮甲／衝撞／平靜）、
## 三系技能 VFX（葉片弧線／火星炭裂／羽狀水花）、安撫收尾演出、結算轉場。

enum View { EVENTS, COMMAND, SKILLS, ITEMS }

const COMMANDS: Array[String] = ["技能", "安撫", "道具"]
const BOSS_SPRITES := {
	"idle": "res://assets/creatures/rockbadger_front.png",
	"shell": "res://assets/creatures/rockbadger_shell.png",
	"attack": "res://assets/creatures/rockbadger_attack.png",
	"hit": "res://assets/creatures/rockbadger_hit.png",
	"weak": "res://assets/creatures/rockbadger_weak.png",
	"calm": "res://assets/creatures/rockbadger_calm.png",
}
const BOSS_PIXEL := 1.0 / 22.0
const PLAYER_PIXEL := 1.0 / 26.0

var _service: CrisisBattleService
var _player: CreatureInstance
var _boss: CreatureInstance
var _rng := RandomNumberGenerator.new()

var _view: int = View.EVENTS
var _cursor := 0
var _waiting_confirm := false
var _finished := false
var _running := false

var _camera: Camera3D
var _environment: Environment
var _sun: DirectionalLight3D
var _boss_sprite: Sprite3D
var _player_sprite: Sprite3D
var _boss_home := Vector3.ZERO
var _player_home := Vector3.ZERO
var _idle_clock := 0.0

var _telegraph_panel: PanelContainer
var _telegraph_label: Label
var _message_label: Label
var _more_label: Label
var _menu_panel: PanelContainer
var _menu_box: VBoxContainer
var _menu_rows: Array[Dictionary] = []
var _player_panel: PanelContainer
var _player_name: Label
var _player_bar: Dictionary
var _player_hp_text: Label
var _boss_name: Label
var _boss_bar: Dictionary
var _canvas: CanvasLayer
var _ui_root: Control


func _ready() -> void:
	InputRouter.set_base_context(InputRouter.Context.BATTLE)
	_rng.randomize()
	_player = PartyService.first_conscious()
	if _player == null:
		SceneRouter.goto_world()
		return
	_boss = DataRegistry.make_creature("rockbadger", 5)
	_boss.display_name = "岩背獾"
	_boss.max_hp = 80
	_boss.hp = 80
	_boss.attack = 16
	_boss.defense = 14
	_boss.speed = 7
	_service = CrisisBattleService.new(_player, _boss, _rng)
	var stage := BattleStage3D.build(self, "haven")
	_camera = stage["camera"]
	_environment = stage["environment"]
	_sun = stage["sun"]
	_player_home = Vector3(stage["player_pos"])
	_boss_home = Vector3(stage["enemy_pos"])
	_player_sprite = BattleStage3D.make_creature(self, load(_player.back_path), _player_home, PLAYER_PIXEL)
	_boss_sprite = BattleStage3D.make_creature(self, load(BOSS_SPRITES["idle"]), _boss_home, BOSS_PIXEL, 2)
	_build_ui()
	_refresh_bars(false)
	AudioManager.set_ambience("none")
	AudioManager.play_music("boss")
	_entry_animation()


func _process(delta: float) -> void:
	_animate_idle(delta)
	if _finished or _service == null:
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
		AudioManager.play_talk()
		_refresh_menu()
	elif Input.is_action_just_pressed("move_down") and count > 0:
		_cursor = (_cursor + 1) % count
		AudioManager.play_talk()
		_refresh_menu()
	elif Input.is_action_just_pressed("confirm"):
		_activate()
	elif Input.is_action_just_pressed("cancel") and _view != View.COMMAND:
		AudioManager.play_cancel()
		_view = View.COMMAND
		_refresh_menu()


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
		if item != null and item.kind == ItemDef.KIND_HEAL and InventoryService.count(item_id) > 0:
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
					_do_action(CrisisBattleService.Action.SOOTHE, {})
				2:
					if _battle_items().is_empty():
						AudioManager.play_bump()
						_message_label.text = "背包裡沒有能用的東西。"
					else:
						AudioManager.play_confirm()
						_view = View.ITEMS
						_cursor = 0
						_refresh_menu()
		View.SKILLS:
			var skills := DataRegistry.skills_for(_player)
			if _cursor < skills.size():
				_do_action(CrisisBattleService.Action.SKILL, {"skill": skills[_cursor]})
		View.ITEMS:
			var items := _battle_items()
			if _cursor < items.size():
				_do_action(CrisisBattleService.Action.ITEM, {"item": items[_cursor]})
		_:
			pass


func _do_action(action: int, payload: Dictionary) -> void:
	if _running:
		return
	AudioManager.play_confirm()
	if action == CrisisBattleService.Action.ITEM:
		InventoryService.use_item((payload["item"] as ItemDef).id)
	_run_events(_service.take_turn(action, payload))


func _refresh_menu() -> void:
	for child in _menu_box.get_children():
		child.queue_free()
	_menu_rows.clear()
	match _view:
		View.SKILLS:
			for skill in DataRegistry.skills_for(_player):
				var row := UiTheme.make_row(skill.display_name, _element_icon(skill.element))
				_menu_box.add_child(row["panel"])
				_menu_rows.append(row)
			var skills := DataRegistry.skills_for(_player)
			if _cursor < skills.size():
				_message_label.text = skills[_cursor].description
		View.ITEMS:
			for item in _battle_items():
				var row := UiTheme.make_row("%s ×%d" % [item.display_name, InventoryService.count(item.id)], null)
				_menu_box.add_child(row["panel"])
				_menu_rows.append(row)
		_:
			for i in range(COMMANDS.size()):
				var row := UiTheme.make_row(COMMANDS[i], null)
				_menu_box.add_child(row["panel"])
				_menu_rows.append(row)
			# 安撫窗口：恐慌壓到下限時高亮「安撫」
			if _service != null and _service.at_floor():
				UiTheme.set_row_state(_menu_rows[1], "pressed")
	for i in range(_menu_rows.size()):
		if i == _cursor:
			UiTheme.set_row_state(_menu_rows[i], "focus")


func _element_icon(element: String) -> Texture2D:
	if element in ["grass", "fire", "water", "neutral"]:
		return load("res://assets/ui/elem_%s.png" % element)
	return null


# ====== 事件演出 ======

func _run_events(events: Array[BattleService.BattleEvent]) -> void:
	_running = true
	_view = View.EVENTS
	_menu_panel.visible = false
	_player_panel.visible = true
	for event in events:
		if not is_inside_tree():
			return
		match event.kind:
			BattleService.EVENT_MESSAGE:
				await _play_message(event)
			BattleService.EVENT_ENEMY_HP:
				_refresh_bars(true)
				await get_tree().create_timer(0.25).timeout
			BattleService.EVENT_PLAYER_HP:
				if int(event.data.get("damage", 0)) > 0:
					await _player_hit_fx()
				elif int(event.data.get("healed", 0)) > 0:
					AudioManager.play_heal()
				_refresh_bars(true)
				await get_tree().create_timer(0.25).timeout
			BattleService.EVENT_CONSUME_ITEM:
				pass
			BattleService.EVENT_END:
				pass
	_running = false
	if _service.outcome == CrisisBattleService.Outcome.ONGOING:
		_view = View.COMMAND
		_cursor = 0
		_menu_panel.visible = true
		_player_panel.visible = false
		_message_label.text = "%s要怎麼做？" % _player.display_name
		_refresh_menu()
	else:
		await _end_sequence()


func _play_message(event: BattleService.BattleEvent) -> void:
	# 前兆訊息：進橫幅、不需確認，保持戰鬥節奏
	if event.data.has("telegraph"):
		_telegraph_label.text = event.text
		_pulse_telegraph()
		if bool(event.data.get("soothe_ready", false)):
			_telegraph_label.add_theme_color_override("font_color", Pal.FOAM)
		else:
			_telegraph_label.add_theme_color_override("font_color", Pal.CORAL_LT)
		await get_tree().create_timer(0.45).timeout
		return
	if event.data.has("fx"):
		await _play_fx(String(event.data["fx"]))
	if event.data.has("boss_pose"):
		_set_boss_pose(String(event.data["boss_pose"]))
	if String(event.data.get("attacker", "")) == "enemy":
		await _boss_lunge()
	elif String(event.data.get("attacker", "")) == "player":
		await _player_lunge()
	_message_label.text = event.text
	await _wait_confirm()
	if _service.outcome == CrisisBattleService.Outcome.ONGOING and not _service.shelled:
		_set_boss_pose("idle")


func _wait_confirm() -> void:
	_more_label.visible = true
	_waiting_confirm = true
	while _waiting_confirm and is_inside_tree():
		await get_tree().process_frame
	_more_label.visible = false


func _play_fx(fx_name: String) -> void:
	match fx_name:
		"vfx_grass":
			AudioManager.play_skill("grass")
			_burst(_player_home + Vector3(0.6, 1.2, -0.3), Pal.LEAF_LT)
		"vfx_fire":
			AudioManager.play_skill("fire")
			_burst(_player_home + Vector3(0.6, 1.0, -0.3), Pal.AMBER_LT)
		"vfx_water":
			AudioManager.play_skill("water")
			_burst(_player_home + Vector3(0.6, 1.2, -0.3), Pal.SEA_PALE)
		"soothe":
			AudioManager.play_soothe()
			await _soothe_rings()
		_:
			pass


func _set_boss_pose(pose: String) -> void:
	var path := String(BOSS_SPRITES.get(pose, BOSS_SPRITES["idle"]))
	if not ResourceLoader.exists(path):
		return
	_boss_sprite.texture = load(path)
	_boss_sprite.hframes = 2 if pose == "idle" else 1
	_boss_sprite.frame = 0


func _animate_idle(delta: float) -> void:
	if _boss_sprite == null:
		return
	_idle_clock += delta
	if _boss_sprite.hframes == 2:
		var speed := 0.34 if (_service != null and not _service.at_floor()) else 0.6
		_boss_sprite.frame = int(_idle_clock / speed) % 2
	_player_sprite.offset.y = 1.0 if fmod(_idle_clock, 1.0) < 0.5 else 0.0


func _boss_lunge() -> void:
	AudioManager.play_attack()
	_set_boss_pose("attack")
	var home := _boss_sprite.position
	var tween := create_tween()
	tween.tween_property(_boss_sprite, "position", home + Vector3(-0.8, 0, 0.5), 0.1)
	tween.tween_property(_boss_sprite, "position", home, 0.16)
	_shake_camera(0.06, 0.16)
	await tween.finished


func _player_lunge() -> void:
	AudioManager.play_attack()
	var home := _player_sprite.position
	var tween := create_tween()
	tween.tween_property(_player_sprite, "position", home + Vector3(0.6, 0, -0.35), 0.1)
	tween.tween_property(_player_sprite, "position", home, 0.14)
	await tween.finished


func _player_hit_fx() -> void:
	AudioManager.play_hit()
	_shake_camera(0.05, 0.14)
	var home_x := _player_sprite.position.x
	var tween := create_tween()
	for i in range(3):
		tween.tween_property(_player_sprite, "position:x", home_x + (0.12 if i % 2 == 0 else -0.12), 0.04)
	tween.tween_property(_player_sprite, "position:x", home_x, 0.04)
	await tween.finished


func _shake_camera(strength: float, duration: float) -> void:
	if AudioManager.reduce_shake:
		return
	var steps := int(duration / 0.04)
	var tween := create_tween()
	for i in range(steps):
		tween.tween_property(_camera, "h_offset", (strength if i % 2 == 0 else -strength), 0.04)
	tween.tween_property(_camera, "h_offset", 0.0, 0.04)


func _burst(at: Vector3, color: Color) -> void:
	var burst := CPUParticles3D.new()
	burst.position = at
	burst.one_shot = true
	burst.emitting = true
	burst.amount = 14 if AudioManager.quality_high else 7
	burst.lifetime = 0.4
	burst.explosiveness = 1.0
	burst.spread = 180.0
	burst.initial_velocity_min = 1.8
	burst.initial_velocity_max = 3.2
	burst.gravity = Vector3(0, -4.0, 0)
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.08, 0.08)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mesh.material = material
	burst.mesh = mesh
	add_child(burst)
	get_tree().create_timer(0.7).timeout.connect(burst.queue_free)


## 安撫成功：暖色擴散環＋環境回暖＋夥伴走近
func _soothe_rings() -> void:
	_set_boss_pose("weak")
	var warm_tween := create_tween().set_parallel(true)
	warm_tween.tween_property(_environment, "ambient_light_color", Color(0.72, 0.66, 0.55), 1.2)
	warm_tween.tween_property(_sun, "light_color", Color(1.0, 0.9, 0.74), 1.2)
	var approach := create_tween()
	approach.tween_property(_player_sprite, "position", _player_home + Vector3(1.6, 0, -1.1), 1.0).set_ease(Tween.EASE_OUT)
	for i in range(3):
		var ring := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(1.0, 1.0)
		quad.orientation = PlaneMesh.FACE_Y
		ring.mesh = quad
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_texture = load("res://assets/ui/resonance_ring.png")
		material.albedo_color = Pal.alpha(Pal.AMBER_LT, 0.9)
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring.material_override = material
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.position = _boss_home + Vector3(0, 0.06, 0)
		ring.scale = Vector3(0.4, 1.0, 0.4)
		add_child(ring)
		var tween := create_tween().set_parallel(true)
		tween.tween_property(ring, "scale", Vector3(4.2, 1.0, 4.2), 0.7)
		tween.tween_property(material, "albedo_color:a", 0.0, 0.7)
		tween.chain().tween_callback(ring.queue_free)
		await get_tree().create_timer(0.24).timeout
	AudioManager.set_music_layer(false)
	_set_boss_pose("calm")
	await get_tree().create_timer(0.9).timeout


func _refresh_bars(animated: bool) -> void:
	_boss_name.text = "%s（外洩警報）" % _boss.display_name
	_player_name.text = "%s Lv%d" % [_player.display_name, _player.level]
	_player_hp_text.text = "%d / %d" % [_player.hp, _player.max_hp]
	_set_bar(_boss_bar, _boss.hp_ratio(), animated, true)
	_set_bar(_player_bar, _player.hp_ratio(), animated, false)


func _set_bar(bar: Dictionary, ratio: float, animated: bool, is_boss: bool) -> void:
	var fill := bar["fill"] as ColorRect
	var target := maxf(0.0, float(bar["width"]) * ratio)
	fill.color = Pal.CORAL if is_boss else UiTheme.hp_color(ratio)
	if animated:
		var tween := create_tween()
		tween.tween_property(fill, "size:x", target, 0.3).set_ease(Tween.EASE_OUT)
	else:
		fill.size.x = target


# ====== 開場與收尾 ======

func _entry_animation() -> void:
	_boss_sprite.position.x += 4.0
	_player_sprite.position.x -= 4.0
	_ui_root.modulate.a = 0.0
	var boss_target_x := _boss_home.x
	var player_target_x := _player_home.x
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_boss_sprite, "position:x", boss_target_x, 0.4).set_ease(Tween.EASE_OUT)
	tween.tween_property(_player_sprite, "position:x", player_target_x, 0.4).set_ease(Tween.EASE_OUT)
	tween.tween_property(_ui_root, "modulate:a", 1.0, 0.45)
	await tween.finished
	_run_events(_service.intro_events())


func _end_sequence() -> void:
	AudioManager.stop_music()
	if _service.outcome == CrisisBattleService.Outcome.SOOTHED:
		_telegraph_panel.visible = false
		_message_label.text = "岩背獾抬起頭，眼睛裡的驚慌退去了。它輕輕蹭了蹭你夥伴的額頭。"
		await _wait_confirm()
		_finished = true
		EventFlagStore.set_flag("crisis_done")
		EventFlagStore.set_flag("ending_pending")
		GameState.set_world_position("haven", Vector2i(16, 8), Vector2i.LEFT)
		SceneRouter.goto_world()
	else:
		_message_label.text = "你抱著%s退到屋簷下。深呼吸——它需要你們，再試一次。" % _player.display_name
		await _wait_confirm()
		_finished = true
		PartyService.heal_all()
		SceneRouter.goto_crisis()


# ====== 版面（掛在 ×2 CanvasLayer） ======

func _build_ui() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 1
	_canvas.scale = Vector2(4, 4)
	add_child(_canvas)
	_ui_root = Control.new()
	_ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_ui_root)

	# 岩背獾資訊（左上）＋恐慌條（含 30% 安撫線）
	var boss_panel := PanelContainer.new()
	boss_panel.position = Vector2(6, 6)
	boss_panel.add_theme_stylebox_override("panel", UiTheme.dark_panel_style())
	_ui_root.add_child(boss_panel)
	var boss_box := VBoxContainer.new()
	boss_box.add_theme_constant_override("separation", 2)
	boss_panel.add_child(boss_box)
	_boss_name = Label.new()
	_boss_name.add_theme_font_size_override("font_size", 12)
	_boss_name.add_theme_color_override("font_color", Pal.CORAL_LT)
	boss_box.add_child(_boss_name)
	_boss_bar = UiTheme.make_hp_bar(110.0)
	boss_box.add_child(_boss_bar["back"])
	var floor_mark := ColorRect.new()
	floor_mark.color = Pal.FOAM
	floor_mark.position = Vector2(1.0 + float(_boss_bar["width"]) * CrisisBattleService.PANIC_FLOOR_RATIO, 0)
	floor_mark.size = Vector2(1, 6)
	(_boss_bar["back"] as Panel).add_child(floor_mark)
	var boss_tag := Label.new()
	boss_tag.text = "事件等級"
	boss_tag.add_theme_font_size_override("font_size", 12)
	boss_tag.add_theme_color_override("font_color", Pal.MIST_LT)
	boss_box.add_child(boss_tag)

	# 前兆橫幅（左側，避開右側指令清單）
	_telegraph_panel = PanelContainer.new()
	_telegraph_panel.position = Vector2(4, 44)
	_telegraph_panel.custom_minimum_size = Vector2(190, 0)
	_telegraph_panel.add_theme_stylebox_override("panel", UiTheme.name_tag_style())
	_ui_root.add_child(_telegraph_panel)
	_telegraph_label = Label.new()
	_telegraph_label.add_theme_font_size_override("font_size", 12)
	_telegraph_label.add_theme_color_override("font_color", Pal.CORAL_LT)
	_telegraph_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_telegraph_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_telegraph_panel.add_child(_telegraph_label)

	# 我方資訊（訊息列右側）
	_player_panel = PanelContainer.new()
	_player_panel.position = Vector2(208, 132)
	_player_panel.size = Vector2(108, 44)
	_player_panel.add_theme_stylebox_override("panel", UiTheme.dark_panel_style())
	_ui_root.add_child(_player_panel)
	var player_box := VBoxContainer.new()
	player_box.add_theme_constant_override("separation", 2)
	_player_panel.add_child(player_box)
	_player_name = Label.new()
	_player_name.add_theme_font_size_override("font_size", 12)
	_player_name.add_theme_color_override("font_color", Pal.PAPER)
	player_box.add_child(_player_name)
	_player_bar = UiTheme.make_hp_bar(98.0)
	player_box.add_child(_player_bar["back"])
	_player_hp_text = Label.new()
	_player_hp_text.add_theme_font_size_override("font_size", 12)
	_player_hp_text.add_theme_color_override("font_color", Pal.MIST_LT)
	_player_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	player_box.add_child(_player_hp_text)

	# 訊息面板
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

	# 指令清單（右側直式，避開觸控按鍵）
	_menu_panel = PanelContainer.new()
	_menu_panel.position = Vector2(200, 30)
	_menu_panel.custom_minimum_size = Vector2(116, 0)
	_menu_panel.add_theme_stylebox_override("panel", UiTheme.panel_style())
	_menu_panel.visible = false
	_ui_root.add_child(_menu_panel)
	_menu_box = VBoxContainer.new()
	_menu_box.add_theme_constant_override("separation", 1)
	_menu_panel.add_child(_menu_box)


func _pulse_telegraph() -> void:
	_telegraph_panel.modulate.a = 0.4
	var tween := create_tween()
	tween.tween_property(_telegraph_panel, "modulate:a", 1.0, 0.2)
