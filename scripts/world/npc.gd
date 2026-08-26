extends Node2D
## Stationary NPC. Occupies one grid cell (the world blocks movement into it)
## and starts a dialogue when the player interacts.

const TILE_SIZE := 16

var cell := Vector2i.ZERO
var facing := Vector2i.DOWN
var dialogue_id: String = ""

@onready var _sprite: Sprite2D = $Sprite


## Must be called after the node has entered the tree.
func setup(data: Dictionary) -> void:
	cell = Vector2i(int(data.get("x", 0)), int(data.get("y", 0)))
	facing = Directions.from_name(String(data.get("facing", "down")))
	dialogue_id = String(data.get("dialogue_id", ""))
	var texture_path := String(data.get("sprite", ""))
	if not texture_path.is_empty():
		_sprite.texture = load(texture_path)
	_sprite.hframes = 2
	_sprite.vframes = 4
	position = Vector2(cell * TILE_SIZE) + Vector2(TILE_SIZE, TILE_SIZE) / 2.0
	_update_frame()


func face_towards(other_cell: Vector2i) -> void:
	facing = Directions.towards(cell, other_cell)
	_update_frame()


func _update_frame() -> void:
	_sprite.frame = Directions.row_for(facing) * 2
