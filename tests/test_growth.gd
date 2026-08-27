extends RefCounted
## 經驗與升級：曲線遞增、跨級進位、多級連升、升級補 HP 差額（不回滿）、
## 能力值成長、存檔往返保留經驗。


func run(t: TestContext) -> void:
	_test_curve(t)
	_test_level_up(t)
	_test_multi_level(t)
	_test_hp_delta(t)
	_test_roundtrip(t)


func _test_curve(t: TestContext) -> void:
	t.check(CreatureInstance.exp_to_next(2) > CreatureInstance.exp_to_next(1), "升級門檻隨等級遞增")
	t.check(CreatureInstance.exp_reward(5) > CreatureInstance.exp_reward(2), "高等對手給更多經驗")
	t.check(CreatureInstance.exp_reward(2) > 0, "經驗獎勵為正")


func _test_level_up(t: TestContext) -> void:
	var def := DataRegistry.get_creature("sproutwing")
	var creature := CreatureInstance.from_def(def, 5)
	var old_attack := creature.attack
	var old_max := creature.max_hp
	var need := CreatureInstance.exp_to_next(5)
	var gained := creature.gain_exp(need - 1, def)
	t.check_eq(gained, 0, "差 1 點經驗不升級")
	t.check_eq(creature.level, 5, "等級不變")
	gained = creature.gain_exp(1, def)
	t.check_eq(gained, 1, "補足門檻升 1 級")
	t.check_eq(creature.level, 6, "升到 Lv6")
	t.check_eq(creature.exp, 0, "多餘經驗歸零（剛好用完）")
	t.check(creature.attack > old_attack, "攻擊隨升級成長")
	t.check(creature.max_hp > old_max, "HP 上限隨升級成長")


func _test_multi_level(t: TestContext) -> void:
	var def := DataRegistry.get_creature("tidecrest")
	var creature := CreatureInstance.from_def(def, 3)
	var need := CreatureInstance.exp_to_next(3) + CreatureInstance.exp_to_next(4) + 5
	var gained := creature.gain_exp(need, def)
	t.check_eq(gained, 2, "一次獲得大量經驗連升 2 級")
	t.check_eq(creature.level, 5, "升到 Lv5")
	t.check_eq(creature.exp, 5, "剩餘經驗累積到下一級")


func _test_hp_delta(t: TestContext) -> void:
	var def := DataRegistry.get_creature("emberhorn")
	var creature := CreatureInstance.from_def(def, 5)
	creature.apply_damage(20)
	var hp_before := creature.hp
	var max_before := creature.max_hp
	creature.gain_exp(CreatureInstance.exp_to_next(5), def)
	var delta := creature.max_hp - max_before
	t.check_eq(creature.hp, hp_before + delta, "升級補 HP 增量，不是回滿")
	t.check(creature.hp < creature.max_hp, "受傷狀態升級後仍未滿血")


func _test_roundtrip(t: TestContext) -> void:
	var def := DataRegistry.get_creature("rockbadger")
	var creature := CreatureInstance.from_def(def, 4)
	creature.gain_exp(10, def)
	var restored := CreatureInstance.from_dict(creature.to_dict(), def)
	t.check_eq(restored.exp, 10, "經驗值入檔往返一致")
	t.check_eq(restored.level, 4, "等級往返一致")