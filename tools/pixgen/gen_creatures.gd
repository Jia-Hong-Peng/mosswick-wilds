class_name GenCreatures
extends RefCounted
## 伴獸素材產生器（潮森群島版）。
## 每隻輸出：<id>_front.png（64×64 ×2 幀 Idle）、<id>_back.png、
## <id>_hit.png（FOAM 白剪影）、<id>_antic/_attack/_weak/_calm、
## <id>_icon.png（32×32）、<id>_mini.png（16×16）、
## <id>_world.png（192×192＝6 欄 × 4 向，32×48 格、行走幀）、
## assets/portraits/<id>_<expr>.png（六表情局部立繪）。
## 剪影原則：芽翼鼯＝圓身＋葉形滑翔膜；燼角羌＝細腿短角站姿；
## 潮冠鷺＝輕身長腳浪形羽冠；岩背獾＝低寬岩甲圓頂。

const S := 64
const BASELINE := 56  # 腳底基準線

const EXPRESSIONS: Array[String] = ["neutral", "curious", "happy", "nervous", "determined", "hurt"]


static func generate() -> void:
	_export_creature("sproutwing", Callable(GenCreatures, "_sproutwing"))
	_export_creature("emberhorn", Callable(GenCreatures, "_emberhorn"))
	_export_creature("tidecrest", Callable(GenCreatures, "_tidecrest"))
	_export_creature("rockbadger", Callable(GenCreatures, "_rockbadger"))
	_export_rockbadger_shell()
	for id: String in ["sproutwing", "emberhorn", "tidecrest"]:
		_export_world_sheet(id)
		_export_portraits(id)


static func _export_creature(id: String, draw: Callable) -> void:
	var front_sheet := Pix.img(S * 2, S)
	var front0: Image
	for f in range(2):
		var frame := Pix.img(S, S)
		draw.call(frame, f, false, "neutral")
		Pix.outline_sprite(frame)
		if f == 0:
			front0 = frame
		Pix.blit(front_sheet, frame, f * S, 0)
	Pix.save(front_sheet, "res://assets/creatures/%s_front.png" % id)

	var back := Pix.img(S, S)
	draw.call(back, 0, true, "neutral")
	Pix.outline_sprite(back)
	Pix.save(back, "res://assets/creatures/%s_back.png" % id)

	# 受擊幀：前視剪影轉 FOAM 白
	var hit := Pix.img(S, S)
	for y in range(S):
		for x in range(S):
			if front0.get_pixel(x, y).a > 0.5:
				hit.set_pixel(x, y, Pal.FOAM)
	Pix.save(hit, "res://assets/creatures/%s_hit.png" % id)

	# 圖示
	var icon := front0.duplicate() as Image
	icon.resize(32, 32, Image.INTERPOLATE_NEAREST)
	Pix.save(icon, "res://assets/creatures/%s_icon.png" % id)
	var mini := front0.duplicate() as Image
	mini.resize(16, 16, Image.INTERPOLATE_NEAREST)
	Pix.save(mini, "res://assets/creatures/%s_mini.png" % id)

	# 姿勢幀：前搖（後坐蓄力）／攻擊（前撲＋速度線）／虛弱（下沉壓暗）／安定
	var antic := _shifted(front_sheet_frame(front_sheet, 1), 3, 2)
	Pix.save(antic, "res://assets/creatures/%s_antic.png" % id)
	var attack := _shifted(front0, -5, 1)
	for dash_y: int in [26, 34, 42]:
		Pix.hline(attack, 52, dash_y, 8, Pal.alpha(Pal.FOAM, 0.6))
		Pix.hline(attack, 54, dash_y + 3, 6, Pal.alpha(Pal.MIST_LT, 0.6))
	Pix.save(attack, "res://assets/creatures/%s_attack.png" % id)
	var weak := _dimmed(_shifted(front0, 0, 3), 0.45)
	Pix.save(weak, "res://assets/creatures/%s_weak.png" % id)
	# 安定：柔和表情版
	var calm := Pix.img(S, S)
	draw.call(calm, 0, false, "happy")
	Pix.outline_sprite(calm)
	Pix.save(calm, "res://assets/creatures/%s_calm.png" % id)


static func front_sheet_frame(sheet: Image, index: int) -> Image:
	var frame := Pix.img(S, S)
	frame.blit_rect(sheet, Rect2i(index * S, 0, S, S), Vector2i.ZERO)
	return frame


