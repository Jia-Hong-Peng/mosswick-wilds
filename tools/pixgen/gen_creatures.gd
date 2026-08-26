class_name GenCreatures
extends RefCounted
## 迴靈素材產生器（art-bible §6）。
## 每隻輸出：<id>_front.png（64×64 ×2 幀 Idle）、<id>_back.png、
## <id>_hit.png（FOAM 白剪影）、<id>_icon.png（32×32）、<id>_mini.png（16×16）。
## 剪影原則：苔角獸＝低寬穩；潮翼＝輕斜有方向；磁殼仔＝緊湊不對稱。

const S := 64
const BASELINE := 56  # 腳底基準線


static func generate() -> void:
	_export_creature("mosshorn", Callable(GenCreatures, "_mosshorn"))
	_export_creature("tidewing", Callable(GenCreatures, "_tidewing"))
	_export_creature("magshell", Callable(GenCreatures, "_magshell"))


static func _export_creature(id: String, draw: Callable) -> void:
	var front_sheet := Pix.img(S * 2, S)
	var front0: Image
	for f in range(2):
		var frame := Pix.img(S, S)
		draw.call(frame, f, false)
		Pix.outline_sprite(frame)
		if f == 0:
			front0 = frame
		Pix.blit(front_sheet, frame, f * S, 0)
	Pix.save(front_sheet, "res://assets/creatures/%s_front.png" % id)

	var back := Pix.img(S, S)
	draw.call(back, 0, true)
	Pix.outline_sprite(back)
	Pix.save(back, "res://assets/creatures/%s_back.png" % id)

	# 受擊幀：前視剪影轉 FOAM 白
	var hit := Pix.img(S, S)
	for y in range(S):
		for x in range(S):
			if front0.get_pixel(x, y).a > 0.5:
				hit.set_pixel(x, y, Pal.FOAM)
	Pix.save(hit, "res://assets/creatures/%s_hit.png" % id)

	# 世界圖示 32×32：前視縮小（最近鄰保持像素感）
	var icon := front0.duplicate() as Image
	icon.resize(32, 32, Image.INTERPOLATE_NEAREST)
	Pix.save(icon, "res://assets/creatures/%s_icon.png" % id)
	var mini := front0.duplicate() as Image
	mini.resize(16, 16, Image.INTERPOLATE_NEAREST)
	Pix.save(mini, "res://assets/creatures/%s_mini.png" % id)


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


# ---------- 苔角獸：潮濕石牆與林緣。低、寬、穩。 ----------

