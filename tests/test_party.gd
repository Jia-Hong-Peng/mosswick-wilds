extends RefCounted
## Party: capacity cap, healing, fainted handling, serialization roundtrip.

const PartyScript := preload("res://scripts/core/party_service.gd")


func run(t: TestContext) -> void:
	var party: Node = PartyScript.new()
	t.check(not party.is_full(), "empty party is not full")
	t.check(party.add_member(TestHelpers.make_creature("A", 30, 5, 5, 5)), "first member joins")
	t.check(party.add_member(TestHelpers.make_creature("B", 30, 5, 5, 5)), "second member joins")
	t.check(party.add_member(TestHelpers.make_creature("C", 30, 5, 5, 5)), "third member joins")
	t.check(party.is_full(), "party of three is full")
	t.check(not party.add_member(TestHelpers.make_creature("D", 30, 5, 5, 5)), "fourth member must be rejected")
	t.check_eq(party.size(), 3, "party size caps at 3")
	t.check(not party.add_member(null), "null members are rejected")

	var members: Array = party.members
	var first: CreatureInstance = members[0]
	var second: CreatureInstance = members[1]
	first.apply_damage(999)
	t.check(first.is_fainted(), "damage past zero faints a creature")
	t.check_eq(party.first_conscious(), second, "first_conscious skips fainted members")
	second.apply_damage(10)
	party.heal_all()
	t.check_eq(first.hp, first.max_hp, "heal_all revives fainted members")
	t.check_eq(second.hp, second.max_hp, "heal_all tops everyone up")

	# Roundtrip through save dictionaries using the real registry.
	var real_party: Node = PartyScript.new()
	var sprout: CreatureInstance = DataRegistry.make_creature("sproutwing", 6)
	sprout.apply_damage(9)
	real_party.add_member(sprout)
	real_party.add_member(DataRegistry.make_creature("tidecrest", 4))
	var saved: Array = real_party.to_dicts()
	var restored: Node = PartyScript.new()
	restored.load_from(saved, DataRegistry)
	t.check_eq(restored.size(), 2, "roundtrip keeps member count")
	var restored_first: CreatureInstance = restored.members[0]
	t.check_eq(restored_first.creature_id, "sproutwing", "roundtrip keeps creature id")
	t.check_eq(restored_first.level, 6, "roundtrip keeps level")
	t.check_eq(restored_first.hp, sprout.hp, "roundtrip keeps current HP")
	t.check_eq(restored_first.max_hp, sprout.max_hp, "stats are rebuilt from the definition")
	party.free()
	real_party.free()
	restored.free()
