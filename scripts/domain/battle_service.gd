class_name BattleService
extends RefCounted
## Turn-based battle rules. Pure domain logic: no scene-tree access.
## All randomness flows through the injected RandomNumberGenerator so
## automated tests can replay battles with a fixed seed.

enum Outcome { ONGOING, VICTORY, DEFEAT, FLED, CAPTURED }
enum ActionType { ATTACK, SKILL, ITEM, CAPTURE, FLEE }

const EVENT_MESSAGE := "message"
const EVENT_PLAYER_HP := "player_hp"
const EVENT_ENEMY_HP := "enemy_hp"
const EVENT_CONSUME_ITEM := "consume_item"
const EVENT_CAPTURED := "captured"
const EVENT_END := "end"


class BattleEvent:
	extends RefCounted

	var kind: String = BattleService.EVENT_MESSAGE
	var text: String = ""
	var data: Dictionary = {}

	static func make(event_kind: String, event_text: String = "", event_data: Dictionary = {}) -> BattleEvent:
		var event := BattleEvent.new()
		event.kind = event_kind
		event.text = event_text
		event.data = event_data
		return event


var player: CreatureInstance
var enemy: CreatureInstance
var outcome: int = Outcome.ONGOING

var _enemy_skills: Array[SkillDef] = []
var _rng: RandomNumberGenerator
var _flee_attempts: int = 0


func _init(player_creature: CreatureInstance, enemy_creature: CreatureInstance, enemy_skills: Array[SkillDef], rng: RandomNumberGenerator) -> void:
	player = player_creature
	enemy = enemy_creature
	_enemy_skills = enemy_skills
	_rng = rng


func intro_events() -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	events.append(BattleEvent.make(EVENT_MESSAGE, "A wild %s appeared!" % enemy.display_name))
	events.append(BattleEvent.make(EVENT_MESSAGE, "Go, %s!" % player.display_name))
	return events


## Resolves one full round for the given player action.
## payload keys: "skill": SkillDef, "item": ItemDef, "party_full": bool.
func take_turn(action: int, payload: Dictionary = {}) -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	if outcome != Outcome.ONGOING:
		return events
	match action:
		ActionType.ATTACK, ActionType.SKILL:
			_resolve_combat_round(payload.get("skill") as SkillDef, events)
		ActionType.ITEM:
			_resolve_item(payload.get("item") as ItemDef, events)
		ActionType.CAPTURE:
			_resolve_capture(payload.get("item") as ItemDef, bool(payload.get("party_full", false)), events)
		ActionType.FLEE:
			_resolve_flee(events)
	if outcome != Outcome.ONGOING:
		events.append(BattleEvent.make(EVENT_END, "", {"outcome": outcome}))
	return events


## Escape odds grow with a speed advantage and with repeated attempts.
func flee_chance() -> float:
	var speed_edge := 0.05 * float(player.speed - enemy.speed)
	var persistence := 0.1 * float(_flee_attempts)
	return clampf(0.5 + speed_edge + persistence, 0.1, 0.95)


## Capture odds scale with the species' capture_rate and how hurt the target is.
static func capture_chance(rate: float, hp_ratio: float) -> float:
	return clampf(rate * (1.6 - hp_ratio), 0.05, 0.95)


func _resolve_combat_round(player_skill: SkillDef, events: Array[BattleEvent]) -> void:
	if player_skill == null:
		events.append(BattleEvent.make(EVENT_MESSAGE, "%s hesitated!" % player.display_name))
		_enemy_attack(events)
		return
	if player.speed >= enemy.speed:
		_perform_attack(player, enemy, player_skill, events)
		if _check_knockouts(events):
			return
		_enemy_attack(events)
	else:
		_enemy_attack(events)
		if _check_knockouts(events):
			return
		_perform_attack(player, enemy, player_skill, events)
		_check_knockouts(events)


