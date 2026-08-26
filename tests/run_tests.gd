extends SceneTree
## Headless test runner. Exits non-zero when any assertion fails.
##
##   godot --headless --path . --script res://tests/run_tests.gd

const TEST_SCRIPTS: Array[String] = [
	"res://tests/test_scripts_compile.gd",
	"res://tests/test_data_integrity.gd",
	"res://tests/test_grid_movement.gd",
	"res://tests/test_damage.gd",
	"res://tests/test_battle.gd",
	"res://tests/test_boss.gd",
	"res://tests/test_demo_flow.gd",
	"res://tests/test_encounter.gd",
	"res://tests/test_inventory.gd",
	"res://tests/test_party.gd",
	"res://tests/test_save.gd",
	"res://tests/test_scene_load.gd",
]


func _initialize() -> void:
	var total_asserts := 0
	var total_failures := 0
	for path in TEST_SCRIPTS:
		var script: GDScript = load(path)
		if script == null:
			total_failures += 1
			print("FAIL  %s (could not load)" % path)
			continue
		var suite: RefCounted = script.new()
		var context := TestContext.new(path)
		suite.run(context)
		if context.assert_count == 0:
			context.failures.append("suite ran zero asserts (aborted by runtime error?)")
		total_asserts += context.assert_count
		total_failures += context.failures.size()
		print("%s  %s (%d asserts)" % ["PASS " if context.failures.is_empty() else "FAIL ", path, context.assert_count])
		for failure in context.failures:
			print("    FAIL: " + failure)
	print("==== %d asserts, %d failures ====" % [total_asserts, total_failures])
	quit(1 if total_failures > 0 else 0)
