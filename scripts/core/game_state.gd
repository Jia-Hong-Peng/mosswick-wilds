extends Node
## Autoload: cross-scene session state (where the player is, pending battle).
## Persistent data lives in the dedicated services; this node tracks the
## world position, the adopted starter, and hands battle parameters between scenes.

const START_MAP_ID := "haven"
const STARTER_LEVEL := 5

var current_map_id: String = START_MAP_ID
var player_cell: Vector2i = Vector2i(10, 3)
var player_facing: Vector2i = Vector2i.DOWN
var pending_encounter: Dictionary = {}

var starter_id: String = ""
var starter_nickname: String = ""


func start_new_game() -> void:
	PartyService.reset()
	InventoryService.reset()
	EventFlagStore.reset()
	starter_id = ""
	starter_nickname = ""
	pending_encounter = {}
	respawn_at_start()


## 正式認養：建立夥伴、套用暱稱、加入隊伍、記錄旗標。
func adopt_starter(creature_id: String, nickname: String) -> void:
	starter_id = creature_id
	var creature := DataRegistry.make_creature(creature_id, STARTER_LEVEL)
	if creature == null:
		return
	starter_nickname = nickname.strip_edges()
	if not starter_nickname.is_empty() and starter_nickname != creature.display_name:
		creature.display_name = starter_nickname
	else:
		starter_nickname = ""
	PartyService.add_member(creature)
	InventoryService.add_item("travel_tag", 1)
	EventFlagStore.set_flag("starter_chosen")
	EventFlagStore.set_flag("adopted_" + creature_id)


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