func _resolve_item(item: ItemDef, events: Array[BattleEvent]) -> void:
	if item == null or item.kind != ItemDef.KIND_HEAL:
		events.append(BattleEvent.make(EVENT_MESSAGE, "Nothing happened."))
		return
	events.append(BattleEvent.make(EVENT_CONSUME_ITEM, "", {"item_id": item.id}))
	var healed := player.heal(item.amount)
	events.append(_hp_event(EVENT_PLAYER_HP, player))
	if healed > 0:
		events.append(BattleEvent.make(EVENT_MESSAGE, "%s restored %d HP with the %s!" % [player.display_name, healed, item.display_name]))
	else:
		events.append(BattleEvent.make(EVENT_MESSAGE, "It had no effect..."))
	_enemy_attack(events)
	_check_knockouts(events)


func _resolve_capture(item: ItemDef, party_full: bool, events: Array[BattleEvent]) -> void:
	if item == null or item.kind != ItemDef.KIND_CAPTURE:
		events.append(BattleEvent.make(EVENT_MESSAGE, "Nothing happened."))
		return
	if party_full:
		events.append(BattleEvent.make(EVENT_MESSAGE, "Your party is full! The %s stays in your bag." % item.display_name))
		return
	events.append(BattleEvent.make(EVENT_CONSUME_ITEM, "", {"item_id": item.id}))
	events.append(BattleEvent.make(EVENT_MESSAGE, "You threw a %s at %s!" % [item.display_name, enemy.display_name]))
	var chance := capture_chance(enemy.capture_rate, enemy.hp_ratio())
	if _rng.randf() < chance:
		outcome = Outcome.CAPTURED
		events.append(BattleEvent.make(EVENT_CAPTURED, "%s was caught! It joined your party." % enemy.display_name))
	else:
		events.append(BattleEvent.make(EVENT_MESSAGE, "Oh no! %s broke free!" % enemy.display_name))
		_enemy_attack(events)
		_check_knockouts(events)


func _resolve_flee(events: Array[BattleEvent]) -> void:
	var chance := flee_chance()
	_flee_attempts += 1
	if _rng.randf() < chance:
		outcome = Outcome.FLED
		events.append(BattleEvent.make(EVENT_MESSAGE, "You got away safely!"))
	else:
		events.append(BattleEvent.make(EVENT_MESSAGE, "You couldn't escape!"))
		_enemy_attack(events)
		_check_knockouts(events)


func _enemy_attack(events: Array[BattleEvent]) -> void:
	if outcome != Outcome.ONGOING or enemy.is_fainted():
		return
	if _enemy_skills.is_empty():
		events.append(BattleEvent.make(EVENT_MESSAGE, "%s is watching carefully." % enemy.display_name))
		return
	var skill := _enemy_skills[_rng.randi_range(0, _enemy_skills.size() - 1)]
	_perform_attack(enemy, player, skill, events)
	_check_knockouts(events)


func _perform_attack(attacker: CreatureInstance, defender: CreatureInstance, skill: SkillDef, events: Array[BattleEvent]) -> void:
	events.append(BattleEvent.make(EVENT_MESSAGE, "%s used %s!" % [attacker.display_name, skill.display_name]))
	if _rng.randf() > skill.accuracy:
		events.append(BattleEvent.make(EVENT_MESSAGE, "But it missed!"))
		return
	var damage := DamageCalculator.compute(attacker, defender, skill, _rng)
	defender.apply_damage(damage)
	events.append(_hp_event(EVENT_ENEMY_HP if defender == enemy else EVENT_PLAYER_HP, defender))
	events.append(BattleEvent.make(EVENT_MESSAGE, "It dealt %d damage!" % damage))


## Returns true when the battle just ended due to a knockout.
func _check_knockouts(events: Array[BattleEvent]) -> bool:
	if outcome != Outcome.ONGOING:
		return true
	if enemy.is_fainted():
		outcome = Outcome.VICTORY
		events.append(BattleEvent.make(EVENT_MESSAGE, "The wild %s fainted. You won!" % enemy.display_name))
		return true
	if player.is_fainted():
		outcome = Outcome.DEFEAT
		events.append(BattleEvent.make(EVENT_MESSAGE, "%s fainted... You blacked out!" % player.display_name))
		return true
	return false


func _hp_event(kind: String, creature: CreatureInstance) -> BattleEvent:
	return BattleEvent.make(kind, "", {"hp": creature.hp, "max_hp": creature.max_hp})
