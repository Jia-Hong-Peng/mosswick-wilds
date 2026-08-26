extends RefCounted
## 格狀移動：牆阻擋、禁止斜向、NPC 佔格、warp 格永遠可走。

const LEGEND_GROUND := {"g": "grass_a", "t": "tallgrass", "w": "water_deep", "W": "wall_plank"}
const LEGEND_DECO := {"T": "tree_trunk", "x": "flowers_a", "D": "door_wood"}


func _map() -> MapData:
	return MapData.from_dict("test", {
		"legend_ground": LEGEND_GROUND,
		"legend_deco": LEGEND_DECO,
		"ground": [
			"WWWWW",
			"WggwW",
			"WgtgW",
			"WgggW",
			"WWWWW",
		],
		"deco": [
			".....",
			".....",
			"..T..",
			"...x.",
			"..D..",
		],
		"warps": [ { "x": 2, "y": 4, "target_map": "test", "target_x": 1, "target_y": 1 } ],
	})


func run(t: TestContext) -> void:
	var map := _map()
	# 基本行走
	var result := GridMovement.attempt_move(map, Vector2i(1, 1), Vector2i.DOWN)
	t.check(bool(result["moved"]), "開放草地必須可走")
	t.check_eq(Vector2i(result["cell"]), Vector2i(1, 2), "一步正好一格")
	# 阻擋：牆、深水、物件層
	t.check(not bool(GridMovement.attempt_move(map, Vector2i(1, 1), Vector2i.UP)["moved"]), "牆面必須阻擋")
	t.check(not bool(GridMovement.attempt_move(map, Vector2i(2, 1), Vector2i.RIGHT)["moved"]), "深水必須阻擋")
	t.check(not bool(GridMovement.attempt_move(map, Vector2i(1, 2), Vector2i.RIGHT)["moved"]), "物件層樹幹必須阻擋")
	# 不阻擋的裝飾（花）
	t.check(bool(GridMovement.attempt_move(map, Vector2i(2, 3), Vector2i.RIGHT)["moved"]), "花叢等非阻擋裝飾可以走")
	# warp 格：地面雖是牆列、上面是門，但 warp 永遠可走
	t.check(bool(GridMovement.attempt_move(map, Vector2i(2, 3), Vector2i.DOWN)["moved"]), "有 warp 的門格必須可走")
	# 禁止斜向與跳格
	t.check(not bool(GridMovement.attempt_move(map, Vector2i(1, 1), Vector2i(1, 1))["moved"]), "斜向必須被拒絕")
	t.check(not bool(GridMovement.attempt_move(map, Vector2i(1, 1), Vector2i(-1, 1))["moved"]), "斜向必須被拒絕")
	t.check(not bool(GridMovement.attempt_move(map, Vector2i(1, 1), Vector2i(0, 2))["moved"]), "跳兩格必須被拒絕")
	t.check(not bool(GridMovement.attempt_move(map, Vector2i(1, 1), Vector2i.ZERO)["moved"]), "零向量必須被拒絕")
	# NPC 佔格
	var occupied := {Vector2i(1, 2): true}
	t.check(not bool(GridMovement.attempt_move(map, Vector2i(1, 1), Vector2i.DOWN, occupied)["moved"]), "NPC 佔格必須阻擋")
	# 出界
	var edge := MapData.from_dict("edge", {"legend_ground": LEGEND_GROUND, "ground": ["gg"]})
	t.check(not bool(GridMovement.attempt_move(edge, Vector2i(0, 0), Vector2i.UP)["moved"]), "地圖邊緣必須阻擋")
	# 失敗的移動不改變位置
	t.check_eq(Vector2i(GridMovement.attempt_move(map, Vector2i(1, 1), Vector2i.UP)["cell"]), Vector2i(1, 1), "被擋下時位置不變")
	# 草叢語意
	t.check(map.is_grass(Vector2i(2, 2)), "高草格必須回報 is_grass")
	t.check(not map.is_grass(Vector2i(1, 1)), "普通草地不觸發遭遇")
