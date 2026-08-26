extends RefCounted
## Battle rules: turn order, victory/defeat, flee, capture, in-battle items.


func run(t: TestContext) -> void:
	_test_turn_order(t)
	_test_victory(t)
	_test_defeat(t)
	_test_flee(t)
	_test_capture_chance(t)
	_test_capture_party_full(t)
	_test_capture_attempts(t)
	_test_item_heal(t)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _first_attack_message(events: Array[BattleService.BattleEvent]) -> String:
	for event in events:
		if event.kind == BattleService.EVENT_MESSAGE and event.text.contains(" used "):
			return event.text
	return ""


func _test_turn_order(t: TestContext) -> void:
	var jab := TestHelpers.make_skill("Jab", 1)
	# Fast player acts first.
	var fast_player := TestHelpers.make_creature("Fasty", 500, 5, 50, 30)
	var slow_enemy := TestHelpers.make_creature("Slowy", 500, 5, 50, 5)
	var battle := BattleService.new(fast_player, slow_enemy, [TestHelpers.make_skill("Enemy Jab", 1)], _rng(3))
	var events := battle.take_turn(BattleService.ActionType.SKILL, {"skill": jab})
	t.check(_first_attack_message(events).begins_with("Fasty"), "faster player must act first")
	# Fast enemy acts first.
	var slow_player := TestHelpers.make_creature("Slowy", 500, 5, 50, 5)
	var fast_enemy := TestHelpers.make_creature("Speedy", 500, 5, 50, 30)
	var battle_b := BattleService.new(slow_player, fast_enemy, [TestHelpers.make_skill("Enemy Jab", 1)], _rng(3))
	var events_b := battle_b.take_turn(BattleService.ActionType.SKILL, {"skill": jab})
	t.check(_first_attack_message(events_b).begins_with("Speedy"), "faster enemy must act first")


func _test_victory(t: TestContext) -> void:
	var player := TestHelpers.make_creature("Hero", 100, 20, 10, 30)
	var enemy := TestHelpers.make_creature("Wisp", 1, 5, 10, 5)
	var battle := BattleService.new(player, enemy, [TestHelpers.make_skill("Enemy Jab", 1)], _rng(5))
	var events := battle.take_turn(BattleService.ActionType.SKILL, {"skill": TestHelpers.make_skill("Jab", 40)})
	t.check_eq(battle.outcome, BattleService.Outcome.VICTORY, "one hit on a 1 HP enemy must win")
	t.check(events.back().kind == BattleService.EVENT_END, "battle must emit an end event")
	# A finished battle refuses further turns.
	t.check(battle.take_turn(BattleService.ActionType.SKILL, {"skill": TestHelpers.make_skill("Jab", 40)}).is_empty(), "finished battle takes no more turns")


func _test_defeat(t: TestContext) -> void:
	var player := TestHelpers.make_creature("Hero", 1, 5, 1, 5)
	var enemy := TestHelpers.make_creature("Brute", 500, 50, 10, 30)
	var battle := BattleService.new(player, enemy, [TestHelpers.make_skill("Smash", 60)], _rng(5))
	battle.take_turn(BattleService.ActionType.SKILL, {"skill": TestHelpers.make_skill("Jab", 40)})
	t.check_eq(battle.outcome, BattleService.Outcome.DEFEAT, "1 HP player hit by a fast brute must lose")


func _test_flee(t: TestContext) -> void:
	var fled := 0
	var stayed := 0
	for seed_value in range(1, 41):
		var player := TestHelpers.make_creature("Hero", 500, 5, 50, 12)
		var enemy := TestHelpers.make_creature("Wisp", 500, 5, 50, 10)
		var battle := BattleService.new(player, enemy, [TestHelpers.make_skill("Enemy Jab", 1)], _rng(seed_value))
		# Replay the same RNG stream to know the expected result.
		var clone := _rng(seed_value)
		var expected_flee := clone.randf() < battle.flee_chance()
		battle.take_turn(BattleService.ActionType.FLEE, {})
		if expected_flee:
			fled += 1
			t.check_eq(battle.outcome, BattleService.Outcome.FLED, "seed %d should flee" % seed_value)
		else:
			stayed += 1
			t.check_eq(battle.outcome, BattleService.Outcome.ONGOING, "seed %d should fail to flee" % seed_value)
	t.check(fled > 0 and stayed > 0, "flee must be able to both succeed and fail (got %d/%d)" % [fled, stayed])


