extends Node2D
## 世界場景：三層 TileMap、NPC、玩家、粒子與霧之外，本版加入——
## 回聲觀測模式（去彩度＋線索顯形＋環境音收窄）、地圖觸發器與自動對話、
## 條件 warp、演出 FX（DialogueManager.fx_requested）、關卡結局導演、
## 通關前後的世界狀態差異（色溫／鐘聲／對話變體）。

const TILE_SIZE := 16

const PlayerScene := preload("res://scenes/characters/player.tscn")
const NpcScene := preload("res://scenes/characters/npc.tscn")
const DialogueBoxScene := preload("res://scenes/ui/dialogue_box.tscn")
const PauseMenuScene := preload("res://scenes/ui/pause_menu.tscn")

const OBSERVE_TINT := Color(0.6, 0.72, 0.8)
const RESTORED_TINT := Color(1.0, 0.96, 0.86)
const CLUE_TEXTURES := {
	"tide": "res://assets/ui/clue_tide.png",
	"signal": "res://assets/ui/clue_signal.png",
	"ripple": "res://assets/ui/clue_ripple.png",
}
const CLUES_READY_COUNT := 2

var _map: MapData
var _npcs_by_cell: Dictionary = {}
var _encounters: EncounterSystem
var _player: Node2D
var _pause_menu: Control
var _dialogue_box: Control
var _ui_layer: CanvasLayer
var _rng := RandomNumberGenerator.new()
var _leaving := false
var _fog_sprites: Array[Sprite2D] = []
var _tint: CanvasModulate
var _observing := false
var _clue_sprites: Dictionary = {}
var _clue_clock := 0.0
var _boss_sprite: Sprite2D
var _ending_running := false


func _ready() -> void:
	_rng.randomize()
	_map = DataRegistry.get_map(GameState.current_map_id)
	if _map == null:
		push_error("Unknown map id: " + GameState.current_map_id)
		return
	_tint = CanvasModulate.new()
	_tint.color = _base_tint()
	add_child(_tint)
	_build_layers()
	_spawn_npcs()
	_spawn_player()
	_spawn_smoke()
	_spawn_fog()
	_spawn_clues()
	_spawn_station_extras()
	_build_ui()
	_setup_encounters()
	_apply_ambience()
	InputRouter.set_base_context(InputRouter.Context.WORLD)
	DialogueManager.fx_requested.connect(_on_fx)
	_run_entry_flow.call_deferred()


func _exit_tree() -> void:
	if DialogueManager.fx_requested.is_connected(_on_fx):
		DialogueManager.fx_requested.disconnect(_on_fx)
	AudioManager.set_observe_filter(false)


func _process(delta: float) -> void:
	_drift_fog(delta)
	_animate_clues(delta)
	var walkable_context := InputRouter.is_context(InputRouter.Context.WORLD) or InputRouter.is_context(InputRouter.Context.OBSERVE)
	if walkable_context and Input.is_action_just_pressed("observe"):
		_toggle_observe()
		return
	if InputRouter.is_context(InputRouter.Context.WORLD) and Input.is_action_just_pressed("menu"):
		_pause_menu.open()


# ====== 進場流程與自動對話 ======

func _run_entry_flow() -> void:
	await get_tree().create_timer(0.35).timeout
	if EventFlagStore.has_flag("ending_pending"):
		EventFlagStore.clear_flag("ending_pending")
		await _run_ending()
		return
	for entry in _map.auto_dialogues:
		if not _conditions_met(entry):
			continue
		if entry.has("fire_flag"):
			if EventFlagStore.has_flag(String(entry["fire_flag"])):
				continue
			EventFlagStore.set_flag(String(entry["fire_flag"]))
		DialogueManager.start(String(entry.get("dialogue_id", "")))
		await DialogueManager.dialogue_finished
		if String(entry.get("fire_flag", "")) == "opening_done":
			_show_observe_hint()
		break


func _conditions_met(entry: Dictionary) -> bool:
	if entry.has("if_flag") and not EventFlagStore.has_flag(String(entry["if_flag"])):
		return false
	if entry.has("if_flag_not") and EventFlagStore.has_flag(String(entry["if_flag_not"])):
		return false
	return true


