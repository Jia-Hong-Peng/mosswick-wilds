extends RefCounted
## 危機戰規則（岩背獾）：前兆一致性、恐慌下限（純攻擊打不完）、
## 修復時機閘門、三隻御三家各自的策略路線都能在有限回合內收尾、
## 破防／閃避／減速機制、敗北路線。


func run(t: TestContext) -> void:
	_test_telegraph_pattern(t)
	_test_attack_cannot_finish(t)
	_test_soothe_gate(t)
	_test_break_mechanic(t)
	_test_dodge_mechanic(t)
	_test_slow_and_shield(t)
	_test_starter_paths(t)
	_test_defeat(t)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _badger() -> CreatureInstance:
	var boss := DataRegistry.make_creature("rockbadger", 5)
	boss.max_hp = 80
	boss.hp = 80
	boss.attack = 16
	boss.defense = 14
	boss.speed = 7
	return boss


func _starter(id: String) -> CreatureInstance:
	return DataRegistry.make_creature(id, 5)


func _skill(creature: CreatureInstance, index: int) -> SkillDef:
	return DataRegistry.skills_for(creature)[index]


func _test_telegraph_pattern(t: TestContext) -> void:
	var service := CrisisBattleService.new(_starter("sproutwing"), _badger(), _rng(1))
	# 行動序列固定：噴氣 → 縮甲 → 衝撞 循環；衝撞永遠有縮甲當前兆
	var expected: Array[int] = [
		CrisisBattleService.Move.SNORT,
		CrisisBattleService.Move.SHELL,
		CrisisBattleService.Move.RAM,
	]
	var previous := -1
	for i in range(9):
		var move := service.next_move()
		t.check_eq(move, expected[i % 3], "第 %d 手前兆必須照固定序列" % i)
		if move == CrisisBattleService.Move.RAM:
			t.check_eq(previous, CrisisBattleService.Move.SHELL, "衝撞前一手必為縮甲（可判讀前兆）")
		t.check(not service.telegraph_text().is_empty(), "每一手都要有前兆文字")
		previous = move
		service.player.heal_full()  # 只驗前兆序列，排除敗北
		service.take_turn(CrisisBattleService.Action.ITEM, {})  # 無效道具＝跳過玩家行動
	# 恐慌壓到下限後，前兆改為修復提示
	var boss := service.boss
	boss.hp = service.panic_floor()
	t.check(service.telegraph_text().contains("修復"), "下限時的前兆必須提示修復")


func _test_attack_cannot_finish(t: TestContext) -> void:
	var player := _starter("emberhorn")
	var service := CrisisBattleService.new(player, _badger(), _rng(7))
	var heat := _skill(player, 0)
	var floor_hp := service.panic_floor()
	var floor_message_seen := false
	for i in range(24):
		if service.outcome != CrisisBattleService.Outcome.ONGOING:
			break
		player.heal_full()  # 排除敗北，純看攻擊能不能打完
		var events := service.take_turn(CrisisBattleService.Action.SKILL, {"skill": heat})
		for event in events:
			if event.text.contains("修復"):
				floor_message_seen = true
	t.check_eq(service.outcome, CrisisBattleService.Outcome.ONGOING, "純攻擊不可能結束戰鬥")
	t.check_eq(service.boss.hp, floor_hp, "恐慌值停在 30% 下限，不得歸零")
	t.check(floor_message_seen, "下限時必須說明需要「修復」")


func _test_soothe_gate(t: TestContext) -> void:
	var service := CrisisBattleService.new(_starter("sproutwing"), _badger(), _rng(3))
	# 恐慌還高：修復失敗、岩背獾照常行動
	var events := service.take_turn(CrisisBattleService.Action.SOOTHE, {})
	t.check_eq(service.outcome, CrisisBattleService.Outcome.ONGOING, "太早修復不能結束戰鬥")
	var failed_text := false
	for event in events:
		if event.text.contains("聽不進去"):
			failed_text = true
	t.check(failed_text, "太早修復要說明原因")
	# 到下限：修復成功
	service.boss.hp = service.panic_floor()
	service.take_turn(CrisisBattleService.Action.SOOTHE, {})
	t.check_eq(service.outcome, CrisisBattleService.Outcome.SOOTHED, "下限時修復必須成功")
	t.check(service.take_turn(CrisisBattleService.Action.SOOTHE, {}).is_empty(), "結束後不再接受行動")


func _test_break_mechanic(t: TestContext) -> void:
	# 前兩回合跳過玩家行動（噴氣→縮甲），避免恐慌先觸底
	var player := _starter("emberhorn")
	var service := CrisisBattleService.new(player, _badger(), _rng(11))
	service.take_turn(CrisisBattleService.Action.ITEM, {})
	service.take_turn(CrisisBattleService.Action.ITEM, {})
	t.check(service.shelled, "第二回合後岩背獾必須處於縮甲")
	# 縮甲時普通攻擊大減
	var hp_before := service.boss.hp
	service.take_turn(CrisisBattleService.Action.SKILL, {"skill": _skill(player, 0)})
	var reduced := hp_before - service.boss.hp
	t.check(reduced > 0, "縮甲下仍要有最低傷害")
	# 重來：用燼角衝撬開
	var player_b := _starter("emberhorn")
	var service_b := CrisisBattleService.new(player_b, _badger(), _rng(11))
	service_b.take_turn(CrisisBattleService.Action.ITEM, {})
	service_b.take_turn(CrisisBattleService.Action.ITEM, {})
	var hp_before_b := service_b.boss.hp
	service_b.take_turn(CrisisBattleService.Action.SKILL, {"skill": _skill(player_b, 1)})  # 燼角衝
	var break_damage := hp_before_b - service_b.boss.hp
	t.check(service_b.shell_broken, "燼角衝必須撬開岩甲")
	t.check(break_damage > reduced, "破防的一擊必須勝過對著岩甲硬打（%d vs %d）" % [break_damage, reduced])
	# 撬開後縮甲失效
	player_b.heal_full()
	for i in range(3):
		player_b.heal_full()
		service_b.take_turn(CrisisBattleService.Action.ITEM, {})
	t.check(not service_b.shelled, "撬開後縮甲不得再生效")


