class_name GenCreatures
extends RefCounted
## 夥伴素材產生器（GHAS 宣導版）。
## 每隻輸出：<id>_front.png（64×64 ×2 幀 Idle）、<id>_back.png、
## <id>_hit.png（FOAM 白剪影）、<id>_antic/_attack/_weak/_calm、
## <id>_icon.png（32×32）、<id>_mini.png（16×16）、
## <id>_world.png（192×192＝6 欄 × 4 向，32×48 格、行走幀）、
## assets/portraits/<id>_<expr>.png（六表情局部立繪）。
## 剪影原則：鎖鱗甲＝直立穿山甲・鱗甲斗篷＋粗尾；啄錯鳥＝紅冠啄木鳥・樁上直立；
## 理木狸＝厚實河狸・格紋大尾＋門牙；馱庫龜＝低寬岩紋龜殼・柱腿。

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


## 馱庫龜「縮甲」：只剩龜殼圓頂、頭腳全收
static func _export_rockbadger_shell() -> void:
	var c := Pix.img(S, S)
	_tortoise_shell(c, 32.0, 44.0, 21.0, 13.0)
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


## 鱗片：一枚帶亮邊與暗緣的小鱗（鎖鱗甲共用）
static func _scale_px(c: Image, sx: int, sy: int, base: Color, lit: Color, dark: Color) -> void:
	Pix.ellipse(c, sx, sy, 3.0, 2.4, base)
	Pix.px(c, sx - 1, sy - 1, lit)
	Pix.px(c, sx, sy + 2, dark)
	Pix.px(c, sx - 2, sy + 1, dark)


# ---------- 鎖鱗甲：穿山甲 × 上鎖的鱗甲。圓、低、謹慎。 ----------

static func _sproutwing(c: Image, f: int, back_view: bool, expr: String = "neutral") -> void:
	var squash := f  # 第二幀：呼吸下沉、鱗甲微收
	var body_y := 38.0 + squash
	var head_y := 22 + squash
	# 鱗甲斗篷：背後大圓頂（剪影關鍵）
	if back_view:
		_volume(c, 32, body_y - 4, 16, 14, Pal.MOSS_DK, Pal.MOSS, Pal.LEAF)
		for ry_i in range(4):
			var sy := 28 + ry_i * 6 + squash
			var offset := (ry_i % 2) * 4
			for xi in range(6):
				var sx := 15 + xi * 7 + offset
				var ddx := (float(sx) - 32.0) / 16.0
				var ddy := (float(sy) - (body_y - 4.0)) / 14.0
				if ddx * ddx + ddy * ddy <= 0.9:
					_scale_px(c, sx, sy, Pal.LEAF, Pal.LEAF_LT, Pal.MOSS_DK)
		# 後腦鱗帽與粗尾
		Pix.ellipse(c, 32, head_y, 8, 7, Pal.MOSS)
		_scale_px(c, 29, head_y - 3, Pal.LEAF, Pal.LEAF_LT, Pal.MOSS_DK)
		_scale_px(c, 35, head_y - 3, Pal.LEAF, Pal.LEAF_LT, Pal.MOSS_DK)
		Pix.ellipse(c, 46, 51.0, 7, 4, Pal.MOSS)
		_scale_px(c, 44, 50, Pal.LEAF, Pal.LEAF_LT, Pal.MOSS_DK)
		return
	# 前視：鱗甲斗篷在後、米白肚皮在前（painter 疊法）
	Pix.ellipse(c, 32, body_y - 2, 16, 13.0 - squash * 0.5, Pal.MOSS)
	Pix.ellipse(c, 27, body_y - 8, 6, 5, Pal.LEAF)
	for ry_i in range(3):
		var sy := 30 + ry_i * 7 + squash
		var offset := (ry_i % 2) * 4
		for xi in range(6):
			var sx := 14 + xi * 7 + offset
			var ddx := (float(sx) - 32.0) / 16.0
			var ddy := (float(sy) - (body_y - 2.0)) / 13.0
			if ddx * ddx + ddy * ddy <= 0.95 and absf(float(sx) - 32.0) > 6.0:
				_scale_px(c, sx, sy, Pal.LEAF, Pal.LEAF_LT, Pal.MOSS_DK)
	# 肚皮與鑰匙孔胸紋（辨識關鍵：秘密鎖在這裡）
	Pix.ellipse(c, 32, body_y + 2, 8, 9, Pal.SAND_LT)
	Pix.ellipse(c, 30, body_y - 1, 4, 4, Pal.PAPER)
	Pix.ellipse(c, 32, body_y + 1, 1.6, 1.6, Pal.WOOD_DK)
	Pix.vline(c, 32, int(body_y) + 2, 3, Pal.WOOD_DK)
	# 粗尾捲到身前右側（鱗片包覆）
	Pix.ellipse(c, 45, 51.0, 8, 4, Pal.MOSS)
	_scale_px(c, 43, 50, Pal.LEAF, Pal.LEAF_LT, Pal.MOSS_DK)
	_scale_px(c, 49, 51, Pal.LEAF, Pal.LEAF_LT, Pal.MOSS_DK)
	Pix.px(c, 52, 49, Pal.LEAF_LT)
	# 前爪抱在肚皮下緣
	Pix.rect(c, 26, int(body_y) + 8, 3, 2, Pal.SAND)
	Pix.rect(c, 35, int(body_y) + 8, 3, 2, Pal.SAND)
	# 頭：淡色小臉＋鱗帽瀏海
	Pix.ellipse(c, 32, head_y, 9, 8, Pal.SAND)
	Pix.ellipse(c, 30, head_y - 2, 4, 3, Pal.SAND_LT)
	for i in range(5):
		_scale_px(c, 24 + i * 4, head_y - 6, Pal.LEAF, Pal.LEAF_LT, Pal.MOSS_DK)
	for i in range(4):
		Pix.px(c, 26 + i * 4, head_y - 9, Pal.MOSS)
	# 小耳
	Pix.px(c, 23, head_y - 2, Pal.SAND_DK)
	Pix.px(c, 41, head_y - 2, Pal.SAND_DK)
	# 尖吻與鼻
	Pix.px(c, 32, head_y + 4, Pal.INK)
	Pix.px(c, 31, head_y + 5, Pal.WOOD_DK)
	Pix.px(c, 33, head_y + 5, Pal.WOOD_DK)
	# 臉
	_creature_eyes(c, 27, 37, head_y, expr)


