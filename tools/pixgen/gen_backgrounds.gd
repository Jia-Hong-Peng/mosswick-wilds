class_name GenBackgrounds
extends RefCounted
## 全畫面背景：標題畫面、戰鬥場景背景（依遭遇地點）、色盤圖。
## 構圖規則：每張都有前景／中景／背景三層（art-bible §開頭）。

const W := 320
const H := 180


static func generate() -> void:
	_title_bg("res://assets/ui/title_bg.png")
	_battle_bg_trail("res://assets/battle/bg_trail.png")
	_battle_bg_village("res://assets/battle/bg_village.png")
	_battle_bg_station("res://assets/battle/bg_station.png")
	_palette_sheet("res://docs_src/palette.png")


## ---------- 頭目戰背景：廢棄潮汐觀測站內部 ----------

static func _battle_bg_station(path: String) -> void:
	var c := Pix.img(W, H)
	# 背景層：暗牆與高窗
	Pix.rect(c, 0, 0, W, 70, Pal.NIGHT)
	Pix.dither(c, 0, 0, W, 12, Pal.INK, Pal.NIGHT)
	for x: int in [40, 150, 262]:
		Pix.rect(c, x, 8, 22, 30, Pal.SLATE)
		Pix.rect(c, x + 2, 10, 18, 26, Pal.SEA_DK)
		Pix.dither(c, x + 2, 10, 18, 10, Pal.SEA_DK, Pal.MIST_DK)
		Pix.vline(c, x + 10, 10, 26, Pal.SLATE)
	# 中景：儀器牆剪影＋指示燈
	var r := Pix.rng(61)
	for i in range(6):
		var mx := 6 + i * 54
		var mh := r.randi_range(22, 34)
		Pix.rect(c, mx, 70 - mh, 40, mh, Pal.INK)
		Pix.rect(c, mx + 2, 70 - mh + 2, 36, mh - 2, Pal.SLATE)
		Pix.rect(c, mx + 6, 70 - mh + 6, 12, 8, Pal.NIGHT)
		Pix.px(c, mx + 8, 70 - mh + 8, Pal.GLITCH_LT if i % 2 == 0 else Pal.AMBER)
		Pix.px(c, mx + 30, 70 - mh + 10, Pal.CORAL if i % 3 == 0 else Pal.SEA_PALE)
		# 藤蔓
		if i % 2 == 1:
			for v in range(10):
				Pix.px(c, mx + 4 + v / 2, 70 - mh - 4 + v, Pal.MOSS)
	Pix.hline(c, 0, 70, W, Pal.INK)
	# 地面：舊木地板
	Pix.rect(c, 0, 71, W, 109, Pal.WOOD)
	Pix.dither(c, 0, 71, W, 8, Pal.WOOD_DK, Pal.WOOD)
	for y in range(78, 180, 12):
		Pix.hline(c, 0, y, W, Pal.WOOD_DK)
	for i in range(20):
		Pix.hline(c, r.randi_range(0, W - 20), r.randi_range(74, 176), r.randi_range(6, 18), Pal.WOOD_LT)
	# 異常電波紋（地板上的干涉環）
	for ring: Array in [[240, 92, 40.0], [240, 92, 26.0], [76, 150, 30.0]]:
		var cx := float(ring[0])
		var cy := float(ring[1])
		var radius := float(ring[2])
		for angle in range(0, 360, 5):
			var px := cx + cos(deg_to_rad(angle)) * radius
			var py := cy + sin(deg_to_rad(angle)) * radius * 0.4
			if int(py) > 72 and int(py) < H:
				Pix.blend(c, int(px), int(py), Pal.GLITCH, 0.25)
	_platform(c, 240, 86, 46, 12)
	_platform(c, 76, 152, 54, 14)
	# 前景：兩側傾倒的儀器架
	Pix.rect(c, 0, 118, 26, 62, Pal.INK)
	Pix.rect(c, 2, 122, 22, 58, Pal.SLATE)
	Pix.px(c, 8, 130, Pal.AMBER)
	Pix.rect(c, 296, 108, 24, 72, Pal.INK)
	Pix.rect(c, 298, 112, 20, 68, Pal.SLATE)
	Pix.px(c, 306, 120, Pal.GLITCH_LT)
	Pix.save(c, path)


## ---------- 標題：霧港村的黃昏海面 ----------

