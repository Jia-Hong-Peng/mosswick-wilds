class_name CrisisBattleService
extends RefCounted
## 首戰規則（受驚的岩背獾）。純領域邏輯、行動序列固定、極少 RNG。
##
## 設計：
## - 這不是狩獵戰——目標是把它的「恐慌」壓下來，最後用「安撫」收尾。
## - 每回合開頭都有可判讀的前兆（telegraph）：噴氣（輕）／縮甲（下回合衝撞）／
##   驚慌衝撞（重，但永遠有前一回合的縮甲當預告）。
## - 恐慌值（以血條呈現）壓到 30% 下限後，純攻擊不再有效；
##   必須選「安撫」結束戰鬥。玩家不能用最後一擊消滅它。
## - 三隻御三家各有不同解法：
##   芽翼鼯：纏芽拖慢衝撞、葉幕硬吃傷害（穩定路線）。
##   燼角羌：燼角衝撬開縮甲、高攻速攻（爆發路線）。
##   潮冠鷺：霧步閃開衝撞並多出一步（速度路線）。

enum Action { SKILL, ITEM, SOOTHE }
enum Move { SNORT, SHELL, RAM }
enum Outcome { ONGOING, SOOTHED, DEFEAT }

const PANIC_FLOOR_RATIO := 0.3

const MOVE_TELEGRAPH := {
	Move.SNORT: "它煩躁地刨著地，鼻子噴著粗氣——（輕撞：站穩就好）",
	Move.SHELL: "它把身體縮進岩甲裡——（下一步是衝撞！先做好準備）",
	Move.RAM: "岩甲繃緊，後腿蹬地——（衝撞：擋下它，或閃開它！）",
}
const MOVE_POWER := {
	Move.SNORT: 26,
	Move.RAM: 55,
}

var player: CreatureInstance
var boss: CreatureInstance
var outcome: int = Outcome.ONGOING
var turn_count := 0

# 岩背獾狀態
var shelled := false            # 縮甲：受到的傷害大減
var shell_broken := false       # 燼角衝撬開岩甲：縮甲失效
var rooted := false             # 纏芽：下一次衝撞大幅減速減傷

# 玩家夥伴狀態
var guard_turns := 0            # 葉幕：下一次受擊大減傷
var evasive := false            # 霧步：下一次受擊幾乎閃開
var extra_strike := false       # 霧步：下一次攻擊多打一段
var attack_up := false          # 暖火：下一次攻擊威力提高
var self_slow := false          # 燼角衝後座：受到的傷害略增

var _rng: RandomNumberGenerator
var _pattern: Array[int] = [Move.SNORT, Move.SHELL, Move.RAM]
var _pattern_index := 0


func _init(player_creature: CreatureInstance, boss_creature: CreatureInstance, rng: RandomNumberGenerator) -> void:
	player = player_creature
	boss = boss_creature
	_rng = rng


func panic_floor() -> int:
	return int(float(boss.max_hp) * PANIC_FLOOR_RATIO)


func at_floor() -> bool:
	return boss.hp <= panic_floor()


## 岩背獾下一步（回合開始前 UI 顯示前兆用）
func next_move() -> int:
	return _pattern[_pattern_index % _pattern.size()]


func telegraph_text() -> String:
	if at_floor():
		return "它的衝勁弱了下來，腳步遲疑——它聽得見你了。（安撫它！）"
	return String(MOVE_TELEGRAPH[next_move()])


func intro_events() -> Array[BattleService.BattleEvent]:
	var events: Array[BattleService.BattleEvent] = []
	events.append(BattleService.BattleEvent.make(BattleService.EVENT_MESSAGE, "金鑰外洩警報！老服務「岩背獾」驚慌暴走！"))
	events.append(_msg("它不是敵人——錯的是外洩，不是它。壓下事件等級，最後安撫（修復）它。"))
	events.append(_telegraph_event())
	return events


func take_turn(action: int, payload: Dictionary = {}) -> Array[BattleService.BattleEvent]:
	var events: Array[BattleService.BattleEvent] = []
	if outcome != Outcome.ONGOING:
		return events
	turn_count += 1
	var skip_boss := false
	match action:
		Action.SKILL:
			_resolve_skill(payload.get("skill") as SkillDef, events)
		Action.ITEM:
			_resolve_item(payload.get("item") as ItemDef, events)
		Action.SOOTHE:
			skip_boss = _resolve_soothe(events)
	if outcome == Outcome.ONGOING and not skip_boss:
		_boss_act(events)
	if outcome == Outcome.ONGOING:
		events.append(_telegraph_event())
	else:
		events.append(BattleService.BattleEvent.make(BattleService.EVENT_END, "", {"outcome": outcome}))
	return events


