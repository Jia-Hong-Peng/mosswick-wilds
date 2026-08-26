extends Node
## Autoload: cross-scene session state (where the player is, pending battle).
## Persistent data lives in the dedicated services; this node only tracks
## the world position and hands battle parameters between scenes.

const START_MAP_ID := "town"
const STARTER_CREATURE_ID := "peatpaw"
const STARTER_LEVEL := 5

var current_map_id: String = START_MAP_ID
var player_cell: Vector2i = Vector2i(9, 6)
var player_facing: Vector2i = Vector2i.DOWN
var pending_encounter: Dictionary = {}


func start_new_game() -> void:
	PartyService.reset()
	InventoryService.reset()
	EventFlagStore.reset()
	PartyService.add_member(DataRegistry.make_creature(STARTER_CREATURE_ID, STARTER_LEVEL))
	InventoryService.add_item("berry_tonic", 3)
	InventoryService.add_item("snare_orb", 2)
	pending_encounter = {}
	respawn_at_start()


func respawn_at_start() -> void:
	current_map_id = START_MAP_ID
	var map := DataRegistry.get_map(START_MAP_ID)
	if map != null:
		player_cell = map.spawn_cell()
		player_facing = map.spawn_facing()


func set_world_position(map_id: String, cell: Vector2i, facing: Vector2i) -> void:
	current_map_id = map_id
	player_cell = cell
	player_facing = facing
