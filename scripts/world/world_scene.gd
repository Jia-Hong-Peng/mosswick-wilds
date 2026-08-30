extends Node3D
## 2.5D 像素立體劇場・世界場景（潮芽伴獸之家）。
## 導演職責：開場運鏡與章節卡、認養流程（互動→確認→儀式→暱稱→入隊）、
## 夥伴跟隨、危機觸發、結局（安撫後的告別、三種結尾小動畫、伏筆、結尾選單）。
## 呈現層：StageBuilder 3D 舞台＋Sprite3D 角色＋方向光/局部暖光＋
## 分層霧面片＋God Ray＋螢幕分級（假移軸／通關暖調）。

const PlayerScene := preload("res://scenes/characters/player.tscn")
const NpcScene := preload("res://scenes/characters/npc.tscn")
const DialogueBoxScene := preload("res://scenes/ui/dialogue_box.tscn")
const PauseMenuScene := preload("res://scenes/ui/pause_menu.tscn")

const MAX_DYNAMIC_LIGHTS := 3
const GATE_CELL := Vector2i(21, 11)

var _map: MapData
var _heights := {}
var _npcs_by_cell: Dictionary = {}
var _player: Node3D
var _follower: Follower3D
var _pause_menu: Control
var _dialogue_box: Control
var _ui_layer: CanvasLayer
var _grade: ScreenGrade
var _rig: CameraRig
var _sun: DirectionalLight3D
var _rng := RandomNumberGenerator.new()
var _leaving := false
var _fog_sprites: Array[Sprite3D] = []
var _ending_running := false
var _ceremony_running := false


func _ready() -> void:
	_rng.randomize()
	_map = DataRegistry.get_map(GameState.current_map_id)
	if _map == null:
		push_error("Unknown map id: " + GameState.current_map_id)
		return
	_build_environment()
	var built := StageBuilder.build(_map, self)
	_heights = built["heights"]
	_place_lights(built["lights"])
	_spawn_npcs()
	_spawn_player()
	_spawn_smoke()
	_spawn_fog()
	_spawn_dust()
	_grade = ScreenGrade.new()
	add_child(_grade)
	_build_ui()
	_apply_ambience()
	_spawn_follower_if_adopted()
	if EventFlagStore.has_flag("chapter_done"):
		_grade.set_warm(1.0, 0.1)
	InputRouter.set_base_context(InputRouter.Context.WORLD)
	DialogueManager.fx_requested.connect(_on_fx)
	DialogueManager.world_action_requested.connect(_on_adopt_requested)
	_run_entry_flow.call_deferred()


func _exit_tree() -> void:
	if DialogueManager.fx_requested.is_connected(_on_fx):
		DialogueManager.fx_requested.disconnect(_on_fx)
	if DialogueManager.world_action_requested.is_connected(_on_adopt_requested):
		DialogueManager.world_action_requested.disconnect(_on_adopt_requested)


func _process(delta: float) -> void:
	_drift_fog(delta)
	if InputRouter.is_context(InputRouter.Context.WORLD) and Input.is_action_just_pressed("menu"):
		_pause_menu.open()


# ====== 環境與光 ======

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# 戲劇光影：環境光壓暗、偏冷海青（陰影帶藍綠），
	# 讓暖色晨光與局部燈火拉出冷暖對比——畫面不得均勻照亮
	env.background_color = Color("9db8b4")
	env.ambient_light_color = Color(0.47, 0.56, 0.58)
	env.ambient_light_energy = 0.78
	env.fog_enabled = true
	env.fog_sky_affect = 0.35
	env.fog_light_color = Color(0.72, 0.8, 0.78)
	env.fog_density = 0.011
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	_sun = DirectionalLight3D.new()
	# 晨光斜射：偏東南（與 ¾ 鏡頭方向一致，南／東面受光）；
	# 仰角略高讓影子不吞掉整個庭院
	_sun.rotation_degrees = Vector3(-52, 26, 0)
	_sun.light_color = Color(1.0, 0.9, 0.72)
	_sun.light_energy = 1.35
	_sun.shadow_enabled = AudioManager.quality_high
	_sun.directional_shadow_max_distance = 40.0
	add_child(_sun)


## 局部暖光：動態燈 ≤3 盞（無陰影），其餘只放光暈面片（假光）
func _place_lights(emitters: Array[Vector3]) -> void:
	var halo_texture: Texture2D = load("res://assets/world3d/light_halo.png")
	for i in range(emitters.size()):
		var at := emitters[i]
		var halo := Sprite3D.new()
		halo.texture = halo_texture
		halo.pixel_size = 1.0 / 24.0
		halo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		halo.shaded = false
		halo.position = at
		add_child(halo)
		if i < MAX_DYNAMIC_LIGHTS:
			var light := OmniLight3D.new()
			light.light_color = Color(1.0, 0.72, 0.38)
			light.light_energy = 1.9
			light.omni_range = 4.2
			light.shadow_enabled = false
			light.position = at
			add_child(light)


