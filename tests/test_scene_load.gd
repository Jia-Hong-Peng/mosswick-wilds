extends RefCounted
## Every scene file must load and instantiate without missing resources.

const SCENES: Array[String] = [
	"res://scenes/main/title_screen.tscn",
	"res://scenes/world/world_scene.tscn",
	"res://scenes/battle/battle_scene.tscn",
	"res://scenes/battle/crisis_battle_scene.tscn",
	"res://scenes/characters/player.tscn",
	"res://scenes/characters/npc.tscn",
	"res://scenes/ui/dialogue_box.tscn",
	"res://scenes/ui/pause_menu.tscn",
	"res://scenes/ui/touch_controls.tscn",
]


func run(t: TestContext) -> void:
	for path in SCENES:
		var packed: Variant = load(path)
		t.check(packed is PackedScene, "scene failed to load: " + path)
		if packed is PackedScene:
			var scene := packed as PackedScene
			t.check(scene.can_instantiate(), "scene cannot instantiate: " + path)
			var node := scene.instantiate()
			t.check(node != null, "instantiate returned null: " + path)
			if node != null:
				node.free()
