extends RefCounted
## 資料完整性：伴獸／技能／道具／御三家設定／地圖／對話劇本／
## 素材檔案之間的參照全部互相成立（不會在執行期才發現斷鏈）。

const ELEMENTS: Array[String] = ["grass", "fire", "water", "neutral"]
const EFFECTS: Array[String] = ["", "slow", "shield", "break", "warm", "dodge", "cleanse"]
const FX_WHITELIST: Array[String] = [
	"crash", "tag_flash", "quake",
	"cry_sproutwing", "cry_emberhorn", "cry_tidecrest",
	"vfx_grass", "vfx_fire", "vfx_water", "soothe",
]
const ACTION_WHITELIST: Array[String] = [
	"", "heal_party", "start_crisis", "rival_battle", "return_title", "continue_explore",
	"adopt_sproutwing", "adopt_emberhorn", "adopt_tidecrest",
]


func run(t: TestContext) -> void:
	DataRegistry.ensure_loaded()
	_test_creatures(t)
	_test_skills(t)
	_test_items(t)
	_test_starters(t)
	_test_map(t)
	_test_dialogues(t)
	_test_ui_assets(t)


func _test_creatures(t: TestContext) -> void:
	t.check_eq(DataRegistry.creatures.size(), 4, "伴獸共 4 隻（御三家＋岩背獾）")
	for creature_id: String in ["sproutwing", "emberhorn", "tidecrest", "rockbadger"]:
		var def := DataRegistry.get_creature(creature_id)
		t.check(def != null, "伴獸存在：" + creature_id)
		if def == null:
			continue
		t.check(not def.display_name.is_empty(), creature_id + " 有名字")
		t.check(def.element in ELEMENTS, creature_id + " 屬性合法")
		t.check(def.skill_ids.size() >= 1, creature_id + " 至少一招")
		for skill_id in def.skill_ids:
			t.check(DataRegistry.get_skill(skill_id) != null, "%s 的技能 %s 存在" % [creature_id, skill_id])
		for path: String in [def.sprite_path, def.back_path, def.hit_path, def.icon_path]:
			t.check(FileAccess.file_exists(path), "%s 圖檔存在：%s" % [creature_id, path])
		# 姿勢幀
		for pose: String in ["antic", "attack", "weak", "calm"]:
			t.check(FileAccess.file_exists("res://assets/creatures/%s_%s.png" % [creature_id, pose]),
				"%s 姿勢幀存在：%s" % [creature_id, pose])
		var creature := DataRegistry.make_creature(creature_id, 5)
		t.check(creature != null and creature.max_hp > 0, creature_id + " 可實例化")
	# 御三家世界行走圖；岩背獾縮甲幀
	for starter_id: String in ["sproutwing", "emberhorn", "tidecrest"]:
		t.check(FileAccess.file_exists("res://assets/creatures/%s_world.png" % starter_id), starter_id + " 有世界行走圖")
	t.check(FileAccess.file_exists("res://assets/creatures/rockbadger_shell.png"), "岩背獾有縮甲幀")
	# 屬性循環：草克水、水克火、火克草
	t.check(DamageCalculator.effectiveness("grass", "water") > 1.0, "草克水")
	t.check(DamageCalculator.effectiveness("water", "fire") > 1.0, "水克火")
	t.check(DamageCalculator.effectiveness("fire", "grass") > 1.0, "火克草")
	t.check(DamageCalculator.effectiveness("water", "grass") < 1.0, "被剋減傷")


func _test_skills(t: TestContext) -> void:
	for skill_id: Variant in DataRegistry.skills:
		var skill := DataRegistry.get_skill(String(skill_id))
		t.check(not skill.display_name.is_empty(), String(skill_id) + " 有名字")
		t.check(skill.element in ELEMENTS, String(skill_id) + " 屬性合法")
		t.check(skill.effect in EFFECTS, String(skill_id) + " 效果合法")
		t.check(skill.power > 0 or not skill.effect.is_empty(), String(skill_id) + " 要嘛有威力要嘛有效果")
		t.check(not skill.description.is_empty(), String(skill_id) + " 有描述")
	# 每隻御三家：一招攻擊＋兩招輔助／混合，三套路線互不相同
	for starter_id: String in ["sproutwing", "emberhorn", "tidecrest"]:
		var creature := DataRegistry.make_creature(starter_id, 5)
		var skills := DataRegistry.skills_for(creature)
		t.check_eq(skills.size(), 3, starter_id + " 有三招")
		var has_attack := false
		var has_effect := false
		for skill in skills:
			if skill.power > 0 and skill.effect.is_empty():
				has_attack = true
			if not skill.effect.is_empty():
				has_effect = true
		t.check(has_attack, starter_id + " 有純攻擊技")
		t.check(has_effect, starter_id + " 有輔助效果技")


