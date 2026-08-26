extends Node2D
## Builds the current map (from GameState.current_map_id) out of data, hosts
## the player and NPCs, and reacts to arrivals: warps, grass encounters,
## interactions. Owns the in-world UI layer (dialogue box, pause menu).

const TILE_SIZE := 16
## Atlas column per tile symbol; must match tools/generate_placeholders.gd.
const TILE_ORDER := "GTPWRBFIDSM"
const TILESET_PATH := "res://assets/tilesets/overworld.png"

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


func _ready() -> void:
	_rng.randomize()
	_map = DataRegistry.get_map(GameState.current_map_id)
	if _map == null:
		push_error("Unknown map id: " + GameState.current_map_id)
		return
	_build_tiles()
	_spawn_npcs()
	_spawn_player()
	_build_ui()
	_setup_encounters()
	InputRouter.set_base_context(InputRouter.Context.WORLD)


func _process(_delta: float) -> void:
	if InputRouter.is_context(InputRouter.Context.WORLD) and Input.is_action_just_pressed("menu"):
		_pause_menu.open()


func try_step(from_cell: Vector2i, direction: Vector2i) -> Dictionary:
	return GridMovement.attempt_move(_map, from_cell, direction, _npcs_by_cell)


func on_player_arrived(arrived_cell: Vector2i) -> void:
	if _leaving:
		return
	GameState.player_cell = arrived_cell
	var warp := _map.warp_at(arrived_cell)
	if not warp.is_empty():
		_leaving = true
		AudioManager.play_confirm()
		SceneRouter.goto_world_at(
			String(warp.get("target_map", "town")),
			Vector2i(int(warp.get("target_x", 1)), int(warp.get("target_y", 1))),
			Directions.from_name(String(warp.get("facing", "down")))
		)
		return
	if _encounters != null and _map.is_grass(arrived_cell) and PartyService.has_conscious():
		var roll := _encounters.roll_step()
		if not roll.is_empty():
			_leaving = true
			AudioManager.play_hit()
			SceneRouter.goto_battle(roll)


func on_player_interact(target_cell: Vector2i) -> void:
	if DialogueManager.active:
		return
	if _npcs_by_cell.has(target_cell):
		var npc: Node2D = _npcs_by_cell[target_cell]
		npc.face_towards(GameState.player_cell)
		AudioManager.play_confirm()
		DialogueManager.start(npc.dialogue_id)
		return
	var sign_id := _map.sign_at(target_cell)
	if not sign_id.is_empty():
		AudioManager.play_confirm()
		DialogueManager.start(sign_id)


func _build_tiles() -> void:
	var source := TileSetAtlasSource.new()
	source.texture = load(TILESET_PATH)
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for i in range(TILE_ORDER.length()):
		source.create_tile(Vector2i(i, 0))
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tile_set.add_source(source, 0)
	var layer := TileMapLayer.new()
	layer.tile_set = tile_set
	add_child(layer)
	for y in range(_map.height):
		for x in range(_map.width):
			var index := TILE_ORDER.find(_map.tile_at(Vector2i(x, y)))
			layer.set_cell(Vector2i(x, y), 0, Vector2i(maxi(index, 0), 0))


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
	var label := Label.new()
	label.text = _map.display_name
	label.position = Vector2(4, 3)
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	ui_layer.add_child(label)
	var tween := create_tween()
	tween.tween_interval(2.0)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