# ====== 進場流程 ======

func _run_entry_flow() -> void:
	await get_tree().create_timer(0.3).timeout
	if EventFlagStore.has_flag("ending_pending"):
		EventFlagStore.clear_flag("ending_pending")
		await _run_ending()
		return
	if not EventFlagStore.has_flag("opening_done"):
		await _run_opening_pan()
	for entry in _map.auto_dialogues:
		if not _conditions_met(entry):
			continue
		if entry.has("fire_flag"):
			if EventFlagStore.has_flag(String(entry["fire_flag"])):
				continue
			EventFlagStore.set_flag(String(entry["fire_flag"]))
		DialogueManager.start(String(entry.get("dialogue_id", "")))
		await DialogueManager.dialogue_finished
		break


## 開場運鏡（0:00–0:20）：港口晨光 → 認養庭院掠過三個活動區 → 玩家。
## 章節卡浮現；按確認可隨時跳過。
func _run_opening_pan() -> void:
	InputRouter.push_context(InputRouter.Context.MENU)
	var marker := Node3D.new()
	add_child(marker)
	marker.position = Vector3(11.5, 0, 13.5)
	_rig.follow_speed = 1.6
	_rig.retarget(marker)
	_rig.jump_to(marker.position)
	# 章節卡
	var card := VBoxContainer.new()
	card.position = Vector2(96, 60)
	card.add_theme_constant_override("separation", 4)
	_ui_layer.add_child(card)
	var title := Label.new()
	title.text = "潮 森 群 島"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size = Vector2(128, 0)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Pal.PAPER)
	title.add_theme_color_override("font_shadow_color", Pal.alpha(Pal.INK, 0.8))
	title.add_theme_constant_override("shadow_offset_x", 1)
	title.add_theme_constant_override("shadow_offset_y", 1)
	card.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "第一章：第一次導入"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.custom_minimum_size = Vector2(128, 0)
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Pal.FOAM)
	subtitle.add_theme_color_override("font_shadow_color", Pal.alpha(Pal.INK, 0.8))
	subtitle.add_theme_constant_override("shadow_offset_x", 1)
	subtitle.add_theme_constant_override("shadow_offset_y", 1)
	card.add_child(subtitle)
	card.modulate.a = 0.0
	var card_tween := create_tween()
	card_tween.tween_property(card, "modulate:a", 1.0, 0.8)
	card_tween.tween_interval(2.6)
	card_tween.tween_property(card, "modulate:a", 0.0, 0.8)
	# 運鏡：碼頭 → 三個活動區 → 玩家
	var waypoints: Array[Vector3] = [
		Vector3(3.5, 0, 6.0),
		Vector3(15.0, 0, 6.0),
		Vector3(20.0, 0, 6.5),
	]
	var elapsed := 0.0
	var waypoint_index := 0
	marker.position = waypoints[0]
	while elapsed < 7.0 and is_inside_tree():
		await get_tree().process_frame
		var delta := get_process_delta_time()
		elapsed += delta
		if elapsed > 2.2 * float(waypoint_index + 1) and waypoint_index < waypoints.size() - 1:
			waypoint_index += 1
			marker.position = waypoints[waypoint_index]
		if Input.is_action_just_pressed("confirm"):
			break
	card_tween.kill()
	card.queue_free()
	marker.queue_free()
	_rig.retarget(_player)
	_rig.follow_speed = 7.0
	InputRouter.pop_context()
	await get_tree().create_timer(0.4).timeout


func _conditions_met(entry: Dictionary) -> bool:
	if entry.has("if_flag") and not EventFlagStore.has_flag(String(entry["if_flag"])):
		return false
	if entry.has("if_flag_not") and EventFlagStore.has_flag(String(entry["if_flag_not"])):
		return false
	return true


# ====== 認養儀式 ======

func _on_adopt_requested(starter_id: String) -> void:
	if _ceremony_running:
		return
	_run_adoption(starter_id)