func _test_items(t: TestContext) -> void:
	for item_id: Variant in DataRegistry.items:
		var item := DataRegistry.get_item(String(item_id))
		t.check(not item.display_name.is_empty(), String(item_id) + " 有名字")
		t.check(FileAccess.file_exists(item.icon_path), String(item_id) + " 圖示存在")
	t.check(DataRegistry.get_item("herbal_balm") != null, "青草膏存在")
	t.check(DataRegistry.get_item("travel_pack") != null, "旅行包存在")
	t.check(DataRegistry.get_item("travel_tag") != null, "旅伴牌存在")
	t.check(DataRegistry.get_item("echo_box") == null, "回聲道具不得殘留")


func _test_starters(t: TestContext) -> void:
	var ids := DataRegistry.starter_ids()
	t.check_eq(ids.size(), 3, "御三家三隻")
	var map := DataRegistry.get_map("haven")
	var behaviors := {}
	var variants := {}
	for starter_id in ids:
		var starter := DataRegistry.get_starter(starter_id)
		t.check(DataRegistry.get_creature(starter_id) != null, starter_id + " 對應伴獸存在")
		t.check_eq(String(starter.get("element", "")), DataRegistry.get_creature(starter_id).element, starter_id + " 屬性一致")
		t.check(Array(starter.get("battle_keywords", [])).size() == 2, starter_id + " 兩個戰鬥關鍵字")
		t.check(not String(starter.get("personality", "")).is_empty(), starter_id + " 有性格描述")
		behaviors[String(starter.get("follow_behavior", ""))] = true
		variants[String(starter.get("ending_variant", ""))] = true
		# 圍欄位置對得上地圖 NPC
		var pen := Dictionary(starter.get("pen_cell", {}))
		var pen_cell := Vector2i(int(pen.get("x", -1)), int(pen.get("y", -1)))
		var found := false
		for npc in map.npcs:
			if String(npc.get("id", "")) == "pen_" + starter_id:
				found = Vector2i(int(npc.get("x", -2)), int(npc.get("y", -2))) == pen_cell
				t.check_eq(String(npc.get("if_flag_not", "")), "adopted_" + starter_id, starter_id + " 認養後欄位空出")
		t.check(found, starter_id + " 的圍欄位置與地圖 NPC 一致")
		# 六表情立繪
		for expr: String in ["neutral", "curious", "happy", "nervous", "determined", "hurt"]:
			t.check(FileAccess.file_exists("res://assets/portraits/%s_%s.png" % [starter_id, expr]),
				"%s 立繪存在：%s" % [starter_id, expr])
	t.check_eq(behaviors.size(), 3, "三種跟隨個性互不相同")
	t.check_eq(variants.size(), 3, "三種結尾動畫互不相同")


func _test_map(t: TestContext) -> void:
	t.check(DataRegistry.maps.size() >= 2, "至少有認養之家與潮風小徑兩張地圖")
	t.check(DataRegistry.get_map("haven") != null, "haven 地圖存在")
	t.check(DataRegistry.get_map("shoreline") != null, "shoreline 地圖存在")
	for map_id: Variant in DataRegistry.maps:
		_check_one_map(t, String(map_id))
	# 認養互動點的鄰格要可以站人（玩家能靠近）
	var haven := DataRegistry.get_map("haven")
	for starter_id in DataRegistry.starter_ids():
		var pen := Dictionary(DataRegistry.get_starter(starter_id).get("pen_cell", {}))
		var pen_cell := Vector2i(int(pen.get("x", 0)), int(pen.get("y", 0)))
		var reachable := false
		for offset: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if haven.is_walkable(pen_cell + offset):
				reachable = true
		t.check(reachable, starter_id + " 的圍欄可被玩家靠近")