static func _shifted(src: Image, dx: int, dy: int) -> Image:
	var out := Pix.img(S, S)
	Pix.blit(out, src, dx, dy)
	return out


static func _dimmed(src: Image, amount: float) -> Image:
	var out := src.duplicate() as Image
	for y in range(out.get_height()):
		for x in range(out.get_width()):
			var color := out.get_pixel(x, y)
			if color.a > 0.05:
				out.set_pixel(x, y, color.lerp(Pal.SLATE, amount))
	return out


## 岩背獾「縮甲」：只剩岩甲圓頂、頭腳全收
static func _export_rockbadger_shell() -> void:
	var c := Pix.img(S, S)
	_badger_dome(c, 32.0, 44.0, 21.0, 13.0)
	Pix.outline_sprite(c)
	Pix.save(c, "res://assets/creatures/rockbadger_shell.png")


## 體積感基底：中間色主體＋左上亮面＋底部 dither 陰影
static func _volume(c: Image, cx: float, cy: float, rx: float, ry: float, dark: Color, mid: Color, light: Color) -> void:
	Pix.ellipse(c, cx, cy, rx, ry, mid)
	Pix.ellipse(c, cx - rx * 0.3, cy - ry * 0.35, rx * 0.45, ry * 0.4, light)
	for y in range(int(cy), int(cy + ry) + 1):
		for x in range(int(cx - rx), int(cx + rx) + 1):
			var dx := (float(x) - cx) / rx
			var dy := (float(y) - cy) / ry
			if dx * dx + dy * dy <= 1.0 and dy > 0.35 and (x + y) % 2 == 0:
				Pix.px(c, x, y, dark)


## 表情眼睛：依 expr 畫在指定位置（雙眼中心 lx/rx、眼線 y）
static func _creature_eyes(c: Image, lx: int, rx: int, y: int, expr: String) -> void:
	match expr:
		"happy":
			# 彎彎瞇眼
			for ex: int in [lx, rx]:
				Pix.px(c, ex - 1, y, Pal.INK)
				Pix.px(c, ex, y - 1, Pal.INK)
				Pix.px(c, ex + 1, y, Pal.INK)
		"nervous":
			Pix.rect(c, lx - 1, y - 1, 2, 3, Pal.INK)
			Pix.rect(c, rx - 1, y - 1, 2, 3, Pal.INK)
			Pix.px(c, lx, y, Pal.FOAM)
			Pix.px(c, rx, y, Pal.FOAM)
			Pix.px(c, rx + 3, y - 3, Pal.SEA_PALE)
		"determined":
			Pix.rect(c, lx - 1, y, 3, 2, Pal.INK)
			Pix.rect(c, rx - 1, y, 3, 2, Pal.INK)
			Pix.hline(c, lx - 2, y - 1, 3, Pal.INK)
			Pix.hline(c, rx, y - 1, 3, Pal.INK)
			Pix.px(c, lx, y, Pal.FOAM)
			Pix.px(c, rx, y, Pal.FOAM)
		"hurt":
			for ex: int in [lx, rx]:
				Pix.px(c, ex - 1, y - 1, Pal.INK)
				Pix.px(c, ex + 1, y - 1, Pal.INK)
				Pix.px(c, ex, y, Pal.INK)
				Pix.px(c, ex - 1, y + 1, Pal.INK)
				Pix.px(c, ex + 1, y + 1, Pal.INK)
		"curious":
			Pix.rect(c, lx - 1, y - 2, 3, 4, Pal.INK)
			Pix.rect(c, rx - 1, y - 2, 3, 4, Pal.INK)
			Pix.px(c, lx, y - 1, Pal.FOAM)
			Pix.px(c, rx, y - 1, Pal.FOAM)
		_:
			Pix.rect(c, lx - 1, y - 1, 3, 3, Pal.INK)
			Pix.px(c, lx, y, Pal.FOAM)
			Pix.rect(c, rx - 1, y - 1, 3, 3, Pal.INK)
			Pix.px(c, rx, y, Pal.FOAM)


# ---------- 芽翼鼯：亞熱帶飛鼠 × 嫩葉 × 種子。圓、軟、謹慎。 ----------

