class_name GenPortraits
extends RefCounted
## 角色立繪（胸像 40×48）：統一構圖（頭部中上、肩線在底）、左上光源、
## 全域色盤、INK 外描邊。表情由眉／眼／口參數組合，不只換嘴型。
## 輸出：assets/portraits/<char>_<expr>.png

const W := 40
const H := 48


static func generate() -> void:
	var player_cfg := {
		"skin": Pal.SKIN, "skin_dk": Pal.SKIN_DK, "hair": Pal.WOOD_DK,
		"hat": "cap", "hat_color": Pal.CORAL, "hat_dark": Pal.BRICK_DK,
		"coat": Pal.SEA_DK, "coat_lt": Pal.SEA, "collar": Pal.FOG, "strap": Pal.WOOD_DK,
	}
	var rei_cfg := {
		"skin": Pal.SKIN, "skin_dk": Pal.SKIN_DK, "hair": Pal.NIGHT,
		"hat": "bun", "coat": Pal.STEEL, "coat_lt": Pal.MIST, "collar": Pal.FOG,
		"scarf": Pal.FOG, "glasses": true,
	}
	var haibo_cfg := {
		"skin": Pal.SKIN_DK, "skin_dk": Pal.WOOD_LT, "hair": Pal.GRAY,
		"hat": "straw", "hat_color": Pal.SAND_LT, "hat_dark": Pal.SAND_DK,
		"coat": Pal.PAPER, "coat_lt": Pal.FOAM, "collar": Pal.PAPER_DIM,
		"apron": Pal.BRICK, "old": true,
	}
	for expr: String in ["neutral", "focused", "surprised", "worried", "determined"]:
		_portrait("player", player_cfg, expr)
	for expr: String in ["neutral", "thinking", "urgent", "relieved"]:
		_portrait("rei", rei_cfg, expr)
	for expr: String in ["neutral", "doubt", "sad", "smile"]:
		_portrait("haibo", haibo_cfg, expr)


static func _portrait(char_name: String, cfg: Dictionary, expr: String) -> void:
	var c := Pix.img(W, H)
	_bust(c, cfg)
	_face(c, cfg, expr)
	Pix.outline_sprite(c)
	Pix.save(c, "res://assets/portraits/%s_%s.png" % [char_name, expr])


## 基底：肩、頸、頭、髮、帽、衣領
static func _bust(c: Image, cfg: Dictionary) -> void:
	var skin: Color = cfg["skin"]
	var skin_dk: Color = cfg["skin_dk"]
	var hair: Color = cfg["hair"]
	# 肩與胸（大衣）
	Pix.rect(c, 4, 36, 32, 12, cfg["coat"])
	Pix.rect(c, 4, 36, 12, 12, cfg["coat_lt"])
	Pix.hline(c, 4, 36, 32, cfg["coat_lt"])
	# 領口
	Pix.rect(c, 15, 35, 10, 4, cfg["collar"])
	if cfg.has("scarf"):
		Pix.rect(c, 10, 34, 20, 5, cfg["scarf"])
		Pix.hline(c, 10, 38, 20, Pal.PAPER_DIM)
	if cfg.has("apron"):
		Pix.rect(c, 12, 41, 16, 7, cfg["apron"])
		Pix.hline(c, 12, 41, 16, Pal.BRICK_LT)
	if cfg.has("strap"):
		for i in range(10):
			Pix.px(c, 8 + i, 38 + i / 2, cfg["strap"])
	# 頸
	Pix.rect(c, 17, 32, 6, 4, skin_dk)
	# 頭（橢圓臉）
	Pix.ellipse(c, 20, 20, 11, 13, skin)
	Pix.ellipse(c, 15.5, 15.5, 4.5, 5.0, Color(skin).lightened(0.08))
	# 顴影
	Pix.px(c, 11, 26, skin_dk)
	Pix.px(c, 29, 26, skin_dk)
	if bool(cfg.get("old", false)):
		Pix.hline(c, 13, 28, 3, skin_dk)
		Pix.hline(c, 24, 28, 3, skin_dk)
	# 髮／帽
	match String(cfg.get("hat", "")):
		"cap":
			Pix.ellipse(c, 20, 12, 11, 6, cfg["hat_color"])
			Pix.rect(c, 8, 12, 24, 3, cfg["hat_dark"])
			Pix.hline(c, 9, 8, 22, Color(cfg["hat_color"]).lightened(0.15))
			Pix.rect(c, 9, 15, 4, 6, hair)
			Pix.rect(c, 27, 15, 4, 6, hair)
		"straw":
			Pix.ellipse(c, 20, 11, 15, 5, cfg["hat_color"])
			Pix.hline(c, 5, 13, 30, cfg["hat_dark"])
			Pix.ellipse(c, 20, 7, 9, 4, cfg["hat_color"])
			Pix.rect(c, 9, 15, 3, 5, hair)
			Pix.rect(c, 28, 15, 3, 5, hair)
		"bun":
			Pix.ellipse(c, 20, 11, 11, 5, hair)
			Pix.rect(c, 9, 11, 4, 12, hair)
			Pix.rect(c, 27, 11, 4, 12, hair)
			Pix.ellipse(c, 31, 8, 4, 3.5, hair)
			Pix.px(c, 30, 6, Color(hair).lightened(0.2))
		_:
			Pix.ellipse(c, 20, 12, 11, 6, hair)