func _show_observe_hint() -> void:
	var tag := PanelContainer.new()
	tag.position = Vector2(96, 56)
	tag.add_theme_stylebox_override("panel", UiTheme.name_tag_style())
	var label := Label.new()
	label.text = "Ｃ／觀測鍵：回聲觀測"
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Pal.FOAM)
	tag.add_child(label)
	_ui_layer.add_child(tag)
	var tween := create_tween()
	tween.tween_interval(2.6)
	tween.tween_property(tag, "modulate:a", 0.0, 0.6)
	tween.tween_callback(tag.queue_free)


# ====== 回聲觀測 ======

func _toggle_observe() -> void:
	_observing = not _observing
	if _observing:
		AudioManager.play_observe_on()
		AudioManager.set_observe_filter(true)
		InputRouter.push_context(InputRouter.Context.OBSERVE)
	else:
		AudioManager.play_observe_off()
		AudioManager.set_observe_filter(false)
		InputRouter.pop_context()
	var tween := create_tween()
	tween.tween_property(_tint, "color", OBSERVE_TINT if _observing else _base_tint(), 0.35)
	for cell: Vector2i in _clue_sprites:
		var sprite := _clue_sprites[cell] as Sprite2D
		sprite.visible = _observing


func _spawn_clues() -> void:
	for clue in _map.clues:
		var cell := Vector2i(int(clue.get("x", 0)), int(clue.get("y", 0)))
		var sprite := Sprite2D.new()
		var texture_path := String(CLUE_TEXTURES.get(String(clue.get("type", "signal")), CLUE_TEXTURES["signal"]))
		sprite.texture = load(texture_path)
		sprite.hframes = 2
		sprite.position = Vector2(cell * TILE_SIZE) + Vector2(8, 8)
		sprite.visible = false
		sprite.z_index = 3
		if EventFlagStore.has_flag(String(clue.get("flag", ""))):
			sprite.modulate.a = 0.4
		add_child(sprite)
		_clue_sprites[cell] = sprite


func _animate_clues(delta: float) -> void:
	if _clue_sprites.is_empty():
		return
	_clue_clock += delta
	var frame := int(_clue_clock / 0.4) % 2
	for cell: Vector2i in _clue_sprites:
		(_clue_sprites[cell] as Sprite2D).frame = frame


func _clue_at(cell: Vector2i) -> Dictionary:
	for clue in _map.clues:
		if int(clue.get("x", -1)) == cell.x and int(clue.get("y", -1)) == cell.y:
			return clue
	return {}


func _examine_clue(clue: Dictionary, cell: Vector2i) -> void:
	AudioManager.play_clue()
	var flag := String(clue.get("flag", ""))
	var newly := not EventFlagStore.has_flag(flag)
	if newly and not flag.is_empty():
		EventFlagStore.set_flag(flag)
		if _clue_sprites.has(cell):
			(_clue_sprites[cell] as Sprite2D).modulate.a = 0.4
	DialogueManager.start(String(clue.get("dialogue_id", "")))
	if newly:
		var count := 0
		for entry in _map.clues:
			if EventFlagStore.has_flag(String(entry.get("flag", ""))):
				count += 1
		if count >= CLUES_READY_COUNT:
			EventFlagStore.set_flag("clues_ready")


# ====== 移動、互動與觸發 ======

func try_step(from_cell: Vector2i, direction: Vector2i) -> Dictionary:
	return GridMovement.attempt_move(_map, from_cell, direction, _npcs_by_cell)


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
	var warp := _map.warp_at(arrived_cell)
	if not warp.is_empty():
		if warp.has("requires_flag") and not EventFlagStore.has_flag(String(warp["requires_flag"])):
			if not DialogueManager.active:
				DialogueManager.start(String(warp.get("blocked_dialogue", "")))
			return
		_leaving = true
		AudioManager.play_door()
		SceneRouter.goto_world_at(
			String(warp.get("target_map", "harbor")),
			Vector2i(int(warp.get("target_x", 1)), int(warp.get("target_y", 1))),
			Directions.from_name(String(warp.get("facing", "down")))
		)
		return
	_fire_triggers(arrived_cell)
	if _encounters != null and _map.is_grass(arrived_cell) and PartyService.has_conscious():
		var roll := _encounters.roll_step()
		if not roll.is_empty():
			_leaving = true
			AudioManager.play_encounter()
			roll["bg"] = _map.battle_bg
			SceneRouter.goto_battle(roll)


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
	if DialogueManager.active:
		return
	if _observing:
		var clue := _clue_at(target_cell)
		if not clue.is_empty():
			_examine_clue(clue, target_cell)
			return
	if _npcs_by_cell.has(target_cell):
		var npc: Node2D = _npcs_by_cell[target_cell]
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
		"station_flash":
			_screen_flash(Pal.FOAM, 0.16)
		"lights_on":
			_fx_lights_on()
		"silence":
			AudioManager.set_ambience("none")
			AudioManager.set_observe_filter(true)
		"gather":
			_fx_gather()
		"boss_reveal":
			_fx_boss_reveal()
		"bell":
			AudioManager.play_bell()
			_screen_flash(Pal.alpha(Pal.AMBER_LT, 0.5), 0.2)
		"quake":
			_shake_world(3.0, 0.4)
		"observe_pulse":
			_fx_observe_pulse()
		_:
			pass