static func _sproutwing(c: Image, f: int, back_view: bool, expr: String = "neutral") -> void:
	var squash := f  # 第二幀：呼吸下沉
	var body_y := 38.0 + squash
	# 葉形滑翔膜：像披了一片完整的葉子（剪影關鍵）
	var leaf_y := body_y + 2.0
	Pix.ellipse(c, 32, leaf_y, 20, 12.0 - squash * 0.5, Pal.LEAF)
	Pix.ellipse(c, 32, leaf_y - 3, 16, 8, Pal.MOSS if back_view else Pal.LEAF)
	# 葉脈
	Pix.vline(c, 32, int(leaf_y) - 8, 16, Pal.MOSS)
	for i in range(3):
		Pix.hline(c, 20 + i * 2, int(leaf_y) - 2 + i * 3, 24 - i * 4, Pal.alpha(Pal.MOSS, 0.7))
	# 膜緣鋸齒
	for i in range(7):
		Pix.px(c, 13 + i * 6, int(leaf_y) + 10 - (i % 2), Pal.LEAF_LT)
	# 身體：圓潤小獸
	if back_view:
		_volume(c, 32, body_y - 6, 12, 10, Pal.MOSS, Pal.MOSS, Pal.LEAF)
	else:
		_volume(c, 32, body_y - 4, 12, 10, Pal.MOSS, Pal.LEAF, Pal.LEAF_LT)
		# 暖米色腹部
		Pix.ellipse(c, 32, body_y + 1, 8, 6, Pal.SAND_LT)
		Pix.ellipse(c, 32, body_y, 6, 4, Pal.PAPER)
	# 頭：大而圓
	var head_y := 24.0 + squash
	if back_view:
		_volume(c, 32, head_y, 11, 9, Pal.MOSS, Pal.MOSS, Pal.LEAF)
	else:
		_volume(c, 32, head_y, 11, 9, Pal.MOSS, Pal.LEAF, Pal.LEAF_LT)
	# 耳：耳尖帶嫩芽輪廓
	var ear_sway := f
	for side: int in [-1, 1]:
		var ex := 32 + side * 8
		Pix.ellipse(c, ex, head_y - 8, 3, 4, Pal.MOSS)
		Pix.px(c, ex + side, int(head_y) - 12 - ear_sway, Pal.SPROUT)
		Pix.px(c, ex + side, int(head_y) - 11 - ear_sway, Pal.SPROUT)
		Pix.px(c, ex, int(head_y) - 8, Pal.SAND_LT)
	# 尾巴：末端種子
	var tail_x := 50
	Pix.vline(c, tail_x, int(body_y) - 4, 8, Pal.WOOD)
	Pix.px(c, tail_x + 1, int(body_y) - 6, Pal.WOOD)
	Pix.ellipse(c, tail_x + 2, body_y - 9 - f, 3, 3.5, Pal.SPROUT)
	Pix.px(c, tail_x + 1, int(body_y) - 11 - f, Pal.LEAF_LT)
	# 前爪搭在膜上
	if not back_view:
		Pix.rect(c, 26, int(body_y) + 6, 3, 2, Pal.SAND)
		Pix.rect(c, 35, int(body_y) + 6, 3, 2, Pal.SAND)
		# 臉
		_creature_eyes(c, 27, 37, int(head_y), expr)
		Pix.px(c, 32, int(head_y) + 3, Pal.INK)
		Pix.px(c, 31, int(head_y) + 4, Pal.WOOD_DK)
		Pix.px(c, 33, int(head_y) + 4, Pal.WOOD_DK)
		# 頰上小葉紋
		Pix.px(c, 23, int(head_y) + 3, Pal.SPROUT)
		Pix.px(c, 41, int(head_y) + 3, Pal.SPROUT)


# ---------- 燼角羌：山羌 × 木炭 × 地熱火種。細腿、短角、站姿有力。 ----------