# ---------- 啄錯鳥：啄木鳥 × 掃描紅冠。直立、俐落、好勝。 ----------

static func _emberhorn(c: Image, f: int, back_view: bool, expr: String = "neutral") -> void:
	var toss := f  # 第二幀：抬頭、冠羽轉旺
	# 棲樁：站在小木樁上（剪影地座）
	Pix.rect(c, 24, 48, 16, 8, Pal.WOOD)
	Pix.ellipse(c, 32, 48.0, 8, 2, Pal.WOOD_LT)
	Pix.hline(c, 28, 48, 8, Pal.WOOD_DK)
	Pix.vline(c, 26, 50, 5, Pal.WOOD_DK)
	Pix.vline(c, 37, 51, 4, Pal.WOOD_DK)
	if back_view:
		# 背視：黑背＋白階紋＋紅冠
		_volume(c, 31, 34, 9, 11, Pal.INK, Pal.NIGHT, Pal.SLATE)
		for i in range(4):
			Pix.hline(c, 26, 28 + i * 5, 11, Pal.PAPER_DIM)
		Pix.rect(c, 36, 42, 3, 8, Pal.NIGHT)
		Pix.ellipse(c, 31, 17.0 - toss, 8, 7, Pal.NIGHT)
		for i in range(5):
			Pix.px(c, 27 + i * 2, 9 - toss - (i % 2), Pal.CORAL)
			Pix.px(c, 27 + i * 2, 8 - toss - (i % 2), Pal.CORAL_LT)
		return
	# 硬尾羽撐住樁緣（啄木鳥站姿關鍵）
	Pix.rect(c, 38, 42, 3, 8, Pal.NIGHT)
	Pix.px(c, 40, 50, Pal.INK)
	# 身體：直立水滴形・黑羽
	_volume(c, 31, 34, 9, 11, Pal.INK, Pal.NIGHT, Pal.SLATE)
	# 白肚
	Pix.ellipse(c, 29, 38.0, 5, 7, Pal.PAPER)
	Pix.ellipse(c, 29, 41.0, 4, 4, Pal.PAPER_DIM)
	# 翼上白斑階紋（掃描點陣的意象）
	for i in range(3):
		Pix.hline(c, 35, 30 + i * 4, 4 - i, Pal.PAPER)
		Pix.hline(c, 22 + i, 31 + i * 4, 3, Pal.PAPER_DIM)
	# 頭：白臉黑帽
	var head_y := 17 - toss
	Pix.ellipse(c, 31, head_y, 8, 7, Pal.PAPER)
	Pix.ellipse(c, 31, head_y - 4.0, 8, 4, Pal.NIGHT)
	# 紅冠羽：掃描的光（剪影與辨識關鍵；第二幀更旺）
	for i in range(5):
		var cx := 27 + i * 2
		Pix.px(c, cx, head_y - 8 - (i % 2), Pal.CORAL)
		Pix.px(c, cx, head_y - 9 - (i % 2), Pal.CORAL_LT)
	if toss == 1:
		Pix.px(c, 31, head_y - 11, Pal.AMBER)
		Pix.px(c, 33, head_y - 10, Pal.AMBER_LT)
	# 頰上橙斑
	Pix.px(c, 24, head_y + 2, Pal.CORAL_LT)
	Pix.px(c, 38, head_y + 2, Pal.CORAL_LT)
	# 鑿子喙：短而有力、朝下待啄
	Pix.rect(c, 30, head_y + 3, 3, 2, Pal.AMBER_DK)
	Pix.px(c, 31, head_y + 5, Pal.AMBER_DK)
	Pix.px(c, 31, head_y + 6, Pal.INK)
	# 抓樁爪
	Pix.px(c, 27, 47, Pal.AMBER_DK)
	Pix.px(c, 28, 47, Pal.AMBER_DK)
	Pix.px(c, 34, 47, Pal.AMBER_DK)
	Pix.px(c, 35, 47, Pal.AMBER_DK)
	# 臉
	_creature_eyes(c, 27, 35, head_y - 1, expr)


