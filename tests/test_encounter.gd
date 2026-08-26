extends RefCounted
## Encounter rolls: rate bounds, weighted picks, level ranges.


func run(t: TestContext) -> void:
	var table := {
		"rate": 1.0,
		"entries": [
			{"creature_id": "a", "weight": 1, "min_level": 3, "max_level": 5},
			{"creature_id": "b", "weight": 0, "min_level": 3, "max_level": 5},
		],
	}
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var system := EncounterSystem.new(table, rng)
	for i in range(30):
		var roll := system.roll_step()
		t.check(not roll.is_empty(), "rate 1.0 must always trigger")
		t.check_eq(String(roll.get("creature_id", "")), "a", "zero-weight entries must never be picked")
		var level := int(roll.get("level", 0))
		t.check(level >= 3 and level <= 5, "level must stay in range (got %d)" % level)

	var never := EncounterSystem.new({"rate": 0.0, "entries": [{"creature_id": "a", "weight": 1}]}, rng)
	for i in range(30):
		t.check(never.roll_step().is_empty(), "rate 0.0 must never trigger")

	var empty := EncounterSystem.new({"rate": 1.0, "entries": []}, rng)
	t.check(empty.roll_step().is_empty(), "empty table must never trigger")

	# A realistic rate triggers sometimes but not always across fixed seeds.
	var hit := 0
	var partial_rng := RandomNumberGenerator.new()
	partial_rng.seed = 99
	var partial := EncounterSystem.new({"rate": 0.14, "entries": [{"creature_id": "a", "weight": 1, "min_level": 2, "max_level": 4}]}, partial_rng)
	for i in range(200):
		if not partial.roll_step().is_empty():
			hit += 1
	t.check(hit > 0 and hit < 200, "14%% rate should trigger sometimes (got %d/200)" % hit)
