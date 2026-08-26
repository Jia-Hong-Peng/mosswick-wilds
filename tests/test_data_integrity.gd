extends RefCounted
## 資料完整性：無懸空 id、無缺圖、legend 全覆蓋、warp 落點可走。


func run(t: TestContext) -> void:
	DataRegistry.ensure_loaded()
	t.check(DataRegistry.creatures.size() == 3, "應有 3 隻迴靈")
	t.check(DataRegistry.maps.size() == 4, "應有 4 張地圖")
	for creature_id: Variant in DataRegistry.creatures:
		var def: CreatureDef = DataRegistry.get_creature(String(creature_id))
		t.check(def.skill_ids.size() >= 3, "%s 需要一般攻擊加兩種技能" % def.id)
		for skill_id in def.skill_ids:
			t.check(DataRegistry.get_skill(skill_id) != null, "%s 引用了不存在的技能 %s" % [def.id, skill_id])
		for path: String in [def.sprite_path, def.back_path, def.hit_path, def.icon_path]:
			t.check(FileAccess.file_exists(path), "%s 缺少素材：%s" % [def.id, path])
		for stat: String in ["max_hp", "attack", "defense", "speed"]:
			t.check(def.base_stat(stat, -1) > 0, "%s 缺少 base stat %s" % [def.id, stat])
	for item_id: Variant in DataRegistry.items:
		var item: ItemDef = DataRegistry.get_item(String(item_id))
		if not item.icon_path.is_empty():
			t.check(FileAccess.file_exists(item.icon_path), "道具 %s 缺少圖示" % item.id)
	for table_key: Variant in DataRegistry.encounter_tables:
		var table := DataRegistry.get_encounter_table(String(table_key))
		for entry: Variant in Array(table.get("entries", [])):
			var creature_id := String(Dictionary(entry).get("creature_id", ""))
			t.check(DataRegistry.get_creature(creature_id) != null, "遭遇表 %s 引用了不存在的迴靈 %s" % [table_key, creature_id])
	for map_id: Variant in DataRegistry.maps:
		_check_map(t, DataRegistry.get_map(String(map_id)))
	# 古道必須有高草與遭遇表
	var trail: MapData = DataRegistry.get_map("trail")
	var grass_count := 0
	for y in range(trail.height):
		for x in range(trail.width):
			if trail.is_grass(Vector2i(x, y)):
				grass_count += 1
	t.check(grass_count >= 10, "古道高草太少（%d）" % grass_count)
	t.check(not DataRegistry.get_encounter_table(trail.encounter_key).is_empty(), "古道缺遭遇表")


func _check_map(t: TestContext, map: MapData) -> void:
	t.check(map.width > 0 and map.height > 0, "地圖 %s 是空的" % map.id)
	for rows: PackedStringArray in [map.ground_rows, map.deco_rows, map.overhead_rows]:
		for row in rows:
			t.check(row.length() == map.width, "地圖 %s 行寬不齊" % map.id)
	# legend 覆蓋與圖塊存在
	_check_legend(t, map, map.ground_rows, map.legend_ground, "ground", true)
	_check_legend(t, map, map.deco_rows, map.legend_deco, "deco", false)
	_check_legend(t, map, map.overhead_rows, map.legend_overhead, "overhead", false)
	t.check(map.is_walkable(map.spawn_cell()), "地圖 %s 出生點不可走" % map.id)
	for warp_cell: Variant in map.warps:
		var warp := map.warp_at(Vector2i(warp_cell))
		var target: MapData = DataRegistry.get_map(String(warp.get("target_map", "")))
		t.check(target != null, "地圖 %s 的 warp 指向不存在的地圖" % map.id)
		if target != null:
			var target_cell := Vector2i(int(warp.get("target_x", 0)), int(warp.get("target_y", 0)))
			t.check(target.is_walkable(target_cell), "地圖 %s 的 warp 落在 %s 的阻擋格 %s" % [map.id, target.id, str(target_cell)])
	for sign_cell: Variant in map.sign_dialogues:
		var dialogue_id := map.sign_at(Vector2i(sign_cell))
		t.check(not DataRegistry.get_dialogue(dialogue_id).is_empty(), "地圖 %s 的互動點引用不存在的對話 %s" % [map.id, dialogue_id])
	for npc in map.npcs:
		var npc_cell := Vector2i(int(npc.get("x", 0)), int(npc.get("y", 0)))
		t.check(map.is_walkable(npc_cell), "地圖 %s 的 NPC %s 站在阻擋格" % [map.id, npc.get("id", "?")])
		t.check(not DataRegistry.get_dialogue(String(npc.get("dialogue_id", ""))).is_empty(), "地圖 %s 的 NPC %s 對話不存在" % [map.id, npc.get("id", "?")])
		t.check(FileAccess.file_exists(String(npc.get("sprite", ""))), "地圖 %s 的 NPC %s 缺少 sprite" % [map.id, npc.get("id", "?")])


func _check_legend(t: TestContext, map: MapData, rows: PackedStringArray, legend: Dictionary, layer: String, required: bool) -> void:
	var used := {}
	for row in rows:
		for i in range(row.length()):
			used[row[i]] = true
	for symbol: Variant in used:
		var ch := String(symbol)
		if ch == "." and not required:
			continue
		var tile_name := String(legend.get(ch, ""))
		t.check(not tile_name.is_empty(), "地圖 %s 的 %s 層符號 '%s' 缺 legend" % [map.id, layer, ch])
		if not tile_name.is_empty():
			t.check(TileCatalog.has_tile(tile_name), "地圖 %s 引用了不存在的圖塊 %s" % [map.id, tile_name])