# ---------- 理木狸：河狸 × 整理成癖。厚實、勤快、較真。 ----------

static func _tidecrest(c: Image, f: int, back_view: bool, expr: String = "neutral") -> void:
	var bob := f  # 第二幀：啃木、尾巴抬起
	# 格紋大尾：攤在右側地上（剪影關鍵）
	var tail_y := 52.0 - bob
	Pix.ellipse(c, 46, tail_y, 8, 3.5, Pal.WOOD_DK)
	for gy in range(int(tail_y) - 2, int(tail_y) + 3):
		for gx in range(39, 54):
			if (gx + gy) % 3 == 0 and absf(float(gx) - 46.0) < 7.5:
				Pix.px(c, gx, gy, Pal.INK)
	Pix.px(c, 40, int(tail_y) - 1, Pal.WOOD)
	if back_view:
		_volume(c, 31, 36, 13, 12, Pal.WOOD_DK, Pal.WOOD, Pal.WOOD_LT)
		Pix.ellipse(c, 31, 22.0 + bob, 9, 8, Pal.WOOD)
		Pix.ellipse(c, 24, 15.0 + bob, 2.5, 2.5, Pal.WOOD_DK)
		Pix.ellipse(c, 38, 15.0 + bob, 2.5, 2.5, Pal.WOOD_DK)
		Pix.speckle(c, 24, 18, 14, 8, Pal.SEA_LT, 5, 61)
		return
	# 身體：厚實坐姿
	_volume(c, 31, 38, 12, 11, Pal.WOOD_DK, Pal.WOOD, Pal.WOOD_LT)
	# 淺色肚皮
	Pix.ellipse(c, 31, 41.0, 8, 7, Pal.SAND)
	Pix.ellipse(c, 29, 38.0, 4, 3, Pal.SAND_LT)
	# 理好的木料：前爪按著一塊板（整理成果＝辨識關鍵）
	var plank_y := 45 + bob
	Pix.rect(c, 22, plank_y, 18, 3, Pal.SAND_LT)
	Pix.hline(c, 23, plank_y + 1, 16, Pal.SAND_DK)
	Pix.vline(c, 26, plank_y, 3, Pal.SAND_DK)
	Pix.vline(c, 34, plank_y, 3, Pal.SAND_DK)
	Pix.rect(c, 25, plank_y - 2, 3, 3, Pal.WOOD_LT)
	Pix.rect(c, 35, plank_y - 2, 3, 3, Pal.WOOD_LT)
	# 頭：圓臉鼓頰
	var head_y := 22 + bob
	Pix.ellipse(c, 32, head_y, 10, 8, Pal.WOOD)
	Pix.ellipse(c, 25, head_y + 2.0, 3, 3, Pal.WOOD_LT)
	Pix.ellipse(c, 39, head_y + 2.0, 3, 3, Pal.WOOD_LT)
	# 圓耳
	Pix.ellipse(c, 24, head_y - 7.0, 2.5, 2.5, Pal.WOOD_DK)
	Pix.px(c, 24, head_y - 7, Pal.SAND)
	Pix.ellipse(c, 40, head_y - 7.0, 2.5, 2.5, Pal.WOOD_DK)
	Pix.px(c, 40, head_y - 7, Pal.SAND)
	# 口鼻與大門牙（辨識關鍵）
	Pix.ellipse(c, 32, head_y + 4.0, 5, 3.5, Pal.SAND)
	Pix.rect(c, 31, head_y + 2, 3, 2, Pal.WOOD_DK)
	Pix.px(c, 32, head_y + 3, Pal.INK)
	Pix.rect(c, 30, head_y + 5, 2, 3, Pal.PAPER)
	Pix.rect(c, 33, head_y + 5, 2, 3, Pal.PAPER)
	Pix.vline(c, 32, head_y + 5, 3, Pal.PAPER_DIM)
	# 濕亮毛與水珠（水系氣質）
	Pix.speckle(c, 25, head_y - 5, 14, 5, Pal.SEA_LT, 4, 62)
	Pix.px(c, 42, head_y - 2 + bob, Pal.SEA_PALE)
	# 臉
	_creature_eyes(c, 27, 37, head_y, expr)


