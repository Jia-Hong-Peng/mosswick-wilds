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

var starter_id: String = ""          # 第一隻導入的功能（跟隨者與對手戰配對用）
var starter_nickname: String = ""
var nicknames: Dictionary = {}       # creature_id → 暱稱（三隻都可導入、各自命名）


func start_new_game() -> void:
	PartyService.reset()
	InventoryService.reset()
	EventFlagStore.reset()
	starter_id = ""
	starter_nickname = ""
	nicknames = {}
	pending_encounter = {}
	respawn_at_start()


## 正式導入：建立夥伴、套用暱稱、加入隊伍、記錄旗標。
## 三隻御三家（三個功能）都可以先後導入；第一隻成為跟隨者。
func adopt_starter(creature_id: String, nickname: String) -> void:
	var creature := DataRegistry.make_creature(creature_id, STARTER_LEVEL)
	if creature == null:
		return
	var clean := nickname.strip_edges()
	if not clean.is_empty() and clean != creature.display_name:
		creature.display_name = clean
		nicknames[creature_id] = clean
	if starter_id.is_empty():
		starter_id = creature_id
		starter_nickname = String(nicknames.get(creature_id, ""))
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
