class_name Directions
extends RefCounted
## Shared helpers for the four cardinal facings.

const NAME_TO_DIR: Dictionary = {
	"up": Vector2i.UP,
	"down": Vector2i.DOWN,
	"left": Vector2i.LEFT,
	"right": Vector2i.RIGHT,
}


static func from_name(direction_name: String) -> Vector2i:
	return Vector2i(NAME_TO_DIR.get(direction_name, Vector2i.DOWN))


static func to_name(direction: Vector2i) -> String:
	for key: String in NAME_TO_DIR:
		if Vector2i(NAME_TO_DIR[key]) == direction:
			return key
	return "down"


## Row index in the 2x4 character sprite sheets (down, up, left, right).
static func row_for(direction: Vector2i) -> int:
	match direction:
		Vector2i.UP:
			return 1
		Vector2i.LEFT:
			return 2
		Vector2i.RIGHT:
			return 3
		_:
			return 0


## Cardinal direction that best points from one cell toward another.
static func towards(from_cell: Vector2i, to_cell: Vector2i) -> Vector2i:
	var delta := to_cell - from_cell
	if absi(delta.x) >= absi(delta.y):
		return Vector2i.RIGHT if delta.x >= 0 else Vector2i.LEFT
	return Vector2i.DOWN if delta.y >= 0 else Vector2i.UP