static func _emberhorn(c: Image, f: int, back_view: bool, expr: String = "neutral") -> void:
	var toss := f  # 第二幀：抬頭、角光轉旺
	# 身體：炭棕小鹿軀幹
	_volume(c, 31, 34, 14, 9, Pal.WOOD_DK, Pal.WOOD, Pal.SAND)
	# 頸部火星短毛
	Pix.rect(c, 36, 22, 5, 10, Pal.WOOD_DK)
	Pix.speckle(c, 35, 22, 7, 10, Pal.AMBER, 6, 41)
	Pix.speckle(c, 36, 24, 5, 8, Pal.CORAL, 3, 42)
	# 四肢：纖細但站姿有力
	for leg: Array in [[22, 0], [27, 1], [37, 0], [43, 1]]:
		var lx := int(leg[0])
		var back_leg := int(leg[1]) == 1
		Pix.rect(c, lx, 41, 2, BASELINE - 41, Pal.NIGHT if back_leg else Pal.WOOD_DK)
		Pix.px(c, lx, BASELINE - 1, Pal.INK)
		# 蹄印暖光
		if not back_leg:
			Pix.px(c, lx, BASELINE, Pal.alpha(Pal.CORAL_LT, 0.7))
	# 尾：短翹
	Pix.rect(c, 18, 30, 3, 2, Pal.WOOD_DK)
	Pix.px(c, 17, 29, Pal.SAND)
	# 頭：小巧、前傾
	var head_cx := 42.0
	var head_cy := 18.0 - toss
	if back_view:
		_volume(c, 32, head_cy + 2, 8, 7, Pal.WOOD_DK, Pal.WOOD, Pal.SAND)
		Pix.rect(c, 30, 8 - toss, 2, 5, Pal.NIGHT)
		Pix.rect(c, 34, 8 - toss, 2, 5, Pal.NIGHT)
		Pix.px(c, 31, 10 - toss, Pal.AMBER_LT)
		Pix.px(c, 35, 10 - toss, Pal.AMBER_LT)
		return
	_volume(c, head_cx, head_cy, 8, 7, Pal.WOOD_DK, Pal.WOOD, Pal.SAND)
	# 口鼻
	Pix.rect(c, int(head_cx) + 5, int(head_cy) + 1, 4, 4, Pal.SAND)
	Pix.px(c, int(head_cx) + 8, int(head_cy) + 2, Pal.INK)
	# 大耳
	Pix.ellipse(c, head_cx - 6, head_cy - 5, 3, 4, Pal.WOOD)
	Pix.px(c, int(head_cx) - 6, int(head_cy) - 5, Pal.SAND)
	# 兩枚未長成的炭黑短角＋角縫橙光（剪影與辨識關鍵）
	for side: int in [-1, 3]:
		var hx := int(head_cx) - 2 + side
		Pix.rect(c, hx, int(head_cy) - 11, 2, 6, Pal.NIGHT)
		Pix.px(c, hx, int(head_cy) - 12, Pal.INK)
	# 角縫光：第二幀更亮
	var glow := Pal.CORAL_LT if toss == 1 else Pal.AMBER
	Pix.px(c, int(head_cx), int(head_cy) - 9, glow)
	Pix.px(c, int(head_cx), int(head_cy) - 7, Pal.AMBER if toss == 1 else Pal.AMBER_DK)
	# 臉
	_creature_eyes(c, int(head_cx) - 2, int(head_cx) + 3, int(head_cy) - 1, expr)


# ---------- 潮冠鷺：幼鷺 × 潮汐 × 水滴。輕、快、好奇。 ----------

