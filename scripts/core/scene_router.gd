extends Node
## Autoload: the only place that switches top-level scenes.

const TITLE_SCENE := "res://scenes/main/title_screen.tscn"
const WORLD_SCENE := "res://scenes/world/world_scene.tscn"
const BATTLE_SCENE := "res://scenes/battle/battle_scene.tscn"


func goto_title() -> void:
	_change(TITLE_SCENE)


## The world scene reads GameState.current_map_id / player_cell on ready.
func goto_world() -> void:
	_change(WORLD_SCENE)


func goto_world_at(map_id: String, cell: Vector2i, facing: Vector2i) -> void:
	GameState.set_world_position(map_id, cell, facing)
	_change(WORLD_SCENE)


## encounter: {"creature_id": String, "level": int}
func goto_battle(encounter: Dictionary) -> void:
	GameState.pending_encounter = encounter
	_change(BATTLE_SCENE)


func _change(path: String) -> void:
	get_tree().change_scene_to_file.call_deferred(path)