func _test_capture_chance(t: TestContext) -> void:
	t.check(absf(BattleService.capture_chance(0.5, 1.0) - 0.3) < 0.0001, "full-HP capture chance")
	t.check(absf(BattleService.capture_chance(0.5, 0.1) - 0.75) < 0.0001, "low-HP capture chance")
	t.check(BattleService.capture_chance(0.01, 1.0) >= 0.05, "capture chance floor")
	t.check(BattleService.capture_chance(2.0, 0.0) <= 0.95, "capture chance ceiling")
	t.check(
		BattleService.capture_chance(0.5, 0.2) > BattleService.capture_chance(0.5, 0.9),
		"weakened creatures must be easier to catch"
	)


func _test_capture_party_full(t: TestContext) -> void:
	var player := TestHelpers.make_creature("Hero", 100, 10, 10, 10)
	var enemy := TestHelpers.make_creature("Wisp", 100, 10, 10, 5)
	var battle := BattleService.new(player, enemy, [TestHelpers.make_skill("Enemy Jab", 1)], _rng(1))
	var events := battle.take_turn(BattleService.ActionType.CAPTURE, {"item": TestHelpers.make_capture_item(), "party_full": true})
	t.check_eq(battle.outcome, BattleService.Outcome.ONGOING, "full party keeps the battle going")
	var consumed := false
	for event in events:
		if event.kind == BattleService.EVENT_CONSUME_ITEM:
			consumed = true
	t.check(not consumed, "full party must not consume the capture item")
	t.check(events.size() == 1 and events[0].kind == BattleService.EVENT_MESSAGE, "full party shows one clear message")


func _test_capture_attempts(t: TestContext) -> void:
	var caught := 0
	var escaped := 0
	for seed_value in range(1, 41):
		var player := TestHelpers.make_creature("Hero", 500, 5, 50, 10)
		var enemy := TestHelpers.make_creature("Wisp", 100, 5, 50, 5)
		enemy.hp = 30  # weakened -> chance = 0.5 * (1.6 - 0.3) = 0.65
		var battle := BattleService.new(player, enemy, [TestHelpers.make_skill("Enemy Jab", 1)], _rng(seed_value))
		var clone := _rng(seed_value)
		var expected_catch := clone.randf() < BattleService.capture_chance(enemy.capture_rate, enemy.hp_ratio())
		var events := battle.take_turn(BattleService.ActionType.CAPTURE, {"item": TestHelpers.make_capture_item(), "party_full": false})
		var consumed := false
		for event in events:
			if event.kind == BattleService.EVENT_CONSUME_ITEM:
				consumed = true
		t.check(consumed, "capture attempt must consume the item (seed %d)" % seed_value)
		if expected_catch:
			caught += 1
			t.check_eq(battle.outcome, BattleService.Outcome.CAPTURED, "seed %d should capture" % seed_value)
		else:
			escaped += 1
			t.check_eq(battle.outcome, BattleService.Outcome.ONGOING, "seed %d should break free" % seed_value)
	t.check(caught > 0 and escaped > 0, "capture must be able to both succeed and fail (got %d/%d)" % [caught, escaped])


func _test_item_heal(t: TestContext) -> void:
	var player := TestHelpers.make_creature("Hero", 50, 10, 10, 10)
	player.hp = 10
	var enemy := TestHelpers.make_creature("Wisp", 100, 10, 10, 5)
	# Enemy with no skills cannot counter-attack; heal amount stays observable.
	var battle := BattleService.new(player, enemy, [], _rng(1))
	var events := battle.take_turn(BattleService.ActionType.ITEM, {"item": TestHelpers.make_heal_item(25)})
	t.check_eq(player.hp, 35, "tonic must heal exactly 25 HP")
	var consumed_id := ""
	for event in events:
		if event.kind == BattleService.EVENT_CONSUME_ITEM:
			consumed_id = String(event.data.get("item_id", ""))
	t.check_eq(consumed_id, "test_tonic", "heal must emit a consume event")
	# Healing cannot exceed max HP.
	var battle_b := BattleService.new(player, enemy, [], _rng(1))
	battle_b.take_turn(BattleService.ActionType.ITEM, {"item": TestHelpers.make_heal_item(999)})
	t.check_eq(player.hp, 50, "healing must cap at max HP")