## 表情：眉（角度）＋眼（開度）＋口（形狀），必要時附輔助記號
static func _face(c: Image, cfg: Dictionary, expr: String) -> void:
	var ink := Pal.INK
	var skin_dk: Color = cfg["skin_dk"]
	var lx := 14  # 左眼中心 x
	var rx := 26
	var ey := 21  # 眼線 y
	var glasses := bool(cfg.get("glasses", false))
	if glasses:
		Pix.outline_rect(c, lx - 3, ey - 3, 7, 6, Pal.MIST_DK)
		Pix.outline_rect(c, rx - 3, ey - 3, 7, 6, Pal.MIST_DK)
		Pix.hline(c, lx + 4, ey - 1, 5, Pal.MIST_DK)
	match expr:
		"neutral":
			_brow(c, lx, rx, ey - 5, 0)
			_eyes_open(c, lx, rx, ey, 3)
			Pix.hline(c, 18, 30, 5, ink)
		"focused":
			_brow(c, lx, rx, ey - 4, -1)
			_eyes_open(c, lx, rx, ey, 2)
			Pix.hline(c, 18, 30, 5, ink)
		"surprised":
			_brow(c, lx, rx, ey - 7, 1)
			_eyes_open(c, lx, rx, ey, 4)
			Pix.ellipse(c, 20, 31, 2, 2.4, ink)
			Pix.px(c, 20, 30, Pal.BRICK_DK)
		"worried":
			_brow(c, lx, rx, ey - 5, 2)
			_eyes_open(c, lx, rx, ey, 3)
			Pix.hline(c, 18, 31, 5, ink)
			Pix.px(c, 17, 30, ink)
			Pix.px(c, 23, 30, ink)
			Pix.px(c, 31, 14, Pal.SEA_PALE)
		"determined":
			_brow(c, lx, rx, ey - 4, -2)
			_eyes_open(c, lx, rx, ey, 3)
			Pix.hline(c, 17, 30, 7, ink)
			Pix.px(c, 16, 31, ink)
			Pix.px(c, 24, 31, ink)
		"thinking":
			_brow(c, lx, rx, ey - 5, 0)
			Pix.hline(c, lx - 2, ey, 5, ink)  # 左眼半閉
			_eye_open_single(c, rx, ey, 3)
			Pix.hline(c, 18, 30, 4, ink)
			Pix.px(c, 30, 33, ink)
			Pix.px(c, 32, 31, ink)
		"urgent":
			_brow(c, lx, rx, ey - 4, -2)
			_eyes_open(c, lx, rx, ey, 3)
			Pix.rect(c, 18, 30, 5, 2, ink)
		"relieved":
			_brow(c, lx, rx, ey - 5, 1)
			Pix.hline(c, lx - 2, ey, 5, ink)
			Pix.hline(c, rx - 2, ey, 5, ink)
			Pix.px(c, lx - 3, ey - 1, ink)
			Pix.px(c, lx + 3, ey - 1, ink)
			Pix.px(c, rx - 3, ey - 1, ink)
			Pix.px(c, rx + 3, ey - 1, ink)
			_smile(c, 20, 30)
		"doubt":
			Pix.hline(c, lx - 2, ey - 6, 5, ink)  # 左眉抬
			Pix.hline(c, rx - 2, ey - 4, 5, ink)
			_eyes_open(c, lx, rx, ey, 2)
			Pix.hline(c, 18, 30, 4, ink)
			Pix.px(c, 22, 31, ink)
		"sad":
			_brow(c, lx, rx, ey - 5, 2)
			_eyes_open(c, lx, rx, ey, 2)
			Pix.hline(c, 18, 31, 5, ink)
			Pix.px(c, 17, 30, ink)
			Pix.px(c, 23, 30, ink)
		"smile":
			_brow(c, lx, rx, ey - 5, 1)
			Pix.hline(c, lx - 2, ey, 5, ink)
			Pix.hline(c, rx - 2, ey, 5, ink)
			Pix.px(c, lx - 3, ey - 1, ink)
			Pix.px(c, lx + 3, ey - 1, ink)
			Pix.px(c, rx - 3, ey - 1, ink)
			Pix.px(c, rx + 3, ey - 1, ink)
			_smile(c, 20, 29)
			Pix.px(c, 12, 27, skin_dk)
			Pix.px(c, 28, 27, skin_dk)
		_:
			_eyes_open(c, lx, rx, ey, 3)


## 眉：tilt <0 內壓（怒／專注）、>0 內揚（憂／驚）
static func _brow(c: Image, lx: int, rx: int, y: int, tilt: int) -> void:
	for i in range(5):
		var offset := 0
		if tilt < 0:
			offset = (i - 2) * -tilt / 2
		elif tilt > 0:
			offset = (2 - i) * tilt / 2
		Pix.px(c, lx - 2 + i, y + offset, Pal.INK)
		Pix.px(c, rx + 2 - i, y + offset, Pal.INK)


static func _eyes_open(c: Image, lx: int, rx: int, y: int, height: int) -> void:
	_eye_open_single(c, lx, y, height)
	_eye_open_single(c, rx, y, height)


static func _eye_open_single(c: Image, x: int, y: int, height: int) -> void:
	Pix.rect(c, x - 2, y - height / 2, 5, height, Pal.INK)
	Pix.px(c, x - 1, y - height / 2, Pal.FOAM)


static func _smile(c: Image, x: int, y: int) -> void:
	Pix.px(c, x - 3, y, Pal.INK)
	Pix.px(c, x - 2, y + 1, Pal.INK)
	Pix.hline(c, x - 1, y + 2, 3, Pal.INK)
	Pix.px(c, x + 2, y + 1, Pal.INK)
	Pix.px(c, x + 3, y, Pal.INK)