func _run_adoption(starter_id: String) -> void:
	_ceremony_running = true
	InputRouter.push_context(InputRouter.Context.MENU)
	var starter := DataRegistry.get_starter(starter_id)
	var pen := Dictionary(starter.get("pen_cell", {}))
	var pen_cell := Vector2i(int(pen.get("x", 0)), int(pen.get("y", 0)))
	var pen_npc: Node3D = _npcs_by_cell.get(pen_cell)
	# 1) 葵姨確認＋認養證
	DialogueManager.start("ceremony_" + starter_id)
	await DialogueManager.dialogue_finished
	# 2) 幼獸主動走向玩家（小跳兩下＋叫聲）
	AudioManager.play_cry(starter_id)
	if pen_npc != null:
		var tween := create_tween()
		for i in range(2):
			tween.tween_property(pen_npc, "position:y", pen_npc.position.y + 0.28, 0.14)
			tween.tween_property(pen_npc, "position:y", pen_npc.position.y, 0.12)
		await tween.finished
	# 3) 旅伴牌
	DialogueManager.start("ceremony_tag_" + starter_id)
	await DialogueManager.dialogue_finished
	# 4) 暱稱（可保留原名）
	var nickname := await _ask_nickname(String(starter.get("display_name", "")))
	# 5) 正式入隊＋自動存檔
	GameState.adopt_starter(starter_id, nickname)
	AudioManager.play_adopt_jingle()
	_grade.flash(0.4, 0.35)
	var celebrate_at := Vector3(float(pen_cell.x) + 0.5, height_of(pen_cell) + 0.8, float(pen_cell.y) + 0.5)
	_burst_3d(celebrate_at, _starter_color(starter_id))
	if pen_npc != null:
		_npcs_by_cell.erase(pen_cell)
		pen_npc.queue_free()
	_spawn_follower(starter_id, pen_cell)
	SaveService.save_game()
	var newest: CreatureInstance = PartyService.members.back()
	_show_toast("%s 導入完成，加入了你的隊伍！（已自動記錄）" % newest.display_name)
	InputRouter.pop_context()
	_ceremony_running = false


func _ask_nickname(default_name: String) -> String:
	InputRouter.push_context(InputRouter.Context.MENU)
	var panel := PanelContainer.new()
	panel.position = Vector2(78, 58)
	panel.custom_minimum_size = Vector2(164, 0)
	panel.add_theme_stylebox_override("panel", UiTheme.panel_style())
	_ui_layer.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var prompt := Label.new()
	prompt.text = "要幫「%s」取個暱稱嗎？" % default_name
	prompt.add_theme_font_size_override("font_size", 12)
	prompt.add_theme_color_override("font_color", UiTheme.text_color("normal"))
	box.add_child(prompt)
	var line := LineEdit.new()
	line.placeholder_text = default_name
	line.max_length = 8
	line.add_theme_font_size_override("font_size", 12)
	box.add_child(line)
	var hint := Label.new()
	hint.text = "Enter 確定　Esc 保留原名"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", UiTheme.text_color("dim"))
	box.add_child(hint)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(buttons)
	var keep := Button.new()
	keep.text = "保留原名"
	keep.add_theme_font_size_override("font_size", 12)
	buttons.add_child(keep)
	var ok := Button.new()
	ok.text = "確定"
	ok.add_theme_font_size_override("font_size", 12)
	buttons.add_child(ok)
	line.grab_focus()
	var result: Array[String] = []
	line.text_submitted.connect(func(text: String) -> void: result.append(text))
	ok.pressed.connect(func() -> void: result.append(line.text))
	keep.pressed.connect(func() -> void: result.append(""))
	while result.is_empty() and is_inside_tree():
		await get_tree().process_frame
		if Input.is_action_just_pressed("cancel"):
			result.append("")
	panel.queue_free()
	InputRouter.pop_context()
	AudioManager.play_confirm()
	return result[0] if not result.is_empty() else ""


func _starter_color(starter_id: String) -> Color:
	match starter_id:
		"sproutwing":
			return Pal.LEAF_LT
		"emberhorn":
			return Pal.AMBER_LT
		_:
			return Pal.SEA_PALE


func _spawn_follower_if_adopted() -> void:
	if GameState.starter_id.is_empty() or not EventFlagStore.has_flag("starter_chosen"):
		return
	var beside := GameState.player_cell + Vector2i(0, 1)
	if not is_cell_free(beside):
		beside = GameState.player_cell + Vector2i(-1, 0)
	if not is_cell_free(beside):
		beside = GameState.player_cell + Vector2i(1, 0)
	_spawn_follower(GameState.starter_id, beside)


func _spawn_follower(starter_id: String, at_cell: Vector2i) -> void:
	if _follower != null:
		return
	_follower = Follower3D.new()
	add_child(_follower)
	_follower.setup(self, _player, starter_id, at_cell)


func _show_toast(text: String) -> void:
	var tag := PanelContainer.new()
	tag.position = Vector2(70, 20)
	tag.add_theme_stylebox_override("panel", UiTheme.name_tag_style())
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Pal.FOAM)
	tag.add_child(label)
	_ui_layer.add_child(tag)
	var tween := create_tween()
	tween.tween_interval(2.4)
	tween.tween_property(tag, "modulate:a", 0.0, 0.6)
	tween.tween_callback(tag.queue_free)


