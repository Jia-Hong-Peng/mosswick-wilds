class_name GenUi
extends RefCounted
## UI 素材：觀測儀器風觸控按鍵（含按下態）、屬性圖示、道具圖示、
## 接觸陰影、遊戲圖示。全部走全域色盤。


static func generate() -> void:
	for dir_name: String in ["up", "down", "left", "right"]:
		_arrow("res://assets/ui/arrow_%s.png" % dir_name, dir_name, false)
		_arrow("res://assets/ui/arrow_%s_pressed.png" % dir_name, dir_name, true)
	_round_button("res://assets/ui/btn_confirm.png", 26, Pal.CORAL, Pal.CORAL_LT, false)
	_round_button("res://assets/ui/btn_confirm_pressed.png", 26, Pal.CORAL, Pal.CORAL_LT, true)
	_round_button("res://assets/ui/btn_cancel.png", 22, Pal.SEA, Pal.SEA_LT, false)
	_round_button("res://assets/ui/btn_cancel_pressed.png", 22, Pal.SEA, Pal.SEA_LT, true)
	_menu_button("res://assets/ui/btn_menu.png", false)
	_menu_button("res://assets/ui/btn_menu_pressed.png", true)
	_elem_icon("res://assets/ui/elem_forest.png", "forest")
	_elem_icon("res://assets/ui/elem_tide.png", "tide")
	_elem_icon("res://assets/ui/elem_signal.png", "signal")
	_elem_icon("res://assets/ui/elem_neutral.png", "neutral")
	_item_balm("res://assets/ui/item_herbal_balm.png")
	_item_echo_box("res://assets/ui/item_echo_box.png")
	_item_stable_echo("res://assets/ui/item_stable_echo.png")
	_shadow("res://assets/ui/contact_shadow.png")
	_fog_blob("res://assets/ui/fog_blob.png")
	_clue_sprites()
	_battle_props()
	_observe_button("res://assets/ui/btn_observe.png", false)
	_observe_button("res://assets/ui/btn_observe_pressed.png", true)
	_app_icon("res://assets/ui/icon.png")


static func _bezel(c: Image, size: int) -> void:
	var half := float(size) / 2.0 - 0.5
	Pix.ellipse(c, half, half, half, half, Pal.INK)
	Pix.ellipse(c, half, half, half - 1.0, half - 1.0, Pal.STEEL)
	Pix.ellipse(c, half - 1.0, half - 1.0, half - 2.0, half - 2.0, Pal.MIST_LT)
	Pix.ellipse(c, half, half, half - 2.0, half - 2.0, Pal.SLATE)


static func _arrow(path: String, dir_name: String, pressed: bool) -> void:
	var size := 20
	var c := Pix.img(size, size)
	# 方形儀器鍵：外框＋斜角高光
	Pix.rect(c, 1, 1, size - 2, size - 2, Pal.INK)
	Pix.rect(c, 2, 2, size - 4, size - 4, Pal.SLATE if not pressed else Pal.NIGHT)
	if not pressed:
		Pix.hline(c, 2, 2, size - 4, Pal.MIST_LT)
		Pix.vline(c, 2, 2, size - 4, Pal.MIST)
	Pix.hline(c, 2, size - 3, size - 4, Pal.INK)
	var arrow_color := Pal.CORAL_LT if pressed else Pal.FOG
	for i in range(5):
		var span := 9 - i * 2
		for j in range(span):
			match dir_name:
				"up": Pix.px(c, 5 + i + j, 12 - i, arrow_color)
				"down": Pix.px(c, 5 + i + j, 7 + i, arrow_color)
				"left": Pix.px(c, 12 - i, 5 + i + j, arrow_color)
				"right": Pix.px(c, 7 + i, 5 + i + j, arrow_color)
	# 半透明化：儀器鍵浮在畫面上但不搶戲
	_fade(c, 0.82)
	Pix.save(c, path)


static func _round_button(path: String, size: int, face: Color, face_lt: Color, pressed: bool) -> void:
	var c := Pix.img(size, size)
	_bezel(c, size)
	var half := float(size) / 2.0 - 0.5
	var face_color := Color(face).darkened(0.25) if pressed else face
	Pix.ellipse(c, half, half, half - 3.0, half - 3.0, face_color)
	if not pressed:
		Pix.ellipse(c, half - 2.0, half - 2.5, (half - 3.0) * 0.45, (half - 3.0) * 0.4, face_lt)
	Pix.px(c, int(half), int(size) - 4, Pal.INK)
	_fade(c, 0.85)
	Pix.save(c, path)