func _resolve_skill(skill: SkillDef, events: Array[BattleService.BattleEvent]) -> void:
	if skill == null:
		events.append(_msg("%s猶豫了！" % player.display_name))
		return
	match skill.effect:
		"slow":
			events.append(BattleService.BattleEvent.make(BattleService.EVENT_MESSAGE, "%s使出%s！嫩藤纏上了岩背獾的腳。" % [player.display_name, skill.display_name], {"attacker": "player", "fx": "vfx_grass"}))
			rooted = true
			_calm_chip(6, events)
			events.append(_msg("它的腳步慢了下來——下一次衝撞不會那麼疼了。"))
		"shield":
			events.append(BattleService.BattleEvent.make(BattleService.EVENT_MESSAGE, "%s展開%s，滑翔膜擋在你們身前！" % [player.display_name, skill.display_name], {"fx": "vfx_grass"}))
			guard_turns = 1
		"warm":
			events.append(BattleService.BattleEvent.make(BattleService.EVENT_MESSAGE, "%s的角縫透出%s的光。" % [player.display_name, skill.display_name], {"fx": "vfx_fire"}))
			var healed := player.heal(int(float(player.max_hp) * 0.22))
			events.append(BattleService.BattleEvent.make(BattleService.EVENT_PLAYER_HP, "", {"hp": player.hp, "max_hp": player.max_hp, "healed": healed}))
			attack_up = true
			events.append(_msg("恢復了 %d HP，下一擊蓄滿了熱度！" % healed))
		"dodge":
			events.append(BattleService.BattleEvent.make(BattleService.EVENT_MESSAGE, "%s踏起%s，身影在薄霧裡快了一倍！" % [player.display_name, skill.display_name], {"fx": "vfx_water"}))
			evasive = true
			extra_strike = true
			events.append(_msg("下一次攻擊能多出一步，衝撞也幾乎碰不到它。"))
		"cleanse":
			events.append(BattleService.BattleEvent.make(BattleService.EVENT_MESSAGE, "%s喚起%s，一道小潮洗過腳邊。" % [player.display_name, skill.display_name], {"fx": "vfx_water"}))
			var healed := player.heal(int(float(player.max_hp) * 0.15))
			events.append(BattleService.BattleEvent.make(BattleService.EVENT_PLAYER_HP, "", {"hp": player.hp, "max_hp": player.max_hp, "healed": healed}))
			if self_slow:
				self_slow = false
				events.append(_msg("腳步輕了回來，恢復了 %d HP。" % healed))
			else:
				events.append(_msg("恢復了 %d HP。" % healed))
		"break":
			_resolve_attack(skill, events, true)
			self_slow = true
		_:
			_resolve_attack(skill, events, false)


func _resolve_attack(skill: SkillDef, events: Array[BattleService.BattleEvent], breaks_shell: bool) -> void:
	events.append(BattleService.BattleEvent.make(BattleService.EVENT_MESSAGE, "%s使出%s！" % [player.display_name, skill.display_name], {"attacker": "player", "fx": _element_fx(skill.element)}))
	var damage := DamageCalculator.compute(player, boss, skill, _rng)
	if attack_up:
		attack_up = false
		damage = int(float(damage) * 1.5)
		events.append(_msg("暖火加持，這一擊格外扎實！"))
	var strikes := 1
	if extra_strike and skill.power > 0:
		extra_strike = false
		strikes = 2
	var total := 0
	for i in range(strikes):
		var hit := damage if i == 0 else int(float(damage) * 0.6)
		if shelled and not shell_broken and not breaks_shell:
			hit = maxi(1, int(float(hit) * 0.45))
		total += hit
	if breaks_shell and (shelled or not shell_broken):
		shelled = false
		shell_broken = true
		events.append(_msg("短角撬進岩甲的縫隙——它縮不回去了！"))
	var floor_hp := panic_floor()
	var was_at_floor := at_floor()
	boss.hp = maxi(floor_hp, boss.hp - total)
	events.append(BattleService.BattleEvent.make(BattleService.EVENT_ENEMY_HP, "", {"hp": boss.hp, "max_hp": boss.max_hp, "damage": total}))
	if was_at_floor:
		events.append(_msg("再打下去只會讓它更慌——它需要的是「安撫」。"))
	elif strikes == 2:
		events.append(_msg("連續兩段，共壓下了 %d 點恐慌！" % total))
	elif shelled and not shell_broken:
		events.append(_msg("岩甲擋掉了大半力道。（壓下 %d 點恐慌）" % total))
	else:
		events.append(_msg("壓下了 %d 點恐慌！" % total))


func _calm_chip(amount: int, events: Array[BattleService.BattleEvent]) -> void:
	var floor_hp := panic_floor()
	if boss.hp > floor_hp:
		boss.hp = maxi(floor_hp, boss.hp - amount)
		events.append(BattleService.BattleEvent.make(BattleService.EVENT_ENEMY_HP, "", {"hp": boss.hp, "max_hp": boss.max_hp, "damage": amount}))


