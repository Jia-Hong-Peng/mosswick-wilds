extends Node2D
## 依 GameState.current_map_id 從資料建構目前地圖：
## 地面／物件／頂層三層 TileMapLayer（含動畫 tile）、NPC、玩家、
## 炊煙粒子、飄霧層與世界 UI（對話框、選單、地名浮標）。

const TILE_SIZE := 16

const PlayerScene := preload("res://scenes/characters/player.tscn")
const NpcScene := preload("res://scenes/characters/npc.tscn")
const DialogueBoxScene := preload("res://scenes/ui/dialogue_box.tscn")
const PauseMenuScene := preload("res://scenes/ui/pause_menu.tscn")

var _map: MapData
var _npcs_by_cell: Dictionary = {}
var _encounters: EncounterSystem
var _player: Node2D
var _pause_menu: Control
var _rng := RandomNumberGenerator.new()
var _leaving := false
var _fog_sprites: Array[Sprite2D] = []


func _ready() -> void:
	_rng.randomize()
	_map = DataRegistry.get_map(GameState.current_map_id)
	if _map == null:
		push_error("Unknown map id: " + GameState.current_map_id)
		return
	_build_layers()
	_spawn_npcs()
	_spawn_player()
	_spawn_smoke()
	_spawn_fog()
	_build_ui()
	_setup_encounters()
	InputRouter.set_base_context(InputRouter.Context.WORLD)


func _process(delta: float) -> void:
	_drift_fog(delta)
	if InputRouter.is_context(InputRouter.Context.WORLD) and Input.is_action_just_pressed("menu"):
		_pause_menu.open()


func try_step(from_cell: Vector2i, direction: Vector2i) -> Dictionary:
	return GridMovement.attempt_move(_map, from_cell, direction, _npcs_by_cell)


## 玩家腳下地面種類（給腳步聲用）："grass" | "splash" | "hard"
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
		_leaving = true
		AudioManager.play_door()
		SceneRouter.goto_world_at(
			String(warp.get("target_map", "harbor")),
			Vector2i(int(warp.get("target_x", 1)), int(warp.get("target_y", 1))),
			Directions.from_name(String(warp.get("facing", "down")))
		)
		return
	if _encounters != null and _map.is_grass(arrived_cell) and PartyService.has_conscious():
		var roll := _encounters.roll_step()
		if not roll.is_empty():
			_leaving = true
			AudioManager.play_encounter()
			roll["bg"] = _map.battle_bg
			SceneRouter.goto_battle(roll)


func on_player_interact(target_cell: Vector2i) -> void:
	if DialogueManager.active:
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


func _build_layers() -> void:
	var tile_set := _build_tile_set()
	_fill_layer(_make_layer(tile_set), _map.ground_rows, _map.legend_ground, true)
	_fill_layer(_make_layer(tile_set), _map.deco_rows, _map.legend_deco, false)


## 頂層在玩家之後加入（蓋過角色）
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


## 一次性寶物等：旗標成立後不再顯示
func _is_hidden_deco(cell: Vector2i, legend: Dictionary, symbol: String) -> bool:
	if symbol == "." or legend.is_empty():
		return false
	for entry in _map.hidden_deco:
		if int(entry.get("x", -1)) == cell.x and int(entry.get("y", -1)) == cell.y:
			return EventFlagStore.has_flag(String(entry.get("flag", "")))
	return false


func _spawn_npcs() -> void:
	for npc_data in _map.npcs:
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


func _setup_encounters() -> void:
	if _map.encounter_key.is_empty():
		return
	var table := DataRegistry.get_encounter_table(_map.encounter_key)
	if not table.is_empty():
		_encounters = EncounterSystem.new(table, _rng)


func _build_ui() -> void:
	var ui_layer := CanvasLayer.new()
	add_child(ui_layer)
	var dialogue_box: Control = DialogueBoxScene.instantiate()
	ui_layer.add_child(dialogue_box)
	_pause_menu = PauseMenuScene.instantiate()
	ui_layer.add_child(_pause_menu)
	_show_map_name(ui_layer)


func _show_map_name(ui_layer: CanvasLayer) -> void:
	var tag := PanelContainer.new()
	tag.position = Vector2(4, 4)
	tag.add_theme_stylebox_override("panel", UiTheme.name_tag_style())
	var label := Label.new()
	label.text = _map.display_name
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Pal.PAPER)
	tag.add_child(label)
	ui_layer.add_child(tag)
	var tween := create_tween()
	tween.tween_interval(2.2)
	tween.tween_property(tag, "modulate:a", 0.0, 0.6)
