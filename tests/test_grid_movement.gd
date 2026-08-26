extends RefCounted
## Grid movement: walls block, diagonals are rejected, NPCs occupy cells.


func run(t: TestContext) -> void:
	var map := MapData.from_dict("test", {
		"grid": [
			"RRRRR",
			"RGGWR",
			"RGRGR",
			"RGGGR",
			"RRRRR",
		],
	})
	# Free movement onto grass.
	var result := GridMovement.attempt_move(map, Vector2i(1, 1), Vector2i.DOWN)
	t.check(bool(result["moved"]), "should walk onto open grass")
	t.check_eq(Vector2i(result["cell"]), Vector2i(1, 2), "step lands exactly one tile away")
	# Walls and water block.
	t.check(not bool(GridMovement.attempt_move(map, Vector2i(1, 1), Vector2i.UP)["moved"]), "tree row must block")
	t.check(not bool(GridMovement.attempt_move(map, Vector2i(1, 1), Vector2i.LEFT)["moved"]), "left wall must block")
	t.check(not bool(GridMovement.attempt_move(map, Vector2i(2, 1), Vector2i.RIGHT)["moved"]), "water must block")
	t.check(not bool(GridMovement.attempt_move(map, Vector2i(1, 2), Vector2i.RIGHT)["moved"]), "inner tree must block")
	# No diagonal movement ever.
	t.check(not bool(GridMovement.attempt_move(map, Vector2i(1, 1), Vector2i(1, 1))["moved"]), "diagonal must be rejected")
	t.check(not bool(GridMovement.attempt_move(map, Vector2i(1, 1), Vector2i(-1, 1))["moved"]), "diagonal must be rejected")
	t.check(not bool(GridMovement.attempt_move(map, Vector2i(1, 1), Vector2i(0, 2))["moved"]), "multi-tile jumps must be rejected")
	t.check(not bool(GridMovement.attempt_move(map, Vector2i(1, 1), Vector2i.ZERO)["moved"]), "zero direction must be rejected")
	# Occupied cells (NPCs) block.
	var occupied := {Vector2i(1, 2): true}
	t.check(not bool(GridMovement.attempt_move(map, Vector2i(1, 1), Vector2i.DOWN, occupied)["moved"]), "occupied cell must block")
	# Out of bounds is blocked.
	var edge := MapData.from_dict("edge", {"grid": ["GG"]})
	t.check(not bool(GridMovement.attempt_move(edge, Vector2i(0, 0), Vector2i.UP)["moved"]), "map edge must block")
	# A failed move never changes the cell.
	t.check_eq(Vector2i(GridMovement.attempt_move(map, Vector2i(1, 1), Vector2i.UP)["cell"]), Vector2i(1, 1), "blocked move keeps position")
