extends RefCounted
## Damage math is deterministic for a fixed RNG state.


func run(t: TestContext) -> void:
	var attacker := TestHelpers.make_creature("Atk", 50, 12, 10, 10, 5, "flame")
	var defender := TestHelpers.make_creature("Def", 50, 10, 10, 10, 5)
	var skill := TestHelpers.make_skill("Jab", 40)

	# Same seed twice -> identical damage.
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 42
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 42
	var damage_a := DamageCalculator.compute(attacker, defender, skill, rng_a)
	var damage_b := DamageCalculator.compute(attacker, defender, skill, rng_b)
	t.check_eq(damage_a, damage_b, "same seed must give identical damage")

	# The exact formula, replayed against a cloned RNG.
	var rng_c := RandomNumberGenerator.new()
	rng_c.seed = 42
	var variance := rng_c.randf_range(DamageCalculator.VARIANCE_MIN, DamageCalculator.VARIANCE_MAX)
	var expected := maxi(1, int(40.0 * 12.0 / 10.0 * 1.25 * variance / DamageCalculator.GLOBAL_DIVISOR))
	t.check_eq(damage_a, expected, "damage formula mismatch")

	# Affinity: a flame attacker deals more with a flame skill (same variance).
	var flame_skill := TestHelpers.make_skill("Flare", 40, "flame")
	var rng_d := RandomNumberGenerator.new()
	rng_d.seed = 7
	var rng_e := RandomNumberGenerator.new()
	rng_e.seed = 7
	var neutral_damage := DamageCalculator.compute(attacker, defender, skill, rng_d)
	var flame_damage := DamageCalculator.compute(attacker, defender, flame_skill, rng_e)
	t.check(flame_damage > neutral_damage, "matching element must add an affinity bonus")

	# Damage never drops below 1.
	var pebble := TestHelpers.make_skill("Pebble", 1)
	var tank := TestHelpers.make_creature("Tank", 999, 1, 999, 1)
	var rng_f := RandomNumberGenerator.new()
	rng_f.seed = 1
	t.check_eq(DamageCalculator.compute(attacker, tank, pebble, rng_f), 1, "minimum damage is 1")

	# Higher attack -> more damage (same variance seed).
	var strong := TestHelpers.make_creature("Strong", 50, 30, 10, 10, 5)
	var rng_g := RandomNumberGenerator.new()
	rng_g.seed = 9
	var rng_h := RandomNumberGenerator.new()
	rng_h.seed = 9
	t.check(
		DamageCalculator.compute(strong, defender, skill, rng_g) > DamageCalculator.compute(attacker, defender, skill, rng_h),
		"higher attack must deal more damage"
	)