static func _menu_button(path: String, pressed: bool) -> void:
	var size := 18
	var c := Pix.img(size, size)
	Pix.rect(c, 1, 1, size - 2, size - 2, Pal.INK)
	Pix.rect(c, 2, 2, size - 4, size - 4, Pal.NIGHT if pressed else Pal.SLATE)
	if not pressed:
		Pix.hline(c, 2, 2, size - 4, Pal.MIST_LT)
	# 三條選單線（手冊頁籤感）
	for i in range(3):
		Pix.hline(c, 5, 5 + i * 4, 8, Pal.AMBER if not pressed else Pal.AMBER_DK)
		Pix.px(c, 5, 5 + i * 4, Pal.AMBER_LT if not pressed else Pal.AMBER)
	_fade(c, 0.82)
	Pix.save(c, path)


static func _fade(c: Image, alpha: float) -> void:
	for y in range(c.get_height()):
		for x in range(c.get_width()):
			var color := c.get_pixel(x, y)
			if color.a > 0.05:
				color.a *= alpha
				c.set_pixel(x, y, color)


static func _elem_icon(path: String, kind: String) -> void:
	var c := Pix.img(12, 12)
	Pix.ellipse(c, 5.5, 5.5, 5.5, 5.5, Pal.INK)
	match kind:
		"forest":
			Pix.ellipse(c, 5.5, 5.5, 4.5, 4.5, Pal.MOSS)
			# 葉片
			for i in range(4):
				Pix.px(c, 4 + i, 8 - i, Pal.SPROUT)
			Pix.px(c, 4, 5, Pal.LEAF_LT)
			Pix.px(c, 5, 4, Pal.LEAF_LT)
			Pix.px(c, 7, 4, Pal.LEAF)
		"tide":
			Pix.ellipse(c, 5.5, 5.5, 4.5, 4.5, Pal.SEA)
			Pix.hline(c, 3, 5, 3, Pal.FOAM)
			Pix.px(c, 6, 4, Pal.FOAM)
			Pix.hline(c, 5, 8, 3, Pal.SEA_PALE)
			Pix.px(c, 8, 7, Pal.SEA_PALE)
		"signal":
			Pix.ellipse(c, 5.5, 5.5, 4.5, 4.5, Pal.NIGHT)
			# 電波弧
			Pix.px(c, 4, 7, Pal.AMBER)
			Pix.px(c, 5, 6, Pal.AMBER)
			Pix.px(c, 6, 5, Pal.AMBER_LT)
			Pix.px(c, 7, 4, Pal.AMBER_LT)
			Pix.px(c, 3, 5, Pal.AMBER_DK)
			Pix.px(c, 8, 8, Pal.AMBER_DK)
		"neutral":
			Pix.ellipse(c, 5.5, 5.5, 4.5, 4.5, Pal.MIST_DK)
			Pix.ellipse(c, 5.5, 5.5, 2.0, 2.0, Pal.MIST_LT)
			Pix.px(c, 5, 5, Pal.FOG)
	Pix.save(c, path)


static func _item_balm(path: String) -> void:
	var c := Pix.img(16, 16)
	# 青草膏：小圓鐵盒
	Pix.ellipse(c, 8, 10, 6, 4, Pal.INK)
	Pix.ellipse(c, 8, 10, 5, 3, Pal.AMBER_DK)
	Pix.ellipse(c, 8, 8.5, 6, 3.5, Pal.INK)
	Pix.ellipse(c, 8, 8.5, 5, 2.5, Pal.AMBER)
	Pix.ellipse(c, 7, 8, 2, 1, Pal.AMBER_LT)
	# 蓋上葉標
	Pix.px(c, 7, 8, Pal.LEAF)
	Pix.px(c, 8, 7, Pal.LEAF)
	Pix.px(c, 9, 8, Pal.SPROUT)
	Pix.save(c, path)


static func _item_echo_box(path: String) -> void:
	var c := Pix.img(16, 16)
	# 共鳴匣：黃銅錄音小匣
	Pix.rect(c, 3, 5, 10, 8, Pal.INK)
	Pix.rect(c, 4, 6, 8, 6, Pal.AMBER_DK)
	Pix.rect(c, 4, 6, 8, 2, Pal.AMBER)
	Pix.px(c, 5, 6, Pal.AMBER_LT)
	# 轉盤與訊號燈
	Pix.ellipse(c, 7, 9.5, 1.6, 1.6, Pal.WOOD_DK)
	Pix.px(c, 7, 9, Pal.SAND_LT)
	Pix.px(c, 11, 7, Pal.CORAL)
	# 提帶
	Pix.hline(c, 6, 3, 5, Pal.WOOD_DK)
	Pix.px(c, 5, 4, Pal.WOOD_DK)
	Pix.px(c, 11, 4, Pal.WOOD_DK)
	Pix.save(c, path)


