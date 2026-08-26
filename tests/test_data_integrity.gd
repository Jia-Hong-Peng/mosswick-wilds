extends RefCounted
## Cross-references every data file: no dangling ids, sprites, or warps.


func run(t: TestContext) -> void:
	# Autoload _ready() never fires in --script mode; load explicitly.
	DataRegistry.ensure_loaded()
	t.check(DataRegistry.creatures.size() == 3, "expected 3 creatures")
	t.check(DataRegistry.maps.size() == 3, "expected 3 maps")
	for creature_id: Variant in DataRegistry.creatures:
		var def: CreatureDef = DataRegistry.get_creature(String(creature_id))
		t.check(def.skill_ids.size() >= 3, "%s needs a basic attack plus two skills" % def.id)
		for skill_id in def.skill_ids:
			t.check(DataRegistry.get_skill(skill_id) != null, "%s references unknown skill %s" % [def.id, skill_id])
		t.check(FileAccess.file_exists(def.sprite_path), "%s sprite missing: %s" % [def.id, def.sprite_path])
		for stat: String in ["max_hp", "attack", "defense", "speed"]:
			t.check(def.base_stat(stat, -1) > 0, "%s missing base stat %s" % [def.id, stat])
	for table_key: Variant in DataRegistry.encounter_tables:
		var table := DataRegistry.get_encounter_table(String(table_key))
		for entry: Variant in Array(table.get("entries", [])):
			var creature_id := String(Dictionary(entry).get("creature_id", ""))
			t.check(DataRegistry.get_creature(creature_id) != null, "encounter table %s references unknown creature %s" % [table_key, creature_id])
	for map_id: Variant in DataRegistry.maps:
		var map: MapData = DataRegistry.get_map(String(map_id))
		t.check(map.width > 0 and map.height > 0, "map %s is empty" % map.id)
		for row in map.rows:
			t.check(row.length() == map.width, "map %s has ragged rows" % map.id)
		t.check(map.is_walkable(map.spawn_cell()), "map %s spawn is not walkable" % map.id)
		for warp_cell: Variant in map.warps:
			var warp := map.warp_at(Vector2i(warp_cell))
			var target: MapData = DataRegistry.get_map(String(warp.get("target_map", "")))
			t.check(target != null, "map %s warp targets unknown map" % map.id)
			if target != null:
				var target_cell := Vector2i(int(warp.get("target_x", 0)), int(warp.get("target_y", 0)))
				t.check(target.is_walkable(target_cell), "map %s warp lands on blocked tile %s in %s" % [map.id, str(target_cell), target.id])
		for sign_cell: Variant in map.sign_dialogues:
			var dialogue_id := map.sign_at(Vector2i(sign_cell))
			t.check(not DataRegistry.get_dialogue(dialogue_id).is_empty(), "map %s sign references unknown dialogue %s" % [map.id, dialogue_id])
		for npc in map.npcs:
			var npc_cell := Vector2i(int(npc.get("x", 0)), int(npc.get("y", 0)))
			t.check(map.is_walkable(npc_cell), "map %s NPC %s stands on blocked tile" % [map.id, npc.get("id", "?")])
			t.check(not DataRegistry.get_dialogue(String(npc.get("dialogue_id", ""))).is_empty(), "map %s NPC %s has unknown dialogue" % [map.id, npc.get("id", "?")])
			t.check(FileAccess.file_exists(String(npc.get("sprite", ""))), "map %s NPC %s sprite missing" % [map.id, npc.get("id", "?")])
	# The encounter route must actually contain tall grass.
	var route: MapData = DataRegistry.get_map("route")
	var grass_count := 0
	for y in range(route.height):
		for x in range(route.width):
			if route.is_grass(Vector2i(x, y)):
				grass_count += 1
	t.check(grass_count > 0, "route has no tall grass")
	t.check(not DataRegistry.get_encounter_table(route.encounter_key).is_empty(), "route has no encounter table")