func _resolve_item(item: ItemDef, events: Array[BattleService.BattleEvent]) -> void:
	if item == null or item.kind != ItemDef.KIND_HEAL:
		events.append(_msg("現在用不上這個。"))
		return
	events.append(BattleService.BattleEvent.make(BattleService.EVENT_CONSUME_ITEM, "", {"item_id": item.id}))
	var healed := player.heal(item.amount)
	events.append(BattleService.BattleEvent.make(BattleService.EVENT_PLAYER_HP, "", {"hp": player.hp, "max_hp": player.max_hp, "healed": healed}))
	events.append(_msg("%s恢復了 %d HP。" % [player.display_name, healed]))


func _resolve_soothe(events: Array[BattleService.BattleEvent]) -> bool:
	events.append(BattleService.BattleEvent.make(BattleService.EVENT_MESSAGE, "你放輕腳步，和夥伴一起慢慢靠近——", {"attacker": ""}))
	if at_floor():
		outcome = Outcome.SOOTHED
		events.append(BattleService.BattleEvent.make(BattleService.EVENT_MESSAGE, "岩背獾的呼吸，跟上了你們的節奏。", {"fx": "soothe", "boss_pose": "calm"}))
		events.append(_msg("它慢慢地、慢慢地，把岩甲鬆開了。"))
		return true
	events.append(_msg("它還在慌，聽不進去！先壓下它的恐慌。"))
	return false


func _boss_act(events: Array[BattleService.BattleEvent]) -> void:
	var move := next_move()
	_pattern_index += 1
	match move:
		Move.SHELL:
			if shell_broken:
				events.append(BattleService.BattleEvent.make(BattleService.EVENT_MESSAGE, "岩背獾想縮進岩甲——撬開的縫隙合不起來！", {"boss_pose": "hit"}))
			else:
				shelled = true
				events.append(BattleService.BattleEvent.make(BattleService.EVENT_MESSAGE, "岩背獾縮進岩甲裡，蓄著下一次衝撞。", {"boss_pose": "shell"}))
		Move.RAM:
			shelled = false
			_boss_attack(Move.RAM, "岩背獾驚慌地衝撞過來！", events)
			rooted = false
		Move.SNORT:
			_boss_attack(Move.SNORT, "岩背獾甩著頭撞了過來！", events)


func _boss_attack(move: int, text: String, events: Array[BattleService.BattleEvent]) -> void:
	events.append(BattleService.BattleEvent.make(BattleService.EVENT_MESSAGE, text, {"attacker": "enemy", "boss_pose": "attack"}))
	var power := int(MOVE_POWER[move])
	var skill := SkillDef.new()
	skill.display_name = "岩背獾的衝撞"
	skill.power = power
	skill.accuracy = 1.0
	var damage := DamageCalculator.compute(boss, player, skill, _rng)
	var factor := 1.0
	var note := ""
	if evasive:
		evasive = false
		factor = 0.15
		note = "霧步！%s滑到一旁，衝撞幾乎落空。" % player.display_name
	else:
		if move == Move.RAM and rooted:
			factor *= 0.35
			note = "嫩藤拖住了衝撞，力道弱了大半。"
		if guard_turns > 0:
			factor *= 0.3
			note = "葉幕撐住了！傷害被壓了下來。"
		if self_slow:
			factor *= 1.2
	if guard_turns > 0:
		guard_turns -= 1
	damage = maxi(1, int(float(damage) * factor))
	player.apply_damage(damage)
	events.append(BattleService.BattleEvent.make(BattleService.EVENT_PLAYER_HP, "", {"hp": player.hp, "max_hp": player.max_hp, "damage": damage}))
	if note.is_empty():
		events.append(_msg("受到了 %d 點傷害！" % damage))
	else:
		events.append(_msg("%s（%d）" % [note, damage]))
	if player.is_fainted():
		outcome = Outcome.DEFEAT
		events.append(_msg("%s撐不住了……你抱起它退到屋簷下。" % player.display_name))


func _element_fx(element: String) -> String:
	match element:
		"grass":
			return "vfx_grass"
		"fire":
			return "vfx_fire"
		"water":
			return "vfx_water"
		_:
			return ""


func _telegraph_event() -> BattleService.BattleEvent:
	return BattleService.BattleEvent.make(BattleService.EVENT_MESSAGE, telegraph_text(), {"telegraph": next_move(), "soothe_ready": at_floor()})


func _msg(text: String) -> BattleService.BattleEvent:
	return BattleService.BattleEvent.make(BattleService.EVENT_MESSAGE, text)