static func _tidecrest(c: Image, f: int, back_view: bool, expr: String = "neutral") -> void:
	var bob := f  # 第二幀：羽冠與身體輕彈
	# 長腳：還沒長成，略顯笨拙（一直一彎）
	Pix.vline(c, 29, 40, BASELINE - 40, Pal.AMBER_DK)
	Pix.vline(c, 36, 42, BASELINE - 44, Pal.AMBER_DK)
	Pix.px(c, 37, BASELINE - 3, Pal.AMBER_DK)
	Pix.px(c, 38, BASELINE - 2, Pal.AMBER_DK)
	for fx: int in [27, 34]:
		Pix.hline(c, fx, BASELINE - 1, 5, Pal.AMBER)
	# 身體：輕盈的水滴形
	_volume(c, 32, 33 + bob, 12, 10, Pal.SEA, Pal.FOAM, Pal.PAPER)
	if back_view:
		Pix.ellipse(c, 32, 32 + bob, 10, 8, Pal.SEA_PALE)
	# 翅緣：透明魚鰭感（半透明海藍）
	for i in range(8):
		var wx := 20 + i
		Pix.vline(c, wx, 34 + bob + i / 3, 5 - i / 3, Pal.alpha(Pal.SEA_LT, 0.65))
	for i in range(8):
		var wx := 44 - i
		Pix.vline(c, wx + 0, 34 + bob + i / 3, 5 - i / 3, Pal.alpha(Pal.SEA_LT, 0.65))
	# 尾羽小簇
	Pix.rect(c, 22, 30 + bob, 3, 3, Pal.SEA)
	# 頭：小而高
	var head_cy := 17.0 + bob
	_volume(c, 34, head_cy, 8, 7, Pal.SEA, Pal.FOAM, Pal.PAPER)
	# 浪形羽冠：向後捲起（剪影關鍵）
	var crest_lift := bob
	for i in range(7):
		Pix.px(c, 30 - i, int(head_cy) - 8 - i / 2 + crest_lift, Pal.SEA)
		Pix.px(c, 30 - i, int(head_cy) - 9 - i / 2 + crest_lift, Pal.SEA_LT)
	Pix.px(c, 23, int(head_cy) - 12 + crest_lift, Pal.FOAM)
	Pix.px(c, 24, int(head_cy) - 13 + crest_lift, Pal.SEA_PALE)
	Pix.px(c, 25, int(head_cy) - 12 + crest_lift, Pal.SEA_LT)
	if back_view:
		Pix.ellipse(c, 34, head_cy, 6, 5, Pal.SEA_PALE)
		return
	# 長喙：靈巧
	Pix.rect(c, int(34) + 6, int(head_cy), 7, 2, Pal.AMBER)
	Pix.px(c, 46, int(head_cy) + 1, Pal.AMBER_DK)
	# 臉：好奇的大眼（單側視角感）
	_creature_eyes(c, 31, 37, int(head_cy) - 1, expr)
	# 頰上青綠小斑
	Pix.px(c, 28, int(head_cy) + 3, Pal.SPROUT)


# ---------- 岩背獾：厚重岩甲、受驚會縮殼衝撞。低、寬、重。 ----------

static func _badger_dome(c: Image, cx: float, cy: float, rx: float, ry: float) -> void:
	_volume(c, cx, cy - 6, rx, ry, Pal.SLATE, Pal.STEEL, Pal.MIST_LT)
	# 岩甲裂紋與刮傷
	for p: Array in [[22, 28, 6], [34, 24, 5], [40, 32, 4], [27, 35, 5]]:
		var px0 := int(p[0])
		var py0 := int(p[1])
		for i in range(int(p[2])):
			Pix.px(c, px0 + i, py0 + i / 2, Pal.SLATE)
	# 施工刮傷：鏽紅色的新傷（劇情細節）
	Pix.hline(c, 36, 26, 6, Pal.RUST)
	Pix.hline(c, 37, 28, 5, Pal.RUST_DK)
	Pix.speckle(c, 18, 24, 28, 12, Pal.MIST, 8, 51)


static func _rockbadger(c: Image, f: int, back_view: bool, expr: String = "neutral") -> void:
	var breath := f
	# 岩甲圓頂（剪影關鍵）
	_badger_dome(c, 32.0, 38.0 + breath, 20.0, 14.0)
	if back_view:
		Pix.ellipse(c, 32, 48, 12, 5, Pal.WOOD_DK)
		Pix.rect(c, 30, 50, 4, 3, Pal.WOOD)
		return
	# 頭：從甲下探出，白色臉紋
	var head_cy := 44 + breath
	_volume(c, 32, head_cy, 11, 7, Pal.WOOD_DK, Pal.WOOD, Pal.SAND)
	Pix.rect(c, 30, head_cy - 6, 4, 8, Pal.PAPER)
	Pix.rect(c, 24, head_cy - 4, 2, 6, Pal.PAPER_DIM)
	Pix.rect(c, 38, head_cy - 4, 2, 6, Pal.PAPER_DIM)
	# 鼻
	Pix.rect(c, 31, head_cy + 2, 3, 2, Pal.INK)
	# 眼（受驚時瞪大）
	if expr == "happy":
		_creature_eyes(c, 27, 38, head_cy - 2, "happy")
	else:
		Pix.rect(c, 26, head_cy - 3, 3, 3, Pal.INK)
		Pix.rect(c, 37, head_cy - 3, 3, 3, Pal.INK)
		Pix.px(c, 27, head_cy - 2, Pal.FOAM)
		Pix.px(c, 38, head_cy - 2, Pal.FOAM)
	# 爪：粗短有力
	for foot_x: int in [18, 26, 36, 43]:
		Pix.rect(c, foot_x, BASELINE - 4, 4, 4, Pal.WOOD_DK)
		Pix.px(c, foot_x, BASELINE - 1, Pal.SAND)
		Pix.px(c, foot_x + 2, BASELINE - 1, Pal.SAND)