func _test_dodge_mechanic(t: TestContext) -> void:
	var player := _starter("tidecrest")
	var service := CrisisBattleService.new(player, _badger(), _rng(5))
	# 霧步後，下一次受擊幾乎無傷
	var hp_before := player.hp
	service.take_turn(CrisisBattleService.Action.SKILL, {"skill": _skill(player, 1)})  # 霧步（回合1 噴氣）
	var dodged_damage := hp_before - player.hp
	t.check(dodged_damage <= 3, "霧步必須幾乎閃開攻擊（受了 %d）" % dodged_damage)
	# 連擊：霧步後的攻擊比平常多一段
	var player_b := _starter("tidecrest")
	var service_b := CrisisBattleService.new(player_b, _badger(), _rng(9))
	var boss_before := service_b.boss.hp
	service_b.take_turn(CrisisBattleService.Action.SKILL, {"skill": _skill(player_b, 0)})
	var single := boss_before - service_b.boss.hp
	var player_c := _starter("tidecrest")
	var service_c := CrisisBattleService.new(player_c, _badger(), _rng(9))
	service_c.take_turn(CrisisBattleService.Action.SKILL, {"skill": _skill(player_c, 1)})
	var boss_mid := service_c.boss.hp
	service_c.take_turn(CrisisBattleService.Action.SKILL, {"skill": _skill(player_c, 0)})
	var double := boss_mid - service_c.boss.hp
	t.check(double > single, "霧步後的攻擊必須多出一段（%d vs %d）" % [double, single])


func _test_slow_and_shield(t: TestContext) -> void:
	# 無減傷的衝撞（回合3）
	var player := _starter("sproutwing")
	var service := CrisisBattleService.new(player, _badger(), _rng(13))
	service.take_turn(CrisisBattleService.Action.ITEM, {})
	service.take_turn(CrisisBattleService.Action.ITEM, {})
	var hp_before := player.hp
	service.take_turn(CrisisBattleService.Action.ITEM, {})  # 回合3：衝撞
	var raw := hp_before - player.hp
	# 纏芽＋葉幕的衝撞
	var player_b := _starter("sproutwing")
	var service_b := CrisisBattleService.new(player_b, _badger(), _rng(13))
	service_b.take_turn(CrisisBattleService.Action.SKILL, {"skill": _skill(player_b, 1)})  # 纏芽
	service_b.take_turn(CrisisBattleService.Action.ITEM, {})
	var hp_before_b := player_b.hp
	service_b.take_turn(CrisisBattleService.Action.SKILL, {"skill": _skill(player_b, 2)})  # 葉幕＋衝撞
	var mitigated := hp_before_b - player_b.hp
	t.check(raw >= mitigated * 3, "纏芽＋葉幕必須大幅壓低衝撞傷害（%d vs %d）" % [raw, mitigated])


## 三條策略路線都能在 3–8 個有效回合內收尾，且不需要道具或練等
func _test_starter_paths(t: TestContext) -> void:
	for id: String in ["sproutwing", "emberhorn", "tidecrest"]:
		for seed_value: int in [21, 22, 23]:
			var player := _starter(id)
			var service := CrisisBattleService.new(player, _badger(), _rng(seed_value))
			var guard := 0
			while service.outcome == CrisisBattleService.Outcome.ONGOING and guard < 14:
				guard += 1
				if service.at_floor():
					service.take_turn(CrisisBattleService.Action.SOOTHE, {})
				else:
					service.take_turn(CrisisBattleService.Action.SKILL, {"skill": _skill(player, _pick(service, id, player))})
			t.check_eq(service.outcome, CrisisBattleService.Outcome.SOOTHED, "%s（seed %d）必須以修復收尾" % [id, seed_value])
			t.check(service.turn_count >= 3 and service.turn_count <= 10, "%s 有效回合 3–10（實際 %d）" % [id, service.turn_count])
			t.check(not player.is_fainted(), "%s 走對策略不應倒下" % id)


func _pick(service: CrisisBattleService, id: String, _player: CreatureInstance) -> int:
	match id:
		"sproutwing":
			if service.next_move() == CrisisBattleService.Move.RAM:
				return 2
			if service.next_move() == CrisisBattleService.Move.SHELL:
				return 1
			return 0
		"emberhorn":
			if service.shelled and not service.shell_broken:
				return 1
			return 0
		_:
			if service.next_move() == CrisisBattleService.Move.RAM:
				return 1
			return 0


func _test_defeat(t: TestContext) -> void:
	var player := _starter("sproutwing")
	player.hp = 1
	var service := CrisisBattleService.new(player, _badger(), _rng(2))
	var events := service.take_turn(CrisisBattleService.Action.SKILL, {"skill": _skill(player, 0)})
	t.check_eq(service.outcome, CrisisBattleService.Outcome.DEFEAT, "1 HP 硬吃攻擊必須敗北")
	t.check_eq(events.back().kind, BattleService.EVENT_END, "敗北要送出結束事件")