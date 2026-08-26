class_name BossBattleService
extends RefCounted
## 頭目戰規則（磁殼仔・失衡體）。純領域邏輯、行動序列固定、極少 RNG。
##
## 設計（docs/vertical-slice-audit.md §5）：
## - 每回合開頭都有「前兆」告知頭目下一步（telegraph）。
## - 第一階段：判讀前兆。防禦對上強波/衝撞→大幅減傷；干擾對上充能→取消強波
##   並使頭目「訊號紊亂」。
## - 第二階段（訊號強度 ≤55%）：純攻擊打不穿（下限 30%）；
##   必須在「紊亂」窗口啟動共鳴才能結束戰鬥。
## - 錯誤有限懲罰＋說明原因；不靠 RNG 拖時間。

enum Action { ATTACK, GUARD, JAM, RESONATE, ITEM }
enum Move { PULSE, RAM, CHARGE, STRONGWAVE }
enum Outcome { ONGOING, RESONATED, DEFEAT }


const HP_FLOOR_RATIO := 0.3
const PHASE2_RATIO := 0.55

const MOVE_TELEGRAPH := {
	Move.PULSE: "天線亂顫，灑出靜電——",
	Move.RAM: "殼一縮，腳蹬地——要衝撞！",
	Move.CHARGE: "長鬚發紅，向後繃緊——",
	Move.STRONGWAVE: "積聚的強波就要炸開——",
}
const MOVE_HINT := {
	Move.PULSE: "（靜電：可防可打）",
	Move.RAM: "（衝撞：防禦能大幅減傷）",
	Move.CHARGE: "（充能：用「干擾」打斷它！）",
	Move.STRONGWAVE: "（強波：立刻防禦！）",
}
const MOVE_POWER := {
	Move.PULSE: 30,
	Move.RAM: 45,
	Move.STRONGWAVE: 70,
}

var player: CreatureInstance
var boss: CreatureInstance
var outcome: int = Outcome.ONGOING
var phase := 1
var disrupted := false          # 訊號紊亂：共鳴窗口
var has_hint := false           # 古道可選觀測取得的前兆明示
var turn_count := 0

var _rng: RandomNumberGenerator
var _pattern_p1: Array[int] = [Move.PULSE, Move.RAM]
var _pattern_p2: Array[int] = [Move.CHARGE, Move.PULSE]
var _pattern_index := 0
var _pending_strongwave := false
var _guarding := false


func _init(player_creature: CreatureInstance, boss_creature: CreatureInstance, rng: RandomNumberGenerator, hint: bool) -> void:
	player = player_creature
	boss = boss_creature
	_rng = rng
	has_hint = hint


func hp_floor() -> int:
	return int(float(boss.max_hp) * HP_FLOOR_RATIO)


## 頭目下一步（回合開始前 UI 顯示前兆用）
func next_move() -> int:
	if _pending_strongwave:
		return Move.STRONGWAVE
	var pattern := _pattern_p1 if phase == 1 else _pattern_p2
	return pattern[_pattern_index % pattern.size()]


func telegraph_text() -> String:
	if disrupted:
		return "牠的訊號亂成一團，殼上的光在明滅——共鳴的機會！"
	var move := next_move()
	var text := String(MOVE_TELEGRAPH[move])
	if has_hint:
		text += String(MOVE_HINT[move])
	return text


func intro_events() -> Array[BattleService.BattleEvent]:
	var events: Array[BattleService.BattleEvent] = []
	events.append(BattleService.BattleEvent.make(BattleService.EVENT_MESSAGE, "失衡的磁殼仔擋在訊號中央！"))
	events.append(_telegraph_event())
	return events


func take_turn(action: int, payload: Dictionary = {}) -> Array[BattleService.BattleEvent]:
	var events: Array[BattleService.BattleEvent] = []
	if outcome != Outcome.ONGOING:
		return events
	turn_count += 1
	_guarding = false
	var skip_boss := false
	match action:
		Action.ATTACK:
			_resolve_attack(payload.get("skill") as SkillDef, events)
		Action.GUARD:
			_guarding = true
			events.append(_msg("你們壓低重心，撐起穩流。"))
		Action.JAM:
			# 干擾成功＝頭目踉蹌跳過本回合，紊亂窗口留到牠下次行動前
			skip_boss = _resolve_jam(events)
		Action.RESONATE:
			_resolve_resonate(events)
		Action.ITEM:
			_resolve_item(payload.get("item") as ItemDef, events)
	if outcome == Outcome.ONGOING and not skip_boss:
		_boss_act(events)
	if outcome == Outcome.ONGOING:
		events.append(_telegraph_event())
	else:
		events.append(BattleService.BattleEvent.make(BattleService.EVENT_END, "", {"outcome": outcome}))
	return events


func _resolve_attack(skill: SkillDef, events: Array[BattleService.BattleEvent]) -> void:
	if skill == null:
		events.append(_msg("%s猶豫了！" % player.display_name))
		return
	events.append(BattleService.BattleEvent.make(BattleService.EVENT_MESSAGE, "%s使用了%s！" % [player.display_name, skill.display_name], {"attacker": "player"}))
	var damage := DamageCalculator.compute(player, boss, skill, _rng)
	var floor_hp := hp_floor()
	var at_floor_before := boss.hp <= floor_hp
	boss.hp = maxi(floor_hp, boss.hp - damage)
	var hp_event := BattleService.BattleEvent.make(BattleService.EVENT_ENEMY_HP, "", {"hp": boss.hp, "max_hp": boss.max_hp, "damage": damage})
	events.append(hp_event)
	if at_floor_before:
		events.append(_msg("攻擊撼不動核心的訊號——需要別的方法。"))
	else:
		events.append(_msg("造成了 %d 點傷害！" % damage))
	_check_phase_shift(events)


