class_name DamageCalculator
extends RefCounted
## Pure damage math. Deterministic for a given RandomNumberGenerator state.

const AFFINITY_BONUS := 1.2
const VARIANCE_MIN := 0.9
const VARIANCE_MAX := 1.1
const GLOBAL_DIVISOR := 3.0

## 經典屬性循環：草克水、水克火、火克草。
const STRONG_AGAINST := {
	"grass": "water",
	"water": "fire",
	"fire": "grass",
}


static func compute(attacker: CreatureInstance, defender: CreatureInstance, skill: SkillDef, rng: RandomNumberGenerator) -> int:
	var offense := float(skill.power) * float(attacker.attack) / float(maxi(1, defender.defense))
	var level_scale := 1.0 + float(attacker.level) * 0.05
	var affinity := AFFINITY_BONUS if has_affinity(attacker, skill) else 1.0
	var variance := rng.randf_range(VARIANCE_MIN, VARIANCE_MAX)
	var matchup := effectiveness(skill.element, defender.element)
	return maxi(1, int(offense * level_scale * affinity * matchup * variance / GLOBAL_DIVISOR))


## A creature deals bonus damage with skills matching its own element.
static func has_affinity(attacker: CreatureInstance, skill: SkillDef) -> bool:
	return skill.element != "neutral" and skill.element == attacker.element


## 屬性相剋倍率：克制 1.3、被剋 0.8、其餘 1.0。
static func effectiveness(attack_element: String, defend_element: String) -> float:
	if STRONG_AGAINST.get(attack_element, "") == defend_element:
		return 1.3
	if STRONG_AGAINST.get(defend_element, "") == attack_element:
		return 0.8
	return 1.0
