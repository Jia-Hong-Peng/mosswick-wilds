extends RefCounted
## 頭目戰規則：前兆一致、攻擊有下限、干擾窗口、共鳴時機、階段轉換、敗北。


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _boss() -> CreatureInstance:
	var boss := TestHelpers.make_creature("Boss", 80, 22, 18, 10, 6)
	return boss


func _player() -> CreatureInstance:
	return TestHelpers.make_creature("Hero", 200, 17, 15, 10, 5)


func _service(hint: bool = false) -> BossBattleService:
	return BossBattleService.new(_player(), _boss(), _rng(7), hint)


func _skill() -> SkillDef:
	return TestHelpers.make_skill("Jab", 45)


func run(t: TestContext) -> void:
	_test_telegraph_consistency(t)
	_test_attack_floor(t)
	_test_phase_shift(t)
	_test_guard(t)
	_test_jam_window(t)
	_test_resonate_timing(t)
	_test_full_win_path(t)
	_test_defeat(t)
	_test_hint_text(t)


## 前兆必須與頭目實際行動一致
func _test_telegraph_consistency(t: TestContext) -> void:
	var service := _service()
	for i in range(6):
		var predicted := service.next_move()
		var events := service.take_turn(BossBattleService.Action.GUARD, {})
		var charged := false
		var attacked := false
		for event in events:
			if String(event.data.get("boss_pose", "")) == "charge":
				charged = true
			if String(event.data.get("attacker", "")) == "enemy":
				attacked = true
		if predicted == BossBattleService.Move.CHARGE:
			t.check(charged and not attacked, "第 %d 回合：前兆為充能，行動必須是充能" % i)
		else:
			t.check(attacked and not charged, "第 %d 回合：前兆為攻擊，行動必須是攻擊" % i)
		if service.outcome != BossBattleService.Outcome.ONGOING:
			break
	t.check(service.turn_count >= 4, "防禦流派應能撐過多回合")


## 純攻擊不能結束戰鬥：訊號強度有下限
func _test_attack_floor(t: TestContext) -> void:
	var service := _service()
	var floor_hp := service.hp_floor()
	var hit_floor_message := false
	for i in range(12):
		if service.outcome != BossBattleService.Outcome.ONGOING:
			break
		var events := service.take_turn(BossBattleService.Action.ATTACK, {"skill": _skill()})
		for event in events:
			if event.text.contains("撼不動"):
				hit_floor_message = true
	t.check(service.boss.hp >= floor_hp, "攻擊不得將頭目打到下限以下")
	t.check(service.outcome != BossBattleService.Outcome.RESONATED, "純攻擊不可能達成共鳴結局")
	t.check(hit_floor_message, "到達下限時必須提示玩家換方法")


func _test_phase_shift(t: TestContext) -> void:
	var service := _service()
	var shifted := false
	for i in range(8):
		var events := service.take_turn(BossBattleService.Action.ATTACK, {"skill": _skill()})
		for event in events:
			if String(event.data.get("fx", "")) == "phase_shift":
				shifted = true
		if shifted or service.outcome != BossBattleService.Outcome.ONGOING:
			break
	t.check(shifted, "訊號強度降至門檻必須觸發第二階段")
	t.check_eq(service.phase, 2, "階段旗標必須更新")
	# 轉階段當回合頭目立即充能 → 玩家看到的下一手是強波（有前兆可防）
	t.check_eq(service.next_move(), BossBattleService.Move.STRONGWAVE, "轉階段後下一手是強波")


func _test_guard(t: TestContext) -> void:
	# 第二階段強波：防禦大幅減傷
	var service := _service()
	while service.phase == 1 and service.outcome == BossBattleService.Outcome.ONGOING:
		service.take_turn(BossBattleService.Action.ATTACK, {"skill": _skill()})
	t.check_eq(service.next_move(), BossBattleService.Move.STRONGWAVE, "充能後必須接強波")
	var hp_before := service.player.hp
	service.take_turn(BossBattleService.Action.GUARD, {})
	var guarded_damage := hp_before - service.player.hp
	t.check(guarded_damage > 0 and guarded_damage <= 14, "防禦下的強波傷害必須被大幅壓低（實際 %d）" % guarded_damage)
	# 對照：不防禦的強波必須顯著更痛（用同 seed 新局）
	var raw := _service()
	while raw.phase == 1 and raw.outcome == BossBattleService.Outcome.ONGOING:
		raw.take_turn(BossBattleService.Action.ATTACK, {"skill": _skill()})
	var raw_before := raw.player.hp
	raw.take_turn(BossBattleService.Action.ATTACK, {"skill": _skill()})
	var raw_damage := raw_before - raw.player.hp
	t.check(raw_damage > guarded_damage * 2, "未防禦強波應遠痛於防禦（%d vs %d）" % [raw_damage, guarded_damage])