func _resolve_jam(events: Array[BattleService.BattleEvent]) -> bool:
	events.append(BattleService.BattleEvent.make(BattleService.EVENT_MESSAGE, "你切換共鳴器，放出逆頻——", {"attacker": "player"}))
	if next_move() == Move.CHARGE:
		events.append(BattleService.BattleEvent.make(BattleService.EVENT_MESSAGE, "逆頻打中充能！牠的訊號亂了——就是現在！", {"fx": "jam_hit", "boss_pose": "weak"}))
		disrupted = true
		_advance_pattern()  # 充能被吃掉，強波不會來
		return true
	if next_move() == Move.STRONGWAVE:
		events.append(_msg("強波已經成形，逆頻擠不進去！"))
		return false
	events.append(_msg("逆頻沒對上節拍，只激起一圈雜訊。"))
	return false


func _resolve_resonate(events: Array[BattleService.BattleEvent]) -> void:
	events.append(BattleService.BattleEvent.make(BattleService.EVENT_MESSAGE, "你舉起共鳴器，對準牠的頻率——", {"attacker": "player"}))
	if disrupted:
		outcome = Outcome.RESONATED
		events.append(BattleService.BattleEvent.make(BattleService.EVENT_MESSAGE, "共鳴器咬住了頻率。", {"fx": "resonance"}))
		events.append(_msg("纏住牠的舊訊號，一圈、一圈剝落。"))
	else:
		events.append(_msg("共鳴被雜訊蓋過。等牠訊號亂掉的瞬間再試。"))


func _resolve_item(item: ItemDef, events: Array[BattleService.BattleEvent]) -> void:
	if item == null or item.kind != ItemDef.KIND_HEAL:
		events.append(_msg("現在用不上這個。"))
		return
	events.append(BattleService.BattleEvent.make(BattleService.EVENT_CONSUME_ITEM, "", {"item_id": item.id}))
	var healed := player.heal(item.amount)
	var hp_event := BattleService.BattleEvent.make(BattleService.EVENT_PLAYER_HP, "", {"hp": player.hp, "max_hp": player.max_hp, "healed": healed})
	events.append(hp_event)
	events.append(_msg("%s恢復了 %d HP。" % [player.display_name, healed]))


func _boss_act(events: Array[BattleService.BattleEvent]) -> void:
	var move := next_move()
	_advance_pattern()
	disrupted = false
	match move:
		Move.CHARGE:
			_pending_strongwave = true
			events.append(BattleService.BattleEvent.make(BattleService.EVENT_MESSAGE, "磁殼仔把電波往殼裡吸，空氣嗡嗡作響。", {"boss_pose": "charge"}))
			if _guarding:
				events.append(_msg("牠還在充能，防禦落了空。"))
		Move.STRONGWAVE:
			_pending_strongwave = false
			_boss_attack(Move.STRONGWAVE, "磁殼仔放出撕裂空氣的強波！", events)
		Move.RAM:
			_boss_attack(Move.RAM, "磁殼仔整顆殼衝了過來！", events)
		Move.PULSE:
			_boss_attack(Move.PULSE, "磁殼仔灑出一圈靜電！", events)


func _boss_attack(move: int, text: String, events: Array[BattleService.BattleEvent]) -> void:
	events.append(BattleService.BattleEvent.make(BattleService.EVENT_MESSAGE, text, {"attacker": "enemy", "boss_pose": "attack"}))
	var power := int(MOVE_POWER[move])
	var skill := SkillDef.new()
	skill.display_name = "頭目行動"
	skill.power = power
	skill.accuracy = 1.0
	var damage := DamageCalculator.compute(boss, player, skill, _rng)
	if _guarding:
		var factor := 0.2 if move == Move.STRONGWAVE else (0.35 if move == Move.RAM else 0.5)
		damage = maxi(1, int(float(damage) * factor))
	player.apply_damage(damage)
	var hp_event := BattleService.BattleEvent.make(BattleService.EVENT_PLAYER_HP, "", {"hp": player.hp, "max_hp": player.max_hp, "damage": damage})
	events.append(hp_event)
	if _guarding and move != Move.PULSE:
		events.append(_msg("穩流護住了你們，傷害被壓了下來。（%d）" % damage))
	elif _guarding:
		events.append(_msg("靜電繞過穩流刺了進來。（%d）" % damage))
	else:
		events.append(_msg("受到了 %d 點傷害！" % damage))
	if player.is_fainted():
		outcome = Outcome.DEFEAT
		events.append(_msg("%s撐不住了……你抱起牠退出觀測站。" % player.display_name))


func _check_phase_shift(events: Array[BattleService.BattleEvent]) -> void:
	if phase == 1 and boss.hp <= int(float(boss.max_hp) * PHASE2_RATIO):
		phase = 2
		_pattern_index = 0
		_pending_strongwave = false
		events.append(BattleService.BattleEvent.make(BattleService.EVENT_MESSAGE, "殼縫裡透出光——訊號更急了。牠在怕。", {"fx": "phase_shift"}))


func _advance_pattern() -> void:
	_pattern_index += 1


func _telegraph_event() -> BattleService.BattleEvent:
	return BattleService.BattleEvent.make(BattleService.EVENT_MESSAGE, telegraph_text(), {"telegraph": next_move()})


func _msg(text: String) -> BattleService.BattleEvent:
	return BattleService.BattleEvent.make(BattleService.EVENT_MESSAGE, text)