func _screen_flash(color: Color, duration: float) -> void:
	if AudioManager.reduce_flash:
		return
	var flash := ColorRect.new()
	flash.color = color
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui_layer.add_child(flash)
	var tween := create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, duration)
	tween.tween_callback(flash.queue_free)


func _shake_world(strength: float, duration: float) -> void:
	if AudioManager.reduce_shake:
		return
	var steps := int(duration / 0.05)
	var tween := create_tween()
	for i in range(steps):
		tween.tween_property(self, "position", Vector2((strength if i % 2 == 0 else -strength), 0), 0.05)
	tween.tween_property(self, "position", Vector2.ZERO, 0.05)


func _fx_lights_on() -> void:
	AudioManager.play_item()
	var tween := create_tween()
	tween.tween_property(_tint, "color", Color(1.1, 1.02, 0.85), 0.3)
	tween.tween_property(_tint, "color", _base_tint(), 0.5)


func _fx_gather() -> void:
	AudioManager.play_jam()
	_shake_world(2.0, 0.3)
	var burst := CPUParticles2D.new()
	burst.position = Vector2(_map.width * TILE_SIZE / 2.0, _map.height * TILE_SIZE / 2.0)
	burst.one_shot = true
	burst.emitting = true
	burst.amount = 20
	burst.lifetime = 0.6
	burst.explosiveness = 1.0
	burst.spread = 180.0
	burst.initial_velocity_min = 30.0
	burst.initial_velocity_max = 60.0
	burst.color = Pal.GLITCH_LT
	add_child(burst)
	get_tree().create_timer(1.0).timeout.connect(burst.queue_free)


func _fx_boss_reveal() -> void:
	AudioManager.play_encounter()
	if _boss_sprite == null:
		_boss_sprite = Sprite2D.new()
		_boss_sprite.texture = load("res://assets/creatures/magshell_unbalanced.png")
		_boss_sprite.hframes = 2
		add_child(_boss_sprite)
	var center := Vector2(_map.width * TILE_SIZE / 2.0, _map.height * TILE_SIZE / 2.0 - 6.0)
	_boss_sprite.position = center + Vector2(0, -24)
	_boss_sprite.modulate.a = 0.0
	_boss_sprite.visible = true
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_boss_sprite, "position", center, 0.3).set_ease(Tween.EASE_IN)
	tween.tween_property(_boss_sprite, "modulate:a", 1.0, 0.25)
	tween.chain().tween_callback(func() -> void: _shake_world(2.0, 0.25))


func _fx_observe_pulse() -> void:
	AudioManager.play_observe_on()
	var tween := create_tween()
	tween.tween_property(_tint, "color", OBSERVE_TINT, 0.4)
	tween.tween_interval(0.8)
	tween.tween_property(_tint, "color", _base_tint(), 0.5)


# ====== 關卡結局導演 ======

func _run_ending() -> void:
	_ending_running = true
	# 1) 聲音與色彩回歸
	AudioManager.stop_music()
	AudioManager.set_ambience(_map.ambience_restored if _map.ambience_restored != "" else "harbor_restored")
	var tween := create_tween()
	tween.tween_property(_tint, "color", RESTORED_TINT, 1.6)
	await get_tree().create_timer(1.0).timeout
	# 2) 結尾對話（含鐘聲 FX 與「穩定回聲」給予）
	DialogueManager.start("ending_scene")
	await DialogueManager.dialogue_finished
	# 3) 自動存檔
	SaveService.save_game()
	# 4) 章節完成卡
	await _show_chapter_card()
	# 5) 伏筆（黑幕＋訊號）→ 繼續探索／返回標題
	await _show_epilogue()
	_ending_running = false


