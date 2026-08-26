class_name TestHelpers
extends RefCounted
## Small factories shared between battle-related test suites.


static func make_creature(creature_name: String, hp: int, attack: int, defense: int, speed: int, level: int = 5, element: String = "neutral") -> CreatureInstance:
	var creature := CreatureInstance.new()
	creature.creature_id = creature_name.to_lower()
	creature.display_name = creature_name
	creature.level = level
	creature.element = element
	creature.max_hp = hp
	creature.hp = hp
	creature.attack = attack
	creature.defense = defense
	creature.speed = speed
	creature.capture_rate = 0.5
	return creature


static func make_skill(skill_name: String, power: int, element: String = "neutral", accuracy: float = 1.0) -> SkillDef:
	var skill := SkillDef.new()
	skill.id = skill_name.to_lower()
	skill.display_name = skill_name
	skill.power = power
	skill.element = element
	skill.accuracy = accuracy
	return skill


static func make_heal_item(amount: int) -> ItemDef:
	var item := ItemDef.new()
	item.id = "test_tonic"
	item.display_name = "Test Tonic"
	item.kind = ItemDef.KIND_HEAL
	item.amount = amount
	item.usable_in_battle = true
	return item


static func make_capture_item() -> ItemDef:
	var item := ItemDef.new()
	item.id = "test_orb"
	item.display_name = "Test Orb"
	item.kind = ItemDef.KIND_CAPTURE
	item.usable_in_battle = true
	return item