static func _title_bg(path: String) -> void:
	var c := Pix.img(W, H)
	# 背景層：霧天
	Pix.rect(c, 0, 0, W, 70, Pal.FOG)
	Pix.dither(c, 0, 40, W, 16, Pal.FOG, Pal.MIST_LT)
	Pix.dither(c, 0, 56, W, 14, Pal.MIST_LT, Pal.MIST)
	# 遠山（左）與外海小島（右）
	_hill(c, -30, 70, 150, 34, Pal.MIST_DK)
	_hill(c, 60, 70, 90, 22, Pal.MIST)
	_hill(c, 250, 70, 60, 12, Pal.MIST_DK)
	# 霧帶蓋過山腳（混色，不覆蓋）
	_mist_band(c, 0, 58, W, 3, 0.45)
	_mist_band(c, 30, 64, W - 60, 2, 0.35)
	# 中景：海面
	Pix.rect(c, 0, 70, W, 60, Pal.SEA)
	Pix.dither(c, 0, 70, W, 8, Pal.SEA_LT, Pal.SEA)
	var r := Pix.rng(51)
	for i in range(26):
		var x := r.randi_range(0, W - 10)
		var y := r.randi_range(74, 124)
		Pix.hline(c, x, y, r.randi_range(3, 9), Pal.SEA_LT if y < 100 else Pal.SEA_PALE)
	# 村落剪影（右側坡地）
	_village_silhouette(c)
	# 浮標與倒影
	Pix.ellipse(c, 60, 100, 3, 2.4, Pal.CORAL)
	Pix.px(c, 60, 97, Pal.AMBER_LT)
	for y in range(103, 107):
		Pix.blend(c, 60, y, Pal.CORAL, 0.3)
	Pix.ellipse(c, 110, 112, 2.4, 2, Pal.CORAL)
	Pix.px(c, 110, 110, Pal.AMBER_LT)
	# 前景：深色水面與碼頭
	Pix.dither(c, 0, 130, W, 10, Pal.SEA, Pal.SEA_DK)
	Pix.rect(c, 0, 140, W, 40, Pal.SEA_DK)
	Pix.dither(c, 0, 140, W, 8, Pal.SEA, Pal.SEA_DK)
	for i in range(10):
		Pix.hline(c, r.randi_range(0, W - 16), r.randi_range(142, 172), r.randi_range(5, 14), Pal.SEA)
	# 前景碼頭木樁
	for x: int in [24, 34, 286, 296]:
		Pix.rect(c, x, 128, 5, 52, Pal.WOOD_DK)
		Pix.vline(c, x, 128, 52, Pal.WOOD)
		Pix.rect(c, x - 1, 126, 7, 3, Pal.WOOD)
		Pix.hline(c, x - 1, 126, 7, Pal.WOOD_LT)
	Pix.hline(c, 20, 132, 22, Pal.WOOD)
	Pix.hline(c, 282, 132, 24, Pal.WOOD)
	# 海鳥（潮翼的暗示）
	for p: Vector2i in [Vector2i(90, 30), Vector2i(104, 24), Vector2i(120, 34)]:
		Pix.px(c, p.x, p.y, Pal.SLATE)
		Pix.px(c, p.x - 1, p.y - 1, Pal.SLATE)
		Pix.px(c, p.x + 1, p.y - 1, Pal.SLATE)
	# 最上層薄霧（混色）
	_mist_band(c, 0, 76, W, 2, 0.2)
	_mist_band(c, 60, 96, 200, 2, 0.18)
	Pix.save(c, path)


## 霧帶：與底色混色而非覆蓋，避免出現實心白條
static func _mist_band(c: Image, x: int, y: int, w: int, h: int, amount: float) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			if xx >= 0 and yy >= 0 and xx < W and yy < H:
				Pix.blend(c, xx, yy, Pal.FOG, amount)