func _test_jam_window(t: TestContext) -> void:
	var service := _service()
	# 第一階段沒有充能：干擾必定落空且不開窗
	service.take_turn(BossBattleService.Action.JAM, {})
	t.check(not service.disrupted, "第一階段干擾不應開啟紊亂窗口")
	# 推進到第二階段（轉階段當回合已充能 → 先防強波，下一手才是充能）
	while service.phase == 1 and service.outcome == BossBattleService.Outcome.ONGOING:
		service.take_turn(BossBattleService.Action.ATTACK, {"skill": _skill()})
	service.take_turn(BossBattleService.Action.GUARD, {})
	t.check_eq(service.next_move(), BossBattleService.Move.CHARGE, "強波後回到充能")
	var events := service.take_turn(BossBattleService.Action.JAM, {})
	t.check(service.disrupted, "對充能施放干擾必須開啟紊亂窗口")
	var skipped := true
	for event in events:
		if String(event.data.get("attacker", "")) == "enemy":
			skipped = false
	t.check(skipped, "干擾成功時頭目跳過該回合")


func _test_resonate_timing(t: TestContext) -> void:
	var service := _service()
	# 過早共鳴：失敗且戰鬥繼續
	var events := service.take_turn(BossBattleService.Action.RESONATE, {})
	t.check_eq(service.outcome, BossBattleService.Outcome.ONGOING, "過早共鳴不得結束戰鬥")
	var explained := false
	for event in events:
		if event.text.contains("雜訊蓋過"):
			explained = true
	t.check(explained, "共鳴失敗必須說明原因")


func _test_full_win_path(t: TestContext) -> void:
	var service := _service()
	# 教科書打法：P1 攻擊、充能時干擾、窗口內共鳴
	var guard_rounds := 0
	while service.outcome == BossBattleService.Outcome.ONGOING and guard_rounds < 20:
		guard_rounds += 1
		if service.disrupted:
			service.take_turn(BossBattleService.Action.RESONATE, {})
		elif service.next_move() == BossBattleService.Move.CHARGE:
			service.take_turn(BossBattleService.Action.JAM, {})
		elif service.next_move() == BossBattleService.Move.STRONGWAVE:
			service.take_turn(BossBattleService.Action.GUARD, {})
		elif service.next_move() == BossBattleService.Move.RAM:
			service.take_turn(BossBattleService.Action.GUARD, {})
		else:
			service.take_turn(BossBattleService.Action.ATTACK, {"skill": _skill()})
	t.check_eq(service.outcome, BossBattleService.Outcome.RESONATED, "正確打法必須以共鳴收尾")
	t.check(service.turn_count >= 3 and service.turn_count <= 12, "有效回合數應在 3–12 之間（實際 %d）" % service.turn_count)
	t.check(not service.player.is_fainted(), "正確打法不應戰敗")


func _test_defeat(t: TestContext) -> void:
	var frail := TestHelpers.make_creature("Frail", 20, 10, 5, 5)
	var service := BossBattleService.new(frail, _boss(), _rng(3), false)
	var rounds := 0
	while service.outcome == BossBattleService.Outcome.ONGOING and rounds < 10:
		rounds += 1
		service.take_turn(BossBattleService.Action.ATTACK, {"skill": _skill()})
	t.check_eq(service.outcome, BossBattleService.Outcome.DEFEAT, "低血量硬打必須戰敗")


func _test_hint_text(t: TestContext) -> void:
	var with_hint := _service(true)
	var without := _service(false)
	t.check(with_hint.telegraph_text().contains("（"), "取得觀測提示後前兆需附明示標籤")
	t.check(not without.telegraph_text().contains("（"), "未取得提示時不給明示標籤")