func _check_one_map(t: TestContext, map_id: String) -> void:
	var map := DataRegistry.get_map(map_id)
	var raw := DataRegistry.read_json_dict("res://data/maps/%s.json" % map_id)
	var width := map.width
	var height := map.height
	t.check(width > 0 and height > 0, map_id + " 尺寸有效")
	# 三層網格與 elevation 尺寸一致、字元都有對應
	for layer_key: String in ["ground", "deco", "overhead", "elevation"]:
		var rows := Array(raw.get(layer_key, []))
		t.check_eq(rows.size(), height, "%s %s 列數一致" % [map_id, layer_key])
		for row: Variant in rows:
			t.check_eq(String(row).length(), width, "%s %s 每列 %d 字" % [map_id, layer_key, width])
	var ground_legend := Dictionary(raw.get("legend_ground", {}))
	for row: Variant in Array(raw.get("ground", [])):
		for ch in String(row):
			t.check(ground_legend.has(ch), "%s ground 字元有圖例：%s" % [map_id, ch])
	var deco_legend := Dictionary(raw.get("legend_deco", {}))
	for row: Variant in Array(raw.get("deco", [])):
		for ch in String(row):
			t.check(ch == "." or deco_legend.has(ch), "%s deco 字元有圖例：%s" % [map_id, ch])
	for key: Variant in ground_legend:
		t.check(TileCatalog.has_tile(String(ground_legend[key])), "圖集有磚：" + String(ground_legend[key]))
	for key: Variant in deco_legend:
		t.check(TileCatalog.has_tile(String(deco_legend[key])), "圖集有磚：" + String(deco_legend[key]))
	# 出生點可走、NPC／告示／觸發合法
	t.check(map.is_walkable(map.spawn_cell()), map_id + " 出生點可走")
	for npc in map.npcs:
		var cell := Vector2i(int(npc.get("x", -1)), int(npc.get("y", -1)))
		t.check(map.in_bounds(cell), "%s NPC 在界內：%s" % [map_id, String(npc.get("id", ""))])
		t.check(FileAccess.file_exists(String(npc.get("sprite", ""))), "NPC 圖檔存在：" + String(npc.get("sprite", "")))
		t.check(not DataRegistry.get_dialogue(String(npc.get("dialogue_id", ""))).is_empty(), "NPC 對話存在：" + String(npc.get("dialogue_id", "")))
	for sign_cell: Variant in map.sign_dialogues:
		t.check(not DataRegistry.get_dialogue(String(map.sign_dialogues[sign_cell])).is_empty(), map_id + " 告示對話存在")
	for trigger in map.triggers:
		t.check(not DataRegistry.get_dialogue(String(trigger.get("dialogue_id", ""))).is_empty(), map_id + " 觸發對話存在")
	for entry in map.auto_dialogues:
		t.check(not DataRegistry.get_dialogue(String(entry.get("dialogue_id", ""))).is_empty(), map_id + " 自動對話存在")
	# warp：目標地圖存在、落點可走；封鎖對話存在
	for warp_cell: Variant in map.warps:
		var warp := Dictionary(map.warps[warp_cell])
		var target := DataRegistry.get_map(String(warp.get("target_map", "")))
		t.check(target != null, "%s warp 目標地圖存在" % map_id)
		if target != null:
			var landing := Vector2i(int(warp.get("target_x", -1)), int(warp.get("target_y", -1)))
			t.check(target.is_walkable(landing), "%s warp 落點可走 %s" % [map_id, str(landing)])
		if warp.has("blocked_dialogue"):
			t.check(not DataRegistry.get_dialogue(String(warp["blocked_dialogue"])).is_empty(), map_id + " warp 封鎖對話存在")
	# 遭遇表：鍵存在、生物有效、等級範圍合法
	if not map.encounter_key.is_empty():
		var table := DataRegistry.get_encounter_table(map.encounter_key)
		t.check(not table.is_empty(), map_id + " 遭遇表存在")
		for entry: Variant in Array(table.get("entries", [])):
			var data := Dictionary(entry)
			t.check(DataRegistry.get_creature(String(data.get("creature_id", ""))) != null,
				"遭遇表生物存在：" + String(data.get("creature_id", "")))
			t.check(int(data.get("min_level", 1)) <= int(data.get("max_level", 1)), "遭遇等級範圍合法")