static func _village_silhouette(c: Image) -> void:
	# 右側岬角坡地：只延伸到水線，底緣一條岩石暗線
	for i in range(120):
		var x := 200 + i
		var top := 70 - i / 4
		var bottom := 86 + i / 10  # 岬角緩緩探進海面
		Pix.vline(c, x, top, bottom - top, Pal.NIGHT)
		Pix.px(c, x, bottom - 1, Pal.INK)
		if i % 7 == 0:
			Pix.px(c, x, bottom, Pal.SEA_DK)
	# 屋形剪影與燈窗
	var houses: Array = [
		[210, 52, 22, 16], [238, 44, 26, 20], [270, 36, 24, 18], [298, 30, 20, 16],
	]
	for h: Array in houses:
		var hx := int(h[0])
		var hy := int(h[1])
		var hw := int(h[2])
		var hh := int(h[3])
		Pix.rect(c, hx, hy, hw, hh, Pal.NIGHT)
		# 斜屋頂
		for i in range(hw / 2):
			Pix.hline(c, hx + i, hy - 1 - i / 2, hw - i * 2, Pal.NIGHT)
		# 暖窗
		Pix.rect(c, hx + 4, hy + 5, 3, 4, Pal.AMBER)
		Pix.px(c, hx + 4, hy + 5, Pal.AMBER_LT)
		if hw > 22:
			Pix.rect(c, hx + hw - 7, hy + 7, 3, 4, Pal.AMBER_DK)
	# 電線桿與觀測塔剪影
	Pix.vline(c, 232, 30, 16, Pal.NIGHT)
	Pix.hline(c, 227, 32, 11, Pal.NIGHT)
	Pix.vline(c, 306, 6, 26, Pal.NIGHT)
	Pix.hline(c, 300, 10, 13, Pal.NIGHT)
	Pix.hline(c, 302, 16, 9, Pal.NIGHT)
	Pix.px(c, 306, 5, Pal.CORAL)
	# 電線
	for x in range(232, 306):
		var sag := 4 - absi(x - 269) / 12
		Pix.blend(c, x, 26 + sag, Pal.INK, 0.6)


static func _hill(c: Image, x: int, base_y: int, width: int, height: int, color: Color) -> void:
	for i in range(width):
		var t := float(i) / float(width)
		var rise := int(sin(t * PI) * height)
		Pix.vline(c, x + i, base_y - rise, rise, color)


## ---------- 戰鬥背景：潮霧古道（林緣） ----------

static func _battle_bg_trail(path: String) -> void:
	var c := Pix.img(W, H)
	# 背景層：霧天與遠山
	Pix.rect(c, 0, 0, W, 64, Pal.FOG)
	Pix.dither(c, 0, 36, W, 18, Pal.FOG, Pal.MIST_LT)
	_hill(c, -20, 66, 180, 30, Pal.MIST)
	_hill(c, 140, 66, 200, 40, Pal.MIST_DK)
	_mist_band(c, 0, 56, W, 4, 0.45)
	# 中景：樹冠層
	var r := Pix.rng(52)
	for i in range(14):
		var x := r.randi_range(-10, W - 20)
		var y := r.randi_range(52, 66)
		Pix.ellipse(c, x + 15, y, r.randf_range(12, 22), r.randf_range(7, 11), Pal.MOSS_DK)
	for i in range(10):
		var x := r.randi_range(0, W - 30)
		var y := r.randi_range(58, 70)
		Pix.ellipse(c, x + 12, y, r.randf_range(8, 15), r.randf_range(5, 8), Pal.MOSS)
	# 草地
	Pix.rect(c, 0, 70, W, 110, Pal.LEAF)
	Pix.dither(c, 0, 70, W, 10, Pal.MOSS, Pal.LEAF)
	Pix.speckle(c, 0, 80, W, 100, Pal.LEAF_LT, 90, 53)
	Pix.speckle(c, 0, 80, W, 100, Pal.MOSS, 70, 54)
	# 高草叢簇（中景）
	for i in range(8):
		var x := r.randi_range(0, W - 24)
		var y := r.randi_range(84, 100)
		_grass_tuft(c, x, y, Pal.MOSS, Pal.LEAF)
	# 敵我站位基座（接地感）
	_platform(c, 240, 86, 46, 12)
	_platform(c, 76, 152, 54, 14)
	# 前景：兩側芭蕉葉與高草（框住畫面）
	_banana_leaves(c, -6, 118, false)
	_banana_leaves(c, 276, 108, true)
	for i in range(6):
		_grass_tuft(c, 10 + i * 6, 164 + (i % 3) * 3, Pal.MOSS_DK, Pal.MOSS)
	for i in range(5):
		_grass_tuft(c, 250 + i * 12, 168, Pal.MOSS_DK, Pal.MOSS)
	# 薄霧（混色）
	_mist_band(c, 0, 74, W, 2, 0.25)
	_mist_band(c, 40, 90, 200, 2, 0.2)
	Pix.save(c, path)


## ---------- 戰鬥背景：霧港村（石板廣場） ----------

