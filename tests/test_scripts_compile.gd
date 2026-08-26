extends RefCounted
## Every .gd file in the project must load (parse + compile) cleanly.

const ROOTS: Array[String] = ["res://scripts", "res://tools", "res://tests"]


func run(t: TestContext) -> void:
	var paths: Array[String] = []
	for root in ROOTS:
		_collect(root, paths)
	t.check(paths.size() >= 20, "expected to find at least 20 scripts, found %d" % paths.size())
	for path in paths:
		var script: Variant = load(path)
		t.check(script is GDScript, "script failed to load: " + path)


func _collect(dir_path: String, out_paths: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := dir_path + "/" + entry
		if dir.current_is_dir():
			_collect(full, out_paths)
		elif entry.ends_with(".gd"):
			out_paths.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
