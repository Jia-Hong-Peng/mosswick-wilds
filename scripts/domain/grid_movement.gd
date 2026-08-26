class_name GridMovement
extends RefCounted
## Pure grid movement rules: one tile at a time, cardinal directions only.

const CARDINALS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]


static func is_cardinal(direction: Vector2i) -> bool:
	return direction in CARDINALS


## Attempts a single-tile step. `occupied` maps Vector2i cells that are
## blocked by dynamic entities (NPCs) to anything truthy.
## Returns {"moved": bool, "cell": Vector2i} — cell is the resulting cell.
static func attempt_move(map: MapData, from_cell: Vector2i, direction: Vector2i, occupied: Dictionary = {}) -> Dictionary:
	if not is_cardinal(direction):
		return {"moved": false, "cell": from_cell}
	var target := from_cell + direction
	if not map.is_walkable(target) or occupied.has(target):
		return {"moved": false, "cell": from_cell}
	return {"moved": true, "cell": target}