# ---------- 馱庫龜：馱著十年舊程式庫的老龜。低、寬、重。 ----------

static func _tortoise_shell(c: Image, cx: float, cy: float, rx: float, ry: float) -> void:
	_volume(c, cx, cy - 6, rx, ry, Pal.SLATE, Pal.STEEL, Pal.MIST_LT)
	# 甲板裂紋與刮傷（跑了十年的痕跡）
	for p: Array in [[22, 28, 6], [34, 24, 5], [40, 32, 4], [27, 35, 5]]:
		var px0 := int(p[0])
		var py0 := int(p[1])
		for i in range(int(p[2])):
			Pix.px(c, px0 + i, py0 + i / 2, Pal.SLATE)
	# 鏽紅色的新傷（外洩事件的劇情細節）
	Pix.hline(c, 40, 31, 6, Pal.RUST)
	Pix.hline(c, 41, 33, 5, Pal.RUST_DK)
	Pix.speckle(c, 18, 22, 28, 10, Pal.MIST, 8, 51)


static func _rockbadger(c: Image, f: int, back_view: bool, expr: String = "neutral") -> void:
	var breath := f
	# 龜殼圓頂（剪影關鍵）
	_tortoise_shell(c, 32.0, 38.0 + breath, 20.0, 14.0)
	if back_view:
		Pix.ellipse(c, 32, 48.0, 12, 5, Pal.WOOD_DK)
		Pix.px(c, 32, 52, Pal.WOOD)
		return
	# 腹甲：把殼、頭、腿連成一體
	Pix.ellipse(c, 32, 47.0 + breath, 15, 5, Pal.WOOD)
	Pix.hline(c, 20, 49 + breath, 24, Pal.WOOD_DK)
	# 皺頸：從殼下探出
	var head_cy := 44 + breath
	Pix.rect(c, 29, head_cy - 6, 6, 6, Pal.WOOD)
	Pix.hline(c, 29, head_cy - 4, 6, Pal.WOOD_DK)
	Pix.hline(c, 29, head_cy - 2, 6, Pal.WOOD_DK)
	# 頭：圓鈍龜首
	_volume(c, 32, head_cy, 10, 6, Pal.WOOD_DK, Pal.WOOD, Pal.SAND)
	# 龜喙與鼻孔
	Pix.hline(c, 29, head_cy + 3, 7, Pal.WOOD_DK)
	Pix.px(c, 31, head_cy + 1, Pal.INK)
	Pix.px(c, 33, head_cy + 1, Pal.INK)
	# 眼（受驚時瞪大）
	if expr == "happy":
		_creature_eyes(c, 27, 38, head_cy - 2, "happy")
	else:
		Pix.rect(c, 26, head_cy - 3, 3, 3, Pal.INK)
		Pix.rect(c, 37, head_cy - 3, 3, 3, Pal.INK)
		Pix.px(c, 27, head_cy - 2, Pal.FOAM)
		Pix.px(c, 38, head_cy - 2, Pal.FOAM)
	# 柱腿：粗短撐地
	for foot_x: int in [16, 24, 37, 44]:
		Pix.rect(c, foot_x, BASELINE - 7, 5, 7, Pal.WOOD_DK)
		Pix.hline(c, foot_x, BASELINE - 5, 5, Pal.WOOD)
		Pix.px(c, foot_x + 1, BASELINE - 1, Pal.SAND)
		Pix.px(c, foot_x + 3, BASELINE - 1, Pal.SAND)


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
	# 鱗甲圓背
	Pix.ellipse(c, 16, body_y - 2, 9, 7, Pal.MOSS)
	Pix.ellipse(c, 14, body_y - 5, 4, 3, Pal.LEAF)
	for i in range(3):
		Pix.px(c, 11 + i * 4, body_y - 3, Pal.LEAF)
		Pix.px(c, 10 + i * 4, body_y - 4, Pal.LEAF_LT)
		Pix.px(c, 13 + i * 4, body_y, Pal.LEAF)
	# 粗尾（左右側身時在身後；正/背面在側邊）
	var tail_x := 25 if row != 2 else 7
	Pix.ellipse(c, tail_x, body_y + 2.0, 4, 2.5, Pal.MOSS)
	Pix.px(c, tail_x, body_y + 1, Pal.LEAF_LT)
	# 頭：淡色小臉＋鱗帽
	Pix.ellipse(c, 16, body_y - 8.0, 5, 4, Pal.SAND if row != 1 else Pal.MOSS)
	Pix.px(c, 13, body_y - 12, Pal.LEAF)
	Pix.px(c, 16, body_y - 13, Pal.LEAF_LT)
	Pix.px(c, 19, body_y - 12, Pal.LEAF)
	match row:
		0:
			Pix.ellipse(c, 16, body_y - 6.0, 3, 2, Pal.SAND_LT)
			Pix.rect(c, 13, body_y - 9, 2, 2, Pal.INK)
			Pix.rect(c, 18, body_y - 9, 2, 2, Pal.INK)
			Pix.px(c, 13, body_y - 9, Pal.FOAM)
			Pix.px(c, 18, body_y - 9, Pal.FOAM)
		2:
			Pix.rect(c, 12, body_y - 9, 2, 2, Pal.INK)
			Pix.px(c, 12, body_y - 9, Pal.FOAM)
		3:
			Pix.rect(c, 19, body_y - 9, 2, 2, Pal.INK)
			Pix.px(c, 19, body_y - 9, Pal.FOAM)
	# 小腳（walk 幀交替）
	var step := col % 2
	Pix.rect(c, 12 + step, ground - 2, 3, 2, Pal.SAND)
	Pix.rect(c, 18 - step, ground - 2, 3, 2, Pal.SAND)