# ---------- 世界行走圖（6 欄 × 4 向、32×48 格） ----------

static func _export_world_sheet(id: String) -> void:
	var sheet := Pix.img(192, 192)
	for row in range(4):  # 0 down, 1 up, 2 left, 3 right
		for col in range(6):
			var cell := Pix.img(32, 48)
			var lift := 0
			if col == 1 or col == 4:
				lift = 1
			_world_frame(cell, id, row, lift, col)
			Pix.outline_sprite(cell)
			Pix.blit(sheet, cell, col * 32, row * 48)
	Pix.save(sheet, "res://assets/creatures/%s_world.png" % id)


## 小型行走幀：底部貼齊 46；朝向 row（0下 1上 2左 3右）
static func _world_frame(c: Image, id: String, row: int, lift: int, col: int) -> void:
	var ground := 46 - lift
	match id:
		"sproutwing":
			_world_sproutwing(c, row, ground, col)
		"emberhorn":
			_world_emberhorn(c, row, ground, col)
		"tidecrest":
			_world_tidecrest(c, row, ground, col)


static func _world_sproutwing(c: Image, row: int, ground: int, col: int) -> void:
	var body_y := ground - 8
	# 葉膜披風
	Pix.ellipse(c, 16, body_y, 9, 6, Pal.LEAF)
	Pix.ellipse(c, 16, body_y - 2, 7, 4, Pal.MOSS)
	# 身體與頭
	Pix.ellipse(c, 16, body_y - 6, 6, 5, Pal.LEAF if row != 1 else Pal.MOSS)
	# 耳芽
	Pix.px(c, 12, body_y - 12, Pal.SPROUT)
	Pix.px(c, 20, body_y - 12, Pal.SPROUT)
	Pix.ellipse(c, 12, body_y - 10, 1.5, 2, Pal.MOSS)
	Pix.ellipse(c, 20, body_y - 10, 1.5, 2, Pal.MOSS)
	# 種子尾（左右側身時在身後；正/背面在側邊）
	var tail_x := 24 if row != 2 else 8
	Pix.vline(c, tail_x, body_y - 4, 5, Pal.WOOD)
	Pix.ellipse(c, tail_x, body_y - 6, 1.8, 2, Pal.SPROUT)
	match row:
		0:
			Pix.ellipse(c, 16, body_y - 4, 4, 3, Pal.SAND_LT)
			Pix.rect(c, 13, body_y - 7, 2, 2, Pal.INK)
			Pix.rect(c, 18, body_y - 7, 2, 2, Pal.INK)
			Pix.px(c, 13, body_y - 7, Pal.FOAM)
			Pix.px(c, 18, body_y - 7, Pal.FOAM)
		2:
			Pix.rect(c, 12, body_y - 7, 2, 2, Pal.INK)
			Pix.px(c, 12, body_y - 7, Pal.FOAM)
		3:
			Pix.rect(c, 19, body_y - 7, 2, 2, Pal.INK)
			Pix.px(c, 19, body_y - 7, Pal.FOAM)
	# 小腳（walk 幀交替）
	var step := col % 2
	Pix.rect(c, 12 + step, ground - 2, 3, 2, Pal.SAND)
	Pix.rect(c, 18 - step, ground - 2, 3, 2, Pal.SAND)