func _show_chapter_card() -> void:
	InputRouter.push_context(InputRouter.Context.MENU)
	var dim := ColorRect.new()
	dim.color = Pal.alpha(Pal.INK, 0.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui_layer.add_child(dim)
	var card := PanelContainer.new()
	card.position = Vector2(70, 62)
	card.custom_minimum_size = Vector2(180, 0)
	card.add_theme_stylebox_override("panel", UiTheme.panel_style())
	card.modulate.a = 0.0
	_ui_layer.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)
	var chapter := Label.new()
	chapter.text = "第一章：失聲的港灣"
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
	var hint := Label.new()
	hint.text = "Z 繼續"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", UiTheme.text_color("dim"))
	box.add_child(hint)
	AudioManager.play_level_complete()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(dim, "color:a", 0.45, 0.5)
	tween.tween_property(card, "modulate:a", 1.0, 0.5)
	await tween.finished
	await _wait_confirm_press()
	dim.queue_free()
	card.queue_free()
	InputRouter.pop_context()


func _show_epilogue() -> void:
	var black := ColorRect.new()
	black.color = Pal.alpha(Pal.INK, 0.0)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui_layer.add_child(black)
	var tween := create_tween()
	tween.tween_property(black, "color:a", 1.0, 0.8)
	await tween.finished
	# 遠方訊號：珊瑚色斷續閃爍（有節拍——不屬於自然）
	var signal_box := HBoxContainer.new()
	signal_box.position = Vector2(112, 70)
	signal_box.add_theme_constant_override("separation", 6)
	_ui_layer.add_child(signal_box)
	var dots: Array[ColorRect] = []
	for i in range(5):
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(14 if i % 2 == 0 else 8, 4)
		dot.color = Pal.alpha(Pal.CORAL, 0.0)
		signal_box.add_child(dot)
		dots.append(dot)
	var blink := create_tween().set_loops(4)
	for i in range(dots.size()):
		blink.tween_property(dots[i], "color:a", 1.0, 0.08)
		blink.tween_interval(0.08)
	blink.parallel().tween_property(signal_box, "modulate:a", 1.0, 0.1)
	for dot in dots:
		blink.tween_property(dot, "color:a", 0.15, 0.1)
	AudioManager.play_jam()
	# 對話框提到黑幕之上
	_ui_layer.move_child(_dialogue_box, _ui_layer.get_child_count() - 1)
	DialogueManager.start("ending_epilogue")
	await DialogueManager.dialogue_finished
	# 若選擇繼續探索：淡出黑幕回到港口
	if is_inside_tree():
		blink.kill()
		signal_box.queue_free()
		var out := create_tween()
		out.tween_property(black, "color:a", 0.0, 0.8)
		out.tween_callback(black.queue_free)


func _wait_confirm_press() -> void:
	while is_inside_tree():
		await get_tree().process_frame
		if Input.is_action_just_pressed("confirm"):
			AudioManager.play_confirm()
			return


# ====== 建構 ======

func _base_tint() -> Color:
	if EventFlagStore.has_flag("level1_complete") and _map.id == "harbor":
		return RESTORED_TINT
	return Color.WHITE


func _apply_ambience() -> void:
	var profile := _map.ambience
	if EventFlagStore.has_flag("level1_complete") and _map.ambience_restored != "":
		profile = _map.ambience_restored
	AudioManager.set_ambience(profile)


func _build_layers() -> void:
	var tile_set := _build_tile_set()
	_fill_layer(_make_layer(tile_set), _map.ground_rows, _map.legend_ground, true)
	_fill_layer(_make_layer(tile_set), _map.deco_rows, _map.legend_deco, false)


func add_overhead_layer() -> void:
	var tile_set := _build_tile_set()
	_fill_layer(_make_layer(tile_set), _map.overhead_rows, _map.legend_overhead, false)


func _make_layer(tile_set: TileSet) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.tile_set = tile_set
	add_child(layer)
	return layer


func _build_tile_set() -> TileSet:
	var source := TileSetAtlasSource.new()
	source.texture = load(TileCatalog.ATLAS_PATH)
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for tile_name: String in TileCatalog.TILES:
		var pos := TileCatalog.pos(tile_name)
		source.create_tile(pos)
		var frames := TileCatalog.frames(tile_name)
		if frames > 1:
			source.set_tile_animation_columns(pos, frames)
			source.set_tile_animation_frames_count(pos, frames)
			for f in range(frames):
				source.set_tile_animation_frame_duration(pos, f, 1.0 / TileCatalog.fps(tile_name))
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tile_set.add_source(source, 0)
	return tile_set