# ====== 移動、互動與觸發 ======

## 夥伴不阻擋玩家（可穿越；重疊時夥伴會自己讓開）——
## 否則牠停在圍欄缺口等窄路時會把玩家關在外面。
func try_step(from_cell: Vector2i, direction: Vector2i) -> Dictionary:
	return GridMovement.attempt_move(_map, from_cell, direction, _npcs_by_cell)


## 跟隨者尋路用：這一格可不可以站（含 NPC 阻擋，不含玩家）。
func is_cell_free(target: Vector2i) -> bool:
	if not _map.in_bounds(target) or not _map.is_walkable(target):
		return false
	return not _npcs_by_cell.has(target)


func height_of(cell: Vector2i) -> float:
	return StageBuilder.height_at(_heights, cell)


func ground_kind_at(cell: Vector2i) -> String:
	if _map.is_splash(cell):
		return "splash"
	var ground := _map.ground_name(cell)
	if ground.begins_with("grass") or ground == "tallgrass" or ground == "dirt":
		return "grass"
	return "hard"


func on_player_arrived(arrived_cell: Vector2i) -> void:
	if _leaving:
		return
	GameState.player_cell = arrived_cell
	if _ending_running or _ceremony_running:
		return
	var warp := _map.warp_at(arrived_cell)
	if not warp.is_empty():
		if warp.has("requires_flag") and not EventFlagStore.has_flag(String(warp["requires_flag"])):
			if not DialogueManager.active:
				DialogueManager.start(String(warp.get("blocked_dialogue", "")))
			return
		_leaving = true
		AudioManager.play_door()
		SceneRouter.goto_world_at(
			String(warp.get("target_map", "haven")),
			Vector2i(int(warp.get("target_x", 1)), int(warp.get("target_y", 1))),
			Directions.from_name(String(warp.get("facing", "down")))
		)
		return
	_fire_triggers(arrived_cell)


func _fire_triggers(cell: Vector2i) -> void:
	if DialogueManager.active:
		return
	for trigger in _map.triggers:
		if int(trigger.get("x", -1)) != cell.x or int(trigger.get("y", -1)) != cell.y:
			continue
		if not _conditions_met(trigger):
			continue
		if trigger.has("fire_flag"):
			if EventFlagStore.has_flag(String(trigger["fire_flag"])):
				continue
			EventFlagStore.set_flag(String(trigger["fire_flag"]))
		DialogueManager.start(String(trigger.get("dialogue_id", "")))
		return


func on_player_interact(target_cell: Vector2i) -> void:
	if DialogueManager.active or _ceremony_running or _ending_running:
		return
	if _follower != null and _follower.cell == target_cell:
		_follower.face_towards(GameState.player_cell)
		_follower.hop()
		AudioManager.play_talk()
		DialogueManager.start("partner_talk")
		return
	if _npcs_by_cell.has(target_cell):
		var npc: Node3D = _npcs_by_cell[target_cell]
		npc.face_towards(GameState.player_cell)
		AudioManager.play_talk()
		DialogueManager.start(npc.dialogue_id)
		return
	var sign_id := _map.sign_at(target_cell)
	if not sign_id.is_empty():
		AudioManager.play_talk()
		DialogueManager.start(sign_id)


# ====== 演出 FX ======

func _on_fx(fx_name: String) -> void:
	match fx_name:
		"crash":
			AudioManager.play_crash()
			_rig.shake(4.0, 0.5)
		"tag_flash":
			AudioManager.play_item()
			_grade.flash(0.45, 0.3)
		"cry_sproutwing", "cry_emberhorn", "cry_tidecrest":
			AudioManager.play_cry(fx_name.trim_prefix("cry_"))
		"quake":
			_rig.shake(3.0, 0.4)
		_:
			pass


func _burst_3d(at: Vector3, color: Color) -> void:
	var burst := CPUParticles3D.new()
	burst.position = at
	burst.one_shot = true
	burst.emitting = true
	burst.amount = 16 if AudioManager.quality_high else 8
	burst.lifetime = 0.6
	burst.explosiveness = 1.0
	burst.direction = Vector3.UP
	burst.spread = 70.0
	burst.initial_velocity_min = 1.5
	burst.initial_velocity_max = 3.0
	burst.gravity = Vector3(0, -2.0, 0)
	burst.mesh = _particle_mesh(color)
	add_child(burst)
	get_tree().create_timer(1.2).timeout.connect(burst.queue_free)