static func _mosshorn(c: Image, f: int, back_view: bool) -> void:
	var squash := f  # 第二幀：呼吸下沉 1px
	var body_y := 40.0 + squash
	# 身體：低寬橢圓
	_volume(c, 32, body_y, 21, 13.0 - squash * 0.5, Pal.WOOD_DK, Pal.WOOD_LT, Pal.SAND)
	# 四肢：粗短
	for leg_x: Array in [[16, 22], [26, 32], [34, 40], [44, 50]]:
		Pix.rect(c, int(leg_x[0]), BASELINE - 5, int(leg_x[1]) - int(leg_x[0]) - 2, 5, Pal.WOOD)
		Pix.hline(c, int(leg_x[0]), BASELINE - 1, 3, Pal.SAND_LT)
	# 背上厚苔：柔和弧線（剪影關鍵）
	Pix.ellipse(c, 32, body_y - 8, 18, 7, Pal.MOSS)
	Pix.ellipse(c, 27, body_y - 10, 9, 4, Pal.LEAF)
	Pix.speckle(c, 16, int(body_y) - 13, 32, 8, Pal.LEAF_LT, 10, 31)
	Pix.speckle(c, 18, int(body_y) - 11, 28, 6, Pal.SPROUT, 5, 32)
	if back_view:
		# 背面：苔覆蓋更多、小尾丘
		Pix.ellipse(c, 32, body_y - 4, 16, 8, Pal.MOSS)
		Pix.ellipse(c, 32, body_y - 6, 10, 4, Pal.LEAF)
		Pix.px(c, 32, int(body_y) + 10, Pal.WOOD_DK)
		Pix.ellipse(c, 32, int(body_y) + 9, 2, 1.5, Pal.WOOD)
		# 後腦與耳
		Pix.ellipse(c, 32, 26 + squash, 11, 8, Pal.WOOD_LT)
		Pix.ellipse(c, 32, 23 + squash, 9, 4, Pal.MOSS)
	else:
		# 頭：與身體相連的圓
		_volume(c, 32, 27 + squash, 12, 10, Pal.WOOD, Pal.WOOD_LT, Pal.SAND)
		# 圓耳
		Pix.ellipse(c, 22, 20 + squash, 3.5, 3, Pal.WOOD)
		Pix.ellipse(c, 42, 20 + squash, 3.5, 3, Pal.WOOD)
		Pix.px(c, 22, 20 + squash, Pal.MOSS)
		Pix.px(c, 42, 20 + squash, Pal.MOSS)
		# 幼角：蕨芽狀（生態細節）
		var horn_sway := f
		Pix.vline(c, 27, 15 + squash, 5, Pal.LEAF)
		Pix.px(c, 26 - horn_sway, 14 + squash, Pal.SPROUT)
		Pix.px(c, 26 - horn_sway, 15 + squash, Pal.SPROUT)
		Pix.vline(c, 37, 15 + squash, 5, Pal.LEAF)
		Pix.px(c, 38 + horn_sway, 14 + squash, Pal.SPROUT)
		Pix.px(c, 38 + horn_sway, 15 + squash, Pal.SPROUT)
		# 臉：謹慎的圓眼
		Pix.rect(c, 26, 27 + squash, 3, 4, Pal.INK)
		Pix.rect(c, 35, 27 + squash, 3, 4, Pal.INK)
		Pix.px(c, 27, 28 + squash, Pal.FOAM)
		Pix.px(c, 36, 28 + squash, Pal.FOAM)
		Pix.rect(c, 31, 32 + squash, 2, 2, Pal.INK)
		Pix.px(c, 30, 35 + squash, Pal.WOOD_DK)
		Pix.px(c, 33, 35 + squash, Pal.WOOD_DK)
		# 頰上小苔點
		Pix.px(c, 22, 31 + squash, Pal.MOSS)
		Pix.px(c, 42, 31 + squash, Pal.MOSS)


# ---------- 潮翼：港口與海蝕岩。輕、斜、有方向感。 ----------

static func _tidewing(c: Image, f: int, back_view: bool) -> void:
	var wing_lift := f * 2  # 第二幀：翅膀下壓
	# 斜置的淚滴身體（永遠像正要起飛）
	var body_cx := 30.0
	var body_cy := 36.0
	_volume(c, body_cx, body_cy, 13, 11, Pal.SEA, Pal.SEA_LT, Pal.SEA_PALE)
	# 腹部亮色
	if not back_view:
		Pix.ellipse(c, body_cx + 2, body_cy + 4, 8, 5, Pal.FOAM)
	# 尾羽：退潮水線（三條漸細）
	for i in range(3):
		var ty := int(body_cy) + 2 + i * 3
		Pix.hline(c, int(body_cx) - 20 + i * 3, ty, 12 - i * 2, Pal.SEA)
		Pix.px(c, int(body_cx) - 21 + i * 3, ty, Pal.SEA_PALE)
	# 翅膀：波浪缺刻邊緣（剪影關鍵）
	var wing_y := int(body_cy) - 10 + wing_lift
	_wave_wing(c, int(body_cx) - 4, wing_y, 24, -1)
	if back_view:
		_wave_wing(c, int(body_cx) - 14, wing_y + 4, 18, -1)
	# 頭：小而前傾
	var head_cx := body_cx + 10
	var head_cy := body_cy - 12.0 + f
	_volume(c, head_cx, head_cy, 7, 6.5, Pal.SEA, Pal.SEA_LT, Pal.FOAM)
	if back_view:
		Pix.ellipse(c, head_cx, head_cy - 1, 5, 3, Pal.SEA)
	else:
		# 嘴喙：琥珀色
		Pix.rect(c, int(head_cx) + 5, int(head_cy) - 1, 5, 2, Pal.AMBER)
		Pix.px(c, int(head_cx) + 5, int(head_cy) + 1, Pal.AMBER_DK)
		# 眼：活潑的亮眼
		Pix.rect(c, int(head_cx), int(head_cy) - 2, 3, 3, Pal.INK)
		Pix.px(c, int(head_cx) + 1, int(head_cy) - 1, Pal.FOAM)
		# 頰上鹽紋
		Pix.px(c, int(head_cx) - 3, int(head_cy) + 2, Pal.SEA_PALE)
	# 腳：短蹼足
	Pix.vline(c, int(body_cx) + 2, BASELINE - 7, 4, Pal.AMBER_DK)
	Pix.vline(c, int(body_cx) + 7, BASELINE - 7, 4, Pal.AMBER_DK)
	Pix.hline(c, int(body_cx) + 1, BASELINE - 3, 3, Pal.AMBER)
	Pix.hline(c, int(body_cx) + 6, BASELINE - 3, 3, Pal.AMBER)