func _test_dialogues(t: TestContext) -> void:
	# 必要對話全部存在
	for dialogue_id: String in [
		"opening_haven", "npc_kui",
		"pen_sproutwing", "pen_emberhorn", "pen_tidecrest",
		"ceremony_sproutwing", "ceremony_emberhorn", "ceremony_tidecrest",
		"ceremony_tag_sproutwing", "ceremony_tag_emberhorn", "ceremony_tag_tidecrest",
		"partner_talk", "yard_gate",
		"ending_calm", "ending_check", "ending_farewell", "ending_last_words",
		"board_notice",
	]:
		t.check(not DataRegistry.get_dialogue(dialogue_id).is_empty(), "對話存在：" + dialogue_id)
	# 每一頁：文字、立繪與 FX 參照都成立；動作都在白名單
	var total_pages := 0
	for dialogue_id: Variant in DataRegistry.dialogues:
		var entry := DataRegistry.get_dialogue(String(dialogue_id))
		var variants: Array = entry.get("variants", [entry])
		for variant: Variant in variants:
			var data := Dictionary(variant)
			for page: Variant in Array(data.get("pages", [])):
				total_pages += 1
				_check_page(t, String(dialogue_id), Dictionary(page))
			var choice := Dictionary(data.get("choice", {}))
			if not choice.is_empty():
				var options := Array(choice.get("options", []))
				t.check(options.size() >= 1, String(dialogue_id) + " 選項至少一個")
				for option: Variant in options:
					var option_data := Dictionary(option)
					t.check(String(option_data.get("action", "")) in ACTION_WHITELIST,
						"%s 動作合法：%s" % [String(dialogue_id), String(option_data.get("action", ""))])
					for page: Variant in Array(option_data.get("pages_after", [])):
						total_pages += 1
						_check_page(t, String(dialogue_id), Dictionary(page))
			for item_id: Variant in Dictionary(data.get("grant_items", {})):
				t.check(DataRegistry.get_item(String(item_id)) != null, "發放道具存在：" + String(item_id))
	t.check(total_pages >= 40, "劇本頁數合理（%d）" % total_pages)
	# 玩家可見文字不得殘留回聲設定
	var script_text := FileAccess.get_file_as_string("res://data/dialogue/dialogues.json")
	for banned: String in ["回聲", "觀測員", "迴靈", "共鳴"]:
		t.check(not script_text.contains(banned), "劇本不得殘留舊設定用語：" + banned)


func _check_page(t: TestContext, dialogue_id: String, page: Dictionary) -> void:
	t.check(not String(page.get("text", "")).is_empty(), dialogue_id + " 每頁有文字")
	for side: String in ["left", "right"]:
		if page.has(side):
			var parts := String(page[side]).split(":")
			t.check_eq(parts.size(), 2, "%s 立繪格式 char:expr" % dialogue_id)
			var path := "res://assets/portraits/%s_%s.png" % [parts[0], parts[1]]
			t.check(FileAccess.file_exists(path), "%s 立繪存在：%s" % [dialogue_id, path])
	if page.has("fx"):
		t.check(String(page["fx"]) in FX_WHITELIST, "%s FX 合法：%s" % [dialogue_id, String(page["fx"])])


func _test_ui_assets(t: TestContext) -> void:
	for element in ELEMENTS:
		t.check(FileAccess.file_exists("res://assets/ui/elem_%s.png" % element), "屬性圖示存在：" + element)
	for asset: String in ["contact_shadow", "fog_blob", "resonance_ring"]:
		t.check(FileAccess.file_exists("res://assets/ui/%s.png" % asset), "UI 素材存在：" + asset)
	for expr: String in ["neutral", "observing", "concerned", "relieved", "smiling"]:
		t.check(FileAccess.file_exists("res://assets/portraits/kui_%s.png" % expr), "葵姨立繪存在：" + expr)
	for expr: String in ["neutral", "thinking", "surprised", "determined", "happy"]:
		t.check(FileAccess.file_exists("res://assets/portraits/player_%s.png" % expr), "玩家立繪存在：" + expr)
	t.check(FileAccess.file_exists("res://assets/characters/npc_kui.png"), "葵姨世界圖存在")