static func _item_stable_echo(path: String) -> void:
	var c := Pix.img(16, 16)
	# 穩定回聲：琥珀同心環，中心一點海藍
	Pix.ellipse(c, 8, 8, 7, 7, Pal.INK)
	Pix.ellipse(c, 8, 8, 6, 6, Pal.AMBER_DK)
	Pix.ellipse(c, 8, 8, 4.5, 4.5, Pal.AMBER)
	Pix.ellipse(c, 8, 8, 3, 3, Pal.AMBER_LT)
	Pix.ellipse(c, 8, 8, 1.4, 1.4, Pal.SEA_PALE)
	Pix.px(c, 6, 6, Pal.FOAM)
	Pix.save(c, path)


## 觀測線索（16×16 ×2 幀）：潮痕（海藍弧）／電波刮痕（珊瑚鋸齒）／無聲波紋（霧白圈）
static func _clue_sprites() -> void:
	for kind: String in ["tide", "signal", "ripple"]:
		var sheet := Pix.img(32, 16)
		for f in range(2):
			var c := Pix.img(16, 16)
			match kind:
				"tide":
					for i in range(3):
						var y := 4 + i * 4 + f
						Pix.px(c, 3, y + 1, Pal.SEA_LT)
						Pix.hline(c, 4, y, 8, Pal.SEA_LT)
						Pix.px(c, 12, y + 1, Pal.SEA_PALE)
				"signal":
					var x := 2
					var y := 11 - f
					for i in range(6):
						Pix.px(c, x, y, Pal.CORAL if i % 2 == 0 else Pal.GLITCH_LT)
						Pix.px(c, x + 1, y - 1, Pal.CORAL_LT)
						x += 2
						y -= 1
					Pix.px(c, 13, 3 + f, Pal.GLITCH_LT)
				"ripple":
					var radius := 4.0 + float(f) * 2.0
					for angle in range(0, 360, 20):
						var px := 8.0 + cos(deg_to_rad(angle)) * radius
						var py := 8.0 + sin(deg_to_rad(angle)) * radius * 0.6
						Pix.px(c, int(px), int(py), Pal.FOAM if f == 0 else Pal.MIST_LT)
			Pix.blit(sheet, c, f * 16, 0)
		Pix.save(sheet, "res://assets/ui/clue_%s.png" % kind)


## 戰鬥道具化 VFX 素材：防禦弧、逆頻箭、共鳴環
static func _battle_props() -> void:
	var arc := Pix.img(12, 32)
	for y in range(32):
		var dy := (float(y) - 15.5) / 16.0
		var x := int(6.0 - dy * dy * 6.0)
		Pix.px(arc, x + 3, y, Pal.SEA_PALE)
		Pix.px(arc, x + 4, y, Pal.FOAM)
	Pix.save(arc, "res://assets/ui/guard_arc.png")

	var bolt := Pix.img(18, 10)
	var bx := 0
	var by := 6
	for i in range(8):
		Pix.px(bolt, bx, by, Pal.CORAL)
		Pix.px(bolt, bx + 1, by - 1, Pal.CORAL_LT)
		bx += 2
		by = 6 if by == 3 else 3
	Pix.px(bolt, 17, 4, Pal.GLITCH_LT)
	Pix.save(bolt, "res://assets/ui/jam_bolt.png")

	var ring := Pix.img(32, 32)
	for angle in range(0, 360, 6):
		var px := 15.5 + cos(deg_to_rad(angle)) * 14.0
		var py := 15.5 + sin(deg_to_rad(angle)) * 14.0
		Pix.px(ring, int(px), int(py), Pal.SEA_PALE)
		var inner_x := 15.5 + cos(deg_to_rad(angle)) * 12.5
		var inner_y := 15.5 + sin(deg_to_rad(angle)) * 12.5
		Pix.px(ring, int(inner_x), int(inner_y), Pal.alpha(Pal.FOAM, 0.6))
	Pix.save(ring, "res://assets/ui/resonance_ring.png")