func _particle_mesh(color: Color) -> QuadMesh:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.06, 0.06)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mesh.material = material
	return mesh


# ====== 關卡結局導演 ======

func _run_ending() -> void:
	_ending_running = true
	InputRouter.push_context(InputRouter.Context.MENU)
	AudioManager.stop_music()
	_apply_ambience()
	await get_tree().create_timer(0.8).timeout
	# 1) 岩背獾平靜離場
	var badger := Sprite3D.new()
	badger.texture = load("res://assets/creatures/rockbadger_calm.png")
	badger.pixel_size = 1.0 / 30.0
	badger.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	badger.shaded = true
	badger.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	badger.position = Vector3(7.5, height_of(Vector2i(7, 8)) + 0.7, 8.5)
	add_child(badger)
	DialogueManager.start("ending_calm")
	await DialogueManager.dialogue_finished
	var leave_tween := create_tween().set_parallel(true)
	leave_tween.tween_property(badger, "position", Vector3(1.0, badger.position.y, 4.0), 2.4)
	leave_tween.tween_property(badger, "modulate:a", 0.0, 2.4)
	leave_tween.chain().tween_callback(badger.queue_free)
	await get_tree().create_timer(1.4).timeout
	# 2) 葵姨檢查夥伴＋依個性反應
	if _follower != null:
		_follower.hop()
	DialogueManager.start("ending_check")
	await DialogueManager.dialogue_finished
	# 3) 旅行證與地圖、閘門開啟
	DialogueManager.start("ending_farewell")
	await DialogueManager.dialogue_finished
	EventFlagStore.set_flag("chapter_done")
	_grade.set_warm(1.0, 1.8)
	AudioManager.play_bell()
	SaveService.save_game()
	# 4) 走向港口道（夥伴依個性同行）
	await _ending_walk()
	# 5) 鏡頭拉遠：港口與下一座島嶼
	var marker := Node3D.new()
	add_child(marker)
	marker.position = Vector3(14.0, 0, 13.0)
	_rig.follow_speed = 1.8
	_rig.retarget(marker)
	_rig.set_zoom(11.0, 2.2)
	DialogueManager.start("ending_last_words")
	await DialogueManager.dialogue_finished
	await get_tree().create_timer(0.8).timeout
	# 6) 章節卡＋認養結果
	AudioManager.play_level_complete()
	await _show_chapter_card()
	# 7) 伏筆：公告板上的失蹤啟事（5 秒、不解釋、切黑）
	await _show_teaser()
	# 8) 結尾選單
	marker.queue_free()
	_rig.retarget(_player)
	_rig.follow_speed = 7.0
	_rig.set_zoom(8.8, 0.5)
	await _show_end_menu()
	_ending_running = false
	InputRouter.pop_context()


## 玩家與夥伴走向閘門；三隻御三家有不同的同行演出。
func _ending_walk() -> void:
	if _follower != null:
		_follower.scripted = true
	var variant := ""
	if _follower != null:
		variant = String(DataRegistry.get_starter(_follower.starter_id).get("ending_variant", ""))
	match variant:
		"glide":
			# 芽翼鼯：跳上玩家肩膀展開葉翼，一起走
			AudioManager.play_cry("sproutwing")
			var tween := create_tween().set_parallel(true)
			tween.tween_property(_follower, "position", _player.position + Vector3(0, 0.9, 0), 0.5).set_ease(Tween.EASE_IN)
			tween.tween_property(_follower, "scale", Vector3(0.7, 0.7, 0.7), 0.5)
			await tween.finished
			_burst_3d(_player.position + Vector3(0, 1.2, 0), Pal.LEAF_LT)
			_follower.visible = false
		"torch":
			# 燼角羌：走在玩家前方，角上的火光映亮道路
			AudioManager.play_cry("emberhorn")
			var glow := OmniLight3D.new()
			glow.light_color = Color(1.0, 0.62, 0.3)
			glow.light_energy = 0.0
			glow.omni_range = 3.2
			_follower.add_child(glow)
			var tween := create_tween()
			tween.tween_property(glow, "light_energy", 1.6, 1.0)
		"chase":
			AudioManager.play_cry("tidecrest")
	# 導演步行：回到大路（列 8）→ 向東到閘門 → 南下到港口道
	await _walk_player_to(Vector2i(GATE_CELL.x, 8))
	await _walk_player_to(Vector2i(GATE_CELL.x, 12))
	if _follower != null and variant == "chase":
		# 潮冠鷺：叼著地圖搶先跑出閘門，玩家追上
		for i in range(2):
			_follower.scripted_step(Vector2i.RIGHT)
			while _follower.is_moving():
				await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout


func _walk_player_to(target: Vector2i) -> void:
	var guard := 0
	while GameState.player_cell != target and guard < 64 and is_inside_tree():
		guard += 1
		var diff := target - GameState.player_cell
		var dir := Vector2i(signi(diff.x), 0) if diff.x != 0 else Vector2i(0, signi(diff.y))
		if not _player.force_step(dir):
			# 夥伴擋路：等牠停下、請牠讓開一步，再走
			var retries := 0
			while retries < 5 and _follower != null and _follower.cell == GameState.player_cell + dir:
				retries += 1
				while _follower.is_moving():
					await get_tree().process_frame
				for side: Vector2i in [Vector2i(dir.y, dir.x), Vector2i(-dir.y, -dir.x), dir]:
					if _follower.scripted_step(side):
						break
				while _follower != null and _follower.is_moving():
					await get_tree().process_frame
			if not _player.force_step(dir):
				break
		while _player.is_moving():
			await get_tree().process_frame
		if _follower != null and _follower.visible:
			var follower_gap: Vector2i = GameState.player_cell - _follower.cell
			if absi(follower_gap.x) + absi(follower_gap.y) > 1:
				var step := Vector2i(signi(follower_gap.x), 0) if follower_gap.x != 0 else Vector2i(0, signi(follower_gap.y))
				_follower.scripted_step(step)


func _show_chapter_card() -> void:
	var dim := ColorRect.new()
	dim.color = Pal.alpha(Pal.INK, 0.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui_layer.add_child(dim)
	var card := PanelContainer.new()
	card.position = Vector2(70, 56)
	card.custom_minimum_size = Vector2(180, 0)
	card.add_theme_stylebox_override("panel", UiTheme.panel_style())
	card.modulate.a = 0.0
	_ui_layer.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)
	var chapter := Label.new()
	chapter.text = "第一章：第一次導入"
	chapter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chapter.add_theme_font_size_override("font_size", 14)
	chapter.add_theme_color_override("font_color", UiTheme.text_color("header"))
	box.add_child(chapter)
	var done := Label.new()
	done.text = "完　成"
	done.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	done.add_theme_font_size_override("font_size", 14)
	done.add_theme_color_override("font_color", UiTheme.text_color("accent"))
	box.add_child(done)
	var adopted_names: Array[String] = []
	for starter_check in DataRegistry.starter_ids():
		if EventFlagStore.has_flag("adopted_" + starter_check):
			adopted_names.append(String(DataRegistry.get_starter(starter_check).get("display_name", "")))
	var adopted := Label.new()
	adopted.text = "已導入：%s" % "・".join(adopted_names)
	adopted.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	adopted.add_theme_font_size_override("font_size", 12)
	adopted.add_theme_color_override("font_color", UiTheme.text_color("normal"))
	box.add_child(adopted)
	var hint := Label.new()
	hint.text = "Z 繼續"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", UiTheme.text_color("dim"))
	box.add_child(hint)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(dim, "color:a", 0.45, 0.5)
	tween.tween_property(card, "modulate:a", 1.0, 0.5)
	await tween.finished
	await _wait_confirm_press()
	dim.queue_free()
	card.queue_free()


func _show_teaser() -> void:
	var black := ColorRect.new()
	black.color = Pal.alpha(Pal.INK, 0.0)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui_layer.add_child(black)
	var fade_in := create_tween()
	fade_in.tween_property(black, "color:a", 1.0, 0.8)
	await fade_in.finished
	# 公告板特寫：被雨水暈開的失蹤啟事，只剩一雙不同顏色的眼睛
	var paper := PanelContainer.new()
	paper.position = Vector2(104, 44)
	paper.custom_minimum_size = Vector2(112, 0)
	paper.add_theme_stylebox_override("panel", UiTheme.panel_style())
	paper.modulate.a = 0.0
	_ui_layer.add_child(paper)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	paper.add_child(box)
	var head := Label.new()
	head.text = "【尋】失蹤伴獸"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 12)
	head.add_theme_color_override("font_color", UiTheme.text_color("header"))
	box.add_child(head)
	var photo := Panel.new()
	photo.custom_minimum_size = Vector2(96, 42)
	var photo_style := StyleBoxFlat.new()
	photo_style.bg_color = Pal.alpha(Pal.SLATE, 0.5)
	photo.add_theme_stylebox_override("panel", photo_style)
	box.add_child(photo)
	var eye_left := ColorRect.new()
	eye_left.color = Pal.alpha(Pal.AMBER_LT, 0.0)
	eye_left.position = Vector2(32, 18)
	eye_left.size = Vector2(6, 4)
	photo.add_child(eye_left)
	var eye_right := ColorRect.new()
	eye_right.color = Pal.alpha(Pal.SEA_PALE, 0.0)
	eye_right.position = Vector2(56, 18)
	eye_right.size = Vector2(6, 4)
	photo.add_child(eye_right)
	var note := Label.new()
	note.text = "……字被雨水暈開了。"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 12)
	note.add_theme_color_override("font_color", UiTheme.text_color("dim"))
	box.add_child(note)
	var show_tween := create_tween()
	show_tween.tween_property(paper, "modulate:a", 1.0, 0.7)
	show_tween.tween_interval(0.9)
	show_tween.tween_property(eye_left, "color:a", 0.9, 0.5)
	show_tween.parallel().tween_property(eye_right, "color:a", 0.9, 0.5)
	AudioManager.play_jam()
	await show_tween.finished
	await get_tree().create_timer(2.4).timeout
	var out := create_tween()
	out.tween_property(paper, "modulate:a", 0.0, 0.7)
	await out.finished
	paper.queue_free()
	black.set_meta("keep", true)
	_teaser_black = black