static func _world_emberhorn(c: Image, row: int, ground: int, col: int) -> void:
	var body_y := ground - 9
	var step := col % 2
	# 直立小黑鳥＋硬尾
	Pix.ellipse(c, 16, body_y, 6, 6, Pal.NIGHT)
	Pix.ellipse(c, 15, body_y + 1.0, 3, 4, Pal.PAPER)
	var tail_x := 22 if row != 2 else 10
	Pix.vline(c, tail_x, body_y + 2, 4, Pal.NIGHT)
	# 白斑
	Pix.px(c, 19, body_y - 2, Pal.PAPER_DIM)
	Pix.px(c, 12, body_y - 1, Pal.PAPER_DIM)
	# 鳥腿（hop 交替）
	Pix.vline(c, 14 + step, body_y + 5, ground - body_y - 5, Pal.AMBER_DK)
	Pix.vline(c, 18 - step, body_y + 5, ground - body_y - 5, Pal.AMBER_DK)
	Pix.hline(c, 13 + step, ground - 1, 3, Pal.AMBER_DK)
	Pix.hline(c, 17 - step, ground - 1, 3, Pal.AMBER_DK)
	# 頭與紅冠
	var head_x := 16
	if row == 2:
		head_x = 11
	elif row == 3:
		head_x = 21
	var head_y := body_y - 7
	Pix.ellipse(c, head_x, head_y, 4, 4, Pal.PAPER)
	Pix.ellipse(c, head_x, head_y - 2.0, 4, 2, Pal.NIGHT)
	for i in range(3):
		Pix.px(c, head_x - 2 + i * 2, head_y - 5 - (i % 2), Pal.CORAL)
	Pix.px(c, head_x, head_y - 7, Pal.CORAL_LT)
	# 喙
	if row == 2:
		Pix.hline(c, head_x - 7, head_y + 1, 4, Pal.AMBER_DK)
	elif row == 3:
		Pix.hline(c, head_x + 3, head_y + 1, 4, Pal.AMBER_DK)
	else:
		Pix.vline(c, head_x, head_y + 2, 3, Pal.AMBER_DK)
	match row:
		0:
			Pix.rect(c, head_x - 2, head_y - 1, 2, 2, Pal.INK)
			Pix.rect(c, head_x + 1, head_y - 1, 2, 2, Pal.INK)
		2:
			Pix.rect(c, head_x - 2, head_y - 1, 2, 2, Pal.INK)
		3:
			Pix.rect(c, head_x + 1, head_y - 1, 2, 2, Pal.INK)