## 觀測鍵（觸控）：眼形波紋儀
static func _observe_button(path: String, pressed: bool) -> void:
	var size := 22
	var c := Pix.img(size, size)
	Pix.rect(c, 1, 1, size - 2, size - 2, Pal.INK)
	Pix.rect(c, 2, 2, size - 4, size - 4, Pal.NIGHT if pressed else Pal.SLATE)
	if not pressed:
		Pix.hline(c, 2, 2, size - 4, Pal.MIST_LT)
	var glow := Pal.SEA_PALE if not pressed else Pal.CORAL_LT
	Pix.ellipse(c, 10.5, 10.5, 6.5, 4.0, Pal.SEA_DK)
	Pix.ellipse(c, 10.5, 10.5, 4.5, 2.6, glow)
	Pix.ellipse(c, 10.5, 10.5, 1.6, 1.6, Pal.INK)
	Pix.px(c, 9, 9, Pal.FOAM)
	_fade(c, 0.82)
	Pix.save(c, path)


static func _shadow(path: String) -> void:
	var c := Pix.img(48, 14)
	for y in range(14):
		for x in range(48):
			var dx := (float(x) - 23.5) / 22.0
			var dy := (float(y) - 6.5) / 5.5
			var d := dx * dx + dy * dy
			if d <= 1.0:
				c.set_pixel(x, y, Pal.alpha(Pal.INK, 0.35 if d < 0.55 else 0.2))
	Pix.save(c, path)


static func _fog_blob(path: String) -> void:
	var c := Pix.img(96, 40)
	var r := Pix.rng(41)
	for i in range(9):
		var cx := r.randf_range(14, 82)
		var cy := r.randf_range(10, 30)
		var rx := r.randf_range(10, 22)
		var ry := r.randf_range(5, 9)
		for y in range(int(cy - ry), int(cy + ry) + 1):
			for x in range(int(cx - rx), int(cx + rx) + 1):
				var dx := (float(x) - cx) / rx
				var dy := (float(y) - cy) / ry
				if dx * dx + dy * dy <= 1.0 and x >= 0 and y >= 0 and x < 96 and y < 40:
					var base := c.get_pixel(x, y)
					var add := 0.09
					c.set_pixel(x, y, Color(Pal.FOG.r, Pal.FOG.g, Pal.FOG.b, minf(base.a + add, 0.32)))
	Pix.save(c, path)


static func _app_icon(path: String) -> void:
	var c := Pix.img(128, 128)
	# 夜霧海面底
	Pix.rect(c, 0, 0, 128, 128, Pal.NIGHT)
	Pix.dither(c, 0, 0, 128, 40, Pal.NIGHT, Pal.SLATE)
	Pix.dither(c, 0, 88, 128, 40, Pal.NIGHT, Pal.SEA_DK)
	for y: int in [96, 106, 118]:
		Pix.hline(c, 8, y, 40, Pal.SEA)
		Pix.hline(c, 70, y + 4, 44, Pal.SEA)
	# 黃銅儀器圈
	for ring in range(3):
		var r := 56.0 - ring
		for angle in range(0, 360, 2):
			var x := 64.0 + cos(deg_to_rad(angle)) * r
			var y := 64.0 + sin(deg_to_rad(angle)) * r
			Pix.px(c, int(x), int(y), [Pal.AMBER, Pal.AMBER_DK, Pal.AMBER][ring])
	# 苔角獸剪影
	Pix.ellipse(c, 64, 78, 34, 20, Pal.MOSS_DK)
	Pix.ellipse(c, 64, 52, 20, 16, Pal.MOSS_DK)
	Pix.ellipse(c, 64, 66, 28, 10, Pal.MOSS)
	Pix.vline(c, 54, 30, 8, Pal.LEAF)
	Pix.rect(c, 52, 27, 3, 4, Pal.SPROUT)
	Pix.vline(c, 74, 30, 8, Pal.LEAF)
	Pix.rect(c, 74, 27, 3, 4, Pal.SPROUT)
	Pix.rect(c, 54, 50, 5, 7, Pal.INK)
	Pix.rect(c, 69, 50, 5, 7, Pal.INK)
	Pix.rect(c, 55, 52, 2, 2, Pal.FOAM)
	Pix.rect(c, 70, 52, 2, 2, Pal.FOAM)
	# 霧帶
	for y: int in [20, 26]:
		Pix.rect(c, 10, y, 50, 2, Pal.alpha(Pal.FOG, 0.35))
		Pix.rect(c, 76, y + 3, 42, 2, Pal.alpha(Pal.FOG, 0.35))
	Pix.save(c, path)