var _teaser_black: ColorRect


func _show_end_menu() -> void:
	var options: Array[String] = ["繼續探索", "重新選擇夥伴", "返回標題"]
	var panel := PanelContainer.new()
	panel.position = Vector2(96, 60)
	panel.custom_minimum_size = Vector2(128, 0)
	panel.add_theme_stylebox_override("panel", UiTheme.panel_style())
	_ui_layer.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	var rows: Array[Dictionary] = []
	for text in options:
		var row := UiTheme.make_row(text, null)
		box.add_child(row["panel"])
		rows.append(row)
	var cursor := 0
	var chosen := -1
	while chosen < 0 and is_inside_tree():
		for i in range(rows.size()):
			UiTheme.set_row_state(rows[i], "focus" if i == cursor else "normal")
		await get_tree().process_frame
		if Input.is_action_just_pressed("move_up"):
			cursor = (cursor - 1 + options.size()) % options.size()
			AudioManager.play_talk()
		elif Input.is_action_just_pressed("move_down"):
			cursor = (cursor + 1) % options.size()
			AudioManager.play_talk()
		elif Input.is_action_just_pressed("confirm"):
			AudioManager.play_confirm()
			chosen = cursor
	panel.queue_free()
	match chosen:
		0:
			# 繼續探索：燈亮回來，自由走動；夥伴解除導演模式、回到玩家身邊
			if _follower != null:
				_follower.scripted = false
				var gap: Vector2i = GameState.player_cell - _follower.cell
				if not _follower.visible or absi(gap.x) + absi(gap.y) > 2:
					for dir: Vector2i in [Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP]:
						if is_cell_free(GameState.player_cell + dir):
							_follower.place_at(GameState.player_cell + dir)
							break
			if _teaser_black != null:
				var out := create_tween()
				out.tween_property(_teaser_black, "color:a", 0.0, 0.8)
				out.tween_callback(_teaser_black.queue_free)
		1:
			# 重新選擇夥伴：從認養日重新開始（跳過開場運鏡）
			GameState.start_new_game()
			EventFlagStore.set_flag("opening_done")
			SceneRouter.goto_world()
		2:
			SceneRouter.goto_title()


func _wait_confirm_press() -> void:
	while is_inside_tree():
		await get_tree().process_frame
		if Input.is_action_just_pressed("confirm"):
			AudioManager.play_confirm()
			return


# ====== 建構 ======

func _apply_ambience() -> void:
	AudioManager.set_ambience(_map.ambience)


func _spawn_npcs() -> void:
	for npc_data in _map.npcs:
		if npc_data.has("if_flag_not") and EventFlagStore.has_flag(String(npc_data["if_flag_not"])):
			continue
		var npc: Node3D = NpcScene.instantiate()
		add_child(npc)
		npc.setup(self, npc_data)
		_npcs_by_cell[npc.cell] = npc


func _spawn_player() -> void:
	_player = PlayerScene.instantiate()
	add_child(_player)
	_player.setup(self, GameState.player_cell, GameState.player_facing)
	_rig = CameraRig.new()
	add_child(_rig)
	_rig.setup(_player, Vector2(float(_map.width), float(_map.height)))
	_spawn_foreground_occluders()