static func _wave_wing(c: Image, x: int, y: int, width: int, _dir: int) -> void:
	# 上緣平滑、下緣波浪缺刻的翼
	for i in range(width):
		var height := 8 - absi(i - width / 3) / 2
		if height < 3:
			height = 3
		var notch := (i % 5 == 4)
		var col_h := height - (2 if notch else 0)
		Pix.vline(c, x + i, y, col_h, Pal.SEA)
		Pix.px(c, x + i, y, Pal.SEA_LT)
		if not notch:
			Pix.px(c, x + i, y + col_h - 1, Pal.SEA_PALE)


# ---------- 磁殼仔：廢棄觀測設備。緊湊、不對稱。 ----------

static func _magshell(c: Image, f: int, back_view: bool) -> void:
	var blink := f == 1
	# 殼：圓頂
	_volume(c, 32, 38, 17, 14, Pal.SLATE, Pal.STEEL, Pal.MIST_LT)
	# 殼上鏽斑與吸附的磁石碎片
	Pix.speckle(c, 20, 28, 24, 14, Pal.RUST, 9, 33)
	for p: Vector2i in [Vector2i(24, 32), Vector2i(38, 30), Vector2i(30, 26), Vector2i(41, 38)]:
		Pix.rect(c, p.x, p.y, 2, 2, Pal.INK)
		Pix.px(c, p.x, p.y, Pal.NIGHT)
	# 訊號燈：琥珀點（第二幀熄滅 → 生物性的閃爍）
	Pix.rect(c, 35, 33, 2, 2, Pal.AMBER if not blink else Pal.AMBER_DK)
	if not blink:
		Pix.px(c, 35, 32, Pal.AMBER_LT)
	# 天線鬚：一長一短（不對稱剪影關鍵）
	var sway := 1 if blink else 0
	for i in range(12):
		Pix.px(c, 22 - i / 2 - sway, 26 - i, Pal.SLATE)
	Pix.rect(c, 15 - sway, 13, 2, 2, Pal.CORAL)
	Pix.px(c, 15 - sway, 12, Pal.CORAL_LT)
	for i in range(5):
		Pix.px(c, 42 + i / 2, 25 - i, Pal.SLATE)
	Pix.px(c, 44, 20, Pal.AMBER)
	if back_view:
		# 背面：殼更完整、鏽跡更多
		Pix.speckle(c, 22, 34, 20, 12, Pal.RUST_DK, 7, 34)
		Pix.rect(c, 31, 50, 3, 3, Pal.MIST_LT)
	else:
		# 殼緣下探出的臉與腳
		Pix.ellipse(c, 32, 50, 10, 5, Pal.MIST_LT)
		Pix.rect(c, 27, 47, 3, 3, Pal.INK)
		Pix.rect(c, 34, 47, 3, 3, Pal.INK)
		Pix.px(c, 28, 48, Pal.FOAM)
		Pix.px(c, 35, 48, Pal.FOAM)
		Pix.px(c, 31, 51, Pal.MIST)
		Pix.px(c, 33, 51, Pal.MIST)
	# 短足
	for foot_x: int in [22, 29, 36, 42]:
		Pix.rect(c, foot_x, BASELINE - 3, 3, 3, Pal.MIST)
		Pix.px(c, foot_x, BASELINE - 3, Pal.MIST_LT)