static func _battle_bg_village(path: String) -> void:
	var c := Pix.img(W, H)
	Pix.rect(c, 0, 0, W, 60, Pal.FOG)
	Pix.dither(c, 0, 34, W, 16, Pal.FOG, Pal.MIST_LT)
	_hill(c, 180, 62, 160, 26, Pal.MIST)
	# 村屋剪影（中景，比標題近）
	for h: Array in [[10, 34, 46, 28, true], [70, 42, 40, 20, false], [250, 38, 50, 24, true]]:
		var hx := int(h[0])
		var hy := int(h[1])
		var hw := int(h[2])
		var hh := int(h[3])
		var tin := bool(h[4])
		Pix.rect(c, hx, hy, hw, hh, Pal.MIST_DK)
		var roof_color := Pal.RUST if tin else Pal.BRICK
		for i in range(6):
			Pix.hline(c, hx - 2 + i, hy - 6 + i, hw + 4 - i * 2, roof_color)
		Pix.rect(c, hx + 6, hy + 8, 5, 6, Pal.AMBER)
		Pix.rect(c, hx + hw - 12, hy + 8, 5, 6, Pal.NIGHT)
	# 電線
	for x in range(0, W):
		Pix.blend(c, x, 28 + ((x / 40) % 2), Pal.INK, 0.5)
	# 石板地
	Pix.rect(c, 0, 62, W, 118, Pal.MIST)
	Pix.speckle(c, 0, 66, W, 114, Pal.MIST_LT, 110, 55)
	Pix.speckle(c, 0, 66, W, 114, Pal.MIST_DK, 80, 56)
	var r := Pix.rng(57)
	for i in range(16):
		Pix.hline(c, r.randi_range(0, W - 30), 70 + i * 7, r.randi_range(16, 30), Pal.MIST_DK)
	_platform(c, 240, 86, 46, 12)
	_platform(c, 76, 152, 54, 14)
	# 前景：石牆角與盆栽
	Pix.rect(c, 0, 150, 40, 30, Pal.MIST_DK)
	Pix.rect(c, 0, 146, 40, 4, Pal.MIST_LT)
	Pix.px(c, 12, 154, Pal.MOSS)
	Pix.px(c, 26, 160, Pal.MOSS)
	Pix.rect(c, 290, 154, 30, 26, Pal.MIST_DK)
	Pix.rect(c, 290, 150, 30, 4, Pal.MIST_LT)
	Pix.save(c, path)


static func _platform(c: Image, cx: int, cy: int, rx: int, ry: int) -> void:
	for y in range(cy - ry, cy + ry + 1):
		for x in range(cx - rx, cx + rx + 1):
			var dx := (float(x) - cx) / float(rx)
			var dy := (float(y) - cy) / float(ry)
			var d := dx * dx + dy * dy
			if d <= 1.0 and x >= 0 and y >= 0 and x < W and y < H:
				if d > 0.72:
					Pix.blend(c, x, y, Pal.MOSS_DK, 0.4)
				elif (x + y) % 2 == 0:
					Pix.blend(c, x, y, Pal.MOSS_DK, 0.22)


static func _grass_tuft(c: Image, x: int, y: int, dark: Color, mid: Color) -> void:
	for i in range(5):
		var bx := x + i * 3
		Pix.vline(c, bx, y - 6 - (i % 2) * 2, 8, dark if i % 2 == 0 else mid)
		Pix.px(c, bx + (1 if i % 2 == 0 else -1), y - 8 - (i % 2), mid)


static func _banana_leaves(c: Image, x: int, y: int, flip: bool) -> void:
	var dir := -1 if flip else 1
	for leaf in range(3):
		var base_x := x + (20 if not flip else 30)
		var base_y := y + leaf * 18
		for i in range(26):
			var lx := base_x + i * dir
			var ly := base_y + i / 3 + leaf * 2
			Pix.rect(c, lx, ly, 2, 5 - i / 8, Pal.MOSS_DK)
			if i % 4 < 2:
				Pix.px(c, lx, ly, Pal.MOSS)


## ---------- 色盤圖 ----------

static func _palette_sheet(path: String) -> void:
	var cols := 8
	var cell := 22
	var rows := int(ceil(float(Pal.ORDER.size()) / cols))
	var c := Pix.img(cols * cell, rows * cell)
	Pix.rect(c, 0, 0, cols * cell, rows * cell, Pal.NIGHT)
	for i in range(Pal.ORDER.size()):
		var entry: Array = Pal.ORDER[i]
		var x := (i % cols) * cell
		var y := (i / cols) * cell
		Pix.rect(c, x + 1, y + 1, cell - 2, cell - 2, entry[1])
	Pix.save(c, path)