func _fill_layer(layer: TileMapLayer, rows: PackedStringArray, legend: Dictionary, required: bool) -> void:
	for y in range(rows.size()):
		var row := rows[y]
		for x in range(row.length()):
			var symbol := row[x]
			if symbol == "." and not required:
				continue
			if _is_hidden_deco(Vector2i(x, y), legend, symbol):
				continue
			var tile_name := String(legend.get(symbol, ""))
			if tile_name.is_empty() or not TileCatalog.has_tile(tile_name):
				if required:
					push_warning("Map %s: unknown ground symbol '%s'" % [_map.id, symbol])
				continue
			layer.set_cell(Vector2i(x, y), 0, TileCatalog.pos(tile_name))


func _is_hidden_deco(cell: Vector2i, legend: Dictionary, symbol: String) -> bool:
	if symbol == "." or legend.is_empty():
		return false
	for entry in _map.hidden_deco:
		if int(entry.get("x", -1)) == cell.x and int(entry.get("y", -1)) == cell.y:
			return EventFlagStore.has_flag(String(entry.get("flag", "")))
	return false


func _spawn_npcs() -> void:
	for npc_data in _map.npcs:
		if npc_data.has("if_flag_not") and EventFlagStore.has_flag(String(npc_data["if_flag_not"])):
			continue
		var npc: Node2D = NpcScene.instantiate()
		add_child(npc)
		npc.setup(npc_data)
		_npcs_by_cell[npc.cell] = npc


func _spawn_player() -> void:
	_player = PlayerScene.instantiate()
	add_child(_player)
	_player.setup(self, GameState.player_cell, GameState.player_facing, Vector2i(_map.width, _map.height) * TILE_SIZE)
	add_overhead_layer()


func _spawn_smoke() -> void:
	for cell in _map.smoke_cells:
		var smoke := CPUParticles2D.new()
		smoke.position = Vector2(cell * TILE_SIZE) + Vector2(8, 2)
		smoke.amount = 14
		smoke.lifetime = 3.5
		smoke.direction = Vector2(0.25, -1)
		smoke.spread = 14.0
		smoke.gravity = Vector2(3, -8)
		smoke.initial_velocity_min = 5.0
		smoke.initial_velocity_max = 10.0
		smoke.scale_amount_min = 2.0
		smoke.scale_amount_max = 3.0
		smoke.color = Color(Pal.FOG.r, Pal.FOG.g, Pal.FOG.b, 0.55)
		smoke.z_index = 5
		add_child(smoke)


func _spawn_fog() -> void:
	if not _map.fog:
		return
	var texture: Texture2D = load("res://assets/ui/fog_blob.png")
	for i in range(5):
		var fog := Sprite2D.new()
		fog.texture = texture
		fog.scale = Vector2(3, 3)
		fog.modulate = Color(1, 1, 1, 0.55)
		fog.position = Vector2(
			_rng.randf_range(0, _map.width * TILE_SIZE),
			_rng.randf_range(0, _map.height * TILE_SIZE)
		)
		fog.z_index = 10
		add_child(fog)
		_fog_sprites.append(fog)


func _drift_fog(delta: float) -> void:
	if _fog_sprites.is_empty():
		return
	var map_w := float(_map.width * TILE_SIZE)
	for i in range(_fog_sprites.size()):
		var fog := _fog_sprites[i]
		fog.position.x += delta * (4.0 + float(i) * 1.5)
		if fog.position.x > map_w + 150.0:
			fog.position.x = -150.0


## 觀測站專屬：通關後中央出現「安定的磁殼仔」
func _spawn_station_extras() -> void:
	if _map.id != "tide_station":
		return
	if EventFlagStore.has_flag("level1_complete"):
		var calm := Sprite2D.new()
		calm.texture = load("res://assets/creatures/magshell_calm.png")
		calm.position = Vector2(_map.width * TILE_SIZE / 2.0, _map.height * TILE_SIZE / 2.0 - 6.0)
		add_child(calm)
	elif EventFlagStore.has_flag("station_entered"):
		_fx_boss_reveal.call_deferred()


func _setup_encounters() -> void:
	if _map.encounter_key.is_empty():
		return
	var table := DataRegistry.get_encounter_table(_map.encounter_key)
	if not table.is_empty():
		_encounters = EncounterSystem.new(table, _rng)


func _build_ui() -> void:
	_ui_layer = CanvasLayer.new()
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