static func _world_tidecrest(c: Image, row: int, ground: int, col: int) -> void:
	var body_y := ground - 8
	var step := col % 2
	# 格紋大尾拖在身後
	var tail_x := 25 if row != 2 else 7
	Pix.ellipse(c, tail_x, ground - 3.0, 5, 2.5, Pal.WOOD_DK)
	Pix.px(c, tail_x - 1, ground - 4, Pal.INK)
	Pix.px(c, tail_x + 1, ground - 3, Pal.INK)
	# 厚實身體
	Pix.ellipse(c, 16, body_y, 8, 6, Pal.WOOD)
	Pix.ellipse(c, 16, body_y + 1.0, 5, 4, Pal.SAND)
	# 短腿（walk 交替）
	Pix.rect(c, 11 + step, ground - 2, 3, 2, Pal.WOOD_DK)
	Pix.rect(c, 18 - step, ground - 2, 3, 2, Pal.WOOD_DK)
	# 頭與圓耳
	var head_x := 16
	if row == 2:
		head_x = 11
	elif row == 3:
		head_x = 21
	var head_y := body_y - 7
	Pix.ellipse(c, head_x, head_y, 5, 4, Pal.WOOD)
	Pix.px(c, head_x - 4, head_y - 3, Pal.WOOD_DK)
	Pix.px(c, head_x + 4, head_y - 3, Pal.WOOD_DK)
	# 門牙
	if row != 1:
		Pix.px(c, head_x, head_y + 3, Pal.PAPER)
		Pix.px(c, head_x, head_y + 4, Pal.PAPER)
	# 濕亮水珠
	Pix.px(c, head_x + 3, head_y - 4, Pal.SEA_PALE)
	match row:
		0:
			Pix.rect(c, head_x - 3, head_y - 1, 2, 2, Pal.INK)
			Pix.rect(c, head_x + 2, head_y - 1, 2, 2, Pal.INK)
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
		# 頭部特寫：裁 40×48 視窗（各自對準頭部；新造型頭都在畫面中央上方）
		var crop_origin := Vector2i(12, 2)
		if id == "emberhorn":
			crop_origin = Vector2i(12, 0)
		var portrait := Pix.img(40, 48)
		portrait.blit_rect(full, Rect2i(crop_origin.x, crop_origin.y, 40, 48), Vector2i.ZERO)
		Pix.save(portrait, "res://assets/portraits/%s_%s.png" % [id, expr])