static func _world_emberhorn(c: Image, row: int, ground: int, col: int) -> void:
	var body_y := ground - 10
	# 軀幹
	Pix.ellipse(c, 16, body_y, 8, 5, Pal.WOOD)
	Pix.ellipse(c, 14, body_y - 1, 4, 3, Pal.SAND)
	# 細腿（walk 交替）
	var step := col % 2
	Pix.vline(c, 11 + step, body_y + 3, ground - body_y - 3, Pal.WOOD_DK)
	Pix.vline(c, 14 - step, body_y + 3, ground - body_y - 3, Pal.NIGHT)
	Pix.vline(c, 19 + step, body_y + 3, ground - body_y - 3, Pal.WOOD_DK)
	Pix.vline(c, 22 - step, body_y + 3, ground - body_y - 3, Pal.NIGHT)
	# 蹄光
	Pix.px(c, 11 + step, ground, Pal.alpha(Pal.CORAL_LT, 0.7))
	# 頭與短角
	var head_x := 16
	if row == 2:
		head_x = 10
	elif row == 3:
		head_x = 22
	var head_y := body_y - 8
	Pix.ellipse(c, head_x, head_y, 4, 4, Pal.WOOD)
	Pix.rect(c, head_x - 3, head_y - 7, 2, 4, Pal.NIGHT)
	Pix.rect(c, head_x + 2, head_y - 7, 2, 4, Pal.NIGHT)
	Pix.px(c, head_x, head_y - 5, Pal.AMBER)
	# 頸部火星
	Pix.speckle(c, head_x - 2, head_y + 2, 5, 4, Pal.AMBER, 3, 43)
	match row:
		0:
			Pix.rect(c, head_x - 2, head_y - 1, 2, 2, Pal.INK)
			Pix.rect(c, head_x + 1, head_y - 1, 2, 2, Pal.INK)
		2:
			Pix.rect(c, head_x - 2, head_y - 1, 2, 2, Pal.INK)
		3:
			Pix.rect(c, head_x + 1, head_y - 1, 2, 2, Pal.INK)


static func _world_tidecrest(c: Image, row: int, ground: int, col: int) -> void:
	var body_y := ground - 12
	# 長腳（walk 大步交替）
	var step := col % 2
	Pix.vline(c, 13 + step * 2, body_y + 4, ground - body_y - 4, Pal.AMBER_DK)
	Pix.vline(c, 19 - step * 2, body_y + 4, ground - body_y - 4, Pal.AMBER_DK)
	Pix.hline(c, 12 + step * 2, ground - 1, 3, Pal.AMBER)
	Pix.hline(c, 18 - step * 2, ground - 1, 3, Pal.AMBER)
	# 身體
	Pix.ellipse(c, 16, body_y, 7, 5, Pal.FOAM)
	Pix.ellipse(c, 16, body_y + 1, 5, 3, Pal.PAPER)
	# 翅緣
	Pix.hline(c, 10, body_y + 2, 4, Pal.alpha(Pal.SEA_LT, 0.7))
	Pix.hline(c, 18, body_y + 2, 4, Pal.alpha(Pal.SEA_LT, 0.7))
	# 頭與浪形羽冠
	var head_x := 16
	if row == 2:
		head_x = 11
	elif row == 3:
		head_x = 21
	var head_y := body_y - 8
	Pix.ellipse(c, head_x, head_y, 4, 3.5, Pal.FOAM)
	var crest_dir := -1 if row != 2 else 1
	for i in range(4):
		Pix.px(c, head_x + crest_dir * (2 + i), head_y - 3 - i / 2, Pal.SEA)
	Pix.px(c, head_x + crest_dir * 5, head_y - 5, Pal.SEA_PALE)
	# 喙
	if row == 2:
		Pix.hline(c, head_x - 7, head_y, 4, Pal.AMBER)
	elif row == 3:
		Pix.hline(c, head_x + 3, head_y, 4, Pal.AMBER)
	elif row == 0:
		Pix.vline(c, head_x, head_y + 2, 3, Pal.AMBER)
	match row:
		0:
			Pix.rect(c, head_x - 2, head_y - 1, 2, 2, Pal.INK)
			Pix.rect(c, head_x + 1, head_y - 1, 2, 2, Pal.INK)
		2:
			Pix.rect(c, head_x - 2, head_y - 1, 2, 2, Pal.INK)
		3:
			Pix.rect(c, head_x + 1, head_y - 1, 2, 2, Pal.INK)


# ---------- 局部立繪（40×48、六表情） ----------

static func _export_portraits(id: String) -> void:
	var draw := Callable(GenCreatures, "_" + id)
	for expr in EXPRESSIONS:
		var full := Pix.img(S, S)
		draw.call(full, 0, false, expr)
		Pix.outline_sprite(full)
		# 頭部特寫：裁 40×48 視窗（各自對準頭部）
		var crop_origin := Vector2i(12, 8)
		match id:
			"emberhorn":
				crop_origin = Vector2i(22, 2)
			"tidecrest":
				crop_origin = Vector2i(16, 0)
		var portrait := Pix.img(40, 48)
		portrait.blit_rect(full, Rect2i(crop_origin.x, crop_origin.y, 40, 48), Vector2i.ZERO)
		Pix.save(portrait, "res://assets/portraits/%s_%s.png" % [id, expr])