## 前景框景：鏡頭角落掛預先模糊的葉片（假性移軸的「近前景柔焦」層）。
## 掛在攝影機上、不阻礙操作；Low 品質不放。
func _spawn_foreground_occluders() -> void:
	if not AudioManager.quality_high:
		return
	var texture: Texture2D = load("res://assets/world3d/foreground_leaves.png")
	for i in range(2):
		var leaves := Sprite3D.new()
		leaves.texture = texture
		# 正交鏡頭下距離不縮小——尺寸要小、只露出畫面角落一角
		leaves.pixel_size = 1.0 / 26.0
		leaves.shaded = false
		leaves.modulate = Color(1, 1, 1, 0.5)
		leaves.flip_h = i == 1
		leaves.position = Vector3(-7.4 if i == 0 else 7.4, -4.4, -2.5)
		leaves.rotation_degrees.z = 14.0 if i == 0 else -14.0
		_rig.camera.add_child(leaves)
		var sway := create_tween().set_loops()
		sway.tween_property(leaves, "rotation_degrees:z", (14.0 if i == 0 else -14.0) + 1.5, 2.8).set_trans(Tween.TRANS_SINE)
		sway.tween_property(leaves, "rotation_degrees:z", (14.0 if i == 0 else -14.0) - 1.5, 2.8).set_trans(Tween.TRANS_SINE)


## 金色光塵：晨光裡緩慢漂浮的微粒（High 品質）
func _spawn_dust() -> void:
	if not AudioManager.quality_high:
		return
	var dust := CPUParticles3D.new()
	dust.amount = 26
	dust.lifetime = 7.0
	dust.preprocess = 7.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(float(_map.width) * 0.5, 1.6, float(_map.height) * 0.5)
	dust.position = Vector3(float(_map.width) * 0.5, 1.8, float(_map.height) * 0.5)
	dust.direction = Vector3(0.3, 0.15, 0)
	dust.spread = 20.0
	dust.gravity = Vector3.ZERO
	dust.initial_velocity_min = 0.08
	dust.initial_velocity_max = 0.2
	dust.mesh = _particle_mesh(Color(1.0, 0.88, 0.6, 0.5))
	add_child(dust)


func _spawn_smoke() -> void:
	for cell in _map.smoke_cells:
		var smoke := CPUParticles3D.new()
		smoke.position = Vector3(float(cell.x) + 0.5, 2.7 + float(_map.elevation(cell)) * StageBuilder.LEVEL_H, float(cell.y) + 0.5)
		smoke.amount = 8 if AudioManager.quality_high else 4
		smoke.lifetime = 4.5
		smoke.preprocess = 2.0
		smoke.direction = Vector3(0.15, 1, 0)
		smoke.spread = 16.0
		smoke.gravity = Vector3(0.12, 0.2, 0)
		smoke.initial_velocity_min = 0.15
		smoke.initial_velocity_max = 0.3
		# 柔霧點（大而淡），避免在天空上讀成虛線刮痕
		var mesh := QuadMesh.new()
		mesh.size = Vector2(0.22, 0.22)
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(Pal.FOG.r, Pal.FOG.g, Pal.FOG.b, 0.3)
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mesh.material = material
		smoke.mesh = mesh
		add_child(smoke)


func _spawn_fog() -> void:
	var fog_texture: Texture2D = load("res://assets/ui/fog_blob.png")
	var count := 3 if AudioManager.quality_high else 2
	for i in range(count):
		var fog := Sprite3D.new()
		fog.texture = fog_texture
		fog.pixel_size = 1.0 / 12.0
		fog.shaded = false
		fog.modulate = Color(1, 1, 1, 0.3)
		fog.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		fog.position = Vector3(
			_rng.randf_range(0, float(_map.width)),
			0.5 + 0.35 * float(i % 3),
			_rng.randf_range(0, float(_map.height)))
		fog.set_meta("speed", 0.25 + float(i) * 0.1)
		add_child(fog)
		_fog_sprites.append(fog)


func _drift_fog(delta: float) -> void:
	if _fog_sprites.is_empty():
		return
	var map_w := float(_map.width)
	for fog in _fog_sprites:
		fog.position.x += delta * float(fog.get_meta("speed"))
		if fog.position.x > map_w + 6.0:
			fog.position.x = -6.0


func _build_ui() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 1
	_ui_layer.scale = Vector2(4, 4)
	add_child(_ui_layer)
	_dialogue_box = DialogueBoxScene.instantiate()
	_ui_layer.add_child(_dialogue_box)
	_pause_menu = PauseMenuScene.instantiate()
	_ui_layer.add_child(_pause_menu)
	_show_map_name()


func _show_map_name() -> void:
	var tag := PanelContainer.new()
	tag.position = Vector2(4, 4)
	tag.add_theme_stylebox_override("panel", UiTheme.name_tag_style())
	var label := Label.new()
	label.text = _map.display_name
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Pal.PAPER)
	tag.add_child(label)
	_ui_layer.add_child(tag)
	var tween := create_tween()
	tween.tween_interval(2.2)
	tween.tween_property(tag, "modulate:a", 0.0, 0.6